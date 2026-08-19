# Shared Router Contract

This is the canonical dispatch contract shared by `/faruk`, `/freddy`, and `/sleep`.
All three routers load it before applying their mode-specific overlay.
Put behavior that should remain identical in this file.
Keep personal posture in `SKILL.md` beside this file, delivery posture in `../freddy/SKILL.md`, and unattended posture in `../sleep/SKILL.md`.

## Common contract

1. Read the request for its deliverable, task shape, current state, and constraints.
2. Select one execution owner by task shape, using the catalog below.
3. Load the selected owner's `SKILL.md` and apply its workflow directly.
   The user does not need to re-invoke the selected skill.
4. Apply the selected owner's validation, safety rules, and interaction protocol.
   A mode overlay may change human approval behavior, but it may not remove correctness checks or persistence requirements.
5. Record the director, mode, owner, objective, acceptance condition, next action, and any write-ahead intent in `/memories/repo/tasks/...` before risky work.
6. Keep the route sticky across follow-ups, clarifications, status requests, and scope adjustments.
   Update the objective when needed instead of re-routing ordinary follow-up work.
7. Refresh the ledger after decisions, risky operations, validation, and phase transitions.
8. Run the cheapest discriminating validation that supports the claimed result.
9. Evaluate task outcome, evidence, scope, and reusable harness learning before reporting completion.

## Native skill loading

The installed skill catalog is authoritative and progressive-disclosure context.
Load the selected owner when its route fires, plus a supporting skill only when it changes the work or its verification.
Do not invoke another user-invocable router as a nested step.

## Sticky route

The ledger carries `director: /freddy | /faruk`, `mode: delivery | personal`, and the selected `owner`.
`REALIGN` rereads the ledger and continues under its recorded director and owner without re-planning or re-routing.
Release the route only when the task completes, pauses, forks, explicitly reroutes, or starts a separate task.
In personal mode, an existing ledger must not pull a follow-up into delivery gates.

## Context discipline

- Start from the nearest concrete anchor: a file, symbol, failing check, test, or call site.
- Form one falsifiable hypothesis and run one cheap check before broad exploration.
- Read the owning path, nearest reference, and validation surface needed for the next action.
- After a worker wave or phase, keep the durable state in the ledger rather than carrying raw exploration forward.

## Selection

Choose the primary owner by task shape, not by a keyword match:

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
For substantial file-changing work, `/ship` owns orchestration, validation, review, and reflection.

## Completion evaluation

Before finishing, confirm that the requested deliverable exists, the evidence supports it, unrelated scope stayed out, and any reusable harness lesson has one durable home.
Report failed or blocked checks with the next concrete recovery step.
