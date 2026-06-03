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

---

## Thinking it through further — configuration vs. secrets vs. tokens

### 1) Configuration in Vault belongs in Terraform

Anything structural and non-sensitive belongs fully in Terraform and git:

- Mount paths and types
- Policy HCL definitions
- Role definitions (TTLs, allowed users)
- Auth backend configurations
- User account names (not passwords)
- SSH CA role settings

None of this is secret. All of it is in `.tf` files in this repo today.

### 2) Actual secrets — different answer for each type

**Passwords for humans** (AnyDesk password, app-service password)
- Human needs to know it → Bitwarden/LastPass is right
- Also in Vault → Vault is the live copy
- Also in `secrets.auto.tfvars` → Terraform is the writer
- All three stay in sync. Bitwarden is the human reference. Vault is the live value.

**Certificates**
- Vault PKI engine issues and renews them — they change on rotation
- Bitwarden/LastPass is NOT suitable (certs expire, auto-rotate)
- Vault is the only right home for certs
- Terraform declares the PKI engine exists but does not manage individual certs

**API tokens and service credentials** — see section 3 below

### 3) Tokens (xyz-token) — the key question for Bitwarden/LastPass

Ask one question about every token or secret:

```
WHO needs to access this?

  A human, interactively            → Vault + Bitwarden/LastPass
  (e.g. pasting a token into a
  config form or logging in)

  A machine, programmatically       → Vault ONLY
  (e.g. an app fetching its own     (Bitwarden cannot help machines)
  API key at runtime)

  Both                              → Vault as system of record,
                                      Bitwarden as human reference copy

  Rotates frequently or is          → Vault ONLY — dynamic secrets
  auto-generated                    (rotation defeats Bitwarden storage)
```

> Vault is a professional-grade secret manager built for machines.
> Bitwarden/LastPass is a secret manager built for humans.
> A token only machines read should never need to be in Bitwarden.
> A token a human occasionally pastes somewhere should be in both.

### Bitwarden/LastPass boundary — drawn precisely

```
Bitwarden/LastPass holds:
  ✓ Secrets a human needs to interactively access a system
  ✓ Reference copy of secrets.auto.tfvars values
  ✓ The "what it should be" before updating Vault or Terraform
  ✗ NOT tokens and certs that only machines consume
  ✗ NOT dynamically-generated credentials (they expire)
  ✗ NOT secrets owned by applications (argo-cd, espch, etc.)
```

### The insurance for machine tokens is Vault version history — not Bitwarden

Every KV v2 secret keeps its last 10 versions automatically. If a token is accidentally
overwritten, it can be restored immediately:

```bash
# See all versions of a secret
vault kv metadata get secret/path/to/xyz-token

# Read a specific old version
vault kv get -version=2 secret/path/to/xyz-token

# Restore a previous version
vault kv undelete -versions=2 secret/path/to/xyz-token
```

The stronger protection for machine tokens: do not declare them in Terraform at all.
Let the application that owns the token write it directly to Vault. Terraform owns the
mount and the policy that grants access. The value stays out of Terraform entirely —
meaning `terraform apply` can never accidentally overwrite it.

---

## The clean model — where everything lives

```
Terraform owns:     Structure, access control, platform bootstrap credentials
Vault owns:         All live secret values, version history
Bitwarden owns:     Human-accessible copies of platform bootstrap credentials
Applications own:   Their own secrets (write directly to Vault, Terraform never touches)
```

Applied to this environment:

| Secret | Who uses it | Right home |
|--------|------------|------------|
| AnyDesk password | Human logs in interactively | Vault + Bitwarden |
| AnyDesk ID | Human connects | Vault + Bitwarden |
| app-service password | Human after bastion hop | Vault + Bitwarden |
| `tracker-db/data/API_AUTH_TOKEN` | CI/CD pipeline (machine) | Vault only |
| `cloudflare/*` SSL certs | Automation (machine) | Vault only |
| `espch/*` tokens | ESPCH service (machine) | Vault only |
| `argo-cd/*` credentials | ArgoCD app (machine) | Vault only |
| GCP / AWS dynamic credentials | Generated on-demand | Vault only — they expire |
