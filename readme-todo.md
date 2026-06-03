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
- [ ] Commit module changes on `modules-terraform-vault-rbac/phase1`
- [ ] Get SHA: `git -C ../modules-terraform-vault-rbac rev-parse HEAD`
- [ ] Replace `<SHA>` in `main.tf` source block
- [ ] Delete `override.tf`
- [ ] `terraform init` — confirm remote module resolves
- [ ] `terraform plan` — confirm no unexpected changes
