# Bootstrap Procedure — First-Time Vault Setup

## The Chicken and Egg Problem

Terraform needs a Vault token to apply. But Terraform creates the auth
methods and policies. So the very first apply needs special handling.

**This procedure is run ONCE. After that, the GitHub Actions runner
handles all subsequent applies via AppRole.**

## Who Runs This

One platform-admin engineer. Ideally the same person every time
for audit trail consistency.

## Prerequisites

- Vault cluster is running (Primary/Anchor + Blue + Green)
- Vault is initialized and unsealed
- You have the Vault root token (from vault operator init)
- Terraform is installed on the build server
- This repo is cloned to the build server

## Step-by-Step

### 1. Get the Vault Root Token

The root token was generated during `vault operator init`.
It should be stored in a secure location (NOT in this repo,
NOT in Slack, NOT in email).

If the root token is lost, you need to unseal Vault and
generate a new one. See: Vault Unseal Runbook.

```bash
export VAULT_ADDR="https://vault.lab.internal:8200"
export VAULT_TOKEN="<root-token>"
```

### 2. Verify Vault Access

```bash
vault status
vault token lookup
```

Confirm: `policies: [root]` appears in the output.

### 3. Mount the SSH Secrets Engine (if not already mounted)

```bash
vault secrets enable -path=ssh-client-signer ssh
vault write ssh-client-signer/config/ca generate_signing_key=true
vault read -field=public_key ssh-client-signer/config/ca > vault-ca.pub
```

### 4. Copy secrets.auto.tfvars.example and Fill In Values

```bash
cd /path/to/vault-access-control
cp secrets.auto.tfvars.example secrets.auto.tfvars
# Edit secrets.auto.tfvars with real AnyDesk IDs, passwords, etc.
vim secrets.auto.tfvars
```

### 5. Run Terraform

```bash
terraform init
terraform plan
terraform apply
```

This creates:
- All Vault policies (vault-admin, SSH roles, KV read/write)
- All userpass accounts (platform-admin engineers)
- All AppRole accounts (service accounts)
- KV v2 secrets engine with initial secrets

### 6. Set Initial Passwords for Engineers

```bash
vault write auth/userpass/users/tom password="<initial-pw>"
vault write auth/userpass/users/harry password="<initial-pw>"
vault write auth/userpass/users/sally password="<initial-pw>"
vault write auth/userpass/users/fawaz password="<initial-pw>"
vault write auth/userpass/users/desmond password="<initial-pw>"
```

Communicate passwords securely — in person or via encrypted channel.
Each engineer MUST change their password on first login.

### 7. Generate AppRole Credentials for GitHub Actions Runner

```bash
# Get the role_id (not secret)
vault read auth/approle/role/github-actions-runner/role-id

# Generate a secret_id
vault write -f auth/approle/role/github-actions-runner/secret-id

# Store on build server
sudo tee /etc/vault.d/github-runner.env << EOF
VAULT_ADDR=https://vault.lab.internal:8200
VAULT_ROLE_ID=<paste role_id>
VAULT_SECRET_ID=<paste secret_id>
EOF
sudo chmod 600 /etc/vault.d/github-runner.env
```

### 8. Verify Everything

```bash
# Check policies
vault policy list

# Check users
vault list auth/userpass/users

# Check AppRoles
vault list auth/approle/role

# Check secrets
vault kv list secret/shared/

# Check SSH CA
vault read ssh-client-signer/config/ca
```

### 9. Revoke the Root Token

**CRITICAL:** After bootstrap, the root token should NOT be used
for day-to-day operations. Platform-admin engineers use their
userpass accounts. The CI runner uses AppRole.

```bash
vault token revoke <root-token>
```

To regenerate a root token later (emergency):
```bash
vault operator generate-root -init
# Follow the unseal key holders procedure
```

### 10. Test End-to-End

Have one engineer:
1. Login: `vault login -method=userpass username=tom`
2. Read a secret: `vault kv get secret/shared/anydesk/server-1`
3. Sign SSH key: `vault write -field=signed_key ssh-client-signer/sign/ssh-bastion public_key=@~/.ssh/id_rsa.pub > ~/.ssh/id_rsa-cert.pub`
4. SSH to bastion: `ssh -p 1020 -i ~/.ssh/id_rsa ej@ssh.auto-deploy.net`

## After Bootstrap

All subsequent changes go through the repo:
1. Edit users.tf / roles.tf / service-accounts.tf / secrets.tf
2. Open PR
3. PR triggers `terraform plan` via GitHub Actions
4. Merge triggers `terraform apply`
5. No manual Vault commands needed

## Emergency: If Terraform State is Lost

If the state file is lost, you must import all existing resources:
```bash
terraform import vault_auth_backend.userpass auth/userpass
terraform import vault_auth_backend.approle auth/approle
terraform import vault_mount.kv secret
terraform import vault_policy.vault_admin vault-admin
# ... etc for each resource
```

This is why the state file at /opt/terraform/state/user-access.tfstate
should be backed up regularly.
