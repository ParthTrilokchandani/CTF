#!/usr/bin/env bash
# ==============================================================================
# port-watchdog.sh - keeps TRANSFER_PORT (used for the Flag 5 .beroot
# hand-off) from being monopolized on a shared, multi-team CTF instance.
#
# Runs continuously as root (via ctf-port-watchdog.service): every
# TRANSFER_PORT_CHECK_INTERVAL seconds it checks whether anything is
# listening on TRANSFER_PORT, and kills it once it's been up for
# TRANSFER_PORT_MAX_AGE_SECONDS. A well-behaved player only needs the port
# open for as long as a single curl/wget download takes, so this never
# interrupts a legitimate transfer in practice - it just reclaims the port
# from something left running (forgotten, crashed client, etc.) so the
# next team isn't locked out for the rest of the event.
#
# Not intended to be run by hand; installed as a systemd service.
# ==============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./config.sh
source "${SCRIPT_DIR}/config.sh"

while true; do
    pid="$(ss -ltnp 2>/dev/null \
        | awk -v p=":${TRANSFER_PORT}\$" '$4 ~ p {print $0}' \
        | grep -oP 'pid=\K[0-9]+' | head -n1)"

    if [ -n "${pid:-}" ] && [ -d "/proc/${pid}" ]; then
        etimes="$(ps -o etimes= -p "${pid}" 2>/dev/null | tr -d ' ')"
        if [ -n "${etimes}" ] && [ "${etimes}" -ge "${TRANSFER_PORT_MAX_AGE_SECONDS}" ]; then
            kill -9 "${pid}" 2>/dev/null || true
            logger -t ctf-port-watchdog "killed pid ${pid} holding port ${TRANSFER_PORT} after ${etimes}s" 2>/dev/null || true
        fi
    fi

    sleep "${TRANSFER_PORT_CHECK_INTERVAL}"
done
