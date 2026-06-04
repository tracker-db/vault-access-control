# Procedures

Common operations for this repo.
Every change: edit → commit → `terraform apply` → `ansible-playbook`

---

## Users

### Add a user
File: `vault-users.tf`
1. Add block with `roles`, `email`, `status: "enabled"`
2. `terraform apply` — creates Vault userpass account + assigns policies
3. `ansible-playbook ...` — creates OS account on all servers
4. `vault write auth/userpass/users/<name> password=<pw>` — set initial password

### Disable a user
File: `vault-users.tf`
1. Set `status: "disabled"`
2. `terraform apply` — strips all Vault policies (account kept)
3. `ansible-playbook ...` — locks OS account (cannot log in, home kept)

### Offboard a user
File: `vault-users.tf`
1. Set `status: "removed"` → `terraform apply` + `ansible-playbook` — deletes OS account
2. Remove block entirely → `terraform apply` — deletes Vault userpass account

---

## Service Accounts

### Add an OS service account
File: `linux-service-accounts.tf`
1. Add to the correct local: `linux_service_accounts` (bastions) / `core_server_service_accounts` (util, green, blue) / `util_service_accounts` / `libvirt_service_accounts`
2. Add Ansible task in `sync-os-users.yml` if a new server group is needed
3. `terraform apply`
4. `ansible-playbook ...`
5. `vault kv put secret/service-accounts/<name>/credentials username=<name> password=<pw>`

### Remove an OS service account
File: `linux-service-accounts.tf`
1. Set `status: "removed"` → `ansible-playbook ...` — deletes OS account
2. Remove block entirely → `terraform apply` — removes KV path from Vault

### Add a Vault AppRole
File: `vault-service-accounts.tf`
1. Add block with role, description
2. `terraform apply` — creates AppRole in Vault

---

## Passwords

### Rotate a service account password
```bash
vault kv put secret/service-accounts/<name>/credentials username=<name> password=<new>
```
No `terraform apply` needed — Vault owns the value.

### Rotate app-service password
```bash
vault kv put secret/shared/app-service/credentials username=app-service password=<new>
```

### Set a user's Vault password
```bash
vault write auth/userpass/users/<name> password=<new>
```

---

## Servers

### Add a server
1. Add host to `scripts/inventory.yml` under the correct group
2. Update `scripts/linux-reconcile.sh` if a new group is needed
3. `scripts/configure-target-vm.sh <hostname>` — trust Vault SSH CA
4. `scripts/sync-principals.sh` — push SSH CA principals
5. `ansible-playbook ...` — sync users to new server

---

## SSH Certificates

### Sign SSH key / connect
```bash
scripts/engineer-ssh-login.sh       # sign key — valid 8h (platform-admin) or 4h (operator)
ssh -i ~/.ssh/user51 <hostname>
```

---

## Health Checks

### Verify everything is clean
```bash
terraform plan
./scripts/vault-reconcile.sh

export anydesk_ssh_password=<pw> core_server_password=<pw>
./scripts/linux-reconcile.sh
```

### Full sync
```bash
terraform apply --auto-approve
ansible-playbook scripts/sync-os-users.yml -i scripts/inventory.yml \
  --extra-vars "anydesk_ssh_password=<pw> core_server_password=<pw>"
```
