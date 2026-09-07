#!/usr/bin/env bash
# ==============================================================================
# install_ctf.sh - deploys the full Sentinel Meridian Group CTF environment
# onto a clean Ubuntu Server host.
#
# Usage: sudo bash scripts/install_ctf.sh
#
# Must be run as root, from within the ctf-project checkout (so that
# scripts/config.sh can locate web/, challenges/ and beroot/ next to it).
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

log()  { printf '\n[*] %s\n' "$1"; }
ok()   { printf '    -> %s\n' "$1"; }
die()  { printf '\n[!] %s\n' "$1" >&2; exit 1; }

b64() { printf '%s' "$1" | base64 -w0; }

# ---------------------------------------------------------------------------
# 1. Pre-flight checks
# ---------------------------------------------------------------------------
step_preflight() {
    log "Pre-flight checks"

    [ "$(id -u)" -eq 0 ] || die "This script must be run as root (use sudo)."

    if [ -r /etc/os-release ]; then
        . /etc/os-release
        [ "${ID:-}" = "ubuntu" ] || die "This installer targets Ubuntu Server only (detected: ${ID:-unknown})."
        ok "Detected Ubuntu ${VERSION_ID:-unknown}"
    else
        die "Cannot determine OS: /etc/os-release not found."
    fi

    [ "${STEGHIDE_PASSPHRASE}" != "__CHANGE_ME_PICK_FROM_ROCKYOU__" ] || \
        die "scripts/config.sh: STEGHIDE_PASSPHRASE is still the placeholder value. Pick a real entry from your rockyou.txt and update config.sh before installing."

    if [ -f "${ROCKYOU_PATH}" ]; then
        if grep -qxF "${STEGHIDE_PASSPHRASE}" "${ROCKYOU_PATH}"; then
            ok "STEGHIDE_PASSPHRASE confirmed present in ${ROCKYOU_PATH}"
        else
            die "STEGHIDE_PASSPHRASE was not found as an exact line in ${ROCKYOU_PATH}. Pick a real entry from your rockyou.txt."
        fi
    else
        printf '    -> WARNING: %s not found; skipping rockyou membership check.\n' "${ROCKYOU_PATH}"
    fi

    command -v systemctl >/dev/null || die "systemd is required."
    ok "Pre-flight checks passed"
}

# ---------------------------------------------------------------------------
# 2. Persist a copy of the project source under CTF_ROOT/src
# ---------------------------------------------------------------------------
step_persist_source() {
    log "Persisting project source under ${CTF_ROOT}/src"

    mkdir -p "${CTF_ROOT}"
    chmod 700 "${CTF_ROOT}"

    local src_real dest_real
    src_real="$(cd "${CTF_SOURCE_DIR}" && pwd)"
    dest_real="$(cd "${CTF_ROOT}/src" 2>/dev/null && pwd || true)"

    if [ "${src_real}" != "${dest_real}" ]; then
        rm -rf "${CTF_ROOT}/src"
        mkdir -p "${CTF_ROOT}/src"
        cp -r "${src_real}/." "${CTF_ROOT}/src/"
        ok "Copied ${src_real} -> ${CTF_ROOT}/src"
    else
        ok "Already running from the persisted copy; skipping"
    fi

    mkdir -p "${CTF_ORGANIZER_DIR}"
    chmod 700 "${CTF_ORGANIZER_DIR}"
}

# ---------------------------------------------------------------------------
# 3. Install required packages
# ---------------------------------------------------------------------------
step_install_packages() {
    log "Installing required packages"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y \
        apache2 \
        steghide \
        imagemagick \
        openssh-server \
        gcc \
        make \
        ufw \
        openssl \
        python3
    ok "Packages installed"
}

# ---------------------------------------------------------------------------
# 4-6. Web server + website + robots.txt
# ---------------------------------------------------------------------------
step_deploy_website() {
    log "Deploying website"

    mkdir -p "${CTF_WEB_ROOT}"
    cp -r "${CTF_SOURCE_DIR}/web/." "${CTF_WEB_ROOT}/"

    cat > /etc/apache2/sites-available/ctf.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${CTF_WEB_ROOT}
    <Directory ${CTF_WEB_ROOT}>
        Options -Indexes +FollowSymLinks
        AllowOverride None
        Require all granted
    </Directory>
    ErrorLog \${APACHE_LOG_DIR}/ctf_error.log
    CustomLog \${APACHE_LOG_DIR}/ctf_access.log combined
</VirtualHost>
EOF

    a2dissite 000-default.conf >/dev/null 2>&1 || true
    a2ensite ctf.conf >/dev/null
    systemctl enable apache2 >/dev/null 2>&1 || true
    apache2ctl configtest
    systemctl reload apache2 >/dev/null 2>&1 || systemctl restart apache2

    chown -R www-data:www-data "${CTF_WEB_ROOT}"
    find "${CTF_WEB_ROOT}" -type d -exec chmod 755 {} \;
    find "${CTF_WEB_ROOT}" -type f -exec chmod 644 {} \;

    ok "Website deployed to ${CTF_WEB_ROOT}, robots.txt in place"
}

# ---------------------------------------------------------------------------
# 7. Steganography image + payload
# ---------------------------------------------------------------------------
step_deploy_stego() {
    log "Generating steganography image and payload"

    local work
    work="$(mktemp -d)"

    # Synthetic "team photo" placeholder: a generated corporate-style graphic.
    # No real photo is required for the steghide mechanics to work.
    convert -size 1200x800 gradient:'#2b3446'-'#7a1f2b' \
        -gravity center -fill white -pointsize 42 \
        -annotate +0+0 "SENTINEL MERIDIAN GROUP - ANNUAL OFFSITE" \
        "${work}/${STEGHIDE_IMAGE_NAME}"

    sed "s|__AGENT99_PASS_B64__|$(b64 "${AGENT99_PASSWORD}")|" \
        "${CTF_SOURCE_DIR}/challenges/stego/Agent99.txt.template" \
        > "${work}/${STEGHIDE_PAYLOAD_NAME}"

    steghide embed -cf "${work}/${STEGHIDE_IMAGE_NAME}" \
        -ef "${work}/${STEGHIDE_PAYLOAD_NAME}" \
        -p "${STEGHIDE_PASSPHRASE}" -f -q

    cp "${work}/${STEGHIDE_IMAGE_NAME}" "${STEGHIDE_IMAGE_PATH}"
    chown www-data:www-data "${STEGHIDE_IMAGE_PATH}"
    chmod 644 "${STEGHIDE_IMAGE_PATH}"

    rm -rf "${work}"
    ok "Stego image deployed to ${STEGHIDE_IMAGE_PATH}"
}

# ---------------------------------------------------------------------------
# 8/9. Create Agent99 and Agent999
# ---------------------------------------------------------------------------
step_create_users() {
    log "Creating users"

    if ! id "${AGENT99_USER}" >/dev/null 2>&1; then
        useradd -m -d "${AGENT99_HOME}" -s /bin/bash "${AGENT99_USER}"
    fi
    echo "${AGENT99_USER}:${AGENT99_PASSWORD}" | chpasswd
    ok "${AGENT99_USER} created with generated password"

    if ! id "${AGENT999_USER}" >/dev/null 2>&1; then
        useradd -m -d "${AGENT999_HOME}" -s /bin/bash "${AGENT999_USER}"
    fi
    usermod -L "${AGENT999_USER}"   # password login disabled - key-only
    ok "${AGENT999_USER} created, password login locked (key-only)"
}

# ---------------------------------------------------------------------------
# 10/13. Home directory content + permissions
# ---------------------------------------------------------------------------
step_populate_agent99_home() {
    log "Populating ${AGENT99_HOME}"

    cp "${CTF_SOURCE_DIR}/challenges/agent99/README.txt" "${AGENT99_HOME}/README.txt"

    sed "s|__FLAG2_B64__|$(b64 "${FLAG2}")|" \
        "${CTF_SOURCE_DIR}/challenges/agent99/net-cache.idx.template" \
        > "${AGENT99_HOME}/.net-cache.idx"

    mkdir -p "${AGENT99_HIDDEN_DIR}"
    b64 "${AGENT99_HIDDEN_CLUE_TEXT}" > "${AGENT99_HIDDEN_DIR}/clue.dat"

    chown -R "${AGENT99_USER}:${AGENT99_USER}" "${AGENT99_HOME}"
    chmod 700 "${AGENT99_HOME}"
    chmod 700 "${AGENT99_HIDDEN_DIR}"
    chmod 600 "${AGENT99_HOME}/.net-cache.idx" "${AGENT99_HOME}/README.txt" "${AGENT99_HIDDEN_DIR}/clue.dat"

    ok "Agent99 home populated (flag 2, hidden directory, clue)"
}

step_populate_agent999_home() {
    log "Populating ${AGENT999_HOME}"

    mkdir -p "${AGENT999_HOME}/.ssh"
    # Overwrite rather than append, so re-running install_ctf.sh directly
    # (without going through uninstall/reset first) can't leave a stale key
    # from a previous run sitting alongside the current one.
    cat "${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}.pub" > "${AGENT999_HOME}/.ssh/authorized_keys"
    chmod 700 "${AGENT999_HOME}/.ssh"
    chmod 600 "${AGENT999_HOME}/.ssh/authorized_keys"

    sed "s|__FLAG4_B64__|$(b64 "${FLAG4}")|" \
        "${CTF_SOURCE_DIR}/challenges/agent999/bash_history.template" \
        > "${AGENT999_HOME}/.bash_history"

    chown -R "${AGENT999_USER}:${AGENT999_USER}" "${AGENT999_HOME}"
    chmod 700 "${AGENT999_HOME}"
    chmod 600 "${AGENT999_HOME}/.bash_history"

    ok "Agent999 home populated (authorized_keys, bash history with flag 4)"
}

# ---------------------------------------------------------------------------
# 11/12. SSH configuration + port change
# ---------------------------------------------------------------------------
step_configure_ssh() {
    log "Configuring SSH"

    cat > /etc/ssh/sshd_config.d/99-ctf.conf <<EOF
# Managed by ctf-project install_ctf.sh - do not edit sshd_config directly.
Port ${SSH_PORT}
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes

Match User ${AGENT999_USER}
    PasswordAuthentication no
    AuthorizedKeysFile ${AGENT999_HOME}/.ssh/authorized_keys
EOF

    passwd -l root >/dev/null

    sshd -t

    # Ubuntu 22.04+/24.04 ship openssh-server as socket-activated by default:
    # ssh.socket hardcodes ListenStream=22 and completely ignores sshd_config's
    # Port directive. Restarting ssh.service alone does nothing about that -
    # the socket unit must be disabled and the service run standalone instead.
    if systemctl list-unit-files 2>/dev/null | grep -q '^ssh\.socket'; then
        systemctl disable --now ssh.socket >/dev/null 2>&1 || true
    fi
    systemctl unmask ssh.service >/dev/null 2>&1 || true
    systemctl enable ssh.service >/dev/null 2>&1 || true
    systemctl restart ssh.service

    ok "SSH listening on port ${SSH_PORT}; root login disabled; Agent999 is key-only"
}

# ---------------------------------------------------------------------------
# 14/15. Backup challenge + SSH key
# ---------------------------------------------------------------------------
step_deploy_backup_and_key() {
    log "Deploying backup challenge and Agent999 SSH key"

    mkdir -p "${BACKUP_DIR}" "${BACKUP_KEYS_DIR}"

    sed "s|__FLAG3_B64__|$(b64 "${FLAG3}")|" \
        "${CTF_SOURCE_DIR}/challenges/backup/ops-notes.txt.template" \
        > "${BACKUP_DIR}/ops-notes.txt"

    # Remove any key from a previous run first so ssh-keygen never hits its
    # interactive "overwrite?" prompt (which would hang / silently no-op
    # under set -e non-interactively) when install_ctf.sh is re-run directly.
    rm -f "${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}" "${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}.pub"
    ssh-keygen -t ed25519 -f "${BACKUP_KEYS_DIR}/${BACKUP_KEY_FILENAME}" -N "" -C "${AGENT999_USER}-legacy-access" -q

    chown -R root:root "${BACKUP_DIR}"
    find "${BACKUP_DIR}" -type d -exec chmod 755 {} \;
    find "${BACKUP_DIR}" -type f -exec chmod 644 {} \;

    # Rabbit hole #1: decoy backup directory, deliberately irrelevant.
    mkdir -p "${DECOY_BACKUP_DIR}"
    cp -r "${CTF_SOURCE_DIR}/challenges/backup/rabbit-hole/." "${DECOY_BACKUP_DIR}/"
    chown -R root:root "${DECOY_BACKUP_DIR}"
    find "${DECOY_BACKUP_DIR}" -type d -exec chmod 755 {} \;
    find "${DECOY_BACKUP_DIR}" -type f -exec chmod 644 {} \;

    ok "Backup challenge deployed at ${BACKUP_DIR} (flag 3, id_rsa-equivalent key)"
    ok "Decoy backup deployed at ${DECOY_BACKUP_DIR} (rabbit hole 1)"
}

# ---------------------------------------------------------------------------
# 16. Compile .beroot
# ---------------------------------------------------------------------------
step_build_beroot() {
    log "Compiling .beroot"

    mkdir -p "${BEROOT_BUILD_DIR}"
    chmod 700 "${BEROOT_BUILD_DIR}"

    sed "s|__BEROOT_PASSWORD__|${BEROOT_PASSWORD}|" \
        "${BEROOT_SRC_TEMPLATE}" > "${BEROOT_BUILD_DIR}/beroot.c"

    gcc -O2 -o "${BEROOT_BUILD_DIR}/.beroot" "${BEROOT_BUILD_DIR}/beroot.c"

    mkdir -p "${AGENT999_HIDDEN_DIR}"
    mv "${BEROOT_BUILD_DIR}/.beroot" "${BEROOT_BIN}"
    chown "${AGENT999_USER}:${AGENT999_USER}" "${BEROOT_BIN}" "${AGENT999_HIDDEN_DIR}"
    chmod 700 "${AGENT999_HIDDEN_DIR}"
    chmod 700 "${BEROOT_BIN}"

    rm -rf "${BEROOT_BUILD_DIR}"
    ok ".beroot compiled and installed at ${BEROOT_BIN}; source removed from disk"
}

# ---------------------------------------------------------------------------
# 17. Exact sudo permission
# ---------------------------------------------------------------------------
step_configure_sudo() {
    log "Configuring sudo rule for ${AGENT999_USER}"

    local tmp
    tmp="$(mktemp)"
    # The trailing "" forbids passing ANY arguments through sudo - without
    # it, sudoers would let the user append arbitrary arguments to the
    # command line. .beroot takes no arguments (it reads the password from
    # stdin), so this closes off that avenue entirely.
    printf '%s ALL=(root) NOPASSWD: %s ""\n' "${AGENT999_USER}" "${BEROOT_BIN}" > "${tmp}"

    visudo -cf "${tmp}" || die "Generated sudoers rule failed validation."

    install -m 440 -o root -g root "${tmp}" "${SUDOERS_FILE}"
    rm -f "${tmp}"

    ok "sudo rule installed: ${AGENT999_USER} may run only ${BEROOT_BIN} (no arguments) as root"
}

# ---------------------------------------------------------------------------
# 18/23. Flags 1 and 5 (2/3/4 are placed inline during their own steps)
# ---------------------------------------------------------------------------
step_deploy_remaining_flags() {
    log "Deploying flag 1 (web) and flag 5 (root)"

    sed -i "s|__FLAG1_B64__|$(b64 "${FLAG1}")|" \
        "${CTF_WEB_ROOT}/hidden/${ROBOTS_HIDDEN_PATH}/index.html"
    chown www-data:www-data "${CTF_WEB_ROOT}/hidden/${ROBOTS_HIDDEN_PATH}/index.html"

    b64 "${FLAG5}" > /root/.sysconfig_cache
    chown root:root /root/.sysconfig_cache
    chmod 600 /root/.sysconfig_cache

    ok "Flag 1 embedded in hidden page; flag 5 stored at /root/.sysconfig_cache"
}

# ---------------------------------------------------------------------------
# Rabbit hole #2 (fake admin page) + #3 (decoy SUID binary)
# ---------------------------------------------------------------------------
step_deploy_rabbit_hole_3() {
    log "Deploying rabbit hole 3 (decoy SUID binary)"

    gcc -O2 -o "${SUID_DECOY_BIN}" "${SUID_DECOY_SRC}"
    chown root:root "${SUID_DECOY_BIN}"
    chmod 4755 "${SUID_DECOY_BIN}"

    ok "Decoy SUID binary installed at ${SUID_DECOY_BIN}"
}

# ---------------------------------------------------------------------------
# 19. Firewall
# ---------------------------------------------------------------------------
step_configure_firewall() {
    log "Configuring firewall"

    ufw --force reset >/dev/null
    ufw default deny incoming >/dev/null
    ufw default allow outgoing >/dev/null
    for port in "${FIREWALL_ALLOWED_TCP_PORTS[@]}"; do
        ufw allow "${port}/tcp" >/dev/null
    done
    ufw --force enable >/dev/null

    ok "Firewall enabled; allowed TCP ports: ${FIREWALL_ALLOWED_TCP_PORTS[*]}"
}

# ---------------------------------------------------------------------------
# 20/21. Deploy scripts for later organizer use, generate flags/secrets
# ---------------------------------------------------------------------------
step_generate_secrets() {
    log "Generating flags and secrets"

    FLAG1="${FLAG_PREFIX}{$(openssl rand -hex 16)}"
    FLAG2="${FLAG_PREFIX}{$(openssl rand -hex 16)}"
    FLAG3="${FLAG_PREFIX}{$(openssl rand -hex 16)}"
    FLAG4="${FLAG_PREFIX}{$(openssl rand -hex 16)}"
    FLAG5="${FLAG_PREFIX}{$(openssl rand -hex 16)}"

    AGENT99_PASSWORD="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 20)"
    BEROOT_PASSWORD="$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 20)"

    cat > "${CTF_ORGANIZER_DIR}/secrets.env" <<EOF
# Generated by install_ctf.sh on $(date -u +%FT%TZ). Organizer-only, root:root 600.
FLAG1="${FLAG1}"
FLAG2="${FLAG2}"
FLAG3="${FLAG3}"
FLAG4="${FLAG4}"
FLAG5="${FLAG5}"
AGENT99_PASSWORD="${AGENT99_PASSWORD}"
BEROOT_PASSWORD="${BEROOT_PASSWORD}"
STEGHIDE_PASSPHRASE="${STEGHIDE_PASSPHRASE}"
EOF
    chmod 600 "${CTF_ORGANIZER_DIR}/secrets.env"
    chown root:root "${CTF_ORGANIZER_DIR}/secrets.env"

    ok "Secrets manifest written to ${CTF_ORGANIZER_DIR}/secrets.env"
}

step_deploy_scripts() {
    log "Confirming organizer scripts are in place"
    # These already live at ${CTF_ROOT}/src/scripts because step_persist_source
    # copied the whole checkout there; just make sure they're executable.
    chmod 750 "${CTF_ROOT}"/src/scripts/*.sh
    chown -R root:root "${CTF_ROOT}"
    ok "Organizer scripts available at ${CTF_ROOT}/src/scripts"
}

# ---------------------------------------------------------------------------
# 22. Validation
# ---------------------------------------------------------------------------
step_validate() {
    log "Running health check"
    bash "${SCRIPT_DIR}/health_check.sh" || true
}

main() {
    step_preflight
    step_persist_source
    step_install_packages
    step_generate_secrets
    step_deploy_website
    step_deploy_stego
    step_create_users
    step_populate_agent99_home
    step_deploy_backup_and_key
    step_populate_agent999_home
    step_configure_ssh
    step_build_beroot
    step_configure_sudo
    step_deploy_remaining_flags
    step_deploy_rabbit_hole_3
    step_configure_firewall
    step_deploy_scripts
    step_validate

    log "Installation complete"
    printf '\nCTF Server IP: %s\n' "$(hostname -I | awk '{print $1}')"
}

main "$@"
