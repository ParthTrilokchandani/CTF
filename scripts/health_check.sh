#!/usr/bin/env bash
# ==============================================================================
# health_check.sh - verifies that every CTF component is present and correctly
# configured. Intended for organizer use only - never expose this script or
# its output to players.
#
# Usage: sudo bash scripts/health_check.sh
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

FAILED=0

result() {
    local name="$1" status="$2"
    if [ "${status}" -eq 0 ]; then
        printf '%-18s PASS\n' "${name}"
    else
        printf '%-18s FAIL\n' "${name}"
        FAILED=1
    fi
}

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

# Web server
curl -s -o /dev/null -w '' --max-time 5 "http://127.0.0.1/" 2>/dev/null
result "Web server" $?

# robots.txt
robots_body="$(curl -s --max-time 5 "http://127.0.0.1/robots.txt" 2>/dev/null)"
echo "${robots_body}" | grep -q "${ROBOTS_HIDDEN_PATH}"
result "robots.txt" $?

# Image (stego artifact)
[ -f "${STEGHIDE_IMAGE_PATH}" ]
result "Image" $?

# SSH service
systemctl is-active --quiet ssh
result "SSH" $?

# SSH port
ss -tln 2>/dev/null | grep -q ":${SSH_PORT} "
result "SSH port" $?

# Agent99 user
id "${AGENT99_USER}" >/dev/null 2>&1
result "Agent99" $?

# Agent999 user
id "${AGENT999_USER}" >/dev/null 2>&1
result "Agent999" $?

# Permissions (home directories locked to 700)
agent99_mode="$(stat -c '%a' "${AGENT99_HOME}" 2>/dev/null || echo '')"
agent999_mode="$(stat -c '%a' "${AGENT999_HOME}" 2>/dev/null || echo '')"
[ "${agent99_mode}" = "700" ] && [ "${agent999_mode}" = "700" ]
result "Permissions" $?

# Backup
[ -f "${BACKUP_DIR}/ops-notes.txt" ]
result "Backup" $?

# SSH key
# The backup copy is deliberately world-readable (0644) - that's the
# intended vulnerability - but ssh-keygen -y refuses to read a private key
# with permissions that open ("bad permissions"). Check a 0600 scratch copy
# instead of the live file so the intentional insecurity doesn't break this
# check.
key_tmp="$(mktemp)"
cp "${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}" "${key_tmp}" 2>/dev/null
chmod 600 "${key_tmp}"
derived_pubkey="$(ssh-keygen -y -f "${key_tmp}" 2>/dev/null)"
rm -f "${key_tmp}"
[ -f "${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}" ] && \
    [ -f "${AGENT999_HOME}/.ssh/authorized_keys" ] && \
    [ -n "${derived_pubkey}" ] && \
    grep -qF "${derived_pubkey}" "${AGENT999_HOME}/.ssh/authorized_keys" 2>/dev/null
result "SSH key" $?

# .bash_history
[ -s "${AGENT999_HOME}/.bash_history" ]
result ".bash_history" $?

# .beroot
[ -x "${BEROOT_BIN}" ]
result ".beroot" $?

# Sudo rule
[ -f "${SUDOERS_FILE}" ] && visudo -cf "${SUDOERS_FILE}" >/dev/null 2>&1 && \
    grep -qF "${BEROOT_BIN}" "${SUDOERS_FILE}"
result "Sudo rule" $?

# Root flag
[ -f /root/.sysconfig_cache ]
result "Root flag" $?

echo
if [ "${FAILED}" -eq 0 ]; then
    echo "CTF STATUS: READY"
    exit 0
else
    echo "CTF STATUS: FAILED"
    exit 1
fi
