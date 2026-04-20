#!/usr/bin/env python3
import json
import os
import sqlite3
import sys
from datetime import datetime, time as dt_time, timezone
from pathlib import Path
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import urlopen


DB_PATH = Path("/var/lib/weewx/weewx.sdb")
STATE_PATH = Path("/var/lib/weewx/windy-upload-state.json")
API_URL = "https://stations.windy.com/api/v2/observation/update"


def f_to_c(value):
    return (value - 32.0) * (5.0 / 9.0)


def mph_to_ms(value):
    return value * 0.44704


def inhg_to_pa(value):
    return value * 3386.389


def inch_to_mm(value):
    return value * 25.4


def round_num(value, digits=1):
    return round(float(value), digits)


def load_config():
    station_id = os.environ["WINDY_STATION_ID"].strip()
    password = os.environ["WINDY_STATION_PASSWORD"].strip()
    return station_id, password


def load_state():
    if not STATE_PATH.exists():
        return {}
    try:
        return json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_state(payload):
    STATE_PATH.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def connect_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def fetch_latest_row(conn):
    row = conn.execute("select * from archive order by dateTime desc limit 1").fetchone()
    if row is None:
        raise RuntimeError("No archive rows found")
    return row


def local_midnight_epoch(epoch):
    local_dt = datetime.fromtimestamp(epoch).astimezone()
    midnight = datetime.combine(local_dt.date(), dt_time.min, tzinfo=local_dt.tzinfo)
    return int(midnight.timestamp())


def daily_precip_mm(conn, row_epoch):
    start_epoch = local_midnight_epoch(row_epoch)
    value = conn.execute(
        """
        select coalesce(sum(rain), 0.0)
        from archive
        where dateTime >= ? and dateTime <= ?
        """,
        (start_epoch, row_epoch),
    ).fetchone()[0]
    return round_num(inch_to_mm(value), 1)


def build_params(conn, row, station_id, password):
    epoch = int(row["dateTime"])
    params = {
        "id": station_id,
        "PASSWORD": password,
        "ts": epoch,
        "softwaretype": "weewx-windy-bridge/1.0",
    }

    if row["outTemp"] is not None:
        params["temp"] = round_num(f_to_c(row["outTemp"]), 1)
    if row["dewpoint"] is not None:
        params["dewpoint"] = round_num(f_to_c(row["dewpoint"]), 1)
    if row["outHumidity"] is not None:
        params["humidity"] = int(round(row["outHumidity"]))
    if row["windSpeed"] is not None:
        params["wind"] = round_num(mph_to_ms(row["windSpeed"]), 1)
    if row["windGust"] is not None:
        params["gust"] = round_num(mph_to_ms(row["windGust"]), 1)
    if row["windDir"] is not None:
        params["winddir"] = int(round(row["windDir"])) % 360
    pressure_source = row["barometer"] if row["barometer"] is not None else row["pressure"]
    if pressure_source is not None:
        params["pressure"] = int(round(inhg_to_pa(pressure_source)))
    params["precip"] = daily_precip_mm(conn, epoch)
    if row["UV"] is not None:
        params["uv"] = round_num(row["UV"], 1)
    if row["radiation"] is not None:
        params["solarradiation"] = int(round(row["radiation"]))

    return params


def post_observation(params):
    url = f"{API_URL}?{urlencode(params)}"
    try:
        with urlopen(url, timeout=30) as response:
            body = response.read().decode("utf-8", errors="replace")
            return response.status, body, url
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return exc.code, body, url


def main():
    station_id, password = load_config()
    state = load_state()

    with connect_db() as conn:
        row = fetch_latest_row(conn)
        latest_epoch = int(row["dateTime"])
        if latest_epoch <= int(state.get("last_uploaded_epoch", 0)):
            print(f"No new archive row to upload. latest={latest_epoch}")
            return 0

        params = build_params(conn, row, station_id, password)
        status, body, url = post_observation(params)
        payload = {
            "last_attempt_utc": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "last_uploaded_epoch": latest_epoch,
            "last_uploaded_utc": datetime.fromtimestamp(latest_epoch, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "last_status": status,
            "last_response": body[:500],
            "last_url_without_password": url.replace(password, "REDACTED"),
        }
        save_state(payload)
        if status == 200:
            print(f"Windy upload OK status={status} ts={latest_epoch}")
            return 0
        raise RuntimeError(f"Windy upload failed status={status}: {body[:300]}")


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as exc:
        print(str(exc), file=sys.stderr)
        sys.exit(1)
