# Reset Guide

Organizer-only.

There are two ways to get back to a clean state between events, plus a
third for when you're done with the CTF entirely.

## Option A — Proxmox snapshot (recommended)

If you took a snapshot right after a verified `CTF STATUS: READY` (see
[INSTALLATION.md](INSTALLATION.md)), restoring it is the fastest and most
reliable reset: it exactly reproduces the state you tested, including the
specific random flags/passwords from that install. Do this from the
Proxmox web UI or:

```bash
qm rollback <vmid> <snapshot-name>
```

Restoring a snapshot never touches the Proxmox host, other VMs, or the
LAN — it only affects the CTF VM itself.

## Option B — `reset_ctf.sh` (in-place reset, new random flags)

Run this on the VM itself when you want a fresh install without going back
to Proxmox:

```bash
sudo bash /opt/ctf/src/scripts/reset_ctf.sh
```

This runs `uninstall_ctf.sh` followed by `install_ctf.sh` (from the
persisted copy at `/opt/ctf/src`), which resets:

- Users and passwords
- SSH configuration (port, host keys are left alone, drop-in config is
  rewritten)
- Web files
- Flags (freshly generated — different from the previous install)
- Backup files and the Agent999 access key (freshly generated keypair)
- `.bash_history`
- `.beroot` (recompiled with a freshly generated password)
- Permissions
- Sudo configuration
- Temporary challenge files

It does **not** touch Proxmox, other VMs, the host filesystem, or anything
else on the LAN — everything it does is local to this VM.

Run `sudo bash scripts/health_check.sh` afterward to confirm `READY`
before handing out the IP again.

## Option C — `uninstall_ctf.sh` (full teardown, no reinstall)

```bash
sudo bash /opt/ctf/src/scripts/uninstall_ctf.sh
```

Removes the live deployment (users, web content, SSH/sudo configuration,
backup/decoy directories, the decoy SUID binary, firewall rules) but
deliberately leaves `/opt/ctf/src` (the persisted project checkout) and
`/opt/ctf/.organizer` (the secrets manifest from the last install) in
place, so it's safe to run from the persisted copy and safe to follow with
`install_ctf.sh` again later.

If you want those removed too — for example, decommissioning the VM
entirely — do it manually afterward:

```bash
sudo rm -rf /opt/ctf
```

## Which should you use?

- **Between back-to-back sessions of the same event, same day**: `reset_ctf.sh`.
- **Before a new event, or after any doubt about VM state**: restore the
  Proxmox snapshot.
- **Decommissioning the CTF VM**: `uninstall_ctf.sh`, then `rm -rf /opt/ctf`
  manually, or simply delete the VM in Proxmox.
