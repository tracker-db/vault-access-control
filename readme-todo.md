# TODO

---

## Phase 1 — COMPLETE

### What was built
- Role system: `platform-admin`, `k8s-operator`, `deployer`, `vault-admin`, `read-only`
- SSH CA role (`ssh-bastion`) with `allow_user_certificates = true`
- Vault policies auto-generated per role: `ssh-role-*`, `kv-read-*`, `vault-admin`, `kv-admin`
- All userpass accounts and AppRole service accounts under Terraform management
- `terraform plan` returns **No changes** — reliable as a CI/CD gate

### Accounts under management
**Users (20):** tom, harry, sally, fawaz, desmond, rich, vishal, ej, arti, niam, richard,
nandha, joe, air, bob, jade, mac, nice, nick, sebastin

**Service accounts (10):** app-service, github-actions-runner, vault-agent-blue,
vault-agent-green, svc-anydesk-blue, svc-anydesk-green, svc-bastion,
ansible-approle, espch-approle, terraform

### Key decisions recorded
- TTLs in seconds throughout (prevents Vault API normalization drift)
- `extra_policies` field available on users for pre-role-system custom policies
- `nandha` carries `nandhapo` (aws/*, secrets/* full access) pending Phase 2 role design
- `jenkins` AppRole and policy deleted (decommissioned)
- `approle-policy` deleted (unused after standardisation)
- Passwords not managed by Terraform — set once via `vault write`, users own them after

---

## Phase 2 — Backlog

### P1 — Blocking or high risk

- [ ] **Remote backend for state**
  Local state at `/opt/terraform/state/user-access.tfstate` has no locking and
  is single-machine. Alternatives are pre-written in `main.tf` (GCS / S3).
  Run `terraform init -migrate-state` after choosing.

- [ ] **Fill in `secrets.auto.tfvars`**
  AnyDesk server credentials and `app_service_password` are still `CHANGE_ME`.
  Until these are set, `terraform apply` will overwrite those KV secrets with
  placeholder values. Keep local apply gated until populated.

- [ ] **nandha role design**
  `nandha` has `nandhapo` policy: full access to `aws/*` and `secrets/*`.
  This access pattern needs a proper role (e.g. `aws-operator`).
  Steps: define role → assign to nandha → remove `extra_policies` → retire nandhapo.

### P2 — Important, not blocking

- [ ] **CI/CD pipeline via terraform AppRole**
  `terraform` AppRole (vault-admin role) exists for automation. Document the
  workflow: fetch role_id + secret_id from Vault, run `terraform plan/apply`
  in CI without a human root token.

- [ ] **Password bootstrap docs**
  New user onboarding requires a manual `vault write auth/userpass/users/<name> password=X`
  step after Terraform creates the account. Automate or document in runbook.

- [ ] **espch-approle role review**
  Assigned `read-only` as a safe default. Confirm this is correct for ESPCH's
  actual access needs.

### P3 — Expand Terraform coverage

The following Vault resources exist but are outside Terraform management.
Each requires a deliberate decision before importing.

- [ ] Auth methods: `cert/`, `gcp/`, `oidc/`, `okta/` — managed by this repo or separate?
- [ ] KV mounts: `argo-cd/`, `proxmox/`, `libvirt/`, `englab/`, `cloudflare/`, etc.
- [ ] PKI engine (`pki/`) — certificate authority management
- [ ] Transit engine (`transit/`) — encryption as a service
- [ ] Remaining custom policies: `nandhapo`, `ej-policy`, `espch`, `root-equivalent`, etc.
- [ ] Other users visible in `vault list auth/userpass/users` not yet in this repo
