#!/bin/sh
set -eu
umask 0002

WEB_ROOT=/var/www/CAAGAWX.org
STATUS_DIR="$WEB_ROOT/status"
INDEX_FILE="$WEB_ROOT/index.html"
MAX_AGE_SECONDS="${MAX_AGE_SECONDS:-900}"

mkdir -p "$STATUS_DIR"

now_epoch="$(date -u +%s)"
now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
index_mtime="$(stat -c %Y "$INDEX_FILE")"
index_iso="$(date -u -d "@$index_mtime" +%Y-%m-%dT%H:%M:%SZ)"
index_age="$((now_epoch - index_mtime))"

health="ok"
if [ "$index_age" -gt "$MAX_AGE_SECONDS" ]; then
    health="stale"
    logger -t update-web-status "Website index is stale: age=${index_age}s path=${INDEX_FILE}"
fi

python3 - "$STATUS_DIR/webserver-status.json" "$STATUS_DIR/index.html" "$STATUS_DIR/edge-status.json" "$STATUS_DIR/edge-push-status.json" "$STATUS_DIR/postgres-replication-status.json" "$now_iso" "$now_epoch" "$index_iso" "$index_mtime" "$index_age" "$health" <<'PY'
import html
import json
import socket
import sys
from pathlib import Path

json_path, html_path, edge_path, push_path, repl_path, now_iso, now_epoch, index_iso, index_mtime, index_age, health = sys.argv[1:]

web_payload = {
    "host": socket.gethostname(),
    "generated_at_utc": now_iso,
    "generated_at_epoch": int(now_epoch),
    "health": health,
    "checks": {
        "website_index": {
            "path": "/var/www/CAAGAWX.org/index.html",
            "mtime_utc": index_iso,
            "mtime_epoch": int(index_mtime),
            "age_seconds": int(index_age),
        }
    },
}
Path(json_path).write_text(json.dumps(web_payload, indent=2, sort_keys=True) + "\n", encoding="ascii")


def load(path_str):
    path = Path(path_str)
    if not path.exists():
        return {}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}


def age_text(value):
    if not isinstance(value, int) or value < 0:
        return "n/a"
    if value < 60:
        return f"{value}s"
    m, s = divmod(value, 60)
    if m < 60:
        return f"{m}m {s}s"
    h, m = divmod(m, 60)
    return f"{h}h {m}m"


def chip(value):
    cls = "chip"
    if value in {"stale", "attention", "error"}:
        cls += " warn"
    return f'<span class="{cls}">{html.escape(str(value))}</span>'


def esc(value):
    return html.escape(str(value))

edge = load(edge_path)
push = load(push_path)
repl = load(repl_path)
battery = edge.get("checks", {}).get("battery", {})
edge_checks = edge.get("checks", {})

battery_summary = battery.get("summary", "unknown")
battery_sample = battery.get("record_time_utc", "n/a")
battery_alerts = battery.get("attention_items", [])
if not battery_alerts:
    battery_alerts_html = "<li>None</li>"
else:
    battery_alerts_html = "".join(f"<li>{esc(item)}</li>" for item in battery_alerts)

latest_battery = battery.get("latest_record", {})
tx_value = latest_battery.get("txBatteryStatus")
if tx_value is None:
    tx_display = "n/a"
else:
    tx_display = "OK (0)" if float(tx_value) == 0.0 else f"Needs attention ({tx_value})"
console_display = latest_battery.get("consBatteryVoltage", "n/a")

repl_result = repl.get("result", "unknown")
repl_latest = repl.get("web_latest_utc_after", "n/a")
repl_rows = repl.get("rows_imported", "n/a")
repl_lag = age_text(repl.get("replication_lag_seconds"))
repl_progress = repl.get("progress_percent", "n/a")
repl_batches = repl.get("batches_completed", "n/a")

page = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Status</title>
  <style>
    :root {{
      --bg: #08111a;
      --bg2: #0d1722;
      --card: rgba(13, 23, 34, 0.88);
      --ink: #e7eef5;
      --muted: #93a4b7;
      --line: rgba(147, 164, 183, 0.18);
      --ok: #79e2a0;
      --warn: #ffb454;
      --ok-bg: rgba(24, 92, 52, 0.45);
      --warn-bg: rgba(128, 78, 0, 0.36);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      padding: 24px;
      background:
        radial-gradient(circle at top left, rgba(37, 99, 235, 0.18), transparent 30%),
        radial-gradient(circle at right, rgba(16, 185, 129, 0.12), transparent 24%),
        linear-gradient(180deg, var(--bg2) 0%, var(--bg) 100%);
      color: var(--ink);
      font: 15px/1.45 "Segoe UI", "Helvetica Neue", Arial, sans-serif;
    }}
    main {{ max-width: 1180px; margin: 0 auto; }}
    h1, h2 {{ margin: 0 0 10px; line-height: 1.05; }}
    h1 {{ font-size: 2rem; letter-spacing: -0.03em; }}
    h2 {{ font-size: 1rem; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); }}
    p {{ margin: 0 0 12px; color: var(--muted); }}
    .grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(210px, 1fr)); gap: 14px; margin: 18px 0; }}
    .card {{
      background: var(--card);
      border: 1px solid var(--line);
      border-radius: 18px;
      padding: 16px;
      box-shadow: 0 16px 40px rgba(0, 0, 0, 0.25);
      backdrop-filter: blur(10px);
    }}
    .chip {{
      display: inline-block;
      padding: 3px 10px;
      border-radius: 999px;
      font-size: 0.75rem;
      font-weight: 700;
      letter-spacing: 0.06em;
      text-transform: uppercase;
      background: var(--ok-bg);
      color: var(--ok);
    }}
    .chip.warn {{ background: var(--warn-bg); color: var(--warn); }}
    dl {{ margin: 0; }}
    dt {{ font-size: 0.72rem; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); margin-bottom: 3px; }}
    dd {{ margin: 0 0 10px; color: var(--ink); font-weight: 600; }}
    table {{ width: 100%; border-collapse: collapse; font-size: 0.95rem; }}
    th, td {{ text-align: left; padding: 8px 10px; border-bottom: 1px solid var(--line); vertical-align: top; }}
    th {{ font-size: 0.72rem; letter-spacing: 0.08em; text-transform: uppercase; color: var(--muted); }}
    ul {{ margin: 6px 0 0 18px; padding: 0; color: var(--ink); }}
    code {{ font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; font-size: 0.88em; color: #c7d7e6; }}
  </style>
</head>
<body>
  <main>
    <h1>Status</h1>
    <p>Freshness, sync, replication, and station-power telemetry.</p>
    <div class="grid">
      <section class="card">
        <h2>Web</h2>
        <p>{chip(web_payload.get('health', 'unknown'))}</p>
        <dl>
          <dt>Index mtime</dt>
          <dd>{esc(index_iso)} ({age_text(int(index_age))} ago)</dd>
          <dt>Snapshot</dt>
          <dd>{esc(now_iso)}</dd>
        </dl>
      </section>
      <section class="card">
        <h2>Generate</h2>
        <p>{chip(edge.get('health', 'unknown'))}</p>
        <dl>
          <dt>weewx service</dt>
          <dd>{esc(edge_checks.get('weewx_service', {}).get('status', 'unknown'))}</dd>
          <dt>HTML</dt>
          <dd>{esc(edge_checks.get('generated_site', {}).get('mtime_utc', 'n/a'))} ({age_text(edge_checks.get('generated_site', {}).get('age_seconds'))} ago)</dd>
          <dt>Archive</dt>
          <dd>{esc(edge_checks.get('archive_database', {}).get('latest_record_utc', 'n/a'))} ({age_text(edge_checks.get('archive_database', {}).get('age_seconds'))} ago)</dd>
        </dl>
      </section>
      <section class="card">
        <h2>Push</h2>
        <p>{chip(push.get('result', 'unknown'))}</p>
        <dl>
          <dt>Last push</dt>
          <dd>{esc(push.get('finished_at_utc', 'n/a'))}</dd>
          <dt>Duration</dt>
          <dd>{esc(push.get('duration_seconds', 'n/a'))} seconds</dd>
          <dt>Target</dt>
          <dd><code>{esc(push.get('target', 'n/a'))}</code></dd>
        </dl>
      </section>
      <section class="card">
        <h2>Replicate</h2>
        <p>{chip(repl_result)}</p>
        <dl>
          <dt>Latest local row</dt>
          <dd>{esc(repl_latest)}</dd>
          <dt>Imported</dt>
          <dd>{esc(repl_rows)} rows in {esc(repl_batches)} batches</dd>
          <dt>Coverage</dt>
          <dd>{esc(repl_progress)}%</dd>
          <dt>Lag</dt>
          <dd>{esc(repl_lag)}</dd>
        </dl>
      </section>
      <section class="card">
        <h2>Battery</h2>
        <p>{chip(battery_summary)}</p>
        <dl>
          <dt>Sample</dt>
          <dd>{esc(battery_sample)}</dd>
          <dt>Alert</dt>
          <dd><ul>{battery_alerts_html}</ul></dd>
        </dl>
      </section>
    </div>
    <section class="card">
      <h2>Battery Values</h2>
      <table>
        <thead><tr><th>Field</th><th>Value</th></tr></thead>
        <tbody>
          <tr><td>ISS transmitter battery status</td><td>{esc(tx_display)}</td></tr>
          <tr><td>Console battery voltage</td><td>{esc(console_display)}</td></tr>
        </tbody>
      </table>
    </section>
  </main>
</body>
</html>
"""
Path(html_path).write_text(page, encoding="utf-8")
PY

if [ "$health" != "ok" ]; then
    exit 1
fi
