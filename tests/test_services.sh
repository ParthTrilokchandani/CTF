#!/usr/bin/env bash
# ==============================================================================
# test_services.sh - organizer/dev test: confirms the core services the CTF
# depends on are up and listening on the expected ports.
#
# Usage: sudo bash tests/test_services.sh
# Not for player use; do not expose this script or its output.
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/config.sh
source "${SCRIPT_DIR}/../scripts/config.sh"

FAILED=0
check() {
    if [ "$2" -eq 0 ]; then printf '%-30s PASS\n' "$1"; else printf '%-30s FAIL\n' "$1"; FAILED=1; fi
}

systemctl is-active --quiet apache2
check "apache2 active" $?

systemctl is-active --quiet ssh
check "ssh active" $?

ss -tln 2>/dev/null | grep -q ':80 '
check "port 80 listening" $?

ss -tln 2>/dev/null | grep -q ":${SSH_PORT} "
check "SSH port ${SSH_PORT} listening" $?

! ss -tln 2>/dev/null | grep -q ':22 '
check "port 22 NOT listening" $?

ufw status 2>/dev/null | grep -qi 'Status: active'
check "firewall active" $?

exit "${FAILED}"
