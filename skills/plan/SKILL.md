---
name: plan
description: "Orient and decompose. Use at the start of any substantial task - before writing any code - to explore, understand, and plan."
---

# Plan Skill

The biggest source of wasted work is implementing the wrong thing.
This skill front-loads the thinking so implementation becomes mechanical.

## Phase 0: Check for Existing Handoff and Jira Context

Before exploring, do two things in parallel:

1. **Handoff check:** look in `/memories/repo/tasks/` for a handoff artifact matching this task.
   - If one exists: read it, confirm decisions and next step with user, resume from there. Skip phases 1-2.
   - If none exists: proceed to Phase 1.

2. **Jira ticket (if ticket ID given):** follow the ticket workflow in the root agent instructions before planning.
   Authenticate to the configured Jira (`JIRA_URL`) and Confluence (`CONFLUENCE_URL`); stop if either authentication fails.
   Retrieve the full ticket and all comments through the tracker MCP, and treat the description and comments as the authoritative definition of done.

## Phase 1: Orient

1. **Explore first.** Read the affected files and find the closest existing sibling to model after.
State what you found - do not skip directly to writing code.
2. **Define done.** Write out the final state in concrete terms: which files change, what new behavior exists, what test cases pass.
3. **Name the reference.** Explicitly state which file/function you are modeling after.
Do not design from scratch if a sibling exists.
4. **Surface blockers.** Flag any ambiguity that would change the approach.
Ask once, clearly, before proceeding - never coin-flip on a design decision.

## Phase 2: Decompose

Break the task into sub-tasks labeled by dependency type:
- **Parallel** - no shared dependency, can be done simultaneously (e.g., "write DTO" and "write interface")
- **Sequential** - strict ordering required (e.g., "IoC registration" must follow "service exists")

Rules:
- Each sub-task should be <= ~20 lines of new code. If larger, decompose further or question the design.
- For complex features or anything touching > 3 files: write out the plan (3-8 bullets) and confirm with user before implementing.
- For trivial tasks (single file, obvious change): proceed directly after a one-line statement of intent.

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
