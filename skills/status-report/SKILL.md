---
name: status-report
description: Decision-maker rundown for a short check-in. Use when Faruk wants a quick status check across queue items and unattended /sleep or /faruk runs, or asks what needs his call.
user-invocable: true
---

# Status Report

Faruk checks in for a few minutes at a time between other things.
He does not want a narrative, he wants to know what needs his call and what is true right now.
Every sentence that is not a decision or a fact is a sentence he has to skim past.

## What this reads

1. `status/TRACKER.md` in `agent-agnostic-harness` — the open-decision log that `/sleep`, `/faruk`, and `/queue` append to whenever they hit something they'd normally ask about but proceeded past instead.
2. `QUEUE-PC.md` and `QUEUE-PHONE.md` — status and latest `Log:` line of every item, in both files. See `skills/queue/SKILL.md`'s Model section for how to resolve their directory (env var, then `~/.claude-harness/queue/`, then this repo's `queue/` as a last resort) — these are not tracked in `agent-agnostic-harness` git.
3. Any scheduled-task or background-agent state visible in-session (e.g. a `/queue` run or `/faruk` task still in flight).

Do not re-derive any of this from git log or transcripts; the tracker and queue files exist so this skill can be O(read three files), not O(investigate everything).

## Contract

1. Read `status/TRACKER.md`, `QUEUE-PC.md`, and `QUEUE-PHONE.md`.
2. Open with the decisions, as one rapid-fire batch, not one at a time and not interleaved with narrative:
	- Every unresolved (`- [ ]`) tracker line, grouped by source (`/sleep` / `/faruk` / `/queue`) and repo.
	- Every `blocked` queue item, with its blocking reason and which queue (PC/phone) it's in.
	- Number them so Faruk can answer by number in one message.
3. Then, separately and briefly, the state of the world — kept in two groups so Faruk can see at a glance what needs him at his desk versus what just needs a thumbs-up:
	- **NEEDS PC:** one line per `in-progress` or recently `done` item from `QUEUE-PC.md`: what happened, what's next.
	- **NEEDS PHONE:** same, for `QUEUE-PHONE.md`.
	- Anything currently running that he should know is still going.
	- Skip anything with nothing new to say; a quiet item does not need a line. Skip an empty group entirely rather than printing a header with nothing under it.
4. Close with **BLOCKED ON YOU**, one line per blocker, each carrying three fields: the blocker, its one-line fix, and which queue item(s) it gates.
	- Derive it from the same files already read in step 1. Do not maintain it as a separate list — a third source of truth would drift, which is the failure this section exists to prevent.
	- A blocker whose fix is not known still gets a line, with the fix field reading `unknown, needs investigation`. Dropping the hard ones is exactly the failure mode this is meant to fix.
	- Name the downstream items explicitly. The value is in the chain, not the individual line: a reader should be able to see that one install releases three items without reconstructing it across two files.
	- Omit the section entirely when nothing is blocked, same rule as `DECISIONS (0)`.
	- **Repair any blocker you cannot restate from its own `Blocked reason:`.** You are reading every item anyway, so you are the cheapest place to catch one that has decayed into a pointer. Treat as broken any `Blocked reason:` that is missing, is shorter than the question it is asking, or contains a back-reference with no referent (`the four fixes`, `see above`, `as previously noted`, `unchanged since`, `restating`, a bare date pointing at earlier prose). Reconstruct the decision from the item body and its `Log:`, rewrite the field so it stands alone, leave the history in `Log:`, and say in the report which items you repaired. Do not silently report a blocker whose description would not survive being read on a phone - the item is what Faruk sees when this conversation is over. The convention is in `instructions/AGENTS.md` under the unpersisted-decision rule.

	This exists because of a real miss. A resume item sat blocked for hours on a single missing local binary. The blocked reason was recorded correctly in the queue, and the old format still failed to surface it as *the* blocker — the one install that, once done, released the rendition item, the interactive-widgets item, and the job-board pass. Reconstructing that chain took reading three entries across two files. The format should do that work, not the reader.
5. If Faruk answers some or all of the numbered items in his reply, or settles a queue item elsewhere in this conversation, apply each answer immediately (make the call, act on it, or record the decision as the assumption to use going forward), reconcile the matching queue entry with `DECIDED` and `ANSWERED`, and move that line out of `status/TRACKER.md` into `status/TRACKER-ARCHIVE.md` (append, gitignored, same as the tracker) rather than deleting it. Mark the queue item `done` only after verifying the work landed; create a new item for unfinished follow-up work. Read back every changed file before ending the turn.
	Do not leave answered items sitting as unresolved once he's answered them.
	Deleting resolved lines outright was the original behavior; it left `/learn` with nothing but `queue/QUEUE.md` log entries to mine for evidence, since resolved tracker history simply vanished. Archiving keeps the gitignore-because-local-only design intact while giving future runs real material.
6. If there is nothing open and nothing worth a status line, say so in one line. Do not manufacture content to fill the format.

## Format

```text
DECISIONS (n)
1. [/queue | repo] <the actual open question or item, stated as a decision, not a summary>
2. [/sleep | repo] <...>

NEEDS PC
- <item>: <done|in-progress|blocked> — <one line, what/next>

NEEDS PHONE
- <item>: <done|in-progress|blocked> — <one line, what/next>
- <running now>: <one line>

BLOCKED ON YOU (n)
- <blocker> -> fix: <the one action that unblocks it> -> gates: <item(s), and which queue>
```

No headers beyond these three, no preamble, no closing summary sentence. If DECISIONS or BLOCKED ON YOU is empty, omit that section entirely rather than printing a header with a zero count.

## Rendering

After writing the text report above, render it again as clickable cards per `instructions/WIDGETS.md`.
Emit both: the text report is the durable record and the fallback, the cards are the affordance.

- One card per numbered `DECISIONS` line, with **Approve** / **Reject** / **Explain** buttons.
- One card per `BLOCKED ON YOU` line, with **I did this** / **Not now**, and its gated items listed as the context line — that chain is the whole point of the section and should survive into the card.
- `NEEDS PC` and `NEEDS PHONE` render as cards only when the item has an action worth clicking. A `done` item with nothing pending stays a text line.
- Skip the widget entirely when there is nothing open, when DECISIONS and BLOCKED ON YOU are both empty, or when this is running unattended.

The buttons send the sentences in `WIDGETS.md`'s action vocabulary. Step 5 above already handles them: an `Answer <n>: approve.` arriving as Faruk's next turn is an answer to a numbered item and gets applied and archived exactly like a typed one. Do not add a parallel code path for clicks.

## Non-goals

This is not `/sleep`'s wake-up report (that is per-run and appears at the end of one unattended session) and not `/queue`'s per-run report (that is scoped to one queue pass). `/status-report` is the aggregate, on-demand view across all of it, read fresh each time it's invoked.
