#!/usr/bin/env bash
# ==============================================================================
# test_flags.sh - organizer/dev test: confirms every flag decodes correctly
# AND that the on-disk representation is not the plaintext flag itself.
#
# Usage: sudo bash tests/test_flags.sh
# Not for player use; do not expose this script or its output.
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/config.sh
source "${SCRIPT_DIR}/../scripts/config.sh"

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

echo "== Decode/compare check =="
bash "${SCRIPT_DIR}/../scripts/check_flags.sh"
decode_status=$?

echo
echo "== Stored-representation check (must NOT be plaintext) =="
[ -f "${CTF_ORGANIZER_DIR}/secrets.env" ] && source "${CTF_ORGANIZER_DIR}/secrets.env"

FAILED=0
not_plaintext() {
    local name="$1" flag="$2" file="$3"
    if [ -f "$file" ] && grep -qF "$flag" "$file" 2>/dev/null; then
        printf '%-10s FAIL  (plaintext found in %s)\n' "$name" "$file"
        FAILED=1
    else
        printf '%-10s PASS\n' "$name"
    fi
}

not_plaintext "FLAG1" "${FLAG1:-__unset__}" "${CTF_WEB_ROOT}/hidden/${ROBOTS_HIDDEN_PATH}/index.html"
not_plaintext "FLAG2" "${FLAG2:-__unset__}" "${AGENT99_HOME}/.net-cache.idx"
not_plaintext "FLAG3" "${FLAG3:-__unset__}" "${BACKUP_DIR}/ops-notes.txt"
not_plaintext "FLAG4" "${FLAG4:-__unset__}" "${AGENT999_HOME}/.bash_history"
not_plaintext "FLAG5" "${FLAG5:-__unset__}" "/root/.sysconfig_cache"

exit $(( decode_status | FAILED ))
