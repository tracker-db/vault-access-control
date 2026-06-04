#!/usr/bin/env bash
# scripts/cleanup-rogue-users.sh
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# One-time cleanup: delete rogue OS accounts from all servers.
#
# These users were removed from vault-users.tf but Ansible was not
# run before the blocks were deleted — so their OS accounts remain.
#
# Runs from workstation using ~/.ssh/config for connections.
# For blue-anydesk: export anydesk_ssh_password=<password>
#
# Usage:
#   ./scripts/cleanup-rogue-users.sh             (dry run — shows what would happen)
#   ./scripts/cleanup-rogue-users.sh --apply     (deletes accounts + home dirs)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
set -euo pipefail

APPLY=false
[[ "${1:-}" == "--apply" ]] && APPLY=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

# ── Rogue users to delete ────────────────────────────────

ROGUE_USERS=(
  aman aqib artif arti behnam bhavesh boby
  es farukh fawaz-test golla hamza jerry jorge
  kishor lucky mangash manish miguel nandha neel
  niam nirav omen pavan peterlight ramu ravi
  richard roy saif santosh sergej solomon
  taimour test testuser tim ubuntu vikhil
)

header() { echo ""; echo -e "${BOLD}$1${NC}"; printf '─%.0s' {1..55}; echo; }
deleted() { echo -e "  ${RED}✗  DELETED${NC}  $1"; }
skipped() { echo -e "  ${YELLOW}–  SKIP${NC}     $1  (not found on this server)"; }
would()   { echo -e "  ${YELLOW}→  WOULD DELETE${NC}  $1"; }

delete_user_on_server() {
    local target="$1"   # SSH target (e.g. ssh.auto-deploy.net or 192.168.2.100)
    local user="$2"

    exists=$(ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$target" \
        "id ${user} &>/dev/null && echo yes || echo no" 2>/dev/null || echo "no")

    if [ "$exists" = "yes" ]; then
        if $APPLY; then
            ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$target" \
                "sudo pkill -u ${user} 2>/dev/null; sudo userdel -rf ${user}" 2>/dev/null && \
                deleted "$user" || deleted "$user (check manually)"
        else
            would "$user"
        fi
    else
        skipped "$user"
    fi
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

if ! $APPLY; then
    echo ""
    echo -e "${YELLOW}${BOLD}DRY RUN — pass --apply to actually delete accounts${NC}"
fi

echo ""
echo -e "${BOLD}Rogue User Cleanup — ${#ROGUE_USERS[@]} users to remove${NC}"
printf '═%.0s' {1..55}; echo

# ── bastion2 ─────────────────────────────────────────────
header "bastion2  (ssh.auto-deploy.net)"
for user in "${ROGUE_USERS[@]}"; do
    delete_user_on_server "ssh.auto-deploy.net" "$user"
done

# ── bastion0 ─────────────────────────────────────────────
header "bastion0  (192.168.2.100)"
for user in "${ROGUE_USERS[@]}"; do
    delete_user_on_server "192.168.2.100" "$user"
done

# ── blue-anydesk ─────────────────────────────────────────
if [ -n "${anydesk_ssh_password:-}" ]; then
    header "blue-anydesk  (192.168.3.91)"
    for user in "${ROGUE_USERS[@]}"; do
        delete_user_on_server \
            "sshpass -p '${anydesk_ssh_password}' ssh -o StrictHostKeyChecking=no -o PreferredAuthentications=password ej@192.168.3.91 sudo" \
            "$user"
    done
else
    echo ""
    echo -e "  ${YELLOW}SKIPPED blue-anydesk${NC} — set anydesk_ssh_password:"
    echo    "    export anydesk_ssh_password=<password>"
    echo    "    ./scripts/cleanup-rogue-users.sh --apply"
fi

# green-anydesk — uncomment when back online
# header "green-anydesk  (<IP>)"
# for user in "${ROGUE_USERS[@]}"; do
#     delete_user_on_server "sshpass -p '${anydesk_ssh_password}' ssh -o StrictHostKeyChecking=no ej@<IP> sudo" "$user"
# done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
echo ""
printf '═%.0s' {1..55}; echo
if $APPLY; then
    echo -e "${GREEN}${BOLD}  Done. Run linux-reconcile.sh to verify.${NC}"
else
    echo -e "${YELLOW}${BOLD}  Dry run complete. Run with --apply to delete.${NC}"
fi
printf '═%.0s' {1..55}; echo
echo ""
