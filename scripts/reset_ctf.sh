#!/usr/bin/env bash
# ==============================================================================
# reset_ctf.sh - restores the machine to a fresh CTF state: tears down the
# current deployment and re-installs from the persisted project copy at
# ${CTF_ROOT}/src, generating a brand new set of random flags and passwords.
#
# Resets: users, passwords, SSH configuration, web files, flags, backup
# files, SSH keys, .bash_history, .beroot, permissions, sudo configuration,
# and temporary challenge files.
#
# Does NOT affect Proxmox, other VMs, the host filesystem, or the LAN - this
# script only ever touches the local machine.
#
# Usage: sudo bash scripts/reset_ctf.sh
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

[ "$(id -u)" -eq 0 ] || { echo "Run as root."; exit 1; }

echo "[*] Resetting CTF environment..."
bash "${SCRIPT_DIR}/uninstall_ctf.sh"

echo "[*] Re-installing from ${CTF_ROOT}/src..."
bash "${CTF_ROOT}/src/scripts/install_ctf.sh"

echo "[*] Reset complete."
