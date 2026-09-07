# Network Guide — Proxmox Deployment & Isolation

Organizer-only.

## VM specification

| Resource | Recommendation |
|---|---|
| OS | Ubuntu Server 24.04 LTS |
| CPU | 2–4 cores |
| RAM | 2–4 GB |
| Disk | 20–40 GB |
| Network | VirtIO NIC |
| Bridge | `vmbr0`, or preferably a dedicated CTF bridge/VLAN (see below) |

## Deployment steps

1. **Create the VM** in Proxmox with the specs above.
2. **Install Ubuntu Server 24.04 LTS**, minimal install is fine (the
   install script pulls in everything else it needs via `apt-get`).
3. **Configure networking** — attach the VM's NIC to the bridge/VLAN you've
   decided to isolate the CTF on (see below), not directly to a bridge that
   routes to production.
4. **Determine the VM's IP** (`ip a` or `hostname -I` once it's up).
5. **Run the installation script** — see [INSTALLATION.md](INSTALLATION.md).
6. **Run the health check** — `sudo bash scripts/health_check.sh`, confirm
   `CTF STATUS: READY`.
7. **Take a Proxmox snapshot** of the VM in this known-good state. This is
   your reset point — see [RESET_GUIDE.md](RESET_GUIDE.md).
8. **Test from another machine on the LAN**, not from the Proxmox host
   itself, before the event: confirm the website loads, `nmap` finds the
   custom SSH port, and the full path in
   [ORGANIZER_SOLUTIONS.md](ORGANIZER_SOLUTIONS.md) works end to end.

## Network isolation

The CTF VM is intentionally vulnerable. It must never provide a route to:

- The Proxmox host itself
- Other production VMs
- Router / switch management interfaces
- NAS or file servers
- Company servers or production databases
- Any cloud infrastructure

**Prefer a dedicated VLAN or an isolated CTF-only bridge** with no gateway
back into your production network. If you only have `vmbr0` available and
it's shared with production traffic, treat that as a stop-gap, not a
long-term setup — a stray misconfiguration on a shared bridge is exactly
the kind of blast radius this project is built to avoid.

Internet access during installation (for `apt-get`) is fine and can be
left in place or removed afterward — nothing in the running challenge
itself requires outbound access once installed.

## What the CTF VM exposes

After installation, `ufw` allows these inbound TCP ports:

- `80` — the website
- `2222` — SSH (configurable via `SSH_PORT` in `scripts/config.sh`)
- `1337` — reserved for the Flag 5 stage, where Agent999 is expected to
  stand up a temporary `python3 -m http.server 1337` to move `.beroot` off
  the target for analysis. Without this port open, that step only works
  when tested from the VM itself (`ufw` doesn't filter loopback traffic) and
  silently fails for a real remote player — see
  [TROUBLESHOOTING.md](TROUBLESHOOTING.md#cant-download-beroot-from-outside-the-vm).

Everything else inbound is denied by default.
