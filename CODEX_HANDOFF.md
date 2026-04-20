# Codex Handoff

Use this repo to recreate the two-host weather stack.

Assumptions:

- There are two target hosts in `inventory/hosts.yml`: `edge` and `web`
- Secrets are present in `group_vars/all/secrets.yml`
- SSH private keys referenced by the vars already exist on the target hosts
- The edge host has similar weather-station hardware, especially a Davis Vantage
  reachable at the configured serial device

What to deploy:

- `roles/edge`: `weewx`, custom skin, edge status scripts, Windy uploader, and edge push timers
- `roles/web`: `nginx`, local status page generator, PostgreSQL replica, and timers

Files to review first:

- `README.md`
- `REBUILD.md`
- `inventory/hosts.example.yml`
- `group_vars/edge.yml`
- `group_vars/web.yml`
- `group_vars/all/secrets.example.yml`

Deployment command:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

After deployment:

1. Copy `inventory/hosts.example.yml` to `inventory/hosts.yml`
2. Copy `group_vars/all/secrets.example.yml` to `group_vars/all/secrets.yml`
3. Fill in hostnames, SSH key paths, and secrets
4. Run the playbook
5. Confirm the edge host is generating fresh HTML
6. Confirm the web replica catches up
7. Run `scripts/verify-edge.sh` and `scripts/verify-web.sh`

If historical data matters:

1. Restore the edge `weewx.sdb`
2. Let the web PostgreSQL replica refill from the edge host
