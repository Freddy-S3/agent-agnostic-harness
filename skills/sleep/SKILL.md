---
name: sleep
description: Zero-interruption personal mode. Use when Faruk is asleep or away and the work must run to completion with no questions, no gates, and no mid-task check-ins.
user-invocable: true
---

# Sleep

`/faruk` with the interruption budget set to zero.

Faruk is asleep. He is not reading this reply until morning.
There is nobody to answer a question, approve a plan, or unblock a decision.
A question asked is a night wasted.

This skill governs what you ask, not what you are permitted to run.
Tool permission prompts are enforced by the harness, so an unattended session must also be launched with a permission mode that does not stop for dialogs.
When a permission prompt would block the work and the session was not launched that way, do not sit on it: finish everything reachable without that tool and record the blocked step in the wake-up report.

## Contract

1. Personal mode for the whole session, regardless of directory.
2. Ask nothing. Not one question, not at the start, not at the end.
	The one-interruption rule from `/faruk` drops to zero interruptions.
3. When a decision is genuinely ambiguous, take the most reversible option, write the assumption into the log, and keep going.
	A reversible wrong choice reviewed at breakfast beats a right choice that never got made.
4. Never stop to report progress.
	No "let me know if you want me to continue", no interim summaries, no pausing at a natural break.
	Run until the work is done, blocked, or out of scope.
5. Verify by running the thing. There is no human to eyeball it.
6. Leave a wake-up report as the final message.

## Recoverability replaces approval

Approval gates exist so a human can catch a bad change before it lands.
Nobody is watching, so recoverability has to do that job instead.

- Work on a branch, never directly on the default branch.
- Commit at every coherent step, with real messages. Frequent small commits are the undo history Faruk wakes up to.
- Never amend, rebase, force-push, or otherwise rewrite anything already published.
- Never delete or overwrite anything that is not committed and pushed. Move it aside instead.
- Prefer additive changes over destructive ones when both reach the goal.

## What to do instead of asking

The `/faruk` stop-and-confirm list still applies, but at night these are not questions.
They are things you simply do not do:

| Situation | Night behaviour |
|---|---|
| Deleting uncommitted data | Commit it, or move it aside. Never delete. |
| Force-push or rewriting published history | Do not. Push the branch as a new commit instead. |
| Production deployment | Do not. Leave it staged and log it. |
| Publishing, posting, emailing, paying | Do not. Draft it, leave it unsent, log it. |
| Ambiguous requirement | Pick the reversible reading, log the assumption, continue. |
| Two comparable approaches | Pick the simpler one, log the choice, continue. |
| Genuinely blocked sub-task | Skip it, finish every other part in full, log why, and write the options. |

Skipping one blocked item and completing the other nine is a good night.
Stopping at item one to ask is a wasted one.

Every block handed back to Faruk carries an `Options:` list on its queue item — two to four answers you actually weighed, each phrased as the instruction he would be giving you (`Branch, commit, push, PR`, not `Yes`). You are the only party who knows the alternatives at the moment you hit the wall; by morning that reasoning is gone unless it was written down. The dashboard turns those lines into one-click answers, so the difference between listing them and not is whether Faruk clears the blocker in a second or has to reconstruct the problem and type a reply. See `queue/README.md` for the field.

## Persist before you sleep (required)

A night run's entire output to Faruk is what it wrote down. He is not reading a transcript at 7am; he is opening a dashboard.

Before the wake-up report, every assumption, skip, and block from this run gets persisted twice:

1. **Into the queue file matching its gate** (`QUEUE-PC.md` or `QUEUE-PHONE.md`, resolved per `skills/queue/SKILL.md`) as a `## ` entry with `Status: blocked`, a `Blocked reason:`, and the `Options:` list described above. Because you ran unattended, you are the only party who ever had the context - so the `Blocked reason:` has to carry all of it, stated in full for a cold phone reader, with the dates and history in `Log:` and no back-references out of the decision field. See `instructions/AGENTS.md` under the unpersisted-decision rule. This is the one that reaches him - `tools/queue-dashboard` parses those two files and nothing else.
2. **Into `status/TRACKER.md`**, one line each: `- [ ] YYYY-MM-DD | /sleep | <repo-or-scope> | <one-line item>`. Append, never overwrite; `/status-report` owns clearing resolved lines.

Read back what you wrote. A refused write is reported in the wake-up report with the exact path and the actual error, never passed over in silence - a night that finds a blocker and loses it is worse than one that never looked, because the report reads clean either way.

The `Assumed:` and `Skipped:` lines in the wake-up report are a summary of what was persisted. They are not a substitute for persisting it, and a session that writes only the report has not done this step.

This binds subagents and parallel tasks in full. A worker that reports a blocker to its orchestrator has not persisted it: the orchestrator's context ends with the run, the queue file survives the night.

## Wake-up report

Close with this, and nothing else:

```text
Done:      <what now exists or changed>
Branch:    <branch name, commit count, pushed or not>
Checked:   <what was run, and its actual result>
Assumed:   <every assumption made instead of asking, one per line>
Skipped:   <anything left undone or deliberately not done, and why>
Next:      <the first thing to look at over coffee>
```

State failures plainly.
An honest "three of five done, here is what broke" is worth more at 7am than a confident summary that hides a red test.
Never report work as complete that was not verified.

## Launching an unattended session

For a night run with no dialogs, start the session with a permission mode that does not stop:

```powershell
claude --permission-mode bypassPermissions
```

Use `acceptEdits` instead when only file writes should pass without asking and shell commands should still be gated.
`bypassPermissions` skips every check, so scope the session to a repository whose work is committed and pushed.
