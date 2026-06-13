#!/bin/bash
# bootstrap.sh — Day-0 greenfield setup for the tracker-db pipeline infrastructure.
#
# Run once from blue-anydesk (/home/ej/vault-access-control).
# Prerequisites:
#   - VAULT_TOKEN set (admin token — already in your shell if you manage Vault)
#   - VAULT_ADDR set (or defaults to https://vault.nextresearch.io)
#   - GitHub PAT with admin:org scope on tracker-db (pass as GITHUB_PAT env var or enter when prompted)
#   - SSH access to util (192.168.2.97) via runner_key or password
#
# What this does:
#   1. terraform apply vault-access-control — creates pipeline-reader policy + AppRole
#   2. Reads AppRole role_id + generates secret_id for github-actions-runner
#   3. Writes .env to util:/storage/docker/next-runner
#   4. Clones / updates next-runner on util
#   5. Builds and starts 4 runner containers
#   6. Registers runner_key on blue-anydesk so the workflow's apply step can SSH back

set -euo pipefail

UTIL="ej@192.168.2.97"
NEXT_RUNNER_DIR="/storage/docker/next-runner"
VAULT_ADDR="${VAULT_ADDR:-https://vault.nextresearch.io}"
BLUE_ANYDESK_IP="192.168.3.91"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── Preflight ────────────────────────────────────────────────────────────────

if [ -z "${VAULT_TOKEN:-}" ]; then
  echo "ERROR: VAULT_TOKEN is not set. Export your Vault admin token first."
  exit 1
fi

if [ -z "${GITHUB_PAT:-}" ]; then
  read -rsp "GitHub PAT (admin:org scope on tracker-db org): " GITHUB_PAT
  echo
fi

if [ -z "${GITHUB_PAT}" ]; then
  echo "ERROR: GitHub PAT is required."
  exit 1
fi

export VAULT_ADDR
export VAULT_TOKEN

echo
echo "════════════════════════════════════════"
echo " tracker-db bootstrap — $(date '+%Y-%m-%d %H:%M')"
echo " Vault: $VAULT_ADDR"
echo " Util:  $UTIL"
echo "════════════════════════════════════════"
echo

# ── Step 1: Apply vault-access-control ──────────────────────────────────────

echo "▶ Step 1/6 — Applying vault-access-control Terraform..."
cd "$REPO_ROOT"
terraform init -input=false -upgrade -reconfigure 2>&1 | tail -5
terraform apply -input=false -auto-approve
echo "  ✓ Vault policies and AppRole updated."
echo

# ── Step 2: Fetch AppRole credentials ───────────────────────────────────────

echo "▶ Step 2/6 — Fetching AppRole credentials for github-actions-runner..."
ROLE_ID=$(vault read -field=role_id auth/approle/role/github-actions-runner/role-id)
SECRET_ID=$(vault write -f -field=secret_id auth/approle/role/github-actions-runner/secret-id)

if [ -z "$ROLE_ID" ] || [ -z "$SECRET_ID" ]; then
  echo "ERROR: Could not retrieve AppRole credentials."
  exit 1
fi
echo "  ✓ role_id and secret_id obtained."
echo

# ── Step 3: Write .env to util ───────────────────────────────────────────────

echo "▶ Step 3/6 — Writing .env to util..."
ssh "$UTIL" "mkdir -p $NEXT_RUNNER_DIR"

ssh "$UTIL" "cat > $NEXT_RUNNER_DIR/.env" <<EOF
GITHUB_URL=https://github.com/tracker-db
GITHUB_PAT=${GITHUB_PAT}
RUNNER_1_NAME=tracker-db-1
RUNNER_2_NAME=tracker-db-2
RUNNER_3_NAME=tracker-db-3
RUNNER_4_NAME=tracker-db-4
RUNNER_LABELS=self-hosted,linux,x64,terraform,docker

# Vault AppRole auth — github-actions-runner AppRole.
# Terraform reads pipeline secrets from Vault at job run time.
VAULT_ADDR=${VAULT_ADDR}
VAULT_ROLE_ID=${ROLE_ID}
VAULT_SECRET_ID=${SECRET_ID}
EOF

ssh "$UTIL" "chmod 600 $NEXT_RUNNER_DIR/.env"
echo "  ✓ .env written to $UTIL:$NEXT_RUNNER_DIR"
echo

# ── Step 4: Clone / update next-runner on util ──────────────────────────────

echo "▶ Step 4/6 — Syncing next-runner repo on util..."
ssh "$UTIL" "
  if [ -d $NEXT_RUNNER_DIR/.git ]; then
    cd $NEXT_RUNNER_DIR && git pull --ff-only
  else
    # Ensure parent dir exists
    mkdir -p \$(dirname $NEXT_RUNNER_DIR)
    git clone git@github.com:tracker-db/next-runner.git $NEXT_RUNNER_DIR
  fi
"
echo "  ✓ next-runner repo ready on util."
echo

# ── Step 5: Build and start runners ─────────────────────────────────────────

echo "▶ Step 5/6 — Building runner image and starting containers..."
ssh "$UTIL" "cd $NEXT_RUNNER_DIR && docker compose build --quiet && docker compose up -d"
echo "  ✓ Containers started."
echo

# ── Step 6: Authorize runner_key on blue-anydesk ────────────────────────────
# The vault-access-control apply workflow SSHes from util → blue-anydesk to run
# terraform apply where the state file lives. The runner_key on util must be
# authorized on blue-anydesk for this to work.

echo "▶ Step 6/6 — Authorizing util runner_key on blue-anydesk ($BLUE_ANYDESK_IP)..."
RUNNER_PUBKEY=$(ssh "$UTIL" "cat ~/.ssh/runner_key.pub 2>/dev/null || echo ''")

if [ -z "$RUNNER_PUBKEY" ]; then
  echo "  ⚠  No runner_key found on util (~/.ssh/runner_key.pub). Skipping."
  echo "     Generate one with: ssh-keygen -t ed25519 -f ~/.ssh/runner_key -N ''"
  echo "     Then re-run step 6: ssh $BLUE_ANYDESK_IP 'echo \"<pubkey>\" >> ~/.ssh/authorized_keys'"
else
  # Use sshpass so this can run non-interactively if CORE_PASSWORD is set,
  # or fall back to interactive if it isn't.
  if [ -n "${CORE_PASSWORD:-}" ]; then
    sshpass -p "$CORE_PASSWORD" ssh -o StrictHostKeyChecking=no "ej@$BLUE_ANYDESK_IP" \
      "grep -qF '$RUNNER_PUBKEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$RUNNER_PUBKEY' >> ~/.ssh/authorized_keys"
  else
    ssh "ej@$BLUE_ANYDESK_IP" \
      "grep -qF '$RUNNER_PUBKEY' ~/.ssh/authorized_keys 2>/dev/null || echo '$RUNNER_PUBKEY' >> ~/.ssh/authorized_keys"
  fi
  echo "  ✓ runner_key authorized on blue-anydesk."
fi

echo
echo "════════════════════════════════════════"
echo " Bootstrap complete."
echo
echo " Runners should appear within ~30s at:"
echo " https://github.com/organizations/tracker-db/settings/actions/runners"
echo
echo " Verify with:"
echo "   ssh $UTIL 'docker compose -f $NEXT_RUNNER_DIR/docker-compose.yaml ps'"
echo "════════════════════════════════════════"
