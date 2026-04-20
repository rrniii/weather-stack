# Paste Into Codex

Use this repository to recreate the CAAGA two-host weather stack on similar hardware.

Repository layout:

- `roles/edge`: edge host deployment for WeeWX, the custom skin, edge status scripts, edge push, and Windy uploads
- `roles/web`: webserver deployment for nginx, local status generation, and PostgreSQL replication
- `inventory/hosts.example.yml`: example inventory to copy to `inventory/hosts.yml`
- `group_vars/all/secrets.example.yml`: example secrets file to copy to `group_vars/all/secrets.yml`
- `REBUILD.md`: operational rebuild notes

Instructions:

1. Read `README.md` and `REBUILD.md`
2. Copy `inventory/hosts.example.yml` to `inventory/hosts.yml`
3. Copy `group_vars/all/secrets.example.yml` to `group_vars/all/secrets.yml`
4. Fill in the real hostnames, usernames, SSH key paths, and service credentials
5. Verify the edge host has a similar Davis Vantage setup and the correct serial device
6. Run:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

After deploy:

1. Run `scripts/verify-edge.sh`
2. Run `scripts/verify-web.sh`
3. Check that `/status/index.html` returns `200 OK`
4. Check that the PostgreSQL `archive` table catches up to the edge SQLite `archive` table

Do not commit:

- `inventory/hosts.yml`
- `group_vars/all/secrets.yml`
- SSH private keys
- database dumps
