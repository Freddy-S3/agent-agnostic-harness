---
name: closing
description: "Phase 6 of the agentic loop: end-of-session knowledge capture. Converts session signal into durable harness improvements so the next conversation starts smarter."
user-invocable: true
---

# Closing Skill (Phase 6: Reflect)

This is the self-improvement engine of the harness.
Every session that ends without a Reflect pass is a session whose lessons are lost.
Run this at the end of every substantial conversation.

## Step 0: Persist every open decision (REQUIRED, do this before anything else)

This step is not optional and has no "if it seems worth it" clause.
Do it even when the session produced no durable lesson and the rest of `/closing` is a no-op.

Sweep the session for everything that is now waiting on Faruk:

- Blockers you hit and worked around.
- Questions you would have asked if there had been someone to ask.
- Assumptions taken instead of asking.
- Defects found in passing that you are not authorised to fix.
- Anything you were about to describe in the final report as "needs your call".

Write each one into the queue file matching its gate - `QUEUE-PC.md` if it needs his desk, `QUEUE-PHONE.md` if a reply or a click settles it, `QUEUE-PC.md` when genuinely unclear - resolving the directory exactly as `skills/queue/SKILL.md` describes.
Either amend the existing `## ` entry it belongs to or add a new one.
Each carries `Status: blocked`, a `Blocked reason:`, and an `Options:` list of the two to four answers you actually weighed, each phrased as the instruction he would give (`Branch, commit, push, PR`, not `Yes`).

Write the `Blocked reason:` for someone reading it cold on a phone who has never seen this session: state the whole decision - what is being asked, what it affects, and what happens either way - in as many sentences as that takes. It is the field the dashboard renders, so it has to stand alone. Put the history in `Log:` instead: dates, what you measured, what a previous run concluded. Never point the decision field at that history (`the four fixes`, `see above`, `restating the earlier answer`, a bare prior date), and never narrate why the item was rewritten. See `instructions/AGENTS.md` under the unpersisted-decision rule for the full convention and a worked example.
See `queue/README.md` for the field.

Then append the same items to `status/TRACKER.md` in the cross-skill format, so `/status-report` sees them too.

After the open-decision sweep, reconcile any existing queue item settled in this conversation, including an item Faruk says is already complete. Record `DECIDED` and `ANSWERED`, verify before marking it `done`, and create a new queue item for unfinished follow-up work. Read the changed entry back. If the queue file cannot be updated in this turn, append the exact queue filename, item title, full answer, source, date, and `state: answered` as one JSON object to `ANSWERS.jsonl` in the resolved queue directory. This explicit handoff is required because the queue dashboard reads files, not conversation history.

**Why this outranks the rest of the skill.** Faruk's dashboard parses the two queue files and the explicit `ANSWERS.jsonl` handoff - not `TRACKER.md`, the transcript, or your closing summary.
A decision reported only in chat is a decision he never sees, and it looks identical to no decision at all.
On 2026-08-14 he opened a dashboard showing zero blockers while seventeen real ones sat in that night's session reports.
Every one had been found, stated clearly, and lost.

**Three failure modes to avoid, all of them real:**

- **Reporting instead of writing.** A subagent or parallel task that tells its orchestrator about a blocker has not persisted it. The orchestrator's context ends with the turn; the queue file does not. If you are running as a subagent, write to the queue file yourself rather than delegating it upward, and say in your report that you did.
- **Writing and not checking.** Read the entry back after writing it. A `TRACKER.md` append was refused by a permission classifier on 2026-08-14 and the session continued as though it had landed. If a write is refused, say so in the final report with the exact path and the actual error text, so the parent session can persist it on your behalf. Never let a failed write pass silently.
- **Marking it answered when it is not.** An item carrying a `DECIDED` line or an `ANSWERED` log line is treated as settled and disappears from the dashboard. When a decision has been made but the work it authorises has not happened, that remaining work goes in a NEW item, not as a log line under the answered one.

## Step 1: Task Handoff Artifact

Before updating any permanent files, handle the task state in `/memories/repo/tasks/`.

**If the task is incomplete** (not yet at Phase 6 merge-ready):
- Write or update a handoff with the naming convention owned by `/ship`: `/memories/repo/tasks/<ticket-id>-<slug>.md` for ticket-backed work or `/memories/repo/tasks/adhoc-<slug>.md` for ticketless work.
	Use this exact structure:

```markdown
# Task: <ticket title>
## Decisions Made
- <one line per settled decision - the WHY matters, not just the what>

## Status
- [x] Phase 1-2: Plan
- [x] Phase 3: <sub-tasks done>
- [ ] Phase 3: <sub-tasks remaining>
- [ ] Phase 4: Synthesize
- [ ] Phase 5: Code review

## Files Changed So Far
- <relative path> (<one-word status: new|partial|done>)

## Next Step
<Single sentence: exactly what the next conversation should do first>
```

Keep it under 20 lines total. This is a context stash, not a narrative.

**If the task is complete** (Phase 5 done, ready to commit):
- Keep the handoff artifact through Gate 3 so a `fork` can resume the proposed harness updates.
- Delete it only after Gate 3 receives `done` and the approved updates are applied.

## Step 2: Permanent Knowledge Capture

Scan the full conversation, including any earlier `/ship` loops in the same session, for:
1. **Corrections** - the user corrected your approach, code style, or architecture.
These are the highest-signal items. The user is telling you what "right" looks like.
2. **Missing context** - you had to search for something that should have been pre-loaded.
That search cost tokens and time; prevent it next time.
3. **Ambiguous skill** - a skill's instructions were unclear and you had to guess.
Update the skill so the next invocation is unambiguous.
4. **New pattern** - a repeatable workflow emerged that no existing skill covers.
Either add it to the closest existing skill or create a new one (only if clearly distinct).
5. **Resolved open questions** - any "open questions" in memory or instructions that this session answered.
Close them out.
6. **Questions the user had to ask** - anything found only because Faruk asked something you had not thought to check.
Ranks with corrections for signal. Each one names a blind spot no mechanism was watching, so capture the missing check rather than the fact it uncovered.
The standing rule is to fix these inline when they happen; reaching `/closing` still holding one means the fix was skipped, not deferred.

## Where To Write

| Signal type | Target file |
|---|---|
| Code style/architecture correction for a specific project | That project's scoped instructions file (e.g. `<PROJECT>.instructions.md`, or the repo's `.github/` / `CLAUDE.md` equivalent) |
| New project-specific gotcha (external API, env quirk, etc.) | The relevant section of that project's scoped instructions file |
| New general workflow or repeatable process | Create or update the relevant harness skill under `skills/` |
| Cross-project user preference or habit | User memory `/memories/` (brief, 1-2 lines) |
| Workspace-specific fact (build commands, file paths, etc.) | Repo memory `/memories/repo/` |
| Anything about the agentic loop itself or skill quality | The root agent instructions (`instructions/AGENTS.md`) or the specific skill file |

## Rules

- Don't append - integrate cleanly into existing structure. This governs the knowledge capture in Step 2 only; the queue and tracker writes in Step 0 are appends by design, and their files are logs rather than living documents.
- Keep each addition to 1-2 lines. Bloat in auto-loaded files has a real token cost.
- Pick the single best home for each fact. Do not duplicate across files.
- Don't document one-off bugs unlikely to recur.
- Don't write a session summary or changelog - update living documents only.
- Don't ask the user for permission. Just do it, then summarize what changed.
- If a skill now has > 8 bullet points in any section, see if two can be combined or removed.

## Editing Harness Documents

For a `SKILL.md`, instruction, prompt, agent, `copilot-instructions.md` / `AGENTS.md`, or task handoff, use `/writing-for-agents` as the authoritative writing guide.

## Harness Health Check (run monthly or when skills drift)

- Are any two skills largely duplicating each other? Merge them.
- Does every skill retain a distinct trigger or workflow? Fold overlapping skills into the closest owner and delete the redundant one.
- Is any skill routinely not being invoked even though the task fits? The trigger condition is wrong - fix it.
- Does any instruction file section exceed 20 lines? It's probably bloated - tighten it.
- Are there "open questions" in memory older than 2 sessions? Either resolve them or delete them.

## Project coordination handoff

When the session worked inside a repository that has `AGENTS.md`, finish the project handoff as part of closing:

1. Summarize the outcome in four lines: result, verification, remaining risk, and next action.
2. If `docs/PROJECT-CONTEXT.md` exists, update it only with stable facts or settled decisions; do not put temporary chat history there.
3. Run `tools/chat-handoff.ps1 -Repository <repo> -Purpose "Resume coordination"` when the portable tool is available.
   This writes `docs/CHAT-HANDOFF.md` for the next Codex or Claude Code session.
   Run it from the claimed worktree and pass that worktree path as `<repo>`; the tool writes directly to the supplied path, so passing the canonical shared checkout from an isolated run collides with another session's tree.
4. If Codex app thread tools are available, publish the same four-line summary to the matching `00 Main - Coordination` task:
	- Call `codex_app__list_threads` and find an existing task whose exact title is `00 Main - Coordination` and whose repository path matches the owning repository.
	- Prefer the current host and an active or idle task; if more than one exact match remains, choose the most recently updated one.
	- If the matching task is the current task, include the summary in the closing response instead of sending a duplicate message.
	- Otherwise call `codex_app__send_message_to_thread` with the task id and host id, using this four-line format:

```text
Result: <outcome and what finished>
Verification: <what was checked>
Remaining risk: <none, or the specific risk>
Next action: <the next recommended action>
```

	- Confirm that the send succeeded before treating the coordination update as complete.
	- Use an existing task only; when no exact match is available, do not create a new task automatically.
5. If the app tools are unavailable, or no exact coordination task exists, present the four-line summary as ready-to-paste text in the closing response.
6. Do not archive the outcome chat until the durable files and coordination update are complete.

## Output

After making updates, give a short summary (not a markdown file) listing:
- Every decision persisted in Step 0, which queue file it landed in, and confirmation you read it back. If there were none, say "no open decisions" explicitly rather than omitting the line - a silent omission is indistinguishable from having skipped the step.
- Which files were updated and the single key fact added to each
- Any new skill created and its purpose
- Anything you considered documenting but decided NOT to, and why
