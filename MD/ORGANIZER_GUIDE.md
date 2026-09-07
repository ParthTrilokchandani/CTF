# Organizer Guide

This is the operational guide for running the event. For step-by-step
solving details (commands, expected output, decoding) see
[ORGANIZER_SOLUTIONS.md](ORGANIZER_SOLUTIONS.md). For install/reset
mechanics see [INSTALLATION.md](INSTALLATION.md) and
[RESET_GUIDE.md](RESET_GUIDE.md).

## Intended attack path

```text
LAN
 │
 ▼
Website (http://<IP>/)
 │
 ├── robots.txt → hidden page → Flag 1 (base64)
 │
 └── Website image (steghide, rockyou-crackable passphrase)
        │
        ▼
     Extracted file is literally named Agent99.txt (reveals the username)
     → contains a base64-encoded password
        │
        ▼
     ssh -p 2222 Agent99@<IP>
        │
        ├── Flag 2 (base64, in a disguised cache file)
        │
        └── Hidden directory (.cache-index/)
               │
               ▼
          Encoded clue → points to the backup area
               │
               ▼
          /var/backups/legacy-ops/
               │
               ├── Flag 3 (base64, in ops-notes.txt)
               │
               └── keys/legacy_agent999_access (world-readable "forgotten" key)
                      │
                      ▼
               ssh -p 2222 -i legacy_agent999_access Agent999@<IP>
                      │
                      ▼
               .bash_history → Flag 4 (base64)
                      │
                      ▼
               sudo -l → reveals the ONE allowed command:
               sudo /home/Agent999/.system-audit/.beroot
                      │
                      ▼
               (this is also how the hidden .system-audit/ dir is found)
                      │
                      ▼
               python3 -m http.server <port>  →  pull .beroot to attacker box
                      │
                      ▼
               Ghidra / strings → recover hardcoded password
                      │
                      ▼
               sudo /home/Agent999/.system-audit/.beroot
               Password: <recovered password>
                      │
                      ▼
               whoami → root
                      │
                      ▼
               /root/.sysconfig_cache → decode → Flag 5
```

This path must remain internally consistent across every install — it's
generated fresh (new random flags and passwords) every time `install_ctf.sh`
runs, but the structure never changes.

## Users

| User | Role | Access |
|---|---|---|
| `Agent99` | Low-privileged entry point | Password auth (from steghide payload), no sudo |
| `Agent999` | Mid-privileged | Key-only SSH auth (from backup key), exactly one sudo command |
| `root` | Normal Linux root | Reachable only through `.beroot`; direct SSH login disabled |

`Agent99` cannot read `Agent999`'s home directory or vice versa (both are
`700`), and `Agent99` has no sudo privileges at all.

## Hint mechanism

Hints are riddles, dispensed manually by the organizer on request (there is
no in-game hint system). Suggested riddles, one per major stage — read only
what's needed for the stage a team is stuck on:

1. **robots.txt** — "Every polite crawler is told where not to look. Read the instructions it was given."
2. **Steganography** — "The photograph remembers more than the moment it shows you."
3. **rockyou/brute force** — "The key isn't clever. It's just been used by someone else before."
4. **Agent99's hidden directory** — "Not everything in a home directory answers to `ls`."
5. **Backup investigation** — "Nothing is ever really deleted here — only relocated and forgotten."
6. **SSH key** — "A door's key doesn't have to live near the door."
7. **Agent999's history** — "Someone tried to erase their tracks and only half-succeeded."
8. **Sudo/privilege escalation** — "Ask the system what it will let you do as someone else."
9. **Reverse engineering** — "If it won't tell you the password, take it apart until it does."

Do not hand these out unprompted, and never reveal rabbit hole content —
see [ORGANIZER_SOLUTIONS.md](ORGANIZER_SOLUTIONS.md) for what those are and
why they're safe dead ends.

## Difficulty

Medium → Hard. Expected skills: Nmap, web enumeration, Base64, steghide,
rockyou-style brute forcing, SSH, Linux permissions/enumeration, backup
investigation, SSH private keys, bash history review, sudo, Python's
`http.server`, Ghidra/basic reverse engineering, and general Linux
privilege escalation reasoning.

## Testing

Two levels of verification, both organizer/dev-only — never expose either
to players:

- `sudo bash scripts/health_check.sh` — fast presence/configuration check,
  used automatically at the end of `install_ctf.sh`.
- `sudo bash scripts/check_flags.sh` — decodes every flag currently on disk
  and compares it against the manifest in `/opt/ctf/.organizer/secrets.env`.
- `sudo bash tests/test_attack_path.sh` — full end-to-end walk of the
  intended path against `127.0.0.1` (requires `sshpass`, `steghide`, `curl`,
  `ssh-keygen`, `strings`, `python3` on the box you run it from). This is
  the closest thing to "did we just verify a player could actually do
  this."
- `sudo bash tests/test_permissions.sh` and `tests/test_services.sh` for
  narrower checks (isolation, sudo rule shape, service/port state).

Run all of the above after every install and after every reset, before
handing out the IP.

## Running an event

1. Install, verify `READY`, take a Proxmox snapshot.
2. Give players only the IP.
3. During the event, dispense hints manually per the list above.
4. After the event (or between sessions), restore the snapshot or run
   `scripts/reset_ctf.sh` — see [RESET_GUIDE.md](RESET_GUIDE.md) for the
   tradeoffs between the two.
