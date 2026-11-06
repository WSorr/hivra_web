#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")

if [ "$#" -ne 1 ] || [ -e "$1" ]; then
  echo "Usage: $0 NEW_DESTINATION_DIRECTORY" >&2
  exit 2
fi

destination=$1
mkdir -p -- "$destination"

for file in index.html about.html network-v2.html support.html style.css robots.txt sitemap.xml; do
  if [ ! -f "$ROOT_DIR/$file" ] || [ -L "$ROOT_DIR/$file" ]; then
    echo "Missing regular public file: $file" >&2
    exit 1
  fi
  cp -- "$ROOT_DIR/$file" "$destination/$file"
done

cp -R -- "$ROOT_DIR/pictures" "$destination/pictures"
if find "$destination" -type l -print | grep -q .; then
  echo "Public assets must not contain symbolic links." >&2
  exit 1
fi
find "$destination" -type d -exec chmod 755 {} +
find "$destination" -type f -exec chmod 644 {} +
