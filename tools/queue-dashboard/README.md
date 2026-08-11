# Queue dashboard

A local, live view of everything the queue is currently blocked on, with a box to answer
each blocker in place.

```
node tools/queue-dashboard/server.mjs
# http://127.0.0.1:4317
```

## Why it is a server and not an artifact

An artifact is a snapshot. It is published once, so it cannot see a queue file that
changed a minute later, and answers given inside it have to be hand-carried back into
the queue by a later session. This reads the real files on every request and writes
answers straight back, so there is no capture step and nothing to re-transcribe.

## What it shows

**Blocked on you** comes first and holds only items that are genuinely waiting: an item
counts as blocked when it has a `Blocked reason` field, or a log line saying
`DECISION NEEDED` / `BLOCKED ON YOU` / `NEEDS YOUR DECISION`, **and** no `DECIDED` line
answering it yet. Everything else is collapsed underneath. Open PRs come from `gh`,
cached 60s because it is slow; the queue read itself is never cached.

## What answering does

Four presets (Approved / Rejected / Defer / Ask me again) submit immediately; anything
typed in the box is appended to the preset, or sent on its own with **Send answer**.
Each answer writes two things into the item it belongs to:

- a `DECIDED <date> by Faruk, via the queue dashboard: <answer>` line directly under
  `Status:`, because that is the first thing an agent run reads
- an `ANSWERED` entry at the end of that item's `Log:` section, as the audit trail

and one row into `TRIAGE-<date>.md`, under an `## Answers from the live dashboard`
section, so a later run can read the day's decisions in one place.

An answer is a recorded decision, not executed work. Nothing here runs anything.

## Safety of the write-back

The queue files are long and hand-written, so every write is guarded:

- a `.bak` copy is taken before the file is touched
- the write is temp-file-plus-rename, so a crash cannot leave a half-written queue
- the page sends the mtime it read; a newer mtime on disk returns 409 and refuses the
  write, so a concurrent session or dispatch run is never clobbered
- only the target item's block is rewritten; the rest of the file is passed through
  byte for byte

Polling pauses while the answer box has focus, so a repaint cannot wipe half-typed text.

## Configuration

| Variable | Default |
|---|---|
| `QUEUE_DIR` | `~/.claude-harness/queue` |
| `PORT` | `4317` |

It binds `127.0.0.1` only. The queue holds private content and must not be reachable
off-box; do not put this behind a tunnel or bind it to `0.0.0.0`.
