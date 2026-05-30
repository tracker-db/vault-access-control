# Engineer Onboarding — SSH Access via Vault

## How It Works

We do **NOT** distribute SSH keys. Instead:

1. You authenticate to Vault with your username/password
2. Vault signs your SSH public key with a **short-lived certificate** (8 hours)
3. You SSH into servers using the signed cert
4. The cert expires automatically — no one needs to revoke anything

This means:
- No shared keys floating around
- No keys to rotate manually
- If you leave the team, your certs expire and Vault stops signing new ones
- Every access is logged in Vault's audit log

## First-Time Setup

### 1. Generate an SSH keypair (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
```

### 2. Get your Vault credentials

Your admin will create your account and give you:
- Vault address: `https://vault.lab.internal:8200`
- Username: your name (e.g., `tom`)
- Initial password: set by admin, **change it immediately**

### 3. Set your Vault environment

```bash
export VAULT_ADDR="https://vault.lab.internal:8200"
```

Add this to your `~/.bashrc` or `~/.zshrc`.

### 4. Change your initial password

```bash
vault login -method=userpass username=<your-username>
vault write auth/userpass/users/<your-username> password=<new-password>
```

## Daily Workflow

### Option A: Use the helper script

```bash
# Interactive — pick a resource and connect
./scripts/engineer-ssh-login.sh

# Direct — sign for a specific resource
./scripts/engineer-ssh-login.sh utility-servers

# Sign and connect in one shot
./scripts/engineer-ssh-login.sh utility-servers vm-1.lab.internal
```

### Option B: Manual commands

```bash
# 1. Login to Vault
export VAULT_TOKEN=$(vault login -method=userpass -token-only \
  username=tom password=<your-password>)

# 2. Sign your public key
vault write -field=signed_key \
  ssh-client-signer/sign/ssh-utility-servers \
  public_key=@~/.ssh/id_rsa.pub \
  > ~/.ssh/id_rsa-cert.pub

# 3. SSH in — the cert is used automatically
ssh root@vm-1.lab.internal

# 4. Verify your cert details
ssh-keygen -L -f ~/.ssh/id_rsa-cert.pub
```

## What You Can Access

Your access depends on which team you're assigned to. Check with your admin or look at `access.tf` in the `user-access` repo.

| Access Level | What It Means |
|---|---|
| `admin` | SSH as `root` or `deploy`, full sudo |
| `read` | SSH as `deploy` only, no sudo |

## Troubleshooting

### "Permission denied (publickey)"
- Your cert expired. Re-run the login script.
- You're trying to access a server you don't have permissions for.

### "No matching host key"
- The server hasn't been configured to trust Vault's CA yet.
- Contact your admin.

### "Could not sign key"
- You don't have a Vault policy for that resource.
- Check `access.tf` — is your username listed for that resource?

### cert says "invalid" in `ssh-keygen -L`
- Clock skew between your machine and Vault. Sync NTP.
