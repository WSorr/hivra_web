#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
PYTHON_BIN=${PYTHON_BIN:-python3}
PUBLIC_BASE_URL=${1:-}
PORT=${PORT:-8765}
SERVER_PID=

cleanup() {
  if [ -n "$SERVER_PID" ]; then
    kill "$SERVER_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

for file in \
  index.html \
  about.html \
  network-v2.html \
  support.html \
  style.css \
  robots.txt \
  sitemap.xml \
  README.md \
  scripts/run.sh; do
  if [ ! -f "$ROOT_DIR/$file" ]; then
    echo "Missing required file: $file" >&2
    exit 1
  fi
done

sh -n "$ROOT_DIR/scripts/run.sh" "$ROOT_DIR/scripts/ci-site.sh"

if [ -z "$PUBLIC_BASE_URL" ]; then
  PUBLIC_BASE_URL="http://127.0.0.1:$PORT/"
  (
    cd "$ROOT_DIR"
    "$PYTHON_BIN" -m http.server "$PORT" >/tmp/hivra_web_smoke_server.log 2>&1
  ) &
  SERVER_PID=$!

  attempts=0
  until "$PYTHON_BIN" - "$PUBLIC_BASE_URL" <<'PY'
import sys
import urllib.request

with urllib.request.urlopen(sys.argv[1], timeout=1):
    pass
PY
  do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 20 ]; then
      echo "Local site server did not start" >&2
      exit 1
    fi
    sleep 0.25
  done
fi

"$PYTHON_BIN" - "$PUBLIC_BASE_URL" <<'PY'
from __future__ import annotations

from html.parser import HTMLParser
import re
import socket
import ssl
import sys
import time
import urllib.parse
import urllib.request


BASE_URL = sys.argv[1]
REQUIRED_PATHS = (
    "index.html",
    "about.html",
    "network-v2.html",
    "support.html",
    "robots.txt",
    "sitemap.xml",
)
IGNORED_SCHEMES = {"data", "javascript", "mailto", "tel"}
MAX_BYTES = 5 * 1024 * 1024


class References(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.values: list[str] = []

    def handle_starttag(self, _tag: str, attrs: list[tuple[str, str | None]]) -> None:
        for name, value in attrs:
            if name in {"href", "src"} and value:
                self.values.append(value.strip())


def fetch(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "hivra-site-smoke/1"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.getcode()
            body = response.read(MAX_BYTES + 1)
            content_type = response.headers.get_content_type()
    except Exception as error:
        print(f"FAIL {url}: {error}", file=sys.stderr)
        raise SystemExit(1) from None
    if status != 200:
        raise RuntimeError(f"{url}: HTTP {status}")
    if not body:
        raise RuntimeError(f"{url}: empty response")
    if len(body) > MAX_BYTES:
        raise RuntimeError(f"{url}: response exceeds {MAX_BYTES} bytes")
    return body, content_type


def local_url(reference: str, source_url: str) -> str | None:
    if not reference or reference.startswith("#"):
        return None
    resolved = urllib.parse.urljoin(source_url, reference)
    parsed = urllib.parse.urlparse(resolved)
    if parsed.scheme in IGNORED_SCHEMES:
        return None
    base = urllib.parse.urlparse(BASE_URL)
    if parsed.scheme not in {"http", "https"}:
        raise RuntimeError(f"{source_url}: unsupported reference {reference!r}")
    if (parsed.scheme, parsed.netloc) != (base.scheme, base.netloc):
        return None
    return urllib.parse.urlunparse(parsed._replace(fragment="", query=""))


def check_tls() -> None:
    parsed = urllib.parse.urlparse(BASE_URL)
    if parsed.scheme != "https":
        return
    host = parsed.hostname
    if not host:
        raise RuntimeError("HTTPS base URL has no host")
    port = parsed.port or 443
    context = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=15) as connection:
        with context.wrap_socket(connection, server_hostname=host) as tls:
            certificate = tls.getpeercert()
    expires_at = ssl.cert_time_to_seconds(certificate["notAfter"])
    remaining_days = int((expires_at - time.time()) // 86400)
    if remaining_days < 14:
        raise RuntimeError(f"TLS certificate expires in {remaining_days} days")
    print(f"OK TLS certificate: {remaining_days} days remaining")


check_tls()
queue = [urllib.parse.urljoin(BASE_URL, path) for path in REQUIRED_PATHS]
seen: set[str] = set()

while queue:
    url = queue.pop(0)
    if url in seen:
        continue
    seen.add(url)
    body, content_type = fetch(url)
    print(f"OK {url} [{content_type}]")

    text = body.decode("utf-8", errors="strict") if content_type.startswith("text/") else ""
    references: list[str] = []
    if content_type == "text/html" or urllib.parse.urlparse(url).path.endswith(".html"):
        parser = References()
        parser.feed(text)
        references.extend(parser.values)
    if content_type == "text/css" or urllib.parse.urlparse(url).path.endswith(".css"):
        references.extend(re.findall(r"url\(\s*['\"]?([^'\")]+)", text))

    for reference in references:
        resolved = local_url(reference, url)
        if resolved and resolved not in seen and resolved not in queue:
            queue.append(resolved)

print(f"site verification passed: {len(seen)} public resources")
PY
