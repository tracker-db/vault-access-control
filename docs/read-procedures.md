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

## SSH Keys and Certificates

### How this works — no key distribution needed

Servers trust Vault's CA certificate, not your personal SSH key.
Each device has its own key pair. Each gets a signed certificate from Vault.
**Changing a key on one device never affects any other device or any server.**

### Daily use — sign your key and connect
```bash
scripts/engineer-ssh-login.sh       # authenticates to Vault, signs key, saves cert
ssh -i ~/.ssh/user51 <hostname>     # cert is picked up automatically alongside the key
# Certificates expire: 8h (platform-admin), 4h (operator)
```

### Rotate SSH key on a device
```bash
ssh-keygen -t ed25519 -f ~/.ssh/user51   # generate new key pair
scripts/engineer-ssh-login.sh            # sign new key with Vault — done
```
No server changes needed. No key distribution. The old cert expires on its own.

### Set up SSH on a new computer
```bash
ssh-keygen -t ed25519 -f ~/.ssh/user51   # generate key pair on the new machine
# Set VAULT_ADDR=https://vault.nextresearch.io
vault login -method=userpass username=<name>
scripts/engineer-ssh-login.sh            # sign key, cert saved to ~/.ssh/user51-cert.pub
ssh -i ~/.ssh/user51 <hostname>          # works immediately
```

### Set up SSH on a phone / SSH app
Each SSH app manages its own keys. Vault signs any public key you submit.

1. In your SSH app — generate a key pair and export the public key
2. On any computer with Vault access:
```bash
vault login -method=userpass username=<name>
vault write -field=signed_key ssh/sign/ssh-bastion \
  public_key="<paste phone public key here>" \
  > phone-cert.pub
```
3. Import `phone-cert.pub` back into the SSH app alongside the private key
4. Cert expires in 8h — repeat to renew

> The phone key never leaves the phone. Vault signs it without seeing the private key.
> If the phone is lost — the cert expires on its own. No key rotation needed anywhere else.

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
