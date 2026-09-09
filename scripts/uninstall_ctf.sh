#!/usr/bin/env bash
# ==============================================================================
# uninstall_ctf.sh - tears down the live CTF deployment (users, web content,
# SSH/sudo configuration, backup/challenge files, firewall rules).
#
# This does NOT delete ${CTF_ROOT}/src (the persisted project checkout) or
# ${CTF_ROOT}/.organizer (the secrets manifest), so it is safe to run from
# the persisted copy itself and safe to follow with install_ctf.sh again.
# If you want those removed too, do it manually afterwards:
#   sudo rm -rf /opt/ctf
#
# This script only ever touches the local machine. It never reaches out to
# Proxmox, other VMs, or anything else on the LAN.
#
# Usage: sudo bash scripts/uninstall_ctf.sh
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

log() { printf '\n[*] %s\n' "$1"; }

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

log "Removing web deployment"
a2dissite ctf.conf >/dev/null 2>&1 || true
rm -f /etc/apache2/sites-available/ctf.conf
a2ensite 000-default.conf >/dev/null 2>&1 || true
systemctl reload apache2 >/dev/null 2>&1 || true
rm -rf "${CTF_WEB_ROOT}"

log "Removing sudo rule"
rm -f "${SUDOERS_FILE}"

log "Removing SSH drop-in (SSH reverts to its distro default: port 22)"
rm -f /etc/ssh/sshd_config.d/99-ctf.conf
if sshd -t 2>/dev/null; then
    systemctl restart ssh >/dev/null 2>&1 || true
fi

log "Removing users ${AGENT99_USER} and ${AGENT999_USER}"
id "${AGENT99_USER}" >/dev/null 2>&1 && userdel -r "${AGENT99_USER}" >/dev/null 2>&1 || true
id "${AGENT999_USER}" >/dev/null 2>&1 && userdel -r "${AGENT999_USER}" >/dev/null 2>&1 || true

log "Removing backup and decoy directories"
rm -rf "${BACKUP_DIR}" "${DECOY_BACKUP_DIR}"

log "Removing decoy SUID binary"
rm -f "${SUID_DECOY_BIN}"

log "Removing root flag file"
rm -f /root/.sysconfig_cache

log "Resetting firewall"
ufw --force reset >/dev/null 2>&1 || true

log "Removing transfer-port watchdog"
systemctl disable --now ctf-port-watchdog.service >/dev/null 2>&1 || true
rm -f /etc/systemd/system/ctf-port-watchdog.service
systemctl daemon-reload >/dev/null 2>&1 || true

log "Uninstall complete (${CTF_ROOT}/src and ${CTF_ORGANIZER_DIR} were left in place)"
