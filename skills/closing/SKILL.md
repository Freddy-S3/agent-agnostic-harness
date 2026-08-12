---
name: closing
description: "Phase 6 of the agentic loop: end-of-session knowledge capture. Converts session signal into durable harness improvements so the next conversation starts smarter."
user-invocable: true
---

# Closing Skill (Phase 6: Reflect)

This is the self-improvement engine of the harness.
Every session that ends without a Reflect pass is a session whose lessons are lost.
Run this at the end of every substantial conversation.

## Step 1: Task Handoff Artifact (do this first)

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

- Don't append - integrate cleanly into existing structure.
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

## Output

After making updates, give a short summary (not a markdown file) listing:
- Which files were updated and the single key fact added to each
- Any new skill created and its purpose
- Anything you considered documenting but decided NOT to, and why
