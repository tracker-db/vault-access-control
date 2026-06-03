# TODO

## Task 1 — DONE
Add service accounts and vault-admin role:
- `svc-anydesk-blue` (AppRole, read-only)
- `svc-anydesk-green` (AppRole, read-only)
- `svc-bastion` (AppRole, deployer)
- `vault-admin` role added to `roles.tf`

---

## Task 2 — Testing & Verification

### Layer 1 — Static checks (no Vault needed)
- [ ] `override.tf` created (local module path, gitignored)
- [ ] `terraform fmt -check -recursive`
- [ ] `terraform init`
- [ ] `terraform validate`

### Layer 2 — Vault connectivity (confirmed)
- [x] Vault reachable: `https://vault.nextresearch.io` (v1.18.2, unsealed, HA active)
- [x] Token valid (root, no TTL)
- [x] SSH CA engine at `ssh/` — CA already configured
- [x] `userpass/` auth already enabled
- [x] `approle/` auth already enabled
- [ ] `terraform plan` — review all intended changes before apply

### Layer 3 — Apply and verify
- [ ] `terraform apply`
- [ ] `vault list auth/userpass/users` — confirm all users from `users.tf`
- [ ] `vault list auth/approle/role` — confirm all service accounts
- [ ] `vault policy list` — confirm all policies
- [ ] `vault read auth/userpass/users/tom` — spot-check user policies
- [ ] `vault read auth/approle/role/svc-bastion` — spot-check service account
- [ ] `vault policy read ssh-role-vault-admin` — confirm vault-admin policy exists

### Layer 4 — Pin SHA and clean up
- [x] Commit module changes on `modules-terraform-vault-rbac/phase1`
- [x] Get SHA: `9656cb888be83a2cd577af4318c2ccec30fc2600`
- [x] Replace `<SHA>` in `main.tf` source block
- [x] Delete `override.tf`
- [x] `terraform init` — remote module resolves from GitHub
- [x] `terraform plan` — stable (7 known-noise changes; see Task 3)

---

## Task 3 — RESOLVED: terraform plan noise

**Plan is now clean: `No changes. Your infrastructure matches the configuration.`**

### What was causing the noise
Two separate issues, both fixed:
1. `password` included in `data_json` — Vault never returns it on read,
   so Terraform always saw a diff. Fix: removed password from config.
   Initial passwords set once manually: `vault write auth/userpass/users/<name> password=X`
2. TTL format mismatch — config sent `"8h"` (string) but Vault returns
   `28800` (number/seconds). Fix: config now sends seconds (`28800`, `86400`).

### Pre-existing resources — import decision (still open)
Pre-existing userpass accounts (ej, bob, mac, air, richard, etc.) and
AppRole roles (ansible-approle, jenkins, terraform) exist in Vault outside
Terraform state. Now that plan is clean, imports will give trustworthy signal.

- **Userpass accounts**: add to `users.tf`, then `terraform import`
  (no password set by Terraform — users keep existing passwords)
- **AppRole roles**: decision needed on which roles this project owns
