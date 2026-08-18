---
name: freddy
description: Delivery-mode router. Select and apply the right harness workflow for a task, then show a concise operational skill trace. Use for ticket-backed work, shared repositories, anything Faruk labels as delivery, or when the right workflow for a substantial task is unclear.
user-invocable: true
---

# Freddy

`/freddy` is the delivery-mode adapter over the shared router contract in `../faruk/ROUTER-CONTRACT.md`.
Load that contract before routing.
`/faruk` and `/sleep` load the same contract and apply personal and unattended overlays, so shared routing changes belong in the shared contract rather than being duplicated here.

**This router runs in delivery mode**, whatever the working directory.
Freddy invokes it for work that matters: preserve the full six-phase loop, the `/ship` gates, the tracker rules, and the adversarial review.
Do not shortcut a phase here on the grounds that the repository is personal.
For casual personal work with minimal interruption, `/faruk` is the counterpart router.

## Delivery overlay

1. Set `mode: delivery` and `director: /freddy` in the task ledger, regardless of directory.
2. Select the smallest effective owner and apply its workflow through the shared contract.
3. Preserve the owner's interaction protocol, including required rounds, checkpoints, and approvals.
4. For `/ship`, honor its `proceed`, `lgtm`, and `done` gates and report the task as paused until the corresponding reply arrives.
5. Emit the compact operational trace below at dispatch and meaningful phase boundaries.
6. End with the shared completion evaluation plus a skill evaluation that retains only instructions that changed a decision or action.

This is an operational trace, not private reasoning.
It reports decisions, actions, validations, and outcomes at a useful level of detail.

## Shared dispatch

The shared contract owns native skill loading, route continuity, context discipline, owner selection, and completion evaluation.
Read `../faruk/ROUTER-CONTRACT.md` when any of those rules are needed rather than maintaining a second copy here.

## Skill Trace

At the start and at each meaningful phase boundary, emit a compact trace like:

```text
[dispatch] task: <plain-language deliverable>
[skill-eval] selected: /ship - <why it owns the work>
[skill-eval] supporting: /writing-for-agents - <specific contribution>
[apply] /plan - <evidence gathered and local plan>
[gate] /ship plan - waiting for "proceed"
[apply] /implement - <change made after "proceed">
[eval] <test, build, review, or evidence check> - <outcome>
[eval] /codereview - <finding summary>
[gate] /ship review - waiting for "lgtm"
[apply] /closing - <reflection prepared after "lgtm">
[gate] /ship reflect - waiting for "done"
[interaction] /grilling round <N> - waiting for <required response>
[skill-eval] retained: <skills that changed the work>; skipped: <nearby skill and reason>
```

Omit no-op steps and hidden reasoning.
When no named skill applies, say so plainly and show the direct validation instead.
When an owner requires user interaction, trace its owner, current round, and required response, then resume its workflow after that response.

## Delivery completion

The shared contract owns the outcome, evidence, and scope checks.
Delivery mode additionally records skill learning once in the best durable home, or records `learning: none` when no reusable lesson emerged.
Report failed or blocked checks explicitly with the next concrete recovery step.
For an owner with approval gates, do not claim final completion before the corresponding reply.

## Core loop: idea → shipped

1. **`/grilling`** (aka `/grill-me`, `/grill-with-docs` — same interview primitive; this harness has no separate stateful/stateless variant) — sharpen a fuzzy idea, plan, or decision by relentless interview before committing to an approach.
2. **`/plan`** — orient and decompose before writing any code. Use at the start of any substantial task.
3. **`/tdd`** — build a concrete piece of behavior test-first, red-green-refactor.
4. **`/codereview`** — grumpy-senior-engineer review of a diff/PR before it merges.
5. **`/ship`** — run the full Plan → Implement → Synthesize → Review → Reflect loop end-to-end in one guided session. Ticket-backed work also lives here: Jira/Confluence routing (a self-hosted Jira via the Jira Data Center MCP tools, Confluence via the Atlassian MCP server) is handled inside `/ship`'s ticket-backed flow, not by this router.
6. **`/closing`** — end-of-session knowledge capture. Run after any substantial session so lessons survive into the next one.

## Planning and coordination

- **`/wayfinder`** — map a large, unclear multi-session effort as a sequence of decision tickets, frontiers, and explicitly scoped fog.
- **`/to-spec`** — turn settled conversation context into an agent-ready specification before publishing it to the configured tracker.
- **`/to-tickets`** — decompose a plan or spec into independently verifiable vertical slices with real blocking edges.
- **`/triage`** — evaluate an issue or external PR, verify its claim, and recommend its next state before any tracker mutation.

## Building features

- **`/newfeature`** — building a new endpoint, service, or UI feature; scope-and-design-first workflow tied to the target repo's existing patterns.

## Diagnosing problems

- **`/debugging`** — systematic workflow for investigating a bug or unexpected behavior: reproduce first, build a feedback loop, then fix.
- **`/resolving-merge-conflicts`** — you're already mid-merge or mid-rebase with conflict markers and need to resolve them hunk by hunk.

## Vocabulary / reference

Pull these in as needed to inform other work, not as flow steps of their own:

- **`/codebase-design`** — shape a module's interface or run a scoped architecture review for deepening opportunities.
- **`/domain-modeling`** — pin down or sharpen domain terminology, resolve an overloaded term, record an architectural decision.
- **`/writing-for-agents`** — writing or editing a `SKILL.md`, instructions file, prompt file, `AGENTS.md`, or task handoff.

## Standalone

- **`/research`** — investigate a question against primary sources and capture substantial findings as a cited Markdown file when that record will be useful later.
- **`/architecture-diagram`** — produce a Mermaid diagram to visualize a real system or codebase.
- **`/prototype`** — create a marked throwaway logic or UI artifact when a concrete design question needs evidence.
- **`/to-questionnaire`** — produce an asynchronous discovery questionnaire for facts or decisions another person must provide.

## Rule

Select the smallest effective skill stack, apply it, and finish the requested work.
