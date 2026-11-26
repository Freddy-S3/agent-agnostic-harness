# Harness Guide

This is a personal, user-level agent harness, installed into whichever host you are using (Copilot, Claude Code, or Codex — see `README.md`).
It gives the agent reusable workflows for planning, implementation, review, research, and reflection.
The harness is separate from application code: it guides the agent but does not change runtime behavior by itself.

Agent-agnostic operation is the default: repository files, queue, tracker, and pull requests remain the source of truth so work can move between Codex and Claude Code without losing context.

## Integration setup and delivery

Use `/connect-workspace` when you need an evidence-based readiness checklist in chat.
It distinguishes installation, registration, configuration, authentication, scoped read evidence, freshness, optional skips, and run authorization.
Use `/start-ticket` to resolve a ticket into a verified isolated branch/worktree receipt while preserving unrelated work.
Use `/deploy-nonprod` for a provider-neutral read-only plan, then an explicitly authorized sandbox run with bounded timeout reconciliation and read-back.
Use `/interview-readiness` before a practical coding assessment to verify the runtime, IDE, AI tool, test command, server, clarification-first plan, visible parallel work, and evidence-backed wrap-up.

The [integration contracts](docs/INTEGRATION-CONTRACTS.md) keep host and provider details out of the portable workflows.
The [onboarding guide](docs/INTEGRATION-ONBOARDING.md) contains the chat format and the offline synthetic demo.
Run `node tools/integration-demo/demo.mjs` to show the demo and `node --test tools/integration-demo/*.test.mjs` to validate its failure, resume, authorization, and duplicate-prevention paths.

## Start Here

Use `/ship <task>` for a substantial change.
For example:

```text
/ship Add a status endpoint to the API for asynchronous export jobs
```

`/ship` runs the complete workflow:

1. Select a fast, standard, or deep planning path and orient against nearby code.
2. Implement in dependency order.
3. Build and run focused validation.
4. Review the complete change adversarially.
5. Capture durable lessons for later work.

For a nontrivial task, the checkpoints are:

| Gate    | Reply     | Meaning                                                                           |
| ------- | --------- | --------------------------------------------------------------------------------- |
| Plan    | `proceed` | Approve the proposed scope and implementation plan.                               |
| Review  | `lgtm`    | Accept a zero-blocker review and continue to reflection.                          |
| Reflect | `done`    | Apply proposed harness updates and finish.                                        |

Planning defaults to auto mode with no time limit, and Ship starts without asking you to confirm them.
Pass `--plan-mode fast|standard|deep` or `--plan-within <duration>` only when you want to override those defaults.
Use `/ship --plan-within 5m <task>` when a professional task needs an explicit planning window; the plan reports whether the window was met or expired without weakening required checks.
Gate 1 reports compact preflight/planning elapsed time and worker counts.
For a gate-free personal run, measured elapsed time and any repeated environment failures are retained in the task closeout when the run was unusually slow.
At Gate 1, reply `proceed + context` when the repository should also receive or update `docs/PROJECT-CONTEXT.md` for faster future sessions.
Ship carries a compact phase packet from planning through review: acceptance criteria, changed paths, risk markers, validation lanes, evidence, and open questions.
Independent validation lanes may run together, while shared-file edits and synthesis stay single-owner.
After a failure, Ship retries only the invalidated lane and reuses evidence that still matches the settled worktree.
These accelerators apply in both modes; planning windows remain optional and never lower the professional quality floor.
For UI or workflow-visible work, Ship carries a compact verification map from user action to expected state and proof artifact.
Runtime verification uses `/browsertest` even when a project has no pre-existing E2E suite; a build or markup inspection alone is not UI evidence.
In professional `/ship` runs, Gate 2 keeps a runnable local surface alive and includes a verified `Hand-test URL` or `Hand-test command` before waiting for `lgtm`.
If no runnable surface exists or startup is blocked, Gate 2 states that explicitly instead of presenting automated results as a substitute for hand testing.
Professional-mode pull request checks opt into an auto-merge guard before human review; personal-mode pull request work leaves GitHub auto-merge available.
Every Ship gate is rendered in full with its concrete fields, evidence, findings, and reply options; summaries may accompany a gate but never replace it.
When a recurring correction is mechanically checkable, `/closing` promotes it to a test, lint rule, validator, or API constraint instead of growing prose by default.

Use `fork` at a gate to start a fresh chat from a saved handoff when the conversation becomes long.
Use `pause` to save the task for a later session.
Ticket-backed handoffs use `<ticket-id>-<slug>.md`; ticketless handoffs use `adhoc-<slug>.md` under `/memories/repo/tasks/`.

## Project and chat operating model

Use one lightweight `00 Control Center` chat for global routing and queue status.
Use one host Project per business or durable domain, with `00 Main - Coordination` as its
short project-level summary and one new chat for each distinct outcome.
Keep the repository, queue, tracker, and pull request as the portable source of truth.
The host Project is useful context, but its account-level chats are not synchronized with
Claude Code, Codex, or another host by this repository.

The current execution default is one agent and one active writing agent per worktree.
Spawn only for independently bounded complex work or an explicit request, and cap justified
parallel work at three agents until the policy is changed.

Keep no more than three active folders for one project family: one canonical checkout, one
pinned service checkout, and one active task checkout. `tools/worktree-add.ps1` enforces the
limit before creation, while claims and the pre-commit hook catch bypasses. Archives and
runtime folders are excluded by the shared `tools/folder-hygiene.psm1` classifier.
Real dirty work cannot pass closeout: `tools/check-dirty-worktrees.ps1` reports unclassified
changes, and claim release refuses to release a tree until the work is committed, stashed with
a handoff, or explicitly released with a recorded exception.
The full setup, copy-paste Project instructions, and reinstall checkpoint live in
[`docs/PROJECT-OPERATING-MODE.md`](docs/PROJECT-OPERATING-MODE.md).

If you do not know which command fits, invoke `/freddy` and describe the task.
It selects the smallest effective skill stack, completes the task, and shows the operational skill trace as it works.
It loads and applies the selected execution owner's `SKILL.md`, including a model-disabled owner, without requiring a second slash command.

For hands-off personal work, use `/faruk`.
It uses the same shared routing contract, owner loading, task ledger, validation floor, and persistence rules as `/freddy`, but bypasses delivery approval gates and operational traces.
Shared routing behavior belongs in `skills/faruk/ROUTER-CONTRACT.md`, so changes there carry over to both routers.

### Skill Trace

`/freddy` makes harness behavior inspectable without exposing private reasoning.
The trace shows the selected execution owner, supporting skills that changed the work, and the focused evaluations that support completion:

```text
[dispatch] task: Add coverage for an audio status service
[skill-eval] selected: /ship - substantial file-changing work
[skill-eval] supporting: /tdd - behavior needs a red-green test loop
[parallel] Wave 1 - code map | test path | project context
[parallel] Wave 1 complete - all reports returned
[apply] /plan - identified the service and closest test sibling
[gate] /ship plan - waiting for "proceed"
[apply] /implement - added coverage after "proceed"
[eval] focused test - passed
[eval] build - passed
[eval] /codereview - BLOCKs: 0
[gate] /ship review - waiting for "lgtm"
[apply] /closing - reflection prepared after "lgtm"
[gate] /ship reflect - waiting for "done"
```

The trace is deliberately compact.
It records observable decisions and checks, not hidden reasoning or no-op workflow steps.

### Dispatcher Checks

Validate both routers against these scenarios whenever the shared routing contract changes:

| Request                                              | Expected owner and trace                                                                                                                                                                | Completion condition                                                                                                                                                 |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `What does this configuration flag do?`              | No named owner; `[eval]` cites the focused code or documentation evidence.                                                                                                              | The answer is grounded in the relevant source.                                                                                                                       |
| `Turn these settled decisions into a specification.` | `/to-spec`; the trace confirms that `/freddy` loaded the selected model-disabled owner's `SKILL.md` before applying it.                                                                 | The requested agent-ready specification is delivered.                                                                                                                |
| `Grill this migration proposal.`                     | `/grilling`; `[interaction] /grilling round 1` waits for the required answers, `[apply]` records their use, then `[interaction] /grilling round 2` waits for its next required answers. | The design tree has no unresolved decision frontier.                                                                                                                 |
| `Add coverage for an audio status service.`          | `/ship` with `/tdd` when a red-green loop changes the implementation; the trace records its plan, review, and reflection gates.                                                          | The model waits for the required `proceed`, `lgtm`, and `done` approvals before advancing.                              |
| `Work on my personal site while I am busy.`         | `/faruk`; it loads the shared contract, selects an owner, records `mode: personal`, and proceeds without a delivery gate or operational trace.                                        | The work completes with the owner's validation and the personal report format.                                           |

## Skill Map

| Situation                                                                | Command                      | What it does                                                                                                      |
| ------------------------------------------------------------------------ | ---------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| You want the harness to choose, explain, and execute the right workflow  | `/freddy`                    | Selects the smallest effective skill stack, completes the task, and reports a compact skill/evaluation trace.     |
| You want the same routing with minimal interruption for personal work   | `/faruk`                     | Applies the shared router contract in personal mode, bypassing delivery gates while preserving owner workflows and validation. |
| A substantial feature, fix, refactor, or configuration change            | `/ship`                      | Runs the six-phase delivery loop with planning, validation, review, and reflection.                               |
| A task needs a design and file-level plan                                | `/plan`                      | Finds the owning code, a reference sibling, and a dependency-ordered plan.                                        |
| A large, unclear effort spans several agent sessions                     | `/wayfinder`                 | Maps decision tickets, the current frontier, unresolved fog, and explicit scope boundaries.                       |
| Settled discussion needs an agent-ready specification                    | `/to-spec`                   | Drafts a behavior- and seam-oriented specification before a confirmed tracker publish.                            |
| A plan or specification needs delivery tickets                           | `/to-tickets`                | Produces reviewable tracer-bullet vertical slices with genuine blocking edges.                                    |
| An issue or external pull request needs an owner decision                | `/triage`                    | Verifies the claim, checks redundancy, and recommends a category and next state before changing the tracker.      |
| A new endpoint, service, or UI feature                                   | `/newfeature`                | Applies implementation order, dependency registration, configuration, and testing rules.                          |
| An unexpected bug or error                                               | `/debugging`                 | Reproduces first, builds a tight failing signal, ranks hypotheses, instruments safely, then fixes the root cause. |
| Test-first work or an integration-test decision                          | `/tdd`                       | Uses red-green vertical slices, agreed seams, independent test oracles, and disciplined mocks.                    |
| A diff or pull request needs scrutiny                                    | `/codereview`                | Reviews correctness, failure handling, security, test quality, conventions, and scope fidelity.                   |
| A change touches HTML, CSS, or client-side JS                            | `/browsertest`               | Renders the page in a real browser and asserts content, interaction, contrast, and responsive overflow.           |
| A page is about to ship, or a rendered defect reached a real visitor     | `/polish`                    | Sweeps the whole surface for controls that do nothing, elements that collide, links to nowhere, and forms with no backend. |
| A branch has one or more commits and no pull request                     | `/pr`                        | Opens the PR, or pushes to the existing one and updates its body. A branch should never sit without an open PR.   |
| A plan, idea, or trade-off is still fuzzy                                | `/grilling`                  | Interviews you in rounds until the decision tree has no unresolved frontier.                                      |
| You are already resolving a merge or rebase conflict                     | `/resolving-merge-conflicts` | Resolves a conflict hunk by hunk without blindly committing or continuing Git operations.                         |
| A module interface or test seam needs shaping, or needs deepening review | `/codebase-design`           | Supplies deep-module vocabulary and ranks scoped architecture-review candidates before interface design.          |
| Terms are overloaded or a decision needs a durable record                | `/domain-modeling`           | Maintains `CONTEXT.md` vocabulary and offers ADRs only for consequential trade-offs.                              |
| Facts need primary-source verification                                   | `/research`                  | Builds a cited evidence record using the tools that are available in the current environment.                     |
| A design question needs a concrete, throwaway experiment                 | `/prototype`                 | Builds a marked logic or UI artifact that answers one question and keeps only its validated decision.             |
| Another person holds missing facts or decisions                          | `/to-questionnaire`          | Produces a focused asynchronous discovery questionnaire without inventing stakeholder knowledge.                  |
| You are editing skills, instructions, prompts, agents, or handoffs       | `/writing-for-agents`        | Keeps agent-facing documents small, explicit, composable, and mechanically valid.                                 |
| A substantial session is finishing outside `/ship`                       | `/closing`                   | Captures only reusable lessons in the best permanent location.                                                    |

`/grill-me` and `/grill-with-docs` are aliases for the same grilling discipline.

## Typical Paths

### New feature

```text
/ship Add a polling endpoint for a new asynchronous operation
```

The harness identifies whether a Jira key is present.
For ticket-backed work, it authenticates to the configured Jira and Confluence, reads the issue and every comment, and treats them as acceptance criteria.
For ticketless work, it stays local and does not make Jira access a blocker.

### Bug fix

```text
/debugging The results panel shows an empty list after a failed retry
```

Expect the agent to reproduce the behavior, establish a deterministic red check where practical, rank competing explanations, and remove any temporary `[DEBUG-...]` instrumentation after verification.

### Small design decision

```text
/grilling Should job status polling live in the shared store or the service layer?
```

The agent asks only questions whose prerequisites are already settled, and offers a recommendation with each question.

### Uncertain where to begin

```text
/freddy I need to add coverage for a service but I am unsure whether to start with TDD or a design discussion
```

It selects the workflow, explains the relevant skill stack, and adds the coverage rather than stopping at a recommendation.

## Guardrails

- Downstream failures are logged and rethrown; a successful response with silent empty data is not an acceptable fallback.
- Debug logs use safe metadata only: no credentials, authorization headers, cookies, tokens, passwords, API keys, or personal data.
- A self-hosted Jira uses the Jira Data Center MCP route; Confluence and Atlassian Cloud use the Atlassian MCP route.
- Work in an area covered by a scoped instructions file reads that file's path map and component-ownership rules before broad exploration.
- The rulebook is split for progressive disclosure. `instructions/AGENTS.md` is the always-loaded core and carries only what applies to essentially every task; conditional detail lives in `instructions/rules/` and is opened by absolute path when a trigger row in the core fires. Nothing loads it for you on Codex, which has no import directive, so treat the trigger table as an instruction to read rather than an index to skim. `tools/check-rule-triggers.ps1` fails the install if a rule file has no trigger, a reference dangles, or the core regrows past its ceiling.

## Tools

- `tools/queue-dashboard` - `node tools/queue-dashboard/server.mjs` serves a live view of every queue item waiting on Faruk, with an answer box per blocker.
  Answers are written back into the item as a `DECIDED` line and recorded in `TRIAGE-<date>.md`, so a decision never needs hand-carrying into the queue afterwards.
  It reads disk on every request rather than publishing a snapshot; see that directory's README for the write-back guards.
  It reads `QUEUE-PC.md` and `QUEUE-PHONE.md` and no other file - not `status/TRACKER.md`, not session transcripts. That is why `/closing`, `/faruk`, `/sleep`, and `/queue` all require writing open decisions into a queue file before a session ends: an empty dashboard means nothing was written, not that nothing is waiting.
- `tools/converge.ps1` - the bounded convergence step for a `/queue` item that carries a `Done when:` command.
  It runs the predicate, writes `Iterations:` to the queue file before the next attempt rather than after a success, and on the cap sets the item `blocked` with the check's actual failing output and a one-click `Options:` list.
  Exit codes are the contract: 0 converged or no predicate, 6 re-enter the brief with a fresh context window, 7 capped, 4 the `Done when:` is prose rather than a command, 5 a peer wrote the queue file mid-step.
  `tools/tests/converge.tests.ps1` drives every one of those states by construction, including a predicate that never passes and a predicate that is prose pretending to be a check.
- `tools/queue-runner.ps1` - the one-item software-factory boundary.
  It selects one routed repository, writes a checkpoint before risky work, resumes an interrupted item, and requires bounded verification plus a PR handoff before marking code done.
  `tools/tests/queue-runner.tests.ps1` constructs the fan-out selection, pause/resume, route refusal, and finish-gate cases.
- `tools/check-skill-caches.ps1` - enumerates every cached, copied, or linked view of the skills and instructions and fails loudly on drift.
  Junctions read live and self-heal; copies do not, and a junction into a worktree left on a merged branch resolves perfectly while serving code that no longer exists - both survive an install that reports success.
  Classes A-D are checked on this machine and `-Fix` regenerates what this repo generates. Class E is the Cowork cache under `%APPDATA%\Claude\local-agent-mode-sessions\skills-plugin\`, which does refresh - but from the claude.ai account rather than from this repository, so a skill that went stale in the account is faithfully re-materialised stale. It is checked and reported, never auto-fixed, because a local rewrite is overwritten on the next materialisation.
  `install.ps1` runs it with `-Fix` at the end of every install.
- Clickable skill cards - `instructions/WIDGETS.md` defines how `/status-report` and `/queue` render their reports as cards inside the Claude desktop app, with buttons for approve/reject and run/skip/requeue.

  These two overlap deliberately and should not be merged.
  The dashboard is a separate long-lived surface Faruk opens on purpose to answer a backlog of blockers; the cards are inline in whichever reply already told him about them, and vanish with it.
  A card's button only ever composes a chat message, so the widget holds no state and can take no action on its own - the write-back guards belong to the dashboard alone.
  Keep the action vocabulary in `WIDGETS.md` as the single list of what any button may send.

## Harness Boundaries

The harness excludes host plugin manifests, automatic commits, and Bash-only secret wizards; host-specific wiring is generated at install time by `install.ps1` rather than kept in the skills.
Its skills provide feedback-loop-first debugging, independent Standards and Spec-fidelity review, recipient-gap questionnaire design, and test-seam-based feature implementation.
The generic implementation discipline is folded into `/newfeature` rather than creating a second overlapping owner.
The installed skills preserve explicit confirmation before tracker mutations and self-contained Markdown with local supporting references.

The native harness is self-contained; its commands rely only on native skills and local supporting references.

## Keeping It Healthy

- Prefer `/freddy` when choosing among user-invoked skills becomes uncertain.
- Use `/closing` after substantial non-`/ship` sessions so a real reusable lesson is captured once, in the right home.
- When Faruk's question surfaces something you had not thought to check, fix the harness gap in the same turn and keep going.
  The question is the signal that no mechanism was asking it; a clean answer counts too.
- Keep each skill focused on one discipline.
  Merge overlapping skills instead of adding duplicate rules in multiple places.
- When updating a skill or instruction, use `/writing-for-agents` and validate both its mechanics and its actual behavior.
