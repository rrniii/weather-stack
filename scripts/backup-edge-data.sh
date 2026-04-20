#!/bin/sh
set -eu

DEST="${1:-./edge-backup}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"

mkdir -p "$DEST"
sqlite3 /var/lib/weewx/weewx.sdb ".backup '$DEST/weewx-${STAMP}.sdb'"
