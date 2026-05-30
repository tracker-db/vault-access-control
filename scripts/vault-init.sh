#!/usr/bin/env bash
# scripts/vault-init.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ONE-TIME SETUP: Initialize Vault SSH CA
#
# Run this ONCE on the build server before terraform apply.
# Requires: VAULT_ADDR and VAULT_TOKEN env vars set.
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

MOUNT_PATH="${SSH_MOUNT_PATH:-ssh-client-signer}"

echo "=== Vault SSH CA Initialization ==="
echo "Vault address: ${VAULT_ADDR}"
echo "Mount path:    ${MOUNT_PATH}"
echo ""

# Check Vault is reachable
vault status > /dev/null 2>&1 || {
  echo "ERROR: Cannot reach Vault at ${VAULT_ADDR}"
  echo "Set VAULT_ADDR and VAULT_TOKEN environment variables."
  exit 1
}

# Enable SSH secrets engine (idempotent)
if vault secrets list | grep -q "^${MOUNT_PATH}/"; then
  echo "[OK] SSH secrets engine already mounted at ${MOUNT_PATH}/"
else
  echo "[+] Mounting SSH secrets engine at ${MOUNT_PATH}/"
  vault secrets enable -path="${MOUNT_PATH}" ssh
fi

# Generate CA keypair (idempotent — will fail silently if exists)
echo "[+] Configuring SSH CA keypair..."
vault write "${MOUNT_PATH}/config/ca" generate_signing_key=true 2>/dev/null || {
  echo "[OK] CA keypair already exists"
}

# Fetch and display the CA public key
echo ""
echo "=== CA PUBLIC KEY ==="
echo "Add this to /etc/ssh/trusted-user-ca-keys.pem on ALL target VMs:"
echo ""
vault read -field=public_key "${MOUNT_PATH}/config/ca"
echo ""
echo ""

# Save CA public key to file for distribution
CA_PUBKEY_FILE="/tmp/vault-ca-pubkey.pem"
vault read -field=public_key "${MOUNT_PATH}/config/ca" > "${CA_PUBKEY_FILE}"
echo "[OK] CA public key saved to ${CA_PUBKEY_FILE}"

echo ""
echo "=== NEXT STEPS ==="
echo "1. Copy ${CA_PUBKEY_FILE} to each target VM"
echo "2. Run: scripts/configure-target-vm.sh <hostname>"
echo "3. Run: terraform apply"
echo "4. Set user passwords: vault write auth/userpass/users/<name> password=<pw>"
