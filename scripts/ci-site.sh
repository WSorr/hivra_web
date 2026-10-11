#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
PYTHON_BIN=${PYTHON_BIN:-python3}
PUBLIC_BASE_URL=${1:-}

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

"$PYTHON_BIN" - "$ROOT_DIR" "$PUBLIC_BASE_URL" <<'PY'
from __future__ import annotations

from html.parser import HTMLParser
import mimetypes
import os
from pathlib import Path
import re
import socket
import ssl
import sys
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ElementTree


ROOT_DIR = Path(sys.argv[1]).resolve()
PUBLIC_BASE_URL = sys.argv[2]
REMOTE = bool(PUBLIC_BASE_URL)
BASE_URL = PUBLIC_BASE_URL.rstrip("/") + "/" if REMOTE else "https://source.invalid/"
CANONICAL_BASE_URL = "https://hivra.space/"
CANONICAL_SITEMAP_URL = urllib.parse.urljoin(CANONICAL_BASE_URL, "sitemap.xml")
REQUIRED_PATHS = (
    "index.html",
    "about.html",
    "network-v2.html",
    "support.html",
    "robots.txt",
    "sitemap.xml",
)
EXPECTED_SITEMAP_URLS = {
    CANONICAL_BASE_URL,
    urllib.parse.urljoin(CANONICAL_BASE_URL, "about.html"),
    urllib.parse.urljoin(CANONICAL_BASE_URL, "network-v2.html"),
    urllib.parse.urljoin(CANONICAL_BASE_URL, "support.html"),
}
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


def fail(message: str) -> None:
    print(f"FAIL {message}", file=sys.stderr)
    raise SystemExit(1)


def validate_body(url: str, body: bytes) -> None:
    if not body:
        fail(f"{url}: empty response")
    if len(body) > MAX_BYTES:
        fail(f"{url}: response exceeds {MAX_BYTES} bytes")


def local_file(url: str) -> tuple[bytes, str]:
    parsed = urllib.parse.urlparse(url)
    relative_path = urllib.parse.unquote(parsed.path).lstrip("/") or "index.html"
    target = (ROOT_DIR / relative_path).resolve()
    if os.path.commonpath((str(ROOT_DIR), str(target))) != str(ROOT_DIR):
        fail(f"{url}: path escapes the source tree")
    if not target.is_file():
        fail(f"{url}: missing source file {relative_path}")
    with target.open("rb") as source:
        body = source.read(MAX_BYTES + 1)
    validate_body(url, body)
    content_type = mimetypes.guess_type(target.name)[0] or "application/octet-stream"
    return body, content_type


def remote_file(url: str) -> tuple[bytes, str]:
    request = urllib.request.Request(url, headers={"User-Agent": "hivra-site-smoke/1"})
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.getcode()
            final_url = response.geturl()
            body = response.read(MAX_BYTES + 1)
            content_type = response.headers.get_content_type()
    except Exception as error:
        fail(f"{url}: {error}")
    if status != 200:
        fail(f"{url}: HTTP {status}")
    final = urllib.parse.urlparse(final_url)
    base = urllib.parse.urlparse(BASE_URL)
    if (final.scheme, final.netloc) != (base.scheme, base.netloc):
        fail(f"{url}: redirected outside {base.netloc}")
    validate_body(url, body)
    return body, content_type


def fetch(url: str) -> tuple[bytes, str]:
    return remote_file(url) if REMOTE else local_file(url)


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
    if not REMOTE:
        return
    parsed = urllib.parse.urlparse(BASE_URL)
    if parsed.scheme != "https":
        fail("public verification requires HTTPS")
    host = parsed.hostname
    if not host:
        fail("HTTPS base URL has no host")
    port = parsed.port or 443
    context = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=15) as connection:
        with context.wrap_socket(connection, server_hostname=host) as tls:
            certificate = tls.getpeercert()
    expires_at = ssl.cert_time_to_seconds(certificate["notAfter"])
    remaining_days = int((expires_at - time.time()) // 86400)
    if remaining_days < 14:
        fail(f"TLS certificate expires in {remaining_days} days")
    print(f"OK TLS certificate: {remaining_days} days remaining")


def validate_robots(text: str) -> None:
    sitemap_urls = set()
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        name, separator, value = line.partition(":")
        if separator and name.strip().lower() == "sitemap":
            sitemap_urls.add(value.strip())
    if CANONICAL_SITEMAP_URL not in sitemap_urls:
        fail(f"robots.txt must reference {CANONICAL_SITEMAP_URL}")


def validate_sitemap(text: str) -> set[str]:
    try:
        root = ElementTree.fromstring(text)
    except ElementTree.ParseError as error:
        fail(f"sitemap.xml: invalid XML: {error}")
    locations = {
        element.text.strip()
        for element in root.iter()
        if element.tag.rsplit("}", 1)[-1] == "loc" and element.text
    }
    missing = EXPECTED_SITEMAP_URLS - locations
    if missing:
        fail(f"sitemap.xml: missing URLs: {', '.join(sorted(missing))}")
    for location in locations:
        parsed = urllib.parse.urlparse(location)
        canonical = urllib.parse.urlparse(CANONICAL_BASE_URL)
        if (parsed.scheme, parsed.netloc) != (canonical.scheme, canonical.netloc):
            fail(f"sitemap.xml: non-canonical URL {location}")
    return locations


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

    path = urllib.parse.urlparse(url).path
    is_text = content_type.startswith("text/") or path.endswith((".html", ".css", ".txt", ".xml"))
    text = body.decode("utf-8", errors="strict") if is_text else ""
    references: list[str] = []
    if content_type == "text/html" or path.endswith(".html"):
        parser = References()
        parser.feed(text)
        references.extend(parser.values)
    if content_type == "text/css" or path.endswith(".css"):
        references.extend(re.findall(r"url\(\s*['\"]?([^'\")]+)", text))
    if path.endswith("robots.txt"):
        validate_robots(text)
    if path.endswith("sitemap.xml"):
        for location in validate_sitemap(text):
            if REMOTE:
                references.append(location)
            else:
                location_path = urllib.parse.urlparse(location).path.lstrip("/")
                references.append(location_path or "index.html")

    for reference in references:
        resolved = local_url(reference, url)
        if resolved and resolved not in seen and resolved not in queue:
            queue.append(resolved)

print(f"site verification passed: {len(seen)} public resources")
PY
