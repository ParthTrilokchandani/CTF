# Troubleshooting

Organizer-only. Everything here was hit and fixed during development of
this project — start with `sudo bash scripts/health_check.sh` to see which
of the 14 checks is failing, then find it below.

## Can't download `.beroot` from outside the VM

A player runs `python3 -m http.server <port>` as Agent999 (or any user) and
it starts fine, but `curl`/`wget`/a browser from their own attacker machine
can't reach it — connection just hangs or refuses.

**Cause**: `ufw` on the CTF VM denies all inbound traffic by default except
`80/tcp`, the configured SSH port, and (once fixed - see below) `1337/tcp`.
Any other port the player's ad-hoc HTTP server binds to is not in that
allowlist, so the connection never reaches the box at all - the server
itself is running fine, it just can't be reached from anywhere but
`127.0.0.1`. This is also why our own `tests/test_attack_path.sh` never
caught it during development: it drives the whole flow against
`127.0.0.1` on the VM itself, and `ufw` doesn't filter loopback traffic -
so the test kept passing while a real remote player would have been stuck.

**Fix**: `scripts/config.sh` now includes `TRANSFER_PORT="1337"` in
`FIREWALL_ALLOWED_TCP_PORTS`, and `install_ctf.sh` opens it via `ufw`
during the firewall step. Players are expected to use exactly this port
for their HTTP server. Re-run `install_ctf.sh` (or `reset_ctf.sh`) from an
updated copy of the project to pick this up. If you need to patch a live
VM without a full reinstall:

```bash
sudo ufw allow 1337/tcp
```

A full `nmap -p- --reason <ip>` scan will technically reveal `1337` as the
one `closed` port sitting among thousands of `filtered` ones (since `ufw
allow` on a port nothing is listening on yet still gets a kernel-level TCP
RST, distinct from the silent drop everything else gets) - but that's slow
and easy to miss during a live event, and isn't something a player can be
expected to find on demand. So the port number is also handed to the
player directly, in-world: `system-audit-note.txt` sits right next to
`.beroot` in `.system-audit/`, discovered by the same `ls -la` that finds
the binary itself, and states the port outright. It still leaves the
actual technique (a disposable Python HTTP server) for the player to land
on themselves.

## `health_check.sh` reports `robots.txt FAIL` but `Web server` passes

**Cause**: Apache wasn't reloaded after `install_ctf.sh` wrote the new
vhost and ran `a2dissite`/`a2ensite`. Enabling/disabling a site only
changes symlinks in `sites-enabled` — it has no effect until Apache is
reloaded. With the old default site still active, `/` still returns `200`
(so the loose "did curl succeed" check passes) while `/robots.txt` 404s
against the wrong document root.

**Fix**: already applied in `install_ctf.sh` — it runs
`systemctl reload apache2` (falling back to `restart`) right after
`a2ensite`. If you still hit this, confirm you're running the current
version of the script (see "`/opt/ctf/src` doesn't reflect my latest
edits" below).

## `health_check.sh` reports `SSH port FAIL` even though `SSH` passes

**Cause**: Ubuntu 22.04+/24.04 ship `openssh-server` as socket-activated by
default. `ssh.socket` hardcodes `ListenStream=22` and completely ignores
the `Port` directive in `sshd_config` — restarting `ssh.service` alone
does nothing about it, so sshd ends up listening on 22 no matter what
`scripts/config.sh` says.

**Fix**: already applied in `install_ctf.sh` — it disables `ssh.socket` if
present and enables/restarts `ssh.service` directly. If you're debugging
this by hand:

```bash
sudo systemctl disable --now ssh.socket
sudo systemctl enable --now ssh.service
sudo systemctl restart ssh.service
ss -tln | grep 2222
```

## `health_check.sh` reports `SSH key FAIL`

Two distinct causes were found here — check both.

**Cause 1: `ssh-keygen -y` refuses a world-readable private key.** The
backup copy of Agent999's key is deliberately `644` (that *is* the
intended vulnerability — Agent99 needs to be able to read it). But
`ssh-keygen -y -f <key>` refuses to operate on a key with group/world
permissions ("bad permissions... This private key will be ignored"). The
health check now copies the key to a `600` scratch file before deriving
the public key from it, rather than operating on the live `644` file
directly.

**Cause 2: stale/duplicate `authorized_keys` entries from re-running
install directly.** Earlier versions of `install_ctf.sh` *appended* the
backup key's public half to `authorized_keys` and never removed an
existing backup keypair before regenerating it. Re-running
`install_ctf.sh` a second time (without going through `uninstall`/`reset`
first) could leave a stale key in `authorized_keys` that no longer matches
the (regenerated, or silently-not-regenerated) key on disk. Fixed by
removing any existing backup keypair before calling `ssh-keygen` and by
overwriting `authorized_keys` instead of appending to it.

If you still see this failure, check what's actually deployed:

```bash
sudo ssh-keygen -y -f /var/backups/legacy-ops/keys/legacy_agent999_access
sudo cat /home/Agent999/.ssh/authorized_keys
```

The `ssh-keygen -y` output should be a prefix of the line in
`authorized_keys` (same key type and base64 blob; the trailing comment
should match too).

## `/opt/ctf/src` doesn't reflect my latest edits

**Cause**: `install_ctf.sh` only copies the project checkout into
`/opt/ctf/src` when it's run from a location *different* from
`/opt/ctf/src` itself (`step_persist_source` compares real paths and skips
the copy if they're already the same). If you get in the habit of
re-running install via `sudo bash /opt/ctf/src/scripts/install_ctf.sh`,
any local edits you made to your working copy never make it onto the VM.

**Fix**: always run `install_ctf.sh` from the freshly-transferred project
directory (wherever you `scp`'d/copied it to), never from `/opt/ctf/src`.
Confirm a file made it over before trusting a re-run:

```bash
grep -n "<something you just changed>" /opt/ctf/src/scripts/<file>.sh
```

If that comes back empty after an install run, the copy you ran from was
stale.

## `install_ctf.sh` dies immediately with a `STEGHIDE_PASSPHRASE` error

You haven't edited `scripts/config.sh` yet. Set `STEGHIDE_PASSPHRASE` to a
real entry from your own `rockyou.txt` — see [INSTALLATION.md](INSTALLATION.md).

## `install_ctf.sh` warns "rockyou.txt not found; skipping membership check"

Harmless — it just means `ROCKYOU_PATH` in `scripts/config.sh` doesn't
point at a real file on this machine, so the script couldn't confirm your
chosen passphrase is a genuine `rockyou.txt` entry. Fix the path or accept
the warning if you've already confirmed it manually.

## gcc warnings during `.beroot` compilation

```text
warning: ignoring return value of 'setuid' declared with attribute 'warn_unused_result'
```

Harmless. `.beroot` is only ever invoked already running as root (via the
sudo rule), so `setuid(0)`/`setgid(0)` are redundant no-ops; the compiler
just wants their return values checked. The binary still compiles and
works correctly. Not worth "fixing" — silencing it would only hide a
genuinely irrelevant warning.

## Players seem to get further than intended / a check that shouldn't pass, passes

Stop the event, reset (see [RESET_GUIDE.md](RESET_GUIDE.md)), and treat it
as a bug per [SECURITY.md](SECURITY.md#reporting-a-problem-with-these-scripts).
Re-run `tests/test_permissions.sh` and `tests/test_attack_path.sh` before
resuming.
