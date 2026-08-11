# Queue

`/queue` is the backlog for ideas too large to run inline — see `skills/queue/SKILL.md`
for the full contract. This directory documents one design decision worth calling out:
the queue is split in two, by what gates the work.

## Why two queues

The user gets limited PC time per day but plenty of phone time. A single queue means a
phone-doable item (research, drafting, a PR waiting on review) sits behind whatever's
next in line even when it needs nothing but a thumbs-up, and a PC-bound item (a local
install, a build he needs to watch) can't jump ahead just because he happens to be at
his desk. Splitting by gate — not by project, not by priority — lets each queue move at
the pace its own approval channel actually allows:

- **`QUEUE-PC.md`** — needs local toolchain, software installs, folder-access
  approvals, or eyes on a running build.
- **`QUEUE-PHONE.md`** — research, drafting, review, PR merges, anything an agent can
  drive to completion with only phone-based approval.

Items move between the two when reality doesn't match the original classification — a
blocked PC item can have a phone-doable half worth splitting out. See either file's
header for the move mechanic; it's just cut-and-paste of a self-contained `## ` entry
plus a one-line log note explaining why.

`/status-report` reads both files and reports them as separate groups (NEEDS PC /
NEEDS PHONE) so a phone check-in surfaces exactly what a thumbs-up can unblock, without
mixing in items that need the desk.

## Where the real queue files live

`QUEUE-PC.md` and `QUEUE-PHONE.md` are gitignored and not tracked in this repo. Real
backlog content — project names, notes on real incidents, anything specific to one
person's actual work — has no business in a public git history. The skills
(`skills/queue/SKILL.md`, `skills/status-report/SKILL.md`) read from a configurable
path: an env var if set, falling back to `~/.claude-harness/queue/` outside any git
repo, falling back to this directory (`queue/`) if files exist here — gitignored either
way, so an accidental `queue/QUEUE-PC.md` in this directory never gets committed, it
just isn't the primary location.

What *is* tracked here, because it's the actual portfolio artifact:

- The `/queue` and `/status-report` skill mechanics that know about the PC/phone split.
- `QUEUE-PC.example.md` / `QUEUE-PHONE.example.md` — invented illustrative items
  showing the pattern in use, safe to publish.
- This file.
