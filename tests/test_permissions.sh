#!/usr/bin/env bash
# ==============================================================================
# test_permissions.sh - organizer/dev test: verifies user isolation and that
# no user can shortcut past the intended privilege boundaries.
#
# Usage: sudo bash tests/test_permissions.sh
# Not for player use; do not expose this script or its output.
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/config.sh
source "${SCRIPT_DIR}/../scripts/config.sh"

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

FAILED=0
check() {
    if [ "$2" -eq 0 ]; then printf '%-45s PASS\n' "$1"; else printf '%-45s FAIL\n' "$1"; FAILED=1; fi
}

[ "$(stat -c '%a' "${AGENT99_HOME}")" = "700" ]
check "Agent99 home is 700" $?

[ "$(stat -c '%a' "${AGENT999_HOME}")" = "700" ]
check "Agent999 home is 700" $?

! sudo -u "${AGENT99_USER}" test -r "${AGENT999_HOME}" 2>/dev/null
check "Agent99 cannot read Agent999 home" $?

! sudo -u "${AGENT999_USER}" test -r "${AGENT99_HOME}" 2>/dev/null
check "Agent999 cannot read Agent99 home" $?

! sudo -u "${AGENT99_USER}" test -r /root 2>/dev/null
check "Agent99 cannot read /root" $?

# Agent99 must have no sudo privileges at all.
agent99_sudo="$(sudo -l -U "${AGENT99_USER}" 2>&1)"
! printf '%s' "${agent99_sudo}" | grep -qE '\(ALL(\s*:\s*ALL)?\)\s*ALL|NOPASSWD:\s*ALL'
check "Agent99 has no ALL/NOPASSWD:ALL sudo rule" $?

# Agent999 must be restricted to exactly the .beroot binary, no arguments.
agent999_sudo="$(sudo -l -U "${AGENT999_USER}" 2>&1)"
printf '%s' "${agent999_sudo}" | grep -qF "${BEROOT_BIN} \"\""
check "Agent999 sudo rule is limited to .beroot with no args" $?
! printf '%s' "${agent999_sudo}" | grep -qE '\(ALL(\s*:\s*ALL)?\)\s*ALL|NOPASSWD:\s*ALL'
check "Agent999 has no ALL/NOPASSWD:ALL sudo rule" $?

visudo -cf "${SUDOERS_FILE}" >/dev/null 2>&1
check "sudoers file passes visudo -c" $?

[ -f "${CTF_ORGANIZER_DIR}/secrets.env" ] && source "${CTF_ORGANIZER_DIR}/secrets.env"

# The .beroot password must not appear in Agent999's own history or home dir.
! grep -RqsF "${BEROOT_PASSWORD:-__unset__}" "${AGENT999_HOME}" 2>/dev/null
check ".beroot password not present in Agent999 home" $?

# A naive global grep for the flag format must not turn up plaintext anywhere
# outside the root-only organizer secrets manifest.
! grep -RIsE "${FLAG_PREFIX}\{[0-9a-f]{32}\}" / \
    --exclude-dir=proc --exclude-dir=sys --exclude-dir="${CTF_ORGANIZER_DIR}" \
    2>/dev/null | grep -q .
check "No plaintext flags found via naive global grep" $?

exit "${FAILED}"
