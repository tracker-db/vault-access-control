#!/usr/bin/env bash
# scripts/configure-target-vm.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Configure a target VM to trust Vault's SSH CA
#
# Usage: ./configure-target-vm.sh <hostname> [<hostname> ...]
#
# What this does on each target:
#   1. Copies Vault CA public key to /etc/ssh/trusted-user-ca-keys.pem
#   2. Configures sshd to trust Vault-signed certs
#   3. Sets up AuthorizedPrincipalsFile for RBAC
#   4. Creates the 'deploy' user (for read-only access)
#   5. Disables password auth
#   6. Restarts sshd
#
# Prerequisites:
#   - You must have existing SSH access to the target (current root key)
#   - VAULT_ADDR and VAULT_TOKEN must be set
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

MOUNT_PATH="${SSH_MOUNT_PATH:-ssh-client-signer}"

if [ $# -eq 0 ]; then
  echo "Usage: $0 <hostname> [<hostname> ...]"
  exit 1
fi

# Fetch CA public key from Vault
CA_PUBKEY=$(vault read -field=public_key "${MOUNT_PATH}/config/ca")
if [ -z "$CA_PUBKEY" ]; then
  echo "ERROR: Could not fetch CA public key from Vault"
  exit 1
fi

for HOST in "$@"; do
  echo ""
  echo "=== Configuring ${HOST} ==="

  ssh "root@${HOST}" bash -s <<REMOTE_SCRIPT
set -euo pipefail

# 1. Install Vault CA public key
echo '${CA_PUBKEY}' > /etc/ssh/trusted-user-ca-keys.pem
chmod 644 /etc/ssh/trusted-user-ca-keys.pem
echo "[OK] CA public key installed"

# 2. Create deploy user (for read-only access level)
if ! id deploy &>/dev/null; then
  useradd -m -s /bin/bash deploy
  echo "[OK] Created 'deploy' user"
else
  echo "[OK] 'deploy' user already exists"
fi

# 3. Set up AuthorizedPrincipalsFile directory
mkdir -p /etc/ssh/auth_principals
chmod 755 /etc/ssh/auth_principals

# 4. Configure sshd
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup original config
cp -n "\${SSHD_CONFIG}" "\${SSHD_CONFIG}.bak.original" 2>/dev/null || true

# Remove any existing Vault CA config (idempotent)
sed -i '/# --- BEGIN VAULT SSH CA ---/,/# --- END VAULT SSH CA ---/d' "\${SSHD_CONFIG}"

# Append Vault CA configuration
cat >> "\${SSHD_CONFIG}" <<'SSHD_BLOCK'

# --- BEGIN VAULT SSH CA ---
# Trust certificates signed by Vault's CA
TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem

# Use principals file for RBAC — only allow certs with matching principals
AuthorizedPrincipalsFile /etc/ssh/auth_principals/%u

# Harden: disable password auth, enforce key/cert only
PasswordAuthentication no
ChallengeResponseAuthentication no
PubkeyAuthentication yes
# --- END VAULT SSH CA ---
SSHD_BLOCK

echo "[OK] sshd_config updated"

# 5. Validate sshd config before restarting
sshd -t || {
  echo "ERROR: sshd_config is invalid. Restoring backup."
  cp "\${SSHD_CONFIG}.bak.original" "\${SSHD_CONFIG}"
  exit 1
}

# 6. Restart sshd
systemctl restart sshd
echo "[OK] sshd restarted"

echo "[DONE] ${HOST} is now configured to trust Vault SSH CA"
echo "[NOTE] You must still populate /etc/ssh/auth_principals/ with principal files."
echo "       Run: scripts/sync-principals.sh ${HOST}"
REMOTE_SCRIPT

  echo "[OK] ${HOST} configured successfully"
done

echo ""
echo "=== ALL TARGETS CONFIGURED ==="
echo "Next: run scripts/sync-principals.sh to push RBAC principal files"
