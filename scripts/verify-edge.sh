#!/bin/sh
set -eu

systemctl is-active weewx
systemctl is-active push-weewx-site.timer
systemctl is-active edge-freshness.timer
systemctl is-active windy-upload.timer

stat /var/www/html/weewx/index.html
sqlite3 /var/lib/weewx/weewx.sdb 'select count(*), max(dateTime) from archive;'
