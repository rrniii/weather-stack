# Weather Stack

This repository captures the configuration and deployment logic for the CAAGA weather stack:

- Edge host: `weewx`, the `neowx-material` skin, edge health/status publishing, site push to the webserver, and the Windy uploader.
- Web host: `nginx`, local status rendering, PostgreSQL replication of the edge `archive` table, and timers for freshness/replication.

What belongs in Git:

- Templates for host configuration
- Versioned scripts and systemd units
- The custom `neowx-material` skin
- Inventory examples, group vars, and rebuild documentation

What stays out of Git:

- API passwords and station credentials
- SSH private keys
- Live databases (`weewx.sdb`, PostgreSQL data directory)
- Generated site output under `/var/www/...`

## Quick Start

1. Copy `inventory/hosts.example.yml` to `inventory/hosts.yml`.
2. Copy `group_vars/all/secrets.example.yml` to `group_vars/all/secrets.yml`.
3. Fill in the real secrets and host/IP values.
4. Make sure the required SSH keys exist on the target hosts.
5. Run:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

6. Restore data backups if needed, then run the verification scripts in `scripts/`.

## Important Secrets and Keys

- `group_vars/all/secrets.yml` for service credentials
- Edge private key used to push to the webserver
- Web private key used to pull/replicate from the edge host

## Notes

- This repo preserves the currently running architecture, including:
  - edge-generated HTML under `/var/www/html/weewx`
  - edge push to the webserver
  - web-side PostgreSQL replica fed from the edge SQLite database
- Data backups are separate from infrastructure. See [REBUILD.md](REBUILD.md).
