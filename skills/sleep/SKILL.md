---
name: sleep
description: Zero-interruption personal mode. Use when Faruk is asleep or away and the work must run to completion with no questions, no gates, and no mid-task check-ins.
user-invocable: true
disable-model-invocation: true
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
| Genuinely blocked sub-task | Skip it, finish every other part in full, log why. |

Skipping one blocked item and completing the other nine is a good night.
Stopping at item one to ask is a wasted one.

## Status tracker

Alongside the wake-up report, append one line to `status/TRACKER.md` (repo-root of `claude-harness`, gitignored, not committed) for every assumption, skip, or block from this run — the same events that land in the report's `Assumed`/`Skipped` lines. Format: `- [ ] YYYY-MM-DD | /sleep | <repo-or-scope> | <one-line item>`. This is what lets `/status-report` give Faruk a same-day rundown without re-deriving it from transcripts. Append, never overwrite; `/status-report` owns clearing resolved lines.

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
