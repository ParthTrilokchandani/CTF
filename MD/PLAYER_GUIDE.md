# Player Guide

## Briefing

Sentinel Meridian Group presents itself as an ordinary risk-advisory
consultancy. It isn't as buttoned-up as its website suggests. Somewhere
inside its infrastructure, an old operational history has been left
carelessly in place — credentials, access material, and internal notes
that were never properly cleaned up as systems changed hands over the
years.

Your task is to reconstruct that history, one exposed detail at a time,
until you control the system completely.

## Target

```text
CTF Server IP: <IP will be provided by the organizer>
```

That's all you get. Everything else — services, entry points, users,
paths forward — is yours to discover.

## Objective

Find and submit **5 flags**, hidden at different stages of the same
overall path. Full compromise of the target (root) is the intended end
state, but each flag along the way stands on its own and can be submitted
as you find it.

## Flag format

Every flag looks like:

```text
CTF{...}
```

Flags are not always sitting in plain text where you find them — read
carefully, and don't assume every string you encounter is already in its
final form.

## Rules

- Only interact with the IP you were given. Do not scan, probe, or attack
  anything else on the network.
- Don't attempt denial-of-service against the target — the goal is access
  and discovery, not disruption.
- Don't share flags or specific findings with other teams during the
  event.
- If something seems broken (not just "hard"), tell the organizer instead
  of trying to force your way around it.

## Tools you'll likely want

A fairly standard offensive toolkit covers everything you need: `nmap`,
a web browser and basic web enumeration tools, `curl`, standard Linux
command-line utilities, an SSH client, common file-analysis tools, and
whatever you're comfortable with for encoding/decoding common formats.
If you end up needing to inspect a compiled program, a decompiler will
help.

## Hints

Hints exist, but they're deliberately indirect — you'll be given a riddle,
not an instruction. Ask the organizer if you'd like one for whatever stage
you're currently stuck on. Asking for a hint doesn't disqualify you; there
is no penalty beyond it being a hint.

Good luck.
