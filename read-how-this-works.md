# How Terraform and Vault Work Together

## The two things Terraform can manage in Vault

There is a critical distinction between managing a **mount** and managing a **secret value**.

| Thing | What it is | Example |
|-------|-----------|---------|
| **Mount** | The engine — the "folder" that holds secrets | `argo-cd/` engine exists |
| **Secret value** | Actual key/value content stored inside a mount | `argo-cd/data/config = { url: "..." }` |

This repo manages both, but **not all mounts have their secrets managed here**.

---

## What Terraform will and will not touch on `terraform apply`

### Terraform WILL write these secrets (declared in `secrets.tf`)

```
secret/shared/anydesk/server-1        ← anydesk IDs and passwords
secret/shared/anydesk/server-2        ← anydesk IDs and passwords
secret/shared/app-service/credentials ← shared lab username and password
```

These values come from `secrets.auto.tfvars` (a file that lives only on the local
machine, is never committed to git, and is backed up via iCloud and Time Machine).

### Terraform will NOT touch the contents of any other mount

For every other mount — `argo-cd/`, `espch/`, `cloudflare/`, `proxmox/`, `keycloak/`,
`tracker-db/`, and all others — Terraform only knows the mount exists. It has no
knowledge of what secrets are stored inside and will never read, write, or overwrite them.

**If a secret is not declared as a Terraform resource, Terraform cannot see it and
will never touch it.**

---

## The risk to understand: declaring a secret Terraform does not know about

If someone adds code like this to `secrets.tf`:

```hcl
resource "vault_kv_secret_v2" "argo_config" {
  mount     = "argo-cd"
  name      = "config"
  data_json = jsonencode({ url = "http://some-value" })
}
```

Running `terraform apply` **will overwrite whatever is currently at `argo-cd/data/config`
in Vault** — even if the real value is completely different.

This is why it matters to understand which secrets are "owned" by this repo and which
are owned by their applications or teams.

---

## Three patterns — which one applies to each mount

### Pattern 1 — Terraform owns the full value

Used for: `secret/shared/anydesk/*` and `secret/shared/app-service/*`

- Secret values are stored in `secrets.auto.tfvars` on the local machine
- Terraform writes them into Vault on every `terraform apply`
- Values are stored in the Terraform state file (marked sensitive, never printed)
- The state file is at `/opt/terraform/state/user-access.tfstate`, backed up via iCloud

Best for: bootstrap credentials that the platform team owns and controls.

### Pattern 2 — Terraform owns the mount, not the contents

Used for: `argo-cd/`, `espch/`, `cloudflare/`, `proxmox/`, `keycloak/`, `tracker-db/`,
and all other mounts in this repo.

- Terraform declares the mount exists and governs who can access it (via policies)
- Secret values are written directly into Vault by the application, operator, or CI/CD pipeline
- `terraform apply` never reads or writes the contents of these mounts
- The secrets inside are completely invisible to Terraform

Best for: application secrets managed by their respective owners.

### Pattern 3 — Import an existing secret into management

If a secret already exists in Vault and you want Terraform to manage it going forward:

```bash
terraform import vault_kv_secret_v2.my_secret argo-cd/data/my-path
```

After import:
- The current value is pulled into the Terraform state file
- Subsequent `terraform apply` will overwrite the Vault value if the config differs
- The value is now "owned" by this repo and `secrets.auto.tfvars`

Use this pattern deliberately — once a secret is imported, `terraform apply` will
overwrite it if the config value differs from what is in Vault.

---

## Who owns what in this environment

```
Mount              Contents managed by
─────────────────────────────────────────────────
secret/shared/     This repo (Terraform)
argo-cd/           ArgoCD / application team
espch/             ESPCH team
cloudflare/        Operations (DNS/SSL configs)
proxmox/           Infrastructure team
keycloak/          Keycloak / identity team
tracker-db/        Tracker application
jenkins/           CI/CD pipeline
kubeadm-cluster/   Kubernetes cluster team
englab/dev/        Engineering lab
ejbest/            Personal / ej's workspace
ej-prod/           Personal / ej's workspace
servers/           Server configuration team
libvirt/           Virtualisation team
malcode/           Malcode analysis team
kv/, kv-v2/        General purpose / mixed
ssh-keys/          SSH key management
ssh_key/           SSH key management
ssh_pass/          SSH password management
aws/               AWS dynamic credentials (engine)
gcp-*/             GCP dynamic credentials (engine)
pki/               PKI / certificate authority
transit/           Encryption as a service
```

---

## How to add a new secret that Terraform should manage

1. Add a `variable` block to `secrets.tf`:

```hcl
variable "my_new_secret" {
  description = "Description of what this is"
  type        = string
  sensitive   = true
}
```

2. Add a `vault_kv_secret_v2` resource to `secrets.tf`:

```hcl
resource "vault_kv_secret_v2" "my_new_secret" {
  mount     = vault_mount.kv.path
  name      = "shared/my-service/credentials"
  data_json = jsonencode({
    password = var.my_new_secret
  })
}
```

3. Add the real value to `secrets.auto.tfvars` (never commit this file):

```hcl
my_new_secret = "the-real-value"
```

4. Run `terraform apply` — Terraform writes the value to Vault.

---

## How to set a user's initial password

User account passwords are **not managed by Terraform**. Terraform manages the account
(which policies it has, what TTL tokens get) but not the password.

To set or reset a password:

```bash
vault write auth/userpass/users/<username> password=<new-password>
```

The user then changes their own password after first login. Terraform will never
overwrite a user's password — it simply does not include it in the account definition.

---

## The state file — where Terraform stores what it knows

Terraform keeps track of everything it manages in a state file:

```
/opt/terraform/state/user-access.tfstate
```

This file:
- Is backed up automatically via iCloud sync and Time Machine
- Contains sensitive values (marked as such, but present as plain text in the file)
- Should never be committed to git (it is not in this repo)
- Is the source of truth for "what Terraform last applied"

If the state file is lost, resources still exist in Vault — they just need to be
re-imported. No Vault data is lost if the state file is lost.

---

## Summary

| Question | Answer |
|----------|--------|
| Will `terraform apply` overwrite existing Vault secrets? | Only the 3 secrets declared in `secrets.tf`. Everything else is untouched. |
| Are secret values stored in this git repo? | No. Values are in `secrets.auto.tfvars` which is gitignored. |
| Are secret values in the state file? | Yes — the 3 managed secrets are in the state file (not in git). |
| Can I store a new secret in Vault without Terraform knowing? | Yes. Write directly to Vault. Terraform will never see it unless you declare and import it. |
| What if I want Terraform to manage a secret already in Vault? | Import it (`terraform import`), add it to `secrets.tf`, add the value to `secrets.auto.tfvars`. |
| Who owns the secrets in `argo-cd/`, `espch/`, etc.? | Their respective applications and teams. This repo only governs access (policies), not content. |
