# Rebuild Notes

This repository is intended to let Codex or a human recreate the stack on similar hardware without relying on ad hoc server memory.

## Prerequisites

- Two Ubuntu/Debian-style hosts: one `edge`, one `web`
- SSH access for Ansible
- A Davis Vantage-compatible edge host with the weather station available at the configured serial device
- Secrets filled in under `group_vars/all/secrets.yml`
- Required SSH keys installed outside Git

## Deploy Order

1. Prepare `inventory/hosts.yml`
2. Prepare `group_vars/all/secrets.yml`
3. Install or copy:
   - edge push private key at the path referenced by `edge_push_identity_file`
   - web replication private key at the path referenced by `web_replication_ssh_key_path`
4. Run the playbook:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Data Restore

Infrastructure and data are different concerns.

Recommended backups outside Git:

- Edge:
  - `/var/lib/weewx/weewx.sdb`
- Web:
  - `pg_dump -Fc weewx`

Suggested restore order:

1. Restore the edge `weewx.sdb`
2. Start `weewx` on the edge host
3. Let the web replication timer backfill PostgreSQL from the edge host

## Verification

Run:

```bash
scripts/verify-edge.sh
scripts/verify-web.sh
```

Expected outcomes:

- `weewx`, `push-weewx-site.timer`, `edge-freshness.timer`, and `windy-upload.timer` active on the edge host
- `nginx`, `postgresql`, `website-freshness.timer`, and `weewx-postgres-replication.timer` active on the web host
- `/status/index.html` returns `200 OK`
- Web PostgreSQL `archive` table catches up to the edge SQLite `archive` table
