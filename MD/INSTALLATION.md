# Installation Guide

Organizer-only. This describes installing the CTF onto a clean Ubuntu Server
VM. See [NETWORK_GUIDE.md](NETWORK_GUIDE.md) for how to provision that VM in
Proxmox first.

## 1. Prerequisites

- Ubuntu Server 24.04 LTS (or 22.04 LTS), freshly installed, nothing else
  running on it that you care about — `install_ctf.sh` will overwrite the
  Apache default site and the SSH configuration.
- Root access.
- Outbound internet access during installation (`apt-get install` needs it).
  It can be removed afterward if you like — nothing in the running challenge
  requires it.
- Your own copy of `rockyou.txt` available somewhere you can read a line out
  of it. These scripts never download or bundle it.

## 2. Get the project onto the VM

Copy the whole `ctf-project` directory onto the VM (scp, a shared folder,
`git clone`, whatever you normally use). Whatever you do, always run
`install_ctf.sh` **from that copy**, never from `/opt/ctf/src` (the
persisted copy install creates on the VM) — see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md#optctfsrc-doesnt-reflect-my-latest-edits)
for why that distinction matters if you're iterating on the scripts.

## 3. Configure

Everything configurable lives in one file: `scripts/config.sh`. Open it and
review:

| Variable | Default | Must you change it? |
|---|---|---|
| `STEGHIDE_PASSPHRASE` | placeholder | **Yes.** Pick a real, uncommon-but-not-absurd entry from your own `rockyou.txt`. Install refuses to run until this is changed. |
| `ROCKYOU_PATH` | `/usr/share/wordlists/rockyou.txt` | Only if your `rockyou.txt` lives elsewhere. Used purely to sanity-check `STEGHIDE_PASSPHRASE` is a real entry; if the path doesn't exist the check is skipped with a warning. |
| `SSH_PORT` | `2222` | Optional. Any non-22 port players are expected to find via `nmap`. |
| `AGENT99_USER` / `AGENT999_USER` | `Agent99` / `Agent999` | Optional. |
| Everything else | — | Leave as-is unless you have a specific reason to change it — paths, hidden directory names, sudo rule, etc. are all cross-referenced by the scripts and templates. |

Flags and the account/`.beroot` passwords are **not** set in `config.sh` —
`install_ctf.sh` generates them randomly on every install and records them
only in `/opt/ctf/.organizer/secrets.env` (root-only, mode 600).

## 4. Install

```bash
cd ctf-project
sudo bash scripts/install_ctf.sh
```

This is safe to re-run from a fresh/updated copy of the project at any time —
it will regenerate flags, passwords, the `.beroot` binary, and reconfigure
everything from scratch. It performs, in order:

1. Pre-flight checks (root, Ubuntu, passphrase not left as placeholder).
2. Persists the project checkout to `/opt/ctf/src`.
3. Installs packages: `apache2`, `steghide`, `imagemagick`, `openssh-server`,
   `gcc`, `make`, `ufw`, `openssl`, `python3`.
4. Generates the 5 flags and the Agent99 / `.beroot` passwords.
5. Deploys the website, robots.txt, and the hidden Flag 1 page.
6. Generates the placeholder "team photo" and embeds the steghide payload.
7. Creates `Agent99` and `Agent999`.
8. Populates both home directories (Flag 2, the hidden clue, Flag 4 in
   `.bash_history`, `authorized_keys`).
9. Deploys the backup challenge (Flag 3, the Agent999 access key) and the
   decoy backup directory.
10. Configures SSH (custom port, root login disabled, Agent999 key-only).
11. Compiles `.beroot` and removes its source from disk.
12. Installs the exact-match `sudoers.d` rule for Agent999.
13. Writes Flag 1 into the hidden page and Flag 5 into `/root`.
14. Installs the decoy SUID binary (rabbit hole 3).
15. Configures the firewall (`ufw`: only your SSH port and 80/tcp open).
16. Confirms the deployed copies of the scripts are executable.
17. Runs `health_check.sh` and prints the result.

At the end it prints:

```text
CTF Server IP: <IP>
```

That's the only thing players should ever receive.

## 5. Verify

```bash
sudo bash scripts/health_check.sh
```

Expect `CTF STATUS: READY` with all 14 checks `PASS`. If anything fails, see
[TROUBLESHOOTING.md](TROUBLESHOOTING.md).

For a deeper, end-to-end verification that actually walks the intended
player path (not just presence checks), see `tests/test_attack_path.sh` in
[ORGANIZER_GUIDE.md](ORGANIZER_GUIDE.md#testing).

## 6. Snapshot

Once `health_check.sh` reports `READY`, take a Proxmox snapshot immediately.
That snapshot is your reset point for future events — see
[RESET_GUIDE.md](RESET_GUIDE.md).
