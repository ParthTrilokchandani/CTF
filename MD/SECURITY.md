# Security Notes

Organizer-only. This documents what is *intentionally* insecure (the
challenge itself) versus what must remain secure regardless (containment).

## Everything in this list is intentional

These are the vulnerabilities players are meant to find and exploit. Do not
"fix" them — they are the CTF:

- `Agent99`'s SSH password is discoverable via web enumeration +
  steganography + a rockyou-crackable passphrase.
- `Agent999`'s SSH private key is stored world-readable (`644`) outside its
  owner's home directory, in a backup location.
- `Agent999`'s `.bash_history` contains an encoded flag left over from a
  prior session.
- `Agent999` has a narrowly-scoped but real sudo rule to a custom binary
  (`.beroot`) whose hardcoded password is recoverable via reverse
  engineering.
- A SUID-root decoy binary (`sysdiag`) exists and is a deliberate red
  herring — see [ORGANIZER_SOLUTIONS.md](ORGANIZER_SOLUTIONS.md) for why it
  is *not* exploitable.

## What must remain true regardless

- **No real credentials, keys, or identifying data anywhere in this
  project.** Every password, SSH key, and flag is generated randomly by
  `install_ctf.sh` at install time and lives only inside the target VM's
  filesystem (`/opt/ctf/.organizer/secrets.env`, root-only, mode 600).
- **`rockyou.txt` is never downloaded, bundled, or committed** by any
  script here. The organizer must supply their own copy from wherever they
  already have security tooling installed; `install_ctf.sh` only reads a
  line out of it to sanity-check `STEGHIDE_PASSPHRASE`.
- **The CTF VM must not be able to reach the Proxmox host, other VMs, or
  any production system** — see [NETWORK_GUIDE.md](NETWORK_GUIDE.md).
  Nothing in this project is designed with the assumption that it's
  network-isolated on its own; that isolation is the organizer's
  responsibility to set up (VLAN/dedicated bridge) and this project's
  responsibility not to undermine (it never tries to reach outside the
  host except during `apt-get install`).
- **Flags are never stored in plaintext** outside the root-only organizer
  manifest. Every on-disk copy a player can reach is base64-encoded; the
  raw `CTF{...}` string does not appear in any web-servable file, any
  world-readable file, or any file under a non-root user's home directory.
- **`root` cannot be reached via SSH.** `PermitRootLogin no` is set
  unconditionally, and `passwd -l root` locks the account's password. The
  only path to root is `.beroot`, run through the one sudo rule granted to
  `Agent999`.
- **Test scripts (`tests/*.sh`) and this documentation must never be
  exposed to players.** They live in the same repository as the challenge
  content as a matter of convenience, not because they belong on the
  target VM's attack surface — `install_ctf.sh` does deploy the whole
  project (including `tests/` and every `.md` file) to `/opt/ctf/src` for
  the organizer's own later use, so make sure `/opt/ctf` stays root-only
  (`700`, as the install script sets it) and is never web-servable.

## Firewall posture

Only `80/tcp`, the configured SSH port, and `1337/tcp` (reserved for the
Flag 5 file-transfer step) are allowed inbound; default deny otherwise
(`ufw`). See [NETWORK_GUIDE.md](NETWORK_GUIDE.md).

## Reporting a problem with these scripts

If you find a way for a player to reach further than intended (root
without `.beroot`, reading another user's home directory, recovering a
flag without decoding it, etc.), treat it as a bug in this project: fix the
underlying script or permission, then reset and re-verify with
`tests/test_attack_path.sh` and `tests/test_permissions.sh` before running
another event.
