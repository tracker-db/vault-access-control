# CLAUDE.md — vault-access-control

## What This Repo Is
Cross-cutting identity and access management for the entire tracker-db infrastructure family.
Single source of truth for HashiCorp Vault config, Linux OS users, and Ansible SSH inventory.
Rule: if a server account or access path is not defined here, it does not exist.

## Why This Matters to Every Other Repo
`scripts/inventory.yml` is the Ansible SSH inventory used by all pipeline automation.
Every SSH connection in the 3-repo build pipeline depends on this file being correct.
Blue: 192.168.3.120, Green: 192.168.2.120, Util: 192.168.2.97, Bastions: ssh.auto-deploy.net / 192.168.2.100

## Key Files
- `scripts/inventory.yml` — **the** Ansible inventory; all pipeline repos reference this
- `scripts/sync-os-users.yml` — Ansible playbook to reconcile Linux users across all servers
- `scripts/vault-init.sh` — Vault init and unseal
- `scripts/vault-reconcile.sh` — Vault drift detection
- `scripts/linux-reconcile.sh` — Linux user drift detection
- `scripts/engineer-ssh-login.sh` — onboard new engineer SSH key to all servers
- `secrets.auto.tfvars.example` — credential template (actual file is gitignored)
- `vault-main.tf`, `vault-users.tf`, `vault-policies-custom.tf` — Vault Terraform config
- `linux-users.tf`, `linux-service-accounts.tf` — OS user definitions

## Server Inventory
| Server | IP | Notes |
|--------|----|-------|
| bastion2 | ssh.auto-deploy.net:1022 | Primary Ansible runner |
| bastion0 | 192.168.2.100 | Internal bastion |
| blue-anydesk | 192.168.3.91 | Runs MAAS |
| green-anydesk | 192.168.2.91 | |
| util | 192.168.2.97 | Smart plug API |
| blue | 192.168.3.120 | HP Server 1, libvirt host |
| green | 192.168.2.120 | HP Server 2, libvirt host |

## How Ansible Runs
Ansible playbooks execute FROM bastion2 (ssh.auto-deploy.net), not from local machine.
```bash
ansible-playbook scripts/sync-os-users.yml -i scripts/inventory.yml \
  --extra-vars "core_server_password=<pw>"
```

## Security: What Must Never Be Committed
- `secrets.auto.tfvars` — copy from `.example`, never commit
- Any file containing plaintext passwords or Vault tokens
- Actual SSH private keys

## Team Members
| Name | Role |
|------|------|
| ej (ejbest) | Platform admin, primary |
| desmond | Platform admin (has remote branch `origin/desmond`) |
| fawaz | Platform admin |

## Family Repos
- `module-baremetal-host` (position 1) — bare metal hosts; `/home/ej/module-baremetal-host`
- `next-base-libvirt` (position 2) — VMs; `/home/ej/next-base-libvirt`
- `next-base-kubernetes` (position 3) — Kubernetes; `/home/ej/next-base-kubernetes`
- `smart-plug-maas` — HP power control API; `/home/ej/smart-plug-maas`

## Full Architecture
See `module-baremetal-host/PIPELINE.md`.
See CHARTER.md in this repo for the complete server and account reference.
