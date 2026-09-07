# Sentinel Meridian Group — CTF Project

A self-contained, intentionally vulnerable Ubuntu Server CTF environment built
for a LAN-based event. Players are given nothing but an IP address and must
work through web enumeration, steganography, SSH credential discovery, Linux
enumeration, backup/key discovery, bash history review, and reverse
engineering to reach root and five flags.

Everything here is designed to run **only inside a single, isolated Ubuntu
Server VM**. See [SECURITY.md](SECURITY.md) and [NETWORK_GUIDE.md](NETWORK_GUIDE.md)
before deploying it anywhere near production infrastructure.

## Documentation map

| Audience | File | Purpose |
|---|---|---|
| Organizer | [INSTALLATION.md](INSTALLATION.md) | How to install/configure the environment |
| Organizer | [ORGANIZER_GUIDE.md](ORGANIZER_GUIDE.md) | Intended attack path, running an event, hints |
| Organizer | [ORGANIZER_SOLUTIONS.md](ORGANIZER_SOLUTIONS.md) | Full step-by-step solution per flag, rabbit holes |
| Organizer | [NETWORK_GUIDE.md](NETWORK_GUIDE.md) | Proxmox deployment and network isolation |
| Organizer | [SECURITY.md](SECURITY.md) | What's intentionally vulnerable, and containment |
| Organizer | [TROUBLESHOOTING.md](TROUBLESHOOTING.md) | Known issues and fixes hit during development |
| Organizer | [RESET_GUIDE.md](RESET_GUIDE.md) | Resetting/uninstalling between events |
| Player | [PLAYER_GUIDE.md](PLAYER_GUIDE.md) | The only file players should ever see |

## Quick start (organizer)

```bash
# 1. On a clean Ubuntu Server 24.04 LTS VM, as root:
git clone <this project> ctf-project   # or copy it over however you prefer
cd ctf-project

# 2. Edit scripts/config.sh - at minimum set STEGHIDE_PASSPHRASE to a real
#    entry from your own rockyou.txt (install refuses to run otherwise).
nano scripts/config.sh

# 3. Install
sudo bash scripts/install_ctf.sh

# 4. Verify
sudo bash scripts/health_check.sh
```

A successful install ends with `CTF STATUS: READY` and prints the VM's IP.
That IP is the only thing players should receive.

## Project layout

```text
ctf-project/
├── scripts/       install / reset / uninstall / health_check / check_flags + config.sh
├── web/           website, robots.txt, hidden page, decoy admin page
├── challenges/    per-stage content templates (agent99, agent999, backup, stego, privesc)
├── beroot/source/ .beroot source template, compiled at install time
└── tests/         organizer/dev-only test scripts (never expose to players)
```
