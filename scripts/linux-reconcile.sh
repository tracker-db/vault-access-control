#!/usr/bin/env bash
# scripts/linux-reconcile.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Reconcile actual OS users on all servers against the
# Ansible-managed manifest (users.auto.yml).
#
# Complements vault-reconcile.sh — together they give
# complete coverage across Vault and all Linux servers.
#
# Reports per server:
#   ROGUE    — user exists on OS, NOT in manifest
#   MISSING  — user in manifest as enabled, NOT on OS (run Ansible)
#   UNLOCKED — user in manifest as disabled/removed but NOT locked on OS
#   OK       — user matches expected state
#
# Run FROM bastion2 (primary — has LAN access to all servers):
#   ./scripts/linux-reconcile.sh
#
# Prerequisites:
#   - users.auto.yml exists at /tmp/users.auto.yml on bastion2
#     (written there by terraform apply automatically)
#   - SSH key access from bastion2 to bastion0
#   - anydesk_ssh_password env var set for blue-anydesk
#     export anydesk_ssh_password=<password>
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

MANIFEST="${1:-/tmp/users.auto.yml}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

ROGUE_COUNT=0
MISSING_COUNT=0
UNLOCKED_COUNT=0

ok()       { echo -e "  ${GREEN}✓${NC}  $1"; }
rogue()    { echo -e "  ${RED}✗  ROGUE${NC}    $1  ← on server, NOT in manifest"; ROGUE_COUNT=$((ROGUE_COUNT+1)); }
missing()  { echo -e "  ${YELLOW}?  MISSING${NC}   $1  ← enabled in manifest, not on server (run Ansible)"; MISSING_COUNT=$((MISSING_COUNT+1)); }
unlocked() { echo -e "  ${YELLOW}!  UNLOCKED${NC}  $1  ← disabled/removed in manifest but account is NOT locked"; UNLOCKED_COUNT=$((UNLOCKED_COUNT+1)); }
header()   { echo ""; echo -e "${BOLD}$1${NC}"; printf '─%.0s' {1..55}; echo; }

# ── Parse manifest — extract user and status ─────────────

parse_manifest() {
    python3 - "$MANIFEST" <<'PYEOF'
import re, sys

users = {}
current = None
for line in open(sys.argv[1]):
    m = re.match(r'^  "([^"]+)":\s*$', line)
    if m:
        current = m.group(1)
    elif current:
        s = re.search(r'"status":\s*"([^"]+)"', line)
        if s:
            users[current] = s.group(1)
            current = None

for u, s in sorted(users.items()):
    print(u, s)
PYEOF
}

# ── Get human users from a server ────────────────────────
# UID >= 1000, excludes nobody (65534)

GET_USERS_CMD='getent passwd | awk -F: '"'"'$3 >= 1000 && $3 < 65534 {print $1}'"'"' | sort'

# ── Check if a user account is locked ────────────────────
# Returns "locked" or "unlocked"

CHECK_LOCK_CMD() {
    local user="$1"
    echo "passwd -S ${user} 2>/dev/null | awk '{print \$2}' | grep -q '^L' && echo locked || echo unlocked"
}

# ── Reconcile one server ─────────────────────────────────

reconcile_server() {
    local server_name="$1"
    local ssh_cmd="$2"       # full ssh command prefix, e.g. "ssh root@192.168.2.100"

    header "SERVER: $server_name"

    # Get actual OS users
    os_users=$(eval "$ssh_cmd '$GET_USERS_CMD'" 2>/dev/null | sort || echo "")

    if [ -z "$os_users" ]; then
        echo "  (could not reach server or no human users found)"
        return
    fi

    # Read manifest
    manifest_users=$(parse_manifest)

    # Check each OS user against manifest
    while IFS= read -r user; do
        [ -z "$user" ] && continue
        manifest_status=$(echo "$manifest_users" | awk -v u="$user" '$1==u {print $2}')

        if [ -z "$manifest_status" ]; then
            rogue "$user"
        else
            # User is in manifest — check lock state matches expected
            if [ "$manifest_status" = "enabled" ]; then
                ok "$user  (enabled)"
            else
                # disabled or removed — should be locked
                lock_state=$(eval "$ssh_cmd \"$(CHECK_LOCK_CMD $user)\"" 2>/dev/null || echo "unknown")
                if [ "$lock_state" = "locked" ]; then
                    ok "$user  ($manifest_status — locked ✓)"
                else
                    unlocked "$user  ($manifest_status in manifest but account is active)"
                fi
            fi
        fi
    done <<< "$os_users"

    # Check for enabled manifest users missing from OS
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        user=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        if [ "$status" = "enabled" ]; then
            if ! echo "$os_users" | grep -qx "$user"; then
                missing "$user"
            fi
        fi
    done <<< "$manifest_users"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if [ ! -f "$MANIFEST" ]; then
    echo -e "${RED}ERROR: manifest not found at $MANIFEST${NC}"
    echo "Run terraform apply on your workstation first — it copies the manifest here."
    exit 1
fi

echo ""
echo -e "${BOLD}Linux User Reconciliation${NC}"
echo -e "Manifest: $MANIFEST"
printf '═%.0s' {1..55}; echo

# ── Servers ──────────────────────────────────────────────

reconcile_server "bastion2 (this server)" "bash -c"

reconcile_server "bastion0  (192.168.2.100)" "ssh -o StrictHostKeyChecking=no root@192.168.2.100"

if [ -n "${anydesk_ssh_password:-}" ]; then
    reconcile_server "blue-anydesk  (192.168.3.91)" \
        "sshpass -p '${anydesk_ssh_password}' ssh -o StrictHostKeyChecking=no ej@192.168.3.91 sudo"
else
    echo ""
    echo -e "  ${YELLOW}SKIPPED blue-anydesk${NC} — set anydesk_ssh_password to include it:"
    echo    "    export anydesk_ssh_password=<password>"
    echo    "    ./scripts/linux-reconcile.sh"
fi

# green-anydesk — uncomment when back online
# reconcile_server "green-anydesk  (<TBD>)" "sshpass -p '${anydesk_ssh_password}' ssh -o StrictHostKeyChecking=no ej@<IP> sudo"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
printf '═%.0s' {1..55}; echo

TOTAL=$((ROGUE_COUNT + MISSING_COUNT + UNLOCKED_COUNT))
if [ "$TOTAL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✓  CLEAN — all servers match the manifest${NC}"
else
    [ "$ROGUE_COUNT"   -gt 0 ] && echo -e "${RED}${BOLD}  ✗  $ROGUE_COUNT ROGUE user(s)   — exist on server, not in manifest${NC}"
    [ "$MISSING_COUNT" -gt 0 ] && echo -e "${YELLOW}${BOLD}  ?  $MISSING_COUNT MISSING user(s) — in manifest as enabled, not on server${NC}"
    [ "$UNLOCKED_COUNT" -gt 0 ] && echo -e "${YELLOW}${BOLD}  !  $UNLOCKED_COUNT UNLOCKED user(s) — should be locked, are not${NC}"
    echo ""
    echo    "  Fix: run Ansible to enforce correct state:"
    echo    "    ansible-playbook sync-os-users.yml -i inventory.yml \\"
    echo    "      --extra-vars \"anydesk_ssh_password=<password>\""
fi

printf '═%.0s' {1..55}; echo
echo ""
