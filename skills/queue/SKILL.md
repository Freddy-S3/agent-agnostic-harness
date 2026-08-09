---
name: queue
description: Work through the idea backlog in queue/QUEUE.md continuously, in personal-mode posture, resuming automatically after usage-limit resets. Use when Faruk wants to drop a larger idea into a backlog instead of running it now, or asks to run or resume the queue.
user-invocable: true
disable-model-invocation: true
---

# Queue

A backlog for ideas too large to run inline, worked continuously without Faruk babysitting it.
`/faruk` and `/sleep` execute one task end to end; `/queue` is the loop that keeps feeding them tasks across usage-limit resets a single session cannot survive.

## Model

`queue/QUEUE.md` in this repo (`~/Repo/claude-harness/queue/QUEUE.md`) is the backlog.
Each idea is a `## ` entry with a `Status:` line (`pending`, `in-progress`, `done`, `blocked`), a `Repo:` line when it targets a specific project, a free-text brief, and a `Log:` list of dated one-line notes.

Adding an item is just appending a new `## ` entry with `Status: pending`. No skill invocation needed for that half.

## Contract

1. Set the mode to personal for the whole run, regardless of directory. Borrow `/faruk`'s one-interruption rule and `/sleep`'s recoverability discipline (branch, frequent real commits, never rewrite published history) — this runs unattended by design, so treat every item as a `/sleep`-style task even during the day.
2. Read `queue/QUEUE.md` top to bottom. Resume the first `in-progress` item if one exists — it means a prior run was interrupted mid-task, most likely by hitting the usage limit. Otherwise take the first `pending` item.
3. Mark the item `in-progress` and commit that status change to `claude-harness` before starting work, so an interruption a moment later still leaves an accurate queue state.
4. Work the item to completion in its own repo (the `Repo:` line), on its own branch, following that item's brief. Append a dated one-line note to the item's `Log:` after each meaningful step (branch created, PR opened, blocked on X) — not a full transcript, just enough for the next run or Faruk to pick up the thread cold.
5. When the item is fully done (PR opened, or the deliverable otherwise landed), mark it `done` and commit. Move to the next `pending` item and repeat, in the same run, until the queue is empty or you hit a stopping condition below.
6. When you hit a usage-limit error (rate-limit / quota message from the harness or API, not an ordinary tool error), stop immediately: leave the current item `in-progress` with a log line describing exactly where it stopped, commit that, and end the run. Do not ask anything first — there is nobody to answer.
7. When an item is genuinely blocked on something only Faruk can decide (credentials, a judgment call with no reversible default, something in the `/sleep` stop-and-confirm list), mark it `blocked` with a one-line reason in the log and move on to the next item rather than stalling the whole queue.
8. A queued item that describes a new project (not a change to an existing repo) follows the new-project convention in `instructions/AGENTS.md`: new sibling repo under `C:\Users\Faruk\Repo`, `git init`, matching GitHub repo, portfolio-piece bar, and a tech stack chosen for what is currently in demand rather than defaulted to Faruk's resume stack.

## Status tracker

For every item worked, in addition to the item's own `Log:` line, append one line to `status/TRACKER.md` (gitignored, not committed) for each assumption, skip, or block — same content, cross-skill format: `- [ ] YYYY-MM-DD | /queue | <repo-or-scope> | <one-line item>`. This is what `/status-report` reads to give Faruk a same-day rundown across every skill's unattended runs.

## Resuming after a usage-limit reset

A single Claude Code session cannot wait out a usage-limit reset by itself — there is no in-session timer for that. Resumption is external:

- A scheduled task (see `mcp__scheduled-tasks`, or the `schedule` skill) re-invokes `/queue` on an interval — e.g. every 2-3 hours. Each firing is a fresh session: it reads `queue/QUEUE.md`, finds the `in-progress` item left by the last run, and continues. If usage is still limited, that firing's first action fails fast and harmlessly; the next one picks it up once the limit has reset. This is the recommended setup and only needs creating once — check `mcp__scheduled-tasks__list_scheduled_tasks` for an existing `queue-runner` task before creating a duplicate.
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
