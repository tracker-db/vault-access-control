#!/usr/bin/env bash
# scripts/vault-reconcile.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Reconcile Vault actual state against Terraform-managed state.
#
# terraform plan catches modifications to managed resources.
# This script catches NEW resources added directly to Vault
# outside of Terraform — rogue accounts, policies, mounts.
#
# Run this alongside terraform plan for complete coverage:
#   terraform plan               ← detects modifications
#   ./scripts/vault-reconcile.sh ← detects rogue additions
#
# Usage:
#   ./scripts/vault-reconcile.sh
#
# Prerequisites:
#   - VAULT_ADDR and VAULT_TOKEN set (or vault login done)
#   - Run from vault-access-control repo root
#   - terraform init completed
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

ROGUE_COUNT=0

ok()     { echo -e "  ${GREEN}✓${NC}  $1"; }
rogue()  { echo -e "  ${RED}✗  ROGUE${NC}  $1  ← in Vault, NOT in Terraform"; ROGUE_COUNT=$((ROGUE_COUNT+1)); }
skipped(){ echo -e "  ${YELLOW}–${NC}  $1  (built-in, skip)"; }
header() { echo ""; echo -e "${BOLD}$1${NC}"; printf '─%.0s' {1..55}; echo; }

# ── Pull managed resources from Terraform state ──────────

tf_users=$(terraform state list 2>/dev/null | \
    grep 'vault_generic_endpoint.users\[' | \
    sed 's/.*\["\(.*\)"\]/\1/' | sort)

tf_approles=$(terraform state list 2>/dev/null | \
    grep 'vault_approle_auth_backend_role.service_accounts\[' | \
    sed 's/.*\["\(.*\)"\]/\1/' | sort)

tf_policies=$(terraform show -json 2>/dev/null | python3 -c "
import json, sys
state = json.load(sys.stdin)
names = set()
def scan(module):
    for r in module.get('resources', []):
        if r['type'] == 'vault_policy':
            names.add(r['values']['name'])
    for child in module.get('child_modules', []):
        scan(child)
scan(state.get('values', {}).get('root_module', {}))
print('\n'.join(sorted(names)))
" 2>/dev/null)

tf_mounts=$(terraform show -json 2>/dev/null | python3 -c "
import json, sys
state = json.load(sys.stdin)
paths = set()
def scan(module):
    for r in module.get('resources', []):
        if r['type'] == 'vault_mount':
            paths.add(r['values']['path'])
    for child in module.get('child_modules', []):
        scan(child)
scan(state.get('values', {}).get('root_module', {}))
print('\n'.join(sorted(paths)))
" 2>/dev/null)

tf_auth=$(terraform show -json 2>/dev/null | python3 -c "
import json, sys
state = json.load(sys.stdin)
types = set()
def scan(module):
    for r in module.get('resources', []):
        if r['type'] == 'vault_auth_backend':
            types.add(r['values']['type'])
        if r['type'] == 'vault_jwt_auth_backend':
            types.add(r['values'].get('path', 'jwt'))
    for child in module.get('child_modules', []):
        scan(child)
scan(state.get('values', {}).get('root_module', {}))
print('\n'.join(sorted(types)))
" 2>/dev/null)

# ── Built-in Vault resources — always present, not managed ─

SYSTEM_MOUNTS="sys identity cubbyhole"
SYSTEM_AUTH="token"
SYSTEM_POLICIES="default root"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "USERPASS USERS — auth/userpass/users"

vault_users=$(vault list -format=json auth/userpass/users 2>/dev/null | \
    python3 -c "import json,sys; [print(u) for u in sorted(json.load(sys.stdin))]" || echo "")

if [ -z "$vault_users" ]; then
    echo "  (none)"
else
    while IFS= read -r user; do
        [ -z "$user" ] && continue
        if echo "$tf_users" | grep -qx "$user"; then
            ok "$user"
        else
            rogue "$user"
        fi
    done <<< "$vault_users"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "APPROLE SERVICE ACCOUNTS — auth/approle/role"

vault_approles=$(vault list -format=json auth/approle/role 2>/dev/null | \
    python3 -c "import json,sys; [print(r) for r in sorted(json.load(sys.stdin))]" || echo "")

if [ -z "$vault_approles" ]; then
    echo "  (none)"
else
    while IFS= read -r role; do
        [ -z "$role" ] && continue
        if echo "$tf_approles" | grep -qx "$role"; then
            ok "$role"
        else
            rogue "$role"
        fi
    done <<< "$vault_approles"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "POLICIES — vault policy list"

vault_policies=$(vault policy list -format=json 2>/dev/null | \
    python3 -c "import json,sys; [print(p) for p in sorted(json.load(sys.stdin))]" || echo "")

while IFS= read -r policy; do
    [ -z "$policy" ] && continue
    if echo "$SYSTEM_POLICIES" | grep -qw "$policy"; then
        skipped "$policy"
    elif echo "$tf_policies" | grep -qx "$policy"; then
        ok "$policy"
    else
        rogue "$policy"
    fi
done <<< "$vault_policies"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "SECRETS MOUNTS — vault secrets list"

vault_mounts=$(vault secrets list -format=json 2>/dev/null | \
    python3 -c "import json,sys; [print(p.rstrip('/')) for p in sorted(json.load(sys.stdin).keys())]" || echo "")

while IFS= read -r mount; do
    [ -z "$mount" ] && continue
    if echo "$SYSTEM_MOUNTS" | grep -qw "$mount"; then
        skipped "$mount"
    elif echo "$tf_mounts" | grep -qx "$mount"; then
        ok "$mount"
    else
        rogue "$mount"
    fi
done <<< "$vault_mounts"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
header "AUTH BACKENDS — vault auth list"

vault_auth_types=$(vault auth list -format=json 2>/dev/null | \
    python3 -c "
import json, sys
data = json.load(sys.stdin)
for info in sorted(data.values(), key=lambda x: x.get('type','')):
    print(info.get('type',''))
" || echo "")

while IFS= read -r backend; do
    [ -z "$backend" ] && continue
    if echo "$SYSTEM_AUTH" | grep -qw "$backend"; then
        skipped "$backend"
    elif echo "$tf_auth" | grep -qx "$backend"; then
        ok "$backend"
    else
        rogue "$backend"
    fi
done <<< "$vault_auth_types"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
printf '═%.0s' {1..55}; echo
if [ "$ROGUE_COUNT" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✓  CLEAN — everything in Vault is Terraform-managed${NC}"
else
    echo -e "${RED}${BOLD}  ✗  $ROGUE_COUNT ROGUE resource(s) found${NC}"
    echo -e "     Add them to Terraform (import) or remove from Vault."
fi
printf '═%.0s' {1..55}; echo
echo ""
