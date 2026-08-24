# Context, Subagents, and Self-Improvement

Read this before spawning a subagent, before deciding what to load into context, and when a session produced a reusable lesson.

When trade-offs arise, prefer lower token cost, then less human effort, then faster execution.
If the user alone has the answer to a requirement, business decision, or stakeholder context, ask once.
If the answer is available in code, read the code instead of asking.
State grounded assumptions explicitly instead of asking speculative implementation questions.
Ask at most one question per checkpoint; when several unknowns exist, ask only the single most blocking one.
Never ask how to implement something - that is the agent's job, and the question spends a checkpoint on nothing.

The installed skill catalog is progressive-disclosure context: load a skill's body when its route fires, not to decide whether it is relevant.
Acquire it through the skill loader or its registered path rather than asking for it to be pasted in, and treat a one-time file-access confirmation as a tool security check rather than a decision gate.

A selected route is sticky. Once a router has chosen an owner for a task, follow-up questions, clarifications, status requests, and scope adjustments inherit that route instead of re-deriving it, and the choice is recorded in the task ledger `/ship` owns rather than in a second record. The canonical shared router contract is `skills/faruk/ROUTER-CONTRACT.md`; both `/faruk` and `/freddy` load it, while their `SKILL.md` files contain only posture-specific overlays. See `skills/freddy/SKILL.md` for the delivery overlay and `skills/faruk/SKILL.md` for the personal overlay.

Task state is written ahead of risk, not after success. Before a risky operation, the ledger records what is about to be attempted, the half-finished state it could leave, and a runnable command a successor uses to tell which happened. A session killed on a usage limit never reaches its end-of-run capture, so anything written only at the end is written only when it was not needed.

Load only files that will be changed or directly referenced.
Prefer targeted reads.
Give subagents only the assigned sub-task, handoff artifact, and reference path.
A subagent inherits none of the parent conversation and does not reliably inherit these instructions - verified on 2026-08-12, where two probe agents reported no prior messages and no visible `CLAUDE.md`/`AGENTS.md` content.
So every subagent prompt must open with `First read ~/Repo/agent-agnostic-harness/instructions/AGENTS.md and follow it.` Without that line the worker writes em dashes, commits to a default branch, and skips the browser-render rule, and the parent has no way to tell it happened.
The same prompt must also carry the persistence rule below in full, because a subagent that reports a blocker only in its final text has not persisted it: the orchestrator reads that text, the dashboard never does.
Treat each completed phase handoff as the context summary; do not carry unnecessary history forward.

The portable project model is documented in `docs/PROJECT-OPERATING-MODE.md`.
Use one `00 Control Center` chat for global routing, one host Project per business or durable domain, and one `00 Main - Coordination` chat plus one outcome chat per distinct result.
The repository, queue, tracker, and PR remain the source of truth across ChatGPT, Claude Code, Codex, and other hosts.
Default to one agent and one active writing agent per worktree; spawn only for independently bounded complex work or an explicit request, and cap justified parallel work at three agents.

**Agent-agnostic operation is the default.** Keep durable instructions, decisions, workflows, and source-of-truth records in repository files or other portable harness artifacts, not only in a host-specific memory, Project, or chat. Codex, Claude Code, ChatGPT, and other hosts must be able to resume the same work from the repository, queue, tracker, and pull request. When a host-specific feature improves convenience, treat it as an optional view over the portable records rather than the only place the context exists.

## Self-Improvement

Update the relevant native instruction or skill immediately when the user corrects style, architecture, or approach; when a task reveals missing reusable context; or when a skill is ambiguous.

Treat Faruk's question as a finding in its own right whenever it surfaces something you had not thought to check.
A defect he had to ask about is two defects: the thing itself, and the fact that nothing in the harness would have caught it.
Fix both, in the same turn, and then carry on with the task rather than stopping to report the improvement.
The rule holds whether or not the answer turns out to be bad news - "is X working?" coming back clean still means nothing was watching X.
It does not apply to questions that merely request information you correctly judged out of scope; the trigger is a gap in what you checked, not a gap in what you said.
Prefer a check that runs over a sentence that advises: the reason the question was needed is that no mechanism asked it.
Worked example: an audit reported the skills junction healthy on the strength of its target path, and `/freddy` was unreachable at that moment in the running session.
Only "can you confirm the skill is working?" found it.
The artifact-versus-consumer rule in General Guidelines exists because of that question, not because of the outage.

- **Maximize queue leverage before choosing work.** Identify unfinished items an answer or completed change would enable, record `Depends on: <exact queue item title>` on each dependent entry, and choose the highest-fan-out actionable item unless Faruk explicitly names another.

At the end of a substantial task, invoke `/closing` to capture remaining durable signal.
In personal mode, run `/closing` only when the session actually produced a reusable lesson, not as a routine step.
