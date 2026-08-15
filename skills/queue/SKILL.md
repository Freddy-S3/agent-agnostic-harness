---
name: queue
description: Work through the idea backlog (split by PC-gated vs phone-gated, see queue/README.md) continuously, in personal-mode posture, resuming automatically after usage-limit resets. Use when Faruk wants to drop a larger idea into a backlog instead of running it now, or asks to run or resume the queue.
user-invocable: true
---

# Queue

A backlog for ideas too large to run inline, worked continuously without Faruk babysitting it.
`/faruk` and `/sleep` execute one task end to end; `/queue` is the loop that keeps feeding them tasks across usage-limit resets a single session cannot survive.

## Model

Two backlog files split by what gates the work — the user gets limited PC time per day but plenty of phone time, so an item that only needs phone-based approval shouldn't wait behind one that needs him at his desk. See `queue/README.md` for the full rationale.

- `QUEUE-PC.md` — needs local toolchain, software installs, folder-access approvals, or eyes on a running build.
- `QUEUE-PHONE.md` — research, drafting, review, PR merges, or anything an agent can drive to completion with only phone approval.

**Real queue contents are not tracked in this repo.** Resolve the queue directory in this order, first match wins:
1. `$CLAUDE_HARNESS_QUEUE_DIR` if set.
2. `~/.claude-harness/queue/` (outside any git repo — the recommended default).
3. This repo's own `queue/` directory, if `QUEUE-PC.md` or `QUEUE-PHONE.md` already exists there (both are gitignored, so this never gets committed even when used).

`queue/QUEUE-PC.example.md` and `queue/QUEUE-PHONE.example.md` in this repo are tracked, sanitized templates showing the format — not live queue files, and `/queue` never reads or writes them.

Each idea is a `## ` entry with a `Status:` line (`pending`, `in-progress`, `done`, `blocked`), a `Repo:` line when it targets a specific project, a free-text brief, an `Options:` list once the item needs a decision from Faruk, and a `Log:` list of dated one-line notes. Same format in both files; see `queue/README.md` for the `Options:` field.

Adding an item is appending a new `## ` entry with `Status: pending` to whichever file matches its gate, in the resolved queue directory. No skill invocation needed for that half. If an item's gate is genuinely unclear, default to `QUEUE-PC.md` — it's the safer overclassification, since a phone-queued item that turns out to need local eyes stalls silently until someone notices, wasting a whole `/queue` run.

**Which queue does `/queue` work?** If invoked with an argument (`/queue pc` or `/queue phone`), work only that file. Invoked bare, work `QUEUE-PHONE.md` first (more phone time to spend reviewing its output) and fall through to `QUEUE-PC.md` once it's empty or fully blocked/in-progress for this run.

**Moving an item between queues:** cut the whole `## ` entry (including its `Log:`) from one file and paste it into the other — no format change needed, a queue entry is self-contained. Add a one-line `Log:` note on the move (from which queue, and why). Do this when a blocked PC item turns out to have a phone-doable half worth splitting out.

## Contract

1. Set the mode to personal for the whole run, regardless of directory. Borrow `/faruk`'s one-interruption rule and `/sleep`'s recoverability discipline (branch, frequent real commits, never rewrite published history) — this runs unattended by design, so treat every item as a `/sleep`-style task even during the day.
2. Read the target queue file (see "Which queue does `/queue` work?" above, and the path resolution in Model) top to bottom. Resume the first `in-progress` item if one exists — it means a prior run was interrupted mid-task, most likely by hitting the usage limit. Otherwise take the first `pending` item.
3. Mark the item `in-progress` in the queue file and save it before starting work, so an interruption a moment later still leaves an accurate queue state. The queue file itself isn't tracked in `agent-agnostic-harness` git — see Model above — so this is a plain file write, not a commit.
4. Work the item to completion in its own repo (the `Repo:` line), on its own branch, following that item's brief. Append a dated one-line note to the item's `Log:` after each meaningful step (branch created, PR opened, blocked on X) — not a full transcript, just enough for the next run or Faruk to pick up the thread cold.
5. When the item is fully done (PR opened, or the deliverable otherwise landed), mark it `done` in the queue file. Move to the next `pending` item and repeat, in the same run, until the queue is empty or you hit a stopping condition below.
6. When you hit a usage-limit error (rate-limit / quota message from the harness or API, not an ordinary tool error), stop immediately: leave the current item `in-progress` with a log line describing exactly where it stopped in the queue file, and end the run. Do not ask anything first — there is nobody to answer.
7. When an item is genuinely blocked on something only Faruk can decide (credentials, a judgment call with no reversible default, something in the `/sleep` stop-and-confirm list), mark it `blocked` with a `Blocked reason:` field and move on to the next item rather than stalling the whole queue. Write that reason to be read cold on a phone by someone with no memory of this run: state what is being asked, what it affects, and what happens either way. It is the field the dashboard renders. Keep dates, measurements, and what earlier runs concluded in `Log:`, and never let the decision field point at them (`the four fixes`, `see above`, `unchanged since`, a bare prior date) or narrate its own rewriting. **Write an `Options:` list on that item in the same edit**, naming the two to four answers you actually considered, each phrased as the instruction Faruk would be giving you (`Branch, commit, push, PR`, not `Yes`). This is not optional and not a formality: it is the only moment the alternatives are known, the dashboard turns them into one-click answers, and a later run reads them to see which paths were already weighed. A blocker with no options costs Faruk a written reply and costs the next agent the reasoning.
8. A queued item that describes a new project (not a change to an existing repo) follows the new-project convention in `instructions/AGENTS.md`: new sibling repo under `C:\Users\Faruk\Repo`, `git init`, matching GitHub repo, portfolio-piece bar, and a tech stack chosen for what is currently in demand rather than defaulted to Faruk's resume stack.

## Status tracker

For every item worked, in addition to the item's own `Log:` line, append one line to `status/TRACKER.md` (gitignored, not committed) for each assumption, skip, or block — same content, cross-skill format: `- [ ] YYYY-MM-DD | /queue | <repo-or-scope> | <one-line item>`. This is what `/status-report` reads to give Faruk a same-day rundown across every skill's unattended runs.

The tracker is the secondary record, not the primary one. `tools/queue-dashboard` parses `QUEUE-PC.md` and `QUEUE-PHONE.md` and reads no other file, so contract step 7's queue write is what actually reaches Faruk and a tracker line never substitutes for it. Write both; if only one is possible, write the queue file and say in the report that the tracker write was refused, naming the path and the real error.

## Ending a run (required)

A `/queue` run may not end while holding an unpersisted decision, including one it discovered incidentally rather than as the worked item's own blocker. A defect noticed in a neighbouring repo, a question the brief did not anticipate, an assumption taken to keep moving - each gets a `## ` entry in the queue file matching its gate, with `Status: blocked`, a `Blocked reason:`, and an `Options:` list, before the report is written. Write it against whichever item it belongs to, or as a new one if it belongs to none.

Read back every entry written. Then check the run's own output against the dashboard's contract, because an entry can be well written and still invisible:

- An item carrying a `DECIDED` line or a log line starting with `ANSWERED` is treated as settled and shown to nobody. When the decision is made but the work it authorises has not happened, the remaining work goes in a NEW item rather than as a log line under the answered one.
- An item at `Status: done` is likewise never shown. Do not mark an item done because its decision was answered; done means the work landed.

Both of these were live on 2026-08-14: several items sat `pending` with a `DECIDED` line and real outstanding work, and the dashboard correctly showed none of them, because the file said they were answered.

This applies without exception to a run spawned as a subagent or a parallel task. Reporting a blocker to an orchestrator is not persisting it - the orchestrator's context ends with the turn, the queue file does not.

## Direct item commands

Normally `/queue` picks the next item itself, top-down. Faruk can override that for one item by naming it, either typed or by clicking a card (see Rendering):

| He says | Do this |
| --- | --- |
| `Run the queue item "<title>" next.` | Work that item now, ahead of queue order. Leave the ordering of everything else alone. |
| `Skip the queue item "<title>" for this run.` | Leave its status untouched, log `skipped this run` with the date, move to the next item. Not the same as `blocked` — a skip carries no reason and expires at the end of the run. |
| `Move the queue item "<title>" to the <pc\|phone> queue.` | The move described in Model: cut the whole entry, paste it into the other file, log the move and why. |
| `Unblock the queue item "<title>": <fix>.` | Re-check the blocking condition. If it now passes, set the item back to `pending` and continue; if it still fails, leave it `blocked` and log what specifically still fails, naming the actual error rather than a guess at its cause. |

Match on the item title, not on position — positions shift between runs, and a stale card clicked an hour later must not act on whatever has since moved into that slot. If the title matches no entry or matches more than one, say so and do nothing rather than guessing.

## Rendering

When a run is interactive, render the per-run report as clickable cards per `instructions/WIDGETS.md`, alongside the text report rather than instead of it.

- One card per item touched or still open, chipped by status, with its latest `Log:` line as the context line.
- Buttons come from `WIDGETS.md`'s queue vocabulary and map onto Direct item commands above; **Unblock** appears only on a `blocked` card.
- Skip the widget entirely for an unattended run — a scheduled firing or a `/sleep` posture run has nobody there to click, so write the text report to the log and stop.

## Resuming after a usage-limit reset

A single Claude Code session cannot wait out a usage-limit reset by itself — there is no in-session timer for that. Resumption is external:

- A scheduled task (see `mcp__scheduled-tasks`, or the `schedule` skill) re-invokes `/queue` on an interval — e.g. every 2-3 hours. Each firing is a fresh session: it resolves the queue directory (see Model), finds the `in-progress` item left by the last run, and continues. If usage is still limited, that firing's first action fails fast and harmlessly; the next one picks it up once the limit has reset. This is the recommended setup and only needs creating once — check `mcp__scheduled-tasks__list_scheduled_tasks` for an existing `queue-runner` task before creating a duplicate. Since PC items need Faruk present, a scheduled `queue-runner` should generally target `/queue phone`; leave `/queue pc` (or bare `/queue`) for when Faruk invokes it himself at his desk.
- Absent a scheduled task, resumption happens the next time Faruk (or anything) invokes `/queue` manually — nothing is lost, the queue file is the durable state.

Never try to sleep or poll inside one run waiting for a reset; end the run and let the next invocation do the waiting.

## Reporting

Same shape as `/sleep`'s wake-up report, but scoped to what this run of the queue did:

```text
Done:      <items completed this run, each with its PR/branch>
In queue:  <items still pending, in-progress, or blocked, one line each>
Assumed:   <assumptions made instead of asking>
Next:      <what the next /queue run will pick up>
```
