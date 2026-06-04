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
# Run from workstation OR bastion2:
#   ./scripts/linux-reconcile.sh
#
# For blue-anydesk:
#   export anydesk_ssh_password=<password>
#   ./scripts/linux-reconcile.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

# ── Find manifest — workstation path first, bastion2 fallback ──

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${1:-}"

if [ -z "$MANIFEST" ]; then
    if [ -f "${SCRIPT_DIR}/users.auto.yml" ]; then
        MANIFEST="${SCRIPT_DIR}/users.auto.yml"
    elif [ -f "/tmp/users.auto.yml" ]; then
        MANIFEST="/tmp/users.auto.yml"
    else
        echo "ERROR: manifest not found."
        echo "Run terraform apply on your workstation first, then retry."
        exit 1
    fi
fi

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# ── Parse manifest ───────────────────────────────────────

# parse_manifest <section> [<section> ...]
# Only includes users from the specified manifest sections.
#   bastions:     vault_users service_accounts
#   anydesk:      vault_users
#   core-servers: vault_users core_service_accounts

parse_manifest() {
    local sections="$*"
    python3 - "$MANIFEST" "$sections" <<'PYEOF'
import re, sys
allowed = set(sys.argv[2].split())
users = {}
section = None
current = None
for line in open(sys.argv[1]):
    sm = re.match(r'^"([^"]+)":\s*$', line)
    if sm:
        section = sm.group(1) if sm.group(1) in allowed else None
        current = None
        continue
    if section:
        um = re.match(r'^  "([^"]+)":\s*$', line)
        if um:
            current = um.group(1)
        elif current:
            s = re.search(r'"status":\s*"([^"]+)"', line)
            if s:
                users[current] = s.group(1)
                current = None
for u, s in sorted(users.items()):
    print(u, s)
PYEOF
}

# ── Reconcile one server ─────────────────────────────────
# $1 = display name
# $2 = ssh target (e.g. "ssh.auto-deploy.net", "192.168.2.100")
# $3 = optional: "sudo" if ej user needs sudo to reach root commands

reconcile_server() {
    local name="$1"
    local target="$2"
    local use_sudo="${3:-}"
    local sections="${4:-vault_users service_accounts}"

    header "SERVER: $name"

    local sudo_prefix=""
    [ -n "$use_sudo" ] && sudo_prefix="sudo "

    # Get human users (UID 1000–65533)
    os_users=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$target" \
        "${sudo_prefix}getent passwd | awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1}'" \
        2>/dev/null | sort || echo "")

    if [ -z "$os_users" ]; then
        echo "  (could not reach server or no human users found)"
        return
    fi

    manifest_users=$(parse_manifest $sections)

    # Check each OS user against manifest
    while IFS= read -r user; do
        [ -z "$user" ] && continue
        manifest_status=$(echo "$manifest_users" | awk -v u="$user" '$1==u {print $2}')

        if [ -z "$manifest_status" ]; then
            rogue "$user"
        elif [ "$manifest_status" = "enabled" ]; then
            ok "$user  (enabled)"
        else
            # disabled or removed — verify account is locked
            lock=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no "$target" \
                "${sudo_prefix}passwd -S ${user} 2>/dev/null | awk '{print \$2}'" \
                2>/dev/null || echo "unknown")
            if echo "$lock" | grep -q '^L'; then
                ok "$user  ($manifest_status — locked ✓)"
            else
                unlocked "$user  ($manifest_status in manifest but account is active)"
            fi
        fi
    done <<< "$os_users"

    # Check for enabled manifest users missing from OS
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        user=$(echo "$line" | awk '{print $1}')
        status=$(echo "$line" | awk '{print $2}')
        if [ "$status" = "enabled" ] && ! echo "$os_users" | grep -qx "$user"; then
            missing "$user"
        fi
    done <<< "$manifest_users"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo ""
echo -e "${BOLD}Linux User Reconciliation${NC}"
echo -e "Manifest: $MANIFEST"
printf '═%.0s' {1..55}; echo

# bastion2 — vault_users + service_accounts (not core_service_accounts)
reconcile_server "bastion2  (ssh.auto-deploy.net)" "ssh.auto-deploy.net" "sudo" "vault_users service_accounts"

# bastion0 — vault_users + service_accounts (not core_service_accounts)
reconcile_server "bastion0  (192.168.2.100)" "192.168.2.100" "sudo" "vault_users service_accounts"

# blue-anydesk — ProxyJump through bastion, password auth, passwordless sudo
if [ -n "${anydesk_ssh_password:-}" ]; then
    export SSHPASS="${anydesk_ssh_password}"
    AD_SSH="sshpass -e ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password -o ProxyJump=ssh.auto-deploy.net ej@192.168.3.91"

    header "SERVER: blue-anydesk  (192.168.3.91)"

    os_users=$($AD_SSH "getent passwd | awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1}'" \
        2>/dev/null | sort || echo "")

    if [ -z "$os_users" ]; then
        echo "  (could not reach server)"
    else
        manifest_users=$(parse_manifest vault_users)
        while IFS= read -r user; do
            [ -z "$user" ] && continue
            manifest_status=$(echo "$manifest_users" | awk -v u="$user" '$1==u {print $2}')
            if [ -z "$manifest_status" ]; then
                rogue "$user"
            elif [ "$manifest_status" = "enabled" ]; then
                ok "$user  (enabled)"
            else
                lock=$($AD_SSH "sudo passwd -S ${user} 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "unknown")
                if echo "$lock" | grep -q '^L'; then
                    ok "$user  ($manifest_status — locked ✓)"
                else
                    unlocked "$user  ($manifest_status in manifest but account is active)"
                fi
            fi
        done <<< "$os_users"
    fi
else
    echo ""
    echo -e "  ${YELLOW}SKIPPED blue-anydesk${NC} — set anydesk_ssh_password to include it:"
    echo    "    export anydesk_ssh_password=<password>"
fi

# green-anydesk — uncomment when back online
# reconcile_server "green-anydesk  (<IP>)" "<IP>" "sudo"

# ── core-servers — password auth, ProxyJump ──────────────
if [ -n "${core_server_password:-}" ]; then
    export SSHPASS="${core_server_password}"
    CS_SSH_OPTS="-o StrictHostKeyChecking=no -o PreferredAuthentications=password -o ProxyJump=ssh.auto-deploy.net"

    for server_info in "util:192.168.2.97" "green:192.168.2.120" "blue:192.168.3.120"; do
        server_name="${server_info%%:*}"
        server_ip="${server_info##*:}"

        CS_SSH="sshpass -e ssh $CS_SSH_OPTS ej@${server_ip}"
        header "SERVER: ${server_name}  (${server_ip})"

        os_users=$($CS_SSH "getent passwd | awk -F: '\$3 >= 1000 && \$3 < 65534 {print \$1}'" \
            2>/dev/null | sort || echo "")

        if [ -z "$os_users" ]; then
            echo "  (could not reach server)"
        else
            manifest_users=$(parse_manifest vault_users core_service_accounts)
            while IFS= read -r user; do
                [ -z "$user" ] && continue
                manifest_status=$(echo "$manifest_users" | awk -v u="$user" '$1==u {print $2}')
                if [ -z "$manifest_status" ]; then
                    rogue "$user"
                elif [ "$manifest_status" = "enabled" ]; then
                    ok "$user  (enabled)"
                else
                    lock=$($CS_SSH "sudo passwd -S ${user} 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "unknown")
                    if echo "$lock" | grep -q '^L'; then
                        ok "$user  ($manifest_status — locked ✓)"
                    else
                        unlocked "$user  ($manifest_status in manifest but account is active)"
                    fi
                fi
            done <<< "$os_users"
        fi
    done
else
    echo ""
    echo -e "  ${YELLOW}SKIPPED core-servers${NC} — set core_server_password to include them:"
    echo    "    export core_server_password=<password>"
fi

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
printf '═%.0s' {1..55}; echo

TOTAL=$((ROGUE_COUNT + MISSING_COUNT + UNLOCKED_COUNT))
if [ "$TOTAL" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}  ✓  CLEAN — all servers match the manifest${NC}"
else
    [ "$ROGUE_COUNT"    -gt 0 ] && echo -e "${RED}${BOLD}  ✗  $ROGUE_COUNT ROGUE user(s)    — on server, not in manifest${NC}"
    [ "$MISSING_COUNT"  -gt 0 ] && echo -e "${YELLOW}${BOLD}  ?  $MISSING_COUNT MISSING user(s)  — enabled in manifest, not on server${NC}"
    [ "$UNLOCKED_COUNT" -gt 0 ] && echo -e "${YELLOW}${BOLD}  !  $UNLOCKED_COUNT UNLOCKED user(s) — should be locked, are not${NC}"
    echo ""
    echo    "  Fix: run Ansible to enforce correct state:"
    echo    "    ansible-playbook scripts/sync-os-users.yml -i scripts/inventory.yml \\"
    echo    "      --extra-vars \"anydesk_ssh_password=<password>\""
fi

printf '═%.0s' {1..55}; echo
echo ""
