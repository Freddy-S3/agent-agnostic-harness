---
name: plan
description: "Orient and decompose. Use at the start of any substantial task - before writing any code - to explore, understand, and plan."
user-invocable: true
---

# Plan Skill

The biggest source of wasted work is implementing the wrong thing.
This skill front-loads the thinking so implementation becomes mechanical.

## Invocation contract

When `/plan` is invoked by `/ship`, `/ship` supplies the preflight packet containing the handoff result, ticket result, branch/worktree readiness, scoped instructions, project-context findings, planning mode, and optional planning window.
Start at the selected planning mode and do not repeat the handoff, Jira, branch, or project-context checks.
Return a compact implementation packet containing acceptance criteria, touched paths, risk markers, validation lanes, settled decisions, and open questions so later phases can reuse evidence without repeating discovery.
When invoked by `/ship`, treat Ship Gate 1 as the plan confirmation and do not add a second approval prompt.
When invoked directly, run Phase 0 as written below.

## Phase 0: Check for Existing Handoff and Jira Context

Before exploring, do two things in parallel:

1. **Handoff check:** look in `/memories/repo/tasks/` for a handoff artifact matching this task.
   - If one exists: read it, confirm decisions and next step with user, resume from there. Skip phases 1-2.
   - If none exists: proceed to Phase 1.

2. **Jira ticket (if ticket ID given):** follow the ticket workflow in the root agent instructions before planning.
   Authenticate to the configured Jira (`JIRA_URL`) and Confluence (`CONFLUENCE_URL`); stop if either authentication fails.
   Retrieve the full ticket and all comments through the tracker MCP, and treat the description and comments as the authoritative definition of done.

## Phase 1: Orient

When the selected mode is **auto**, choose the smallest mode below that preserves correctness.
When the caller explicitly selected Fast, Standard, or Deep, honor that selection unless new evidence makes it unsafe, then promote to the next mode and explain why.

Select the smallest mode that preserves correctness:

- **Fast** - one file or an obvious, low-risk docs/config/test change with no external service, auth, migration, or ambiguous behavior.
  Read the affected area, define the observable done condition, and surface blockers.
  Skip broad sibling searches and dependency decomposition unless the scope expands.
- **Standard** - a normal feature or fix touching up to three files.
  Read the affected area, one closest sibling, and the nearest validation path, then produce a short dependency-ordered plan.
- **Deep** - more than three files, external integrations, auth, migrations, ambiguous requirements, or high failure cost.
  Use the full exploration and decomposition workflow.

The fast path is a scope gate, not a lower quality bar.
Promote to Standard or Deep when new evidence breaks its assumptions.
Stop orientation when the completion predicate is satisfied: affected files and why, observable done condition, reference or an explicit reason none exists, and blockers.

1. **Explore first.** Read the affected files and state what you found.
For Standard and Deep, find the closest existing sibling to model after.
For Fast, inspect a sibling only when the pattern is not already obvious from the affected area.
Do not skip directly to writing code.
2. **Define done.** Write out the final state in concrete terms: which files change, what new behavior exists, what test cases pass.
3. **Name the reference.** Explicitly state which file/function you are modeling after.
Do not design from scratch if a sibling exists.
4. **Surface blockers.** Flag any ambiguity that would change the approach.
Ask once, clearly, before proceeding - never coin-flip on a design decision.

## Phase 2: Decompose

For Standard and Deep work, fan out independent read-only exploration when it materially reduces wall time.
Typical workers are code-map, test/validation, project-context, and ticket retrieval when a key is supplied.
Use no more than three workers in one wave, start the wave together, wait for every report, and serialize all writes.
Emit compact start and completion status; if the host cannot delegate, state `Parallel delegation unavailable` and continue sequentially.
Do not start a wave when worker startup and merge overhead are likely to exceed the saved time.

Break Standard and Deep work into sub-tasks labeled by dependency type:
- **Parallel** - no shared dependency, can be done simultaneously (e.g., "write DTO" and "write interface")
- **Sequential** - strict ordering required (e.g., "IoC registration" must follow "service exists")

Rules:
- Each sub-task should be <= ~20 lines of new code. If larger, decompose further or question the design.
- For complex features or anything touching > 3 files: write out the plan (3-8 bullets) and confirm with user before implementing.
- For trivial tasks (single file, obvious change): proceed directly after a one-line statement of intent.

Fast mode uses the one-line intent and completion predicate rather than a dependency graph.
Promote it when the affected file count, risk, or ambiguity grows.

If the caller supplies a planning window, honor it as an explicit time target without skipping required security, ticket, or scoped-instruction checks.
When the window expires, stop new discovery, report the evidence gaps, and wait for `continue planning` or the user's adjustment.

Include the risk markers and validation lanes in the plan so implementation, synthesis, and review can run only the work that the settled scope invalidates.

## Phase 3: Gate

Before leaving Plan phase, confirm:
- [ ] You know which files are changing and why
- [ ] You have a reference implementation to follow
- [ ] All blockers are resolved or explicitly parked
- [ ] The user has agreed to the plan if scope is non-trivial

## When to Use This Skill

Use it when the task:
- Touches more than 2 files
- Involves a pattern not yet in the codebase
- Integrates with an external service (ARC, Bedrock, ElevenLabs, Polly, etc.)
- Is ambiguous about scope or expected behavior
- Would be hard to reverse if the wrong approach is taken
