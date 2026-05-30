#!/usr/bin/env bash
# scripts/engineer-ssh-login.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# ENGINEER WORKFLOW: Get a Vault-signed SSH certificate
#
# Usage:
#   ./engineer-ssh-login.sh                    # Interactive: pick a resource
#   ./engineer-ssh-login.sh utility-servers    # Direct: sign for a specific resource
#   ./engineer-ssh-login.sh utility-servers vm-1.lab.internal  # Sign and connect
#
# Prerequisites:
#   - VAULT_ADDR set (e.g., https://vault.lab.internal:8200)
#   - SSH keypair exists (~/.ssh/id_rsa, ~/.ssh/id_rsa.pub)
#   - You have a Vault userpass account
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

VAULT_ADDR="${VAULT_ADDR:-https://vault.lab.internal:8200}"
SSH_MOUNT="${SSH_MOUNT_PATH:-ssh-client-signer}"
SSH_PUBKEY="${SSH_PUBKEY:-${HOME}/.ssh/id_rsa.pub}"
SSH_SIGNED_CERT="${HOME}/.ssh/id_rsa-cert.pub"

RESOURCE="${1:-}"
TARGET="${2:-}"

# ──────────────────────────────────────────────
# Step 1: Authenticate to Vault
# ──────────────────────────────────────────────

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "=== Vault Authentication ==="
  read -rp "Vault username: " VAULT_USER
  read -rsp "Vault password: " VAULT_PASS
  echo ""

  VAULT_TOKEN=$(vault login \
    -method=userpass \
    -token-only \
    username="${VAULT_USER}" \
    password="${VAULT_PASS}" \
  )

  export VAULT_TOKEN
  echo "[OK] Authenticated to Vault"
  echo ""
fi

# ──────────────────────────────────────────────
# Step 2: Select resource (if not provided)
# ──────────────────────────────────────────────

if [ -z "$RESOURCE" ]; then
  echo "Available resources (based on your policies):"
  echo ""
  echo "  1) utility-servers   (vm-1, vm-2, vm-3)"
  echo "  2) bastion-ssh       (bastion)"
  echo "  3) k8s-blue          (blue cluster nodes)"
  echo "  4) k8s-green         (green cluster nodes)"
  echo "  5) build-server      (build server)"
  echo ""
  read -rp "Select resource [1-5]: " CHOICE

  case "$CHOICE" in
    1) RESOURCE="utility-servers" ;;
    2) RESOURCE="bastion-ssh" ;;
    3) RESOURCE="k8s-blue" ;;
    4) RESOURCE="k8s-green" ;;
    5) RESOURCE="build-server" ;;
    *) echo "Invalid choice"; exit 1 ;;
  esac
fi

ROLE="ssh-${RESOURCE}"

# ──────────────────────────────────────────────
# Step 3: Sign SSH public key
# ──────────────────────────────────────────────

echo "=== Signing SSH Key ==="
echo "Resource: ${RESOURCE}"
echo "Role:     ${ROLE}"
echo "Key:      ${SSH_PUBKEY}"

if [ ! -f "$SSH_PUBKEY" ]; then
  echo ""
  echo "ERROR: SSH public key not found at ${SSH_PUBKEY}"
  echo "Generate one: ssh-keygen -t rsa -b 4096"
  exit 1
fi

# Sign the key — Vault returns a signed certificate
vault write -field=signed_key \
  "${SSH_MOUNT}/sign/${ROLE}" \
  public_key=@"${SSH_PUBKEY}" \
  > "${SSH_SIGNED_CERT}"

echo "[OK] Signed certificate saved to ${SSH_SIGNED_CERT}"

# Show cert details
echo ""
echo "=== Certificate Details ==="
ssh-keygen -L -f "${SSH_SIGNED_CERT}" 2>/dev/null | head -20
echo ""

# ──────────────────────────────────────────────
# Step 4: Connect (if target provided)
# ──────────────────────────────────────────────

if [ -n "$TARGET" ]; then
  echo "=== Connecting to ${TARGET} ==="
  # The -i flag uses the base key; SSH auto-finds the -cert.pub file
  ssh -i "${SSH_PUBKEY%.pub}" "${TARGET}"
else
  echo "=== Ready ==="
  echo "Your cert is valid. Connect with:"
  echo ""
  echo "  ssh -i ~/.ssh/id_rsa root@<hostname>"
  echo "  ssh -i ~/.ssh/id_rsa deploy@<hostname>"
  echo ""
  echo "The cert will be used automatically."
fi
