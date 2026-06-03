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

## Task 3 — OPEN DISCUSSION: terraform plan noise (mandatory)

`terraform plan` always shows 7 user accounts as "to change."
This is the `vault_generic_endpoint` write-only pattern (`disable_read = true`).
Applying is safe and idempotent — but the noise **masks real drift** and
breaks the ability to use plan as a reliable CI/CD gate.

### Root cause
Vault userpass does not return the password on read. Terraform sees
config (has password) vs. state (no password) and always flags a diff.

### Fix options to discuss
1. Remove `password` from `data_json` — manage initial passwords manually
   via `vault write auth/userpass/users/<name> password=X`. Terraform
   only manages policies and TTLs. One-time bootstrap step per user.
2. Use Vault Identity (entities + groups) for policy assignment.
   Userpass becomes auth only; policies attach to the identity entity,
   not the userpass account. Fully idempotent.
3. Separate bootstrap apply (targeted, one-time) from day-to-day apply.

### Pre-existing resources — import decision
Pre-existing userpass accounts (ej, bob, mac, air, richard, etc.) and
AppRole roles (ansible-approle, jenkins, terraform) exist in Vault outside
Terraform state.

- **Userpass accounts**: do NOT import until plan-noise is resolved.
  Importing now would immediately overwrite passwords on every apply.
- **AppRole roles**: can be imported cleanly (no password issue).
  Decision needed: which roles does this project own vs. other tooling?

Rule: fix plan-noise first, then import gives a trustworthy signal.
