---
name: freddy
description: Delivery-mode router. Select and apply the right harness workflow for a task, then show a concise operational skill trace. Use for ticket-backed work, shared repositories, anything Faruk labels as delivery, or when the right workflow for a substantial task is unclear.
user-invocable: true
---

# Freddy

Use this meta-skill when the right workflow is unclear or when the user wants to learn how the harness approaches real work.
It selects the smallest effective workflow, completes the request, and exposes a concise operational record of the skills and evaluations that materially affected the result.

**This router runs in delivery mode**, whatever the working directory.
Freddy invokes it for work that matters: preserve the full six-phase loop, the `/ship` gates, the tracker rules, and the adversarial review.
Do not shortcut a phase here on the grounds that the repository is personal.
For casual personal work with minimal interruption, `/faruk` is the counterpart router.

## Contract

1. Read the request for its deliverable, task shape, current state, and stated constraints.
2. Select one **execution owner** from the catalog below.
	Add supporting skills only when they change the work or its verification.
3. State the selected stack, then directly adopt and perform the execution owner's workflow.
	Load the selected owner's `SKILL.md` and apply its instructions, including when the owner is model-disabled.
	This router does not invoke another user-invocable command; it applies the loaded workflow without requiring the user to re-invoke it.
4. Follow the execution owner's interaction protocol.
	Ask a single focused question for a direct task with one blocked decision; otherwise preserve the owner's required rounds, checkpoints, and approvals.
5. Run the owner workflow's relevant validation and review before declaring completion.
	For `/ship`, trace and honor its `proceed`, `lgtm`, and `done` gates; report the task as paused at a gate until the corresponding approval arrives.
6. End with a skill evaluation: retain instructions that changed a decision or action, and propose a harness update only for a reusable gap.

This is an operational trace, not private reasoning.
It reports decisions, actions, validations, and outcomes at a useful level of detail.

## Native Skill Loading

The installed skill catalog is authoritative and is progressive-disclosure context.
Load the selected owner's `SKILL.md` when its route fires, plus a supporting skill only when it changes an action or a validation.
Do not preload the catalog, hand-count it, or read skills to decide whether they are relevant - the description in the catalog is what routing is for.

Acquire the owner through the skill loader or its registered file path. Never ask the user to paste or attach a skill body.
A one-time access confirmation for a user-level harness file is a tool security check, not a human decision gate; do not present it as one.

## Sticky Route

A `/freddy` invocation establishes the director for the current task, and the selected owner stays selected.
Follow-up questions, clarifications, status requests, gate replies, and scope adjustments inherit the active route. They do not trigger a fresh routing decision, and re-deriving the route each turn is the expensive way to reach the same answer.

Record the route in the same ledger `/ship` owns (`/memories/repo/tasks/...`) before handing control to the owner - never as a second, competing record. When the owner is `/ship`, it extends that ledger with phase and gate state.

Release the route only on `done`, `skip`, `pause`, `fork`, an explicit `reroute to <skill>`, or an explicit request to start a separate task.
If a later request changes the objective without rerouting, update `objective` and keep the owner.
`REALIGN` rereads the ledger, prints its state, and continues under the recorded director and owner.

**Mode interaction.** The route record carries `mode`. In delivery mode the release triggers are the gate replies above. In personal mode there are no gates, so the route is released when the task completes or when Faruk redirects it; `/faruk` and `/sleep` write the same record with their own mode and director, and must not be re-routed into delivery ceremony on a follow-up turn just because a ledger exists.

## Context Discipline

- Start from the nearest concrete anchor: a file, a symbol, a failing check, a test, or a call site.
- Form one falsifiable hypothesis and run one cheap check before any broad exploration.
- Read only the owning path, the nearest reference, and the validation surface the next action needs.
- After a worker wave or a phase, update the ledger and drop the raw exploration behind it.
- Prefer a handoff or fork over carrying stale history into another phase.

## Selection

Choose the primary owner by task shape, not a keyword match:

| Task shape | Execution owner | Supporting discipline when needed |
| --- | --- | --- |
| Substantial code, configuration, test, or documentation change | `/ship` | `/newfeature`, `/debugging`, `/tdd`, `/codereview`, `/closing` as applicable |
| Unexpected behavior or a failing check | `/debugging` | `/ship` for a substantial multi-phase repair |
| Fuzzy decision, proposal, or technical direction | `/grilling` | `/codebase-design` or `/domain-modeling` when the decision changes an interface or language |
| Long-running, unclear, multi-session effort | `/wayfinder` | `/to-spec` or `/to-tickets` after decisions settle |
| Agent-ready specification or delivery tickets | `/to-spec` or `/to-tickets` | `/grilling` when prerequisites remain unresolved |
| Issue or external pull request needs an owner decision | `/triage` | `/codereview` for a local diff |
| Primary-source facts or API behavior need evidence | `/research` | Apply the findings to the requested change or answer |
| Architecture visualization | `/architecture-diagram` | `/codebase-design` if the diagram exposes a seam decision |
| Throwaway experiment for a concrete design question | `/prototype` | Promote only the validated decision, not the artifact |
| Merge or rebase is already in progress | `/resolving-merge-conflicts` | Focused build, test, and review |
| Agent-facing harness document | `/writing-for-agents` | `/closing` when the change creates a reusable lesson |
| Direct answer or trivial, reversible change | No named owner | Complete it directly and validate proportionately |

When multiple rows match, prefer the owner responsible for the requested deliverable.
For a substantial file-changing task, `/ship` owns orchestration, validation, review, and reflection; a domain discipline informs the relevant phase instead of competing with it.
Do not select a skill merely because its name appears in the request.

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

## Completion Evaluation

Before finishing, evaluate the result on these axes:

1. **Task outcome:** the requested deliverable exists and meets the stated acceptance criteria.
2. **Evidence:** a focused test, build, lint, runtime check, document trace, or other discriminating check supports the result.
3. **Scope:** selected skills added value; unrelated workflows and speculative edits stayed out.
4. **Harness learning:** a durable correction is captured once in the best home; one-off execution detail is not preserved as policy. If nothing reusable emerged, record `learning: none` rather than inventing one.

Report failed or blocked checks explicitly with the next concrete recovery step.
For an owner with approval gates, the completion evaluation records the current gate and does not claim final completion early.

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
