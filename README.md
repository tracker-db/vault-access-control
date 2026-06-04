# vault-access-control

Single source of truth for HashiCorp Vault and all Linux server accounts.
If it's not in this repo, it doesn't exist.

---

## What this manages

**Vault** — policies, userpass accounts, AppRole service accounts, SSH CA, auth backends, mounts

**Linux OS users — all servers**

| Account | Servers | Purpose |
|---|---|---|
| ej, ejbest, desmond, fawaz | all servers | platform-admin vault users |
| ansible-job-user, ansible-work, ansible-work-service-account, auto-deploy | bastions | automation service accounts |
| app-service | util, green, blue | shared service account (passwordless sudo) |
| mysql | util | database service account |
| libvirt-qemu | green, blue | libvirt service account |

**Servers**

| Group | Server | IP |
|---|---|---|
| bastions | bastion2 (primary — Ansible runs here) | ssh.auto-deploy.net:1022 |
| bastions | bastion0 | 192.168.2.100 |
| anydesk | blue-anydesk | 192.168.3.91 |
| anydesk | green-anydesk | TBD (was offline) |
| core_servers | util | 192.168.2.97 |
| core_servers | green | 192.168.2.120 |
| core_servers | blue | 192.168.3.120 |

---

## Key files

| File | What it controls |
|---|---|
| `vault-users.tf` | Human users — roles, status, email |
| `vault-roles.tf` | Role definitions — what each role grants |
| `vault-service-accounts.tf` | AppRole accounts that authenticate to Vault |
| `linux-service-accounts.tf` | OS-only service accounts (no Vault access) |
| `vault-secrets.tf` | KV mount + service account credential paths |
| `vault-main.tf` | Provider, backend, policy wiring |
| `scripts/sync-os-users.yml` | Ansible — enforces OS user state |
| `scripts/inventory.yml` | Server inventory |
| `scripts/vault-reconcile.sh` | Detect rogue resources in Vault |
| `scripts/linux-reconcile.sh` | Detect rogue/missing users on servers |

---

## Workflow

```bash
# Edit .tf files → commit → apply

terraform plan                            # review Vault changes
terraform apply --auto-approve            # apply Vault + write manifest

ansible-playbook scripts/sync-os-users.yml -i scripts/inventory.yml \
  --extra-vars "anydesk_ssh_password=<pw> core_server_password=<pw>"

# Verify
./scripts/vault-reconcile.sh
./scripts/linux-reconcile.sh
```

See `read-procedures.yaml` for all common operations.
See `read-how-this-works.md` for architecture.

---

## State

`/opt/terraform/state/user-access.tfstate` — local, backed up via iCloud + Time Machine.
