#!/usr/bin/env bash
# ==============================================================================
# CTF central configuration.
#
# Every other script (install / reset / health_check / check_flags /
# uninstall / tests) sources this file so that usernames, paths, ports and
# secrets only ever need to change in ONE place.
#
# This file is meant to be edited by the organizer BEFORE running
# install_ctf.sh. It must never be copied into anything web-servable.
# ==============================================================================

# ---- Filesystem layout -------------------------------------------------
CTF_ROOT="/opt/ctf"                      # organizer-owned install root (root:root 700)
CTF_ORGANIZER_DIR="${CTF_ROOT}/.organizer"   # generated secrets manifest lives here (600)
# install_ctf.sh copies the whole ctf-project checkout into ${CTF_ROOT}/src on
# first run, so reset_ctf.sh / health_check.sh / uninstall_ctf.sh can be
# re-run later from that persisted copy without needing the organizer's
# original checkout to still be present.
CTF_SCRIPTS_DIR="${CTF_ROOT}/src/scripts"
CTF_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # path to the ctf-project checkout being installed from

CTF_WEB_ROOT="/var/www/ctf"

# ---- SSH -----------------------------------------------------------------
SSH_PORT="2222"

# ---- Users -----------------------------------------------------------------
AGENT99_USER="Agent99"
AGENT999_USER="Agent999"

AGENT99_HOME="/home/${AGENT99_USER}"
AGENT999_HOME="/home/${AGENT999_USER}"

# Hidden directories (deliberately non-obvious names).
AGENT99_HIDDEN_DIR="${AGENT99_HOME}/.cache-index"
AGENT999_HIDDEN_DIR="${AGENT999_HOME}/.system-audit"

# ---- Backup / id_rsa staging area ------------------------------------------
BACKUP_DIR="/var/backups/legacy-ops"
BACKUP_KEYS_DIR="${BACKUP_DIR}/keys"
BACKUP_KEY_FILENAME="legacy_agent999_access"   # NOT named id_rsa on disk, but is one

# Rabbit hole #1: decoy backup directory with no real content.
DECOY_BACKUP_DIR="/var/backups/website-backup-2021"

# ---- .beroot privilege escalation ------------------------------------------
BEROOT_BIN="${AGENT999_HIDDEN_DIR}/.beroot"
BEROOT_SRC_TEMPLATE="${CTF_SOURCE_DIR}/beroot/source/beroot.c.template"
BEROOT_BUILD_DIR="/root/.beroot-build"   # transient, root-only, wiped after compilation

# The sudo rule grants Agent999 exactly one root command: running this exact
# binary with NO arguments. See scripts/install_ctf.sh step "sudo rule" for
# why the trailing "" matters (it forbids passing arguments through sudo).
SUDOERS_FILE="/etc/sudoers.d/ctf-agent999"

# ---- Web / robots.txt -------------------------------------------------------
ROBOTS_HIDDEN_PATH="classified-briefing-7f3a2b"   # web/hidden/<this>/index.html

# ---- Steganography -----------------------------------------------------------
STEGHIDE_IMAGE_NAME="team-photo.jpg"
STEGHIDE_IMAGE_PATH="${CTF_WEB_ROOT}/assets/${STEGHIDE_IMAGE_NAME}"
STEGHIDE_PAYLOAD_NAME="message.txt"

# IMPORTANT: organizer must change this before install. It must be a real
# entry copied from the organizer's own rockyou.txt (a later/less common
# entry, timed for a meaningful-but-not-absurd brute-force). install_ctf.sh
# refuses to run while this is left at the placeholder value.
STEGHIDE_PASSPHRASE="__CHANGE_ME_PICK_FROM_ROCKYOU__"

# Optional: local path to the organizer's own rockyou.txt, used only to
# sanity-check that STEGHIDE_PASSPHRASE actually appears in it. Never
# downloaded or copied by these scripts.
ROCKYOU_PATH="/usr/share/wordlists/rockyou.txt"

# ---- Static hint text (not secret, just base64-wrapped to avoid a trivial
# ---- plaintext grep hit) ----------------------------------------------------
AGENT99_HIDDEN_CLUE_TEXT="Old operations material was never deleted, only moved. Check what the system backs up, not just what you can see."

# ---- Rabbit hole #3: decoy SUID binary --------------------------------------
SUID_DECOY_BIN="/usr/local/bin/sysdiag"
SUID_DECOY_SRC="${CTF_SOURCE_DIR}/challenges/privilege-escalation/sysdiag.c"

# ---- Flag format -------------------------------------------------------------
FLAG_PREFIX="CTF"

# ---- Firewall ------------------------------------------------------------------
FIREWALL_ALLOWED_TCP_PORTS=("${SSH_PORT}" "80")
