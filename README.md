# user-access

**Single source of truth for SSH access to the DevOps lab.**

Three files control everything:

| File | Question it answers | Who edits it |
|---|---|---|
| `users.tf` | Who are the engineers? What role do they have? | Admin (onboard/offboard) |
| `service-accounts.tf` | What automation identities exist? | Platform team |
| `roles.tf` | What does each role grant access to? | Security/architecture |

Users and service accounts **never reference servers directly**. They get roles. Roles define access.

## How It Works

```
roles.tf                    Vault                         Target VM
┌────────────────────┐     ┌──────────────────┐          ┌──────────┐
│ platform-admin:    │     │                  │          │          │
│   utility-servers  │────►│ SSH CA Role      │          │  sshd    │
│   bastion          │     │ Vault Policy     │          │  trusts  │
│   build-server     │     │                  │          │  Vault   │
└────────────────────┘     └──────┬───────────┘          │  CA      │
                                  │                      │          │
users.tf                          │                      │          │
┌────────────────────┐            │                      │          │
│ tom:               │     ┌──────┴───────────┐          │          │
│   role: platform-  │────►│ Userpass account │          │          │
│         admin      │     │ w/ policy        │          │          │
└────────────────────┘     └──────┬───────────┘          │          │
                                  │                      │          │
              tom signs key ──────┤                      │          │
              gets 8h cert ◄──────┘                      │          │
              SSH ───────────────────────────────────────►│ ✓ valid  │
                                                         └──────────┘
```

## Quick Reference

| Task | What to do |
|---|---|
| **Add an engineer** | Add to `users.tf` → PR → merge → set password via `vault write` |
| **Remove an engineer** | Remove from `users.tf` → PR → merge (certs expire within TTL) |
| **Change someone's access** | Change their `roles` list in `users.tf` |
| **Add a server to a role** | Add target to the role's grants in `roles.tf` |
| **Create a new role** | Add a role block to `roles.tf` |
| **Add a service account** | Add to `service-accounts.tf` → PR → merge |
| **Bootstrap a new VM** | `./scripts/configure-target-vm.sh <hostname>` |
| **Engineer daily SSH** | `./scripts/engineer-ssh-login.sh` |

## Repo Structure

```
user-access/
├── users.tf               ← WHO: human engineers and their roles
├── service-accounts.tf    ← WHO: CI runners, agents, automation
├── roles.tf               ← WHAT: role → resource → access level
├── main.tf                ← WIRING: connects everything to Vault
├── principals.tf          ← AUTO-GENERATED: principals.d/ from roles
├── principals.d/          ← Pushed to VMs by sync script (auto-generated)
├── modules/
│   └── vault-rbac/        ← github.com/tracker-db/modules-terraform-vault-rbac
├── scripts/
│   ├── vault-init.sh           ← One-time: mount SSH engine, gen CA
│   ├── configure-target-vm.sh  ← One-time per VM: trust Vault CA
│   ├── sync-principals.sh      ← Post-apply: push RBAC to VMs
│   └── engineer-ssh-login.sh   ← Engineer daily workflow
├── docs/
│   └── engineer-onboarding.md
└── .github/workflows/
    └── terraform-access.yml    ← PR=plan, merge=apply+sync
```

## Setup Order (First Time)

1. `./scripts/vault-init.sh`
2. `./scripts/configure-target-vm.sh vm-1 vm-2 vm-3 vm-4 vm-5 bastion build`
3. `terraform init && terraform apply`
4. `./scripts/sync-principals.sh`
5. Set passwords: `vault write auth/userpass/users/tom password=...`
6. Generate SA secret-ids: `vault write -f auth/approle/role/ci-runner/secret-id`
7. Hand engineers `docs/engineer-onboarding.md`

## Access Levels

| Level | SSH as | Sudo | Use case |
|---|---|---|---|
| `admin` | `root`, `deploy` | Yes | Platform engineers, full control |
| `read` | `deploy` only | No | Monitoring, CI, limited operators |

## Design Decisions

- **Vault SSH CA** (not stored keys): Certs are ephemeral. No key rotation needed. Revocation is automatic via TTL expiry.
- **Roles, not direct grants**: Users never reference servers. Changing a role's targets updates everyone with that role.
- **Principals files auto-generated**: `principals.tf` derives them from `roles.tf`. No manual sync, no drift.
- **AppRole for service accounts**: No passwords. Uses role_id + secret_id. Secret IDs can be rotated without touching Terraform.
- **GitHub Actions enforces the workflow**: No one runs `terraform apply` manually. PR = plan, merge = apply.
