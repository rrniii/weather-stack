#!/bin/sh
set -eu

systemctl is-active nginx
systemctl is-active postgresql
systemctl is-active website-freshness.timer
systemctl is-active weewx-postgres-replication.timer

curl -I http://localhost/status/index.html
psql -d weewx -Atqc 'select count(*), max("dateTime") from archive;'
