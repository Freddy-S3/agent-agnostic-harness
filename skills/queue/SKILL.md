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

**`Done when:` — the item's exit predicate.** Optional. Its value is a **single runnable command** whose exit code defines completion (`npm test`, `python tools/test_site.py`, `gh pr view 41 --json state -q .state`). Prose is not permitted and is rejected rather than charitably interpreted: a loop whose exit condition is the agent's own opinion of doneness is the failure this field exists to prevent, and `instructions/AGENTS.md` already draws the line between a check that runs and a sentence that advises. An item with no `Done when:` behaves exactly as `/queue` did before — one pass, then `done` — so no existing item needs migrating.

**`Iterations:`** — integer, maintained by `tools/converge.ps1`, not by hand. Absent means zero.

Adding an item is appending a new `## ` entry with `Status: pending` to whichever file matches its gate, in the resolved queue directory. No skill invocation needed for that half. If an item's gate is genuinely unclear, default to `QUEUE-PC.md` — it's the safer overclassification, since a phone-queued item that turns out to need local eyes stalls silently until someone notices, wasting a whole `/queue` run.

**Impact pass:** Before adding, selecting, or blocking an item, identify the unfinished work it enables. Add one `Depends on: <exact queue item title>` line to each dependent entry. The dashboard follows those edges across both queue files and orders each gate by direct plus transitive downstream fan-out; items without declared dependents keep their source order. Treat that computed order as the default priority because Faruk's time should unlock the most work possible.

**Which queue does `/queue` work?** If invoked with an argument (`/queue pc` or `/queue phone`), work only that file. Invoked bare, work `QUEUE-PHONE.md` first (more phone time to spend reviewing its output) and fall through to `QUEUE-PC.md` once it's empty or fully blocked/in-progress for this run.

**Moving an item between queues:** cut the whole `## ` entry (including its `Log:`) from one file and paste it into the other — no format change needed, a queue entry is self-contained. Add a one-line `Log:` note on the move (from which queue, and why). Do this when a blocked PC item turns out to have a phone-doable half worth splitting out.

## Software-factory run boundary

`tools/queue-runner.ps1` is the deterministic boundary around the model-driven workflow.

- Run `pwsh -NoProfile -File tools/queue-runner.ps1 start -Gate auto` before work begins.
  It reads both queues, resumes the highest-impact `in-progress` item before considering `pending`, preserves phone-before-PC order for `auto`, and claims exactly one item.
- An actionable item has exactly one `Repo:` line resolving to an existing Git repository.
  A missing or ambiguous route stops with an actionable error instead of guessing or skipping to another item.
- `start` writes `.software-factory/checkpoints/<run>.json` before marking the item `in-progress`.
  The checkpoint carries the owning route, phase, next action, and write-ahead intent history.
- Before a branch, push, build, network call, external tool, or other risky operation, run `checkpoint -Operation` with its partial state and a runnable discriminator.
  Close it with `checkpoint -Outcome` after the operation.
- On usage, permission, network, or tool failure, run `stop -Reason`.
  The item stays `in-progress`, the checkpoint becomes `paused`, and the next firing resumes the same run from its recorded phase.
- Finish only after one bounded verification path and a PR opened or updated when code changed.
  `finish -Verification ... -PullRequest ...` records the evidence and marks the item done; it never merges or publishes.
- Public publishing, paid infrastructure, external messages, production deployment, and merges are human gates.
  Use `block -Reason ... -Options ...` when one of those decisions stops the run.

## Contract

1. Set the mode to personal for the whole run, regardless of directory. Borrow `/faruk`'s one-interruption rule and `/sleep`'s recoverability discipline (branch, frequent real commits, never rewrite published history) — this runs unattended by design, so treat every item as a `/sleep`-style task even during the day.
2. Start `tools/queue-runner.ps1` before work begins. Read both queue files for the impact pass, even when an argument limits which gate this run may work. Resume the highest-impact `in-progress` item in the selected gate if one exists. Otherwise take the highest-impact `pending` item in that gate. If no dependency edges are declared, preserve source order.
3. Let the runner validate that the selected item has exactly one owning repository, create its checkpoint, mark it `in-progress`, and return the route before starting work. The queue file itself is not tracked in `agent-agnostic-harness` git, so the runner uses `tools/queue-cas.ps1` for its shared-file mutation.
   Treat the brief as a hypothesis about external state: before any cloud or other external mutation, run the cheapest live check that could falsify it. If read-only verification contradicts the brief, correct the queue decision fields and log before ending the run, then stop for a human choice rather than acting on stale prose.
4. Work only that item in its owning repo and on its own branch. Append a dated one-line note to the item's `Log:` after each meaningful step, such as a branch created, a PR opened, or a pause after a failure. Do not select or start a second item in the same run.
5. **When the item carries a `Done when:` command, converge on it rather than declaring it finished.** After the item's work, run:

   ```
   pwsh -NoProfile -File tools/converge.ps1 step -Queue <queue file> -Item "<title>" -Session <session id>
   ```

   Act on its exit code, which is the whole contract — do not re-decide doneness yourself:

   | Exit | Meaning | Do this |
   | --- | --- | --- |
   | 0 `converged` | the predicate passed | pass the result to `finish`, then end this run |
   | 0 `no-predicate` | the item declares none | use the bounded verification result with `finish`, then end this run |
   | 6 `reiterate` | the predicate failed, budget remains | re-enter the item **from its brief, with a fresh context window**, then run the step again |
   | 7 `capped` | the cap tripped | the script has already set the item `blocked` with the failing output and an `Options:` list. End this run. Do not raise the cap on your own authority |
   | 4 `usage` | the `Done when:` is prose, or the title matches no entry | fix the item, do not work around the gate |
   | 5 `conflict` | a peer wrote the queue file mid-step | re-read the file and re-decide, per the CAS rule |

   The re-entry is stateless on purpose: a fresh window is the point, not an accident. The count survives it because the script writes `Iterations:` to the queue file **before** the next attempt, so a session killed on a usage limit mid-loop resumes with an accurate count on the same terms as any other interrupted run. Caps are three iterations per firing and five in total; they are the script's defaults and are not to be overridden without Faruk's say-so, because "raise the cap" is exactly the move an unconverged loop will find attractive.

   **Hold the tree claim across the whole loop, not per iteration.** `tools/claim.ps1 acquire` runs before the first iteration and `release` after the loop exits; heartbeat between iterations. A loop that acquires and releases per iteration is worse than no loop at all, because it advertises the tree as free in the gaps.

   **`fix_plan.md` is the loop's scratch memory.** In the item's worktree, written by the first iteration and read and pruned by each one after it: the decomposition, what has been tried, what a prior iteration concluded, what remains. Its reader is a successor iteration of the same item, mid-flight — not Faruk and not the dashboard. Nothing from it goes into `Blocked reason:` or `Options:` unmodified. Delete it when the item reaches `done`.

6. When the bounded verification passes and the PR is opened or updated, run the runner's `finish` action with the verification result and PR URL. Marking an item done means the code change is handed off for review, not merged or deployed.
7. When you hit a usage-limit error, permission refusal, network failure, or tool failure, stop immediately with the runner's `stop` action. Leave the current item `in-progress`, record where it stopped, and end the run. The next firing resumes from the checkpoint without starting a second item.
8. When an item is genuinely blocked on something only Faruk can decide, use the runner's `block` action or write the same `Blocked reason:` and `Options:` fields through the queue CAS flow. Write the reason to be read cold on a phone: state what is being asked, what it affects, and what happens either way. Keep dates, measurements, and what earlier runs concluded in `Log:`, and never let the decision field point at them (`the four fixes`, `see above`, `unchanged since`, a bare prior date) or narrate its own rewriting. **Write an `Options:` list on that item in the same edit**, naming the two to four answers you actually considered, each phrased as the instruction Faruk would be giving you (`Branch, commit, push, PR`, not `Yes`).
9. A queued item that describes a new project (not a change to an existing repo) follows the new-project convention in `instructions/AGENTS.md`: new sibling repo under `C:\Users\Faruk\Repo`, `git init`, matching GitHub repo, portfolio-piece bar, and a tech stack chosen for what is currently in demand rather than defaulted to Faruk's resume stack.

## Status tracker

For every item worked, in addition to the item's own `Log:` line, append one line to `status/TRACKER.md` (gitignored, not committed) for each assumption, skip, or block — same content, cross-skill format: `- [ ] YYYY-MM-DD | /queue | <repo-or-scope> | <one-line item>`. This is what `/status-report` reads to give Faruk a same-day rundown across every skill's unattended runs.

The tracker is the secondary record, not the primary one. `tools/queue-dashboard` parses `QUEUE-PC.md`, `QUEUE-PHONE.md`, and the explicit `ANSWERS.jsonl` handoff; a tracker line never substitutes for either queue persistence path. Write both; if only one is possible, write the queue file and say in the report that the tracker write was refused, naming the path and the real error.

## Ending a run (required)

A `/queue` run may not end while holding an unpersisted decision, including one it discovered incidentally rather than as the worked item's own blocker. A defect noticed in a neighbouring repo, a question the brief did not anticipate, an assumption taken to keep moving - each gets a `## ` entry in the queue file matching its gate, with `Status: blocked`, a `Blocked reason:`, and an `Options:` list, before the report is written. Write it against whichever item it belongs to, or as a new one if it belongs to none.

If Faruk settles an existing queue item during the run - including saying that its work is already done - reconcile that item before continuing: add the `DECIDED` and `ANSWERED` records, verify the work before setting `Status: done`, and create a new item for any remaining work.
If the answer came from another conversation or host and the queue file cannot be updated in this turn, append one JSON object to `ANSWERS.jsonl` in the resolved queue directory: `{"file":"QUEUE-PHONE.md","title":"Exact ## title","answer":"Full decision","source":"direct conversation","recorded":"YYYY-MM-DD","state":"answered"}`.
Use the exact queue filename and title; the dashboard uses the newest record for that key until the queue entry is reconciled.

Read back every entry written. Then check the run's own output against the dashboard's contract, because an entry can be well written and still invisible:

- An item carrying a `DECIDED` line or a log line starting with `ANSWERED` is treated as settled and shown to nobody. When the decision is made but the work it authorises has not happened, the remaining work goes in a NEW item rather than as a log line under the answered one.
- An item at `Status: done` is likewise never shown. Do not mark an item done because its decision was answered; done means the work landed.

Both of these were live on 2026-08-14: several items sat `pending` with a `DECIDED` line and real outstanding work, and the dashboard correctly showed none of them, because the file said they were answered.

This applies without exception to a run spawned as a subagent or a parallel task. Reporting a blocker to an orchestrator is not persisting it - the orchestrator's context ends with the turn, the queue file does not.

## Direct item commands

Normally `/queue` asks the runner for one item using the impact and resume rules above. Faruk can override that one-item choice by naming a title, either typed or by clicking a card (see Rendering):

| He says | Do this |
| --- | --- |
| `Run the queue item "<title>" next.` | Work that item now, ahead of queue order. Leave the ordering of everything else alone. |
| `Skip the queue item "<title>" for this run.` | Leave its status untouched, log `skipped this run` with the date, and end this run. Not the same as `blocked` - a skip carries no reason and expires at the end of the run. |
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

- If the host supports scheduled tasks, keep one low-frequency `queue-runner` automation for the phone queue, such as every six hours. Its first action is the deterministic `queue-runner.ps1 start` check; when there is no actionable item it exits without starting model work. Each firing is a fresh session that resumes the checkpointed `in-progress` item, and each firing owns at most one item. Check for an existing `queue-runner` task before creating a duplicate. Do not create one schedule per usage reset or a set of token-polling schedules. PC items stay manual because they may need Faruk at the desk.
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
