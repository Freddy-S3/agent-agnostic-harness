---
name: status-report
description: Decision-maker rundown for a short check-in. Use when Faruk wants a quick status check across queue items and unattended /sleep or /faruk runs, or asks what needs his call.
user-invocable: true
disable-model-invocation: true
---

# Status Report

Faruk checks in for a few minutes at a time between other things.
He does not want a narrative, he wants to know what needs his call and what is true right now.
Every sentence that is not a decision or a fact is a sentence he has to skim past.

## What this reads

1. `status/TRACKER.md` in `claude-harness` — the open-decision log that `/sleep`, `/faruk`, and `/queue` append to whenever they hit something they'd normally ask about but proceeded past instead.
2. `queue/QUEUE.md` — status and latest `Log:` line of every item.
3. Any scheduled-task or background-agent state visible in-session (e.g. a `/queue` run or `/faruk` task still in flight).

Do not re-derive any of this from git log or transcripts; the tracker and queue file exist so this skill can be O(read two files), not O(investigate everything).

## Contract

1. Read `status/TRACKER.md` and `queue/QUEUE.md`.
2. Open with the decisions, as one rapid-fire batch, not one at a time and not interleaved with narrative:
	- Every unresolved (`- [ ]`) tracker line, grouped by source (`/sleep` / `/faruk` / `/queue`) and repo.
	- Every `blocked` queue item, with its blocking reason.
	- Number them so Faruk can answer by number in one message.
3. Then, separately and briefly, the state of the world:
	- One line per `in-progress` or recently `done` queue item: what happened, what's next.
	- Anything currently running that he should know is still going.
	- Skip anything with nothing new to say; a quiet item does not need a line.
4. If Faruk answers some or all of the numbered items in his reply, apply each answer immediately (make the call, act on it, or record the decision as the assumption to use going forward), then move that line out of `status/TRACKER.md` into `status/TRACKER-ARCHIVE.md` (append, gitignored, same as the tracker) rather than deleting it, and note the answer inline before ending the turn.
	Do not leave answered items sitting as unresolved once he's answered them.
	Deleting resolved lines outright was the original behavior; it left `/learn` with nothing but `queue/QUEUE.md` log entries to mine for evidence, since resolved tracker history simply vanished. Archiving keeps the gitignore-because-local-only design intact while giving future runs real material.
5. If there is nothing open and nothing worth a status line, say so in one line. Do not manufacture content to fill the format.

## Format

```text
DECISIONS (n)
1. [/queue | repo] <the actual open question or item, stated as a decision, not a summary>
2. [/sleep | repo] <...>

STATUS
- <item>: <done|in-progress|blocked> — <one line, what/next>
- <running now>: <one line>
```

No headers beyond these two, no preamble, no closing summary sentence. If DECISIONS is empty, omit the section entirely rather than printing "DECISIONS (0)".

## Non-goals

This is not `/sleep`'s wake-up report (that is per-run and appears at the end of one unattended session) and not `/queue`'s per-run report (that is scoped to one queue pass). `/status-report` is the aggregate, on-demand view across all of it, read fresh each time it's invoked.
