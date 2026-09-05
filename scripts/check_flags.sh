#!/usr/bin/env bash
# ==============================================================================
# check_flags.sh - organizer-only script that validates every flag currently
# deployed on disk decodes back to the value recorded at install time.
#
# Usage: sudo bash scripts/check_flags.sh
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

SECRETS_FILE="${CTF_ORGANIZER_DIR}/secrets.env"
[ -f "${SECRETS_FILE}" ] || { echo "Secrets manifest not found at ${SECRETS_FILE}. Run install_ctf.sh first."; exit 1; }
# shellcheck source=/dev/null
source "${SECRETS_FILE}"

FAILED=0

check() {
    local name="$1" expected="$2" actual="$3"
    if [ "${expected}" = "${actual}" ] && [ -n "${expected}" ]; then
        printf '%-10s PASS  (%s)\n' "${name}" "${actual}"
    else
        printf '%-10s FAIL  (expected=%s actual=%s)\n' "${name}" "${expected}" "${actual}"
        FAILED=1
    fi
}

flag1_b64="$(curl -s --max-time 5 "http://127.0.0.1/hidden/${ROBOTS_HIDDEN_PATH}/index.html" 2>/dev/null | grep -oP 'Ref:\s*\K\S+')"
flag1_decoded="$(printf '%s' "${flag1_b64}" | base64 -d 2>/dev/null)"
check "FLAG1" "${FLAG1:-}" "${flag1_decoded}"

flag2_b64="$(grep -oP '^entry_hash=\K.*' "${AGENT99_HOME}/.net-cache.idx" 2>/dev/null)"
flag2_decoded="$(printf '%s' "${flag2_b64}" | base64 -d 2>/dev/null)"
check "FLAG2" "${FLAG2:-}" "${flag2_decoded}"

flag3_b64="$(grep -A1 'Archive checksum' "${BACKUP_DIR}/ops-notes.txt" 2>/dev/null | tail -n1)"
flag3_decoded="$(printf '%s' "${flag3_b64}" | base64 -d 2>/dev/null)"
check "FLAG3" "${FLAG3:-}" "${flag3_decoded}"

flag4_b64="$(grep -oP "LEGACY_TOKEN='\K[^']+" "${AGENT999_HOME}/.bash_history" 2>/dev/null)"
flag4_decoded="$(printf '%s' "${flag4_b64}" | base64 -d 2>/dev/null)"
check "FLAG4" "${FLAG4:-}" "${flag4_decoded}"

flag5_b64="$(cat /root/.sysconfig_cache 2>/dev/null)"
flag5_decoded="$(printf '%s' "${flag5_b64}" | base64 -d 2>/dev/null)"
check "FLAG5" "${FLAG5:-}" "${flag5_decoded}"

echo
if [ "${FAILED}" -eq 0 ]; then
    echo "ALL FLAGS VALID"
    exit 0
else
    echo "FLAG VALIDATION FAILED"
    exit 1
fi
