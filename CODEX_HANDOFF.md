# Codex Handoff

Use this repo to recreate the two-host weather stack.

Assumptions:

- There are two target hosts in `inventory/hosts.yml`: `edge` and `web`
- Secrets are present in `group_vars/all/secrets.yml`
- SSH private keys referenced by the vars already exist on the target hosts

What to deploy:

- `roles/edge`: `weewx`, custom skin, edge status scripts, Windy uploader, and edge push timers
- `roles/web`: `nginx`, local status page generator, PostgreSQL replica, and timers

Deployment command:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

After deployment:

1. Restore the edge `weewx.sdb` if historical data is needed
2. Confirm the edge host is generating fresh HTML
3. Confirm the web replica catches up
4. Run `scripts/verify-edge.sh` and `scripts/verify-web.sh`
