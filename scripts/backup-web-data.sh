#!/bin/sh
set -eu

DEST="${1:-./web-backup}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$DEST"
pg_dump -Fc weewx > "$DEST/weewx-${STAMP}.dump"
