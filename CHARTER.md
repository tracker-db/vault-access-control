# Charter: vault-access-control

## Role in Family
**Cross-cutting — used by all 5 repos.** Single source of truth for identity, access, and credentials
across the entire tracker-db infrastructure family.

> Rule: If a server account, vault policy, or SSH access path is not defined here, it does not exist.

## What This Repo Manages

### HashiCorp Vault
- Auth backends (userpass, AppRole, SSH CA)
- Secret mounts and policies
- Userpass accounts for platform-admin team
- AppRole service accounts for automation
- SSH certificate authority for host access

### Linux OS Users (all servers)
| Account | Servers | Purpose |
|---------|---------|---------|
| ej, ejbest, desmond, fawaz | all | Platform-admin personal accounts |
| ansible-job-user, ansible-work, ansible-work-service-account, auto-deploy | bastions | Automation service accounts |
| app-service | util, green, blue | Shared service account (passwordless sudo) |
| mysql | util | Database service account |
| libvirt-qemu | green, blue | libvirt runtime service account |

### Ansible Inventory (`scripts/inventory.yml`)
The authoritative SSH inventory for all pipeline automation. Groups:
- `bastions` — bastion2 (ssh.auto-deploy.net, primary Ansible runner), bastion0 (192.168.2.100)
- `anydesk` — blue-anydesk (192.168.3.91), green-anydesk (192.168.2.91)
- `core_servers` — util (192.168.2.97), blue (192.168.3.120), green (192.168.2.120)

## Server Reference
| Group | Server | IP | Notes |
|-------|--------|----|-------|
| bastions | bastion2 | ssh.auto-deploy.net:1022 | Primary Ansible runner |
| bastions | bastion0 | 192.168.2.100 | Internal bastion |
| anydesk | blue-anydesk | 192.168.3.91 | Runs MAAS server |
| anydesk | green-anydesk | 192.168.2.91 | |
| core_servers | util | 192.168.2.97 | Smart plug API, MAAS support |
| core_servers | blue | 192.168.3.120 | HP Server 1 / libvirt host |
| core_servers | green | 192.168.2.120 | HP Server 2 / libvirt host |

## Key Scripts
| Script | Purpose |
|--------|---------|
| `scripts/inventory.yml` | Ansible SSH inventory — referenced by all pipeline repos |
| `scripts/sync-os-users.yml` | Ansible playbook to reconcile OS users across all servers |
| `scripts/vault-init.sh` | Vault initialization and unseal procedure |
| `scripts/vault-reconcile.sh` | Drift detection for Vault state |
| `scripts/linux-reconcile.sh` | Drift detection for Linux user state |
| `scripts/engineer-ssh-login.sh` | Onboards new engineer SSH key to all servers |

## Mandatory Role in Pipeline
Every SSH connection in the 3-repo build pipeline uses this inventory.
Every credentials rotation, new team member, or service account change lands here first.
No other repo manages identity — changes in other repos that require access changes must
be reflected here before they can be applied.

## Security Standard
- Secrets in Vault, not in code
- `secrets.auto.tfvars` is gitignored; copy from `secrets.auto.tfvars.example`
- Ansible playbooks run from bastion2 (ssh.auto-deploy.net) — not from local machine
- All human access is via SSH key; service accounts use AppRole or ansible vault

## Pre-flight for Any Pipeline Run
- [ ] Vault unsealed and reachable
- [ ] `scripts/inventory.yml` reflects current server IPs
- [ ] SSH key for `ej` present at `~/.ssh/user51` on bastion

## Team Members
| Name | GitHub | Role |
|------|--------|------|
| ej | ejbest | Platform admin, primary |
| desmond | — | Platform admin |
| fawaz | — | Platform admin |

## Related Repositories

| Repository | Remote | Why Related |
|------------|--------|-------------|
| `next-base-baremetal` | https://github.com/tracker-db/next-base-baremetal | Pipeline position 1 — its Terraform reads MAAS API key, SSH key, and admin password from Vault; its runner identity is defined here |
| `next-base-libvirt` | https://github.com/tracker-db/next-base-libvirt | Pipeline position 2 — same credential dependency on Vault; SSH inventory here governs its bastion access |
| `next-base-kubernetes` | https://github.com/tracker-db/next-base-kubernetes | Pipeline position 3 — Vault credentials and SSH inventory govern cluster node access |
| `next-runner` | https://github.com/tracker-db/next-runner | The self-hosted runner containers that execute all pipeline workflows; AppRole credentials for the runners are created and owned here |
| `smart-plug-maas` | https://github.com/tracker-db/smart-plug-maas | Runs on util (192.168.2.97) — the service account for util is managed here; smart-plug-maas must run before bare metal provisioning |

## Pipeline Map
See `next-base-baremetal/PIPELINE.md` for the full pipeline architecture.
