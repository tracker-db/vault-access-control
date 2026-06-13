# Key and Token Rotation

All pipeline credentials originate from `vault-access-control`. Rotate here, nowhere else.

---

## GitHub PAT (`GITHUB_PAT`)

**What it does:** Registers ephemeral runners against the `tracker-db` org on every container start.
**Scope required:** `admin:org` on the `tracker-db` GitHub organisation.
**When to rotate:** When it expires or is compromised.

```bash
# 1. Create a new PAT at: GitHub → Settings → Developer settings → Personal access tokens
# 2. Re-run bootstrap.sh — it writes the new PAT to util and restarts runners
export GITHUB_PAT=ghp_new_token_here
bash scripts/bootstrap.sh
```

---

## Vault AppRole secret_id (`VAULT_SECRET_ID`)

**What it does:** Authenticates the runner containers to Vault so Terraform can read pipeline secrets.
**When to rotate:** On any suspected compromise, or proactively (secret_ids do not expire by default).

```bash
# Generate a fresh secret_id and restart runners
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/github-actions-runner/secret-id)
ssh ej@192.168.2.97 "
  sed -i 's|^VAULT_SECRET_ID=.*|VAULT_SECRET_ID=${SECRET_ID}|' /storage/docker/next-runner/.env
  cd /storage/docker/next-runner && docker compose up -d --force-recreate
"
```

Or just re-run `bootstrap.sh` — it generates a fresh secret_id automatically.

---

## Runner SSH Key (`runner_key` on util)

**What it does:** Allows runner containers to SSH to blue (192.168.3.120), green (192.168.2.120),
and blue-anydesk (192.168.3.91) without a password.
**When to rotate:** On any suspected compromise.

```bash
# 1. Generate new key on util
ssh ej@192.168.2.97 "ssh-keygen -t ed25519 -f ~/.ssh/runner_key -N '' -C 'tracker-db-runner'"

# 2. Push new public key to target hosts
for HOST in 192.168.3.120 192.168.2.120 192.168.3.91; do
  ssh-copy-id -i ~/.ssh/runner_key.pub ej@$HOST
done

# 3. Remove old key from authorized_keys on each host (search by old comment or fingerprint)
```

---

## Vault Admin Token

**What it does:** Used by engineers and bootstrap.sh to manage Vault (apply policies, create AppRoles).
**When to rotate:** Per your Vault token policy TTL (platform-admin role: 8h TTL, 24h max).

```bash
# Renew before expiry
vault token renew

# Or re-authenticate
vault login -method=userpass username=ej
```

---

## Quick Reference

| Credential | Lives On | Rotated By | Command / Script |
|------------|----------|------------|------------------|
| `GITHUB_PAT` | util `.env` | engineer | `bootstrap.sh` |
| `VAULT_SECRET_ID` | util `.env` | engineer | `bootstrap.sh` or manual `vault write -f` |
| `runner_key` | util `~/.ssh/` | engineer | `ssh-keygen` + `ssh-copy-id` |
| Vault admin token | engineer shell | self-service | `vault login` |
