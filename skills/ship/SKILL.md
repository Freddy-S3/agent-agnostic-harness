---
name: ship
description: "Full 6-phase loop orchestrator. Invoke with a task description to run Plan → Implement → Synthesize → Review → Reflect in a single guided conversation with only 3 human checkpoints."
user-invocable: true
disable-model-invocation: false
---

# Ship Skill - Full Loop Orchestrator

Execute all 6 phases automatically.
Only stop at Gate 1, Gate 2, and Gate 3 when reflection has proposed updates.
Never ask the user to invoke a sub-skill manually.

## Invocation

```
/ship <task description>
```

When the host supports scoped agent modes, invoking `/ship` from a project-specific agent (`@<agent> /ship <task>`) is preferred, since the agent supplies the project's conventions.

---

## Context Management

Token cost accumulates with conversation length. Each presented gate is a valid fork point.
The live ledger below - not the chat history - is what the next conversation needs.

**At every gate**, append after the reply options:
`→ Reply "fork" to start a new chat with "/ship continue <task-id>" — resets token count, the ledger preserves full state.`
`→ Reply "REALIGN" to reread the ledger and continue from its recorded state.`

## Live Task Ledger

The handoff artifact is a **live ledger**, not an end-of-session summary.
It is the compact recovery source of truth; the conversation is supplementary context.
Writing it only at the end is worthless, because a session that dies on a usage limit never reaches the end.

Create it at preflight, before any work: `/memories/repo/tasks/<ticket-id>-<slug>.md` for tracker-backed work, `/memories/repo/tasks/adhoc-<slug>.md` otherwise.
Keep one ledger per active task and never overwrite an unrelated active one.

```text
status: active | paused
mode: personal | delivery
director: /freddy | /faruk | none
owner: /ship
phase: plan | implement | synthesize | review | reflect
gate: none | 1 | 2 | 3
objective: <one sentence>
acceptance: <observable definition of done>
decisions: <settled choices>
changed: <paths or none>
evidence: <validation and its actual output, or none>
blocker: <none, or the one blocking decision>
next: <single next action>
updated: <timestamp>
```

Refresh it at startup, after each settled decision, after each worker wave, after each validation, at every phase transition and gate reply, and on any change to `objective`, `changed`, `evidence`, `blocker`, or `next`.

### Write-Ahead Entries

Death is unannounced, so the ledger records what is **about to** happen, not only what did.

Before any risky operation - an irreversible change, an outward-facing action, a git operation beyond reading, or a pass that crosses a repository boundary - append to the ledger body:

```text
## INTENT <n> <timestamp>
op: <what is about to be attempted>
partial: <the half-completed state this could leave>
discriminator: <the exact command a successor runs to tell which happened>
```

Append `## OUTCOME <n>` with `result: done | failed | abandoned` when it finishes.
`discriminator` must be a runnable command whose output differs between the two states; a description is not a discriminator.

A run of independently reversible same-kind edits may share one INTENT. Anything irreversible gets its own.

An INTENT with no matching OUTCOME is unfinished work, and it is how a successor distinguishes a session that **died** from one that **chose to stop** - a deliberate stop writes `status: paused` with every INTENT closed.

### Lifecycle

If a matching active ledger conflicts with the new task, ask whether to `resume`, `restart with a new task id`, or `archive`. Never silently replace it.
At `fork` or `pause`, set `status: paused` and record the exact next action.
On `REALIGN`, reread the ledger, print the state record, reconcile it with the newest request, and continue at the recorded phase or gate - do not re-plan and do not re-route.
Delete a completed ledger only after the task finishes and any approved harness updates are applied, so it cannot bind a later task.

**Subagent invocations:** pass only the specific sub-task + ledger + reference file path.
Never pass conversation history or full exploration output.
Open every worker prompt with `First read ~/Repo/agent-agnostic-harness/instructions/AGENTS.md and follow it.` - a worker starts with none of this conversation and no guarantee of the standing rules, so an uninstructed one will violate them silently.
Require each worker to end with a compact report: files written, the validation it ran and that check's actual output, and anything it could not complete. A worker that reports only prose has not been verified.

**Parallel delegation:** fan out reads, serialise writes.
Read-only workers - exploration, audits, verification, research - take no claim, cannot conflict, and should be launched as wide as the plan usefully allows.
A writing worker must hold the claim for the tree it writes in before it starts: `tools/claim.ps1 acquire -Tree <path> -Session <id>`, exit 3 meaning the tree is taken and the worker needs its own worktree instead.
A worker producing shared generated output also claims that cascade by name (`-Cascade <name>`); one owner at a time, because those files collide at merge rather than corrupting on write.
Launch independent workers in the same batch; do not wait for one before starting another in the same wave.
- Parallelize only tasks that have no dependency on another task's output and have disjoint write ownership.
- Run tasks sequentially when they touch the same files, share mutable state, require prior output, or the harness does not expose the agent/runSubagent tool.
- Wait for every worker in a parallel wave to finish before starting dependent work or Phase 4 synthesis.
- Unless the user explicitly requests otherwise, let each worker inherit the parent session's selected model.
- If the harness cannot perform parallel delegation, state `Parallel delegation unavailable` and continue sequentially; never imply that the work ran in parallel.

**Drop after each phase:**
- Post-Gate 1: Phase 1 exploration is dead weight (it lives in the ledger). Fork here for cheapest implementation phase.
- Post-Phase 3: implementation details are dead weight (they live in the changed files). Fork here for cheapest review.
- Post-Phase 6: after explicit Gate 3 approval or implicit no-update completion, delete the completed ledger (knowledge absorbed into instruction files and memory).

### Phase-Boundary Decision Rule

Use phase boundaries (Gate 1, Gate 2, conditional Gate 3, or the automatic phases between them) for context-management decisions. During a phase, continue the scoped work by default; if a blocking decision or unexpected dependency arises, surface it immediately and pause the affected slice rather than guessing.

- **Continue** — default whenever the next phase needs this one as a primary source (Plan → Implement is the standard case) or token budget is not yet tight. Costs nothing, loses nothing; rule this out first.
- **Compact** — relevant context, same session, but budget is getting tight and nothing below applies. Compress and carry on; this is the fallback, not the first reach.
- **Handoff / fork** — only when something is actually leaving this session: a fresh chat, a new harness, a colleague, or a paused/side task branched mid-phase. This is the existing gate-reply `fork` behavior above — write/refresh the handoff artifact, then resume with `/ship continue <ticket-id>`.
- **Subagent delegation** — the remaining work is scoped tightly enough to run unattended (a parallel-wave worker, a focused review or build check). Hand it only its sub-task, the handoff artifact, and the reference file path; take back a compact report. If the delegation is not independent, keep it sequential.

**Orchestration vs. discipline:** `/ship` is user- and model-invocable: a human can start it with the slash command, and the harness starts it automatically for file-changing work. It owns Gate 1, Gate 2, the conditional Gate 3, and the fork wording above. The phases it drives (PLAN, NEWFEATURE/DEBUGGING, CLOSING) are model-invoked reusable disciplines: each can also fire on its own outside `/ship` when a task only needs that one piece. Driving them through `/ship` does not change their own internal judgment — it only means the gates and handoff/fork decisions in this file are `/ship`'s to make, not theirs.

### Scoped Project Context

When the target area has a scoped instructions file (a repo `.github/instructions/*.instructions.md`, `AGENTS.md`, or `CLAUDE.md` covering that path), consult it before broad exploration.
Use its entry-point, route, service, store, and test map to select the smallest owning files and nearest validation target.
Do not duplicate the full map in the plan or handoff; record only the selected paths and task-specific findings.

### Task Intake (automatic - before Handoff Check)

Classify the request before looking up Jira:

- Extract an explicitly supplied Jira key matching `PROJECT-123` (uppercase project key, hyphen, numeric issue id).
- If a Jira key is present, mark the task **ticket-backed**. Before planning or implementation, require successful MCP authentication to the configured Jira (`JIRA_URL`) and Confluence (`CONFLUENCE_URL`); if either authentication fails, stop immediately and do not proceed. After both succeed, fetch the issue, including all comments, before planning. Read every comment and capture the summary, description, acceptance criteria, status, priority, relevant links, and comment requirements. Treat comments as acceptance criteria; surface any conflict with the ticket description before planning. Use the Jira Data Center MCP server for a self-hosted Jira instance; use the Atlassian MCP server for Confluence and for an actual Cloud site. Never print credentials, cookies, tokens, or full authentication payloads. When no tracker is configured at all, treat the task as ticketless rather than blocking.
- If no Jira key is present, mark the task **ticketless** and continue normally. Do not search Jira and do not treat missing Jira access as a blocker for a coding question, local bug report, refactor, test request, or other ad hoc task.
- If the user asks to work from Jira but gives no issue key, ask for the key at Gate 1 rather than guessing from a search result.
- Record the classification in the Gate 1 output as `Ticket: <key>` or `Ticket: none (ticketless)`.

---

## Execution Sequence

### Pre-flight: Handoff Check (automatic - no gate)

Check `/memories/repo/tasks/` for a handoff artifact matching this task. For ticket-backed work, match `<ticket-id>-*.md`. For ticketless work, match `adhoc-<slug>.md`.

- **Found:** read it, state what was already decided and what was already done, and run the `discriminator` of any INTENT with no OUTCOME before touching anything - that entry is a half-applied operation from a session that did not survive.
Skip Phase 1-2 and jump directly to Gate 1 with the existing plan pre-filled.
- **Not found:** create the ledger, then proceed to Phase 1.

The ad hoc ledger is created at startup like a tracker-backed one, not only when the task pauses. A ledger that only appears on a clean pause is absent in exactly the case it exists for.

---

### Phase 1-2: Plan (automatic → outputs Gate 1)

Run PLAN skill: explore affected files, find the reference sibling, and decompose the work into dependency-ordered sequential sub-tasks.
Add a parallel wave only when independently bounded work materially benefits from it; independent work is not, by itself, a reason to spawn more agents.
Surface any blockers as part of the Gate 1 output.

```
════════════════════════════════════════════════
 GATE 1 - PLAN  (reply to continue)
════════════════════════════════════════════════
Task:       <task name>
Ticket:     <Jira key> | none (ticketless)
Reference:  <file being modeled after>
Type:       feature | bugfix | refactor

Parallel waves (optional, only when the benefit justifies the extra context and merge cost):
  Wave 1:
    • <sub-task>
    • <sub-task>
  Wave 2:
    • <sub-task>

Sequential sub-tasks (in order, including tasks that depend on a parallel wave):
  1. <sub-task>
  2. <sub-task>

Blockers (resolve before I start):
  • <question> — or "none"

Scope estimate: ~<N> lines changed across <N> files
════════════════════════════════════════════════
Reply "proceed" to implement | adjust any item | "fork" to reset context (handoff preserves state)
```

---

### Phase 3: Implement (automatic after Gate 1 approval)

Load NEWFEATURE or DEBUGGING skill based on task type.
Implement the plan as dependency-ordered waves:
1. Keep the default path sequential with one task owner and one active writing agent per worktree.
2. For an approved parallel wave, launch only independently bounded work, cap the wave at three agents, and give each writer an isolated worktree.
3. Pass each worker only its specific sub-task, the handoff artifact, and the reference file path.
4. Wait for all workers in the wave to finish before starting the next wave.
5. After the wave completes, output one status line per sub-task:
  `  ✓ <sub-task> → <file> (parallel wave <N>)`
6. Run sequential sub-tasks in order after their dependencies are complete.
7. For sequential work, output the existing status format:
  `  ✓ <sub-task> → <file>`

Do not create a parallel wave merely because tasks are independent.
Do not run parallel workers that edit the same file or depend on each other's uncommitted changes.
If a blocking decision arises mid-implementation that was not in Gate 1, surface it immediately as an inline question and wait for a one-line answer before continuing.

---

### Phase 4: Synthesize (automatic - no gate)

Run `dotnet build` (C#) or `npm run build` (Vue/TS) depending on what changed.
Fix any compilation errors automatically without pausing.
Output: `Build: ✓ (or ✗ <error summary>)`

When the change touches a UI that has an E2E suite, also run the browser validation path:

1. Build the application artifact the E2E suite loads.
2. If a saved authenticated session and the required target URL env var are both present, run the stable E2E project against the saved session, skipping the interactive setup dependency (e.g. `playwright test --config <config> --project=<project> --no-deps --retries=0`).
3. If the saved session is missing or expired, report `E2E blocked: interactive re-authentication required` and identify the auth-refresh command as the recovery step. Never write a fake token, copy a token into application storage, or bypass the authenticated assertion.
4. Treat a passing page-load check plus the authenticated view assertion as the browser validation result. Do not expose token or cookie values in logs.

---

### Phase 5: Evaluate (automatic → outputs Gate 2)

Run an **adversarial** review of the complete diff using `/codereview`.
`/codereview` owns the reviewer mindset, review checklist, finding labels, Standards and Spec-Fidelity axes, smell baseline, and debugging-change filter.
`/ship` owns the gate presentation, approval timing, and the post-approval remediation sequence below.
Make the complete `/codereview` verdict and its findings visible inside Gate 2.

```
════════════════════════════════════════════════
 GATE 2 - CODE REVIEW  (reply to continue)
════════════════════════════════════════════════
<complete /codereview verdict and findings>
BLOCKs: N  |  NITs: N  |  SUGGESTs: N
════════════════════════════════════════════════
If BLOCKs: 0, reply "lgtm" to accept | list items to fix | "fork" to reset context before reflect
If BLOCKs > 0, fix each `[BLOCK]` and rerun review | "fork" to reset context before review
```

Before Gate 2 approval, fix every `[BLOCK]` and rerun the complete review.
Only offer `lgtm` when `BLOCKs: 0`.
After Gate 2 approval: auto-fix all `[NIT]` items and rerun focused validation.
Do not auto-fix anything labeled [SUGGEST] — those need intent.

---

### Phase 6: Reflect (automatic → conditionally outputs Gate 3)

Run CLOSING skill.
Draft all proposed harness updates.

If there are no proposed harness updates, treat Gate 3 as implicitly approved: delete any completed task handoff and finish the session without presenting Gate 3.
When at least one proposed harness update needs approval, keep the handoff through Gate 3 so `fork` remains resumable.
Update it if pausing; after `done`, apply the approved updates and delete the completed task's handoff.

```
════════════════════════════════════════════════
 GATE 3 - REFLECT  (reply to finish)
════════════════════════════════════════════════
Handoff artifact: <retain until "done" - task complete | update - pausing mid-task>

Proposed harness updates:
  • <file>: <one-line fact being added or changed>
  • <file>: <one-line fact being added or changed>

Not capturing (and why):
  • <item> - <reason, e.g. "one-off, unlikely to recur">
════════════════════════════════════════════════
Reply "done" to apply all | adjust any item | "skip" to discard updates and finish
```

After `done`, apply all updates and delete a completed task's handoff.
After `skip`, discard the proposed updates and delete a completed task's handoff.
Either path completes the session.

---

## Gate Reply Shortcuts

| Reply | Effect |
|---|---|
| `proceed` | Approve Gate 1, start implementing |
| `lgtm` | Approve Gate 2, continue to Phase 6 |
| `done` | Approve Gate 3, apply harness updates |
| `pause` | At any gate - write handoff artifact, stop (resumable next session) |
| `skip review` | Skip Gate 2 entirely - only for trivial/config-only changes |
| `skip reflect` | Skip Phase 6, delete the completed task handoff, and finish - not recommended, harness degrades over time |

Any other reply at a gate is treated as an adjustment to the current phase.
