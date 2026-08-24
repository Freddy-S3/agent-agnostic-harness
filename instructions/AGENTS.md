# Freddy's Agent Instructions

These common instructions apply across Freddy's workspaces.

This file is the always-loaded core. It is deliberately small: context spent on rules that do not
apply to the current task is context not spent on the task, and a long rulebook dilutes attention as
surely as it costs tokens. Conditional detail lives in `instructions/rules/` and is loaded only when
its trigger fires.

## Rule files - read on trigger

Codex has no import directive, so nothing below is loaded for you. Open the file yourself, by path,
at the moment its trigger fires. Paths are absolute so they resolve from any host and any directory.

| Read this file | Before you |
| --- | --- |
| `~/Repo/agent-agnostic-harness/instructions/rules/queue-and-persistence.md` | Write or update any queue item, blocked decision, or `status/TRACKER.md` entry |
| `~/Repo/agent-agnostic-harness/instructions/rules/web-ui.md` | Report any HTML, CSS, or client-side JS change as done, or ship any page |
| `~/Repo/agent-agnostic-harness/instructions/rules/renames.md` | Rename any repo, directory, package, module, or URL |
| `~/Repo/agent-agnostic-harness/instructions/rules/harness-conventions.md` | Add, edit, or remove a skill, instruction file, installer path, or enforcing mechanism |
| `~/Repo/agent-agnostic-harness/instructions/rules/new-projects.md` | Act on a new project idea, or split mixed harness and product work |
| `~/Repo/agent-agnostic-harness/instructions/rules/context-and-subagents.md` | Spawn a subagent, or decide what to load into context |
| `~/Repo/agent-agnostic-harness/instructions/rules/tickets-and-review.md` | Start Jira or Confluence backed work, or review a pull request |
| `~/Repo/agent-agnostic-harness/instructions/rules/agentic-loop.md` | Run the six-phase loop explicitly in delivery mode |
| `~/Repo/agent-agnostic-harness/instructions/rules/incident-record.md` | Argue an exception to any core rule, or need the full incident behind a one-clause tag below |
| `~/Repo/agent-agnostic-harness/instructions/WIDGETS.md` | Add or change a clickable card button in any skill |

## Operating Modes

Pick the mode before picking a workflow.

**Personal mode is the default**, and `/faruk` is its router.
It applies to everything under `C:\Users\Faruk\Repo` and to any personal project or personal website.
Optimize for throughput: act instead of asking, choose a sensible default instead of presenting options, and skip approval gates.
Breaking things is acceptable; the work is committed to GitHub and recoverable.
Verify with the cheapest check that would actually catch the problem, and prefer running the thing over reasoning about it.
Do not open a ceremony the task does not need.

**Delivery mode** is the enterprise-grade posture, and `/freddy` is its router.
It applies to ticket-backed work, shared repositories, and anything Freddy explicitly labels as delivery or invokes `/freddy` for.
It restores the full six-phase loop, the `/ship` gates, the tracker rules below, and the adversarial diff review.

`/sleep` is personal mode with the interruption budget at zero, for unattended overnight runs.
It never asks anything and trades approval gates for recoverability; see its skill for the rules.

`/queue` is the backlog for ideas too large to run inline: drop an entry into the PC or phone queue (see `queue/README.md` — the real files are gitignored and live outside this repo, `queue/QUEUE-PC.example.md` / `queue/QUEUE-PHONE.example.md` show the format), and `/queue` works through pending items in `/sleep` posture, one per run, resuming automatically on the next scheduled firing after a usage-limit reset.


The invoked command wins over the directory.
`/freddy` runs delivery mode even in a personal repository; `/faruk` runs personal mode even outside one.
When neither is invoked and the mode is ambiguous, assume personal mode and say so in one line.
When personal-mode work turns out to be high-stakes or genuinely irreversible, say so and recommend `/freddy` rather than quietly switching.

- In delivery mode, prefer quality, simplicity, robustness, scalability, and long-term maintainability over development cost.
- In personal mode, prefer simplicity and speed: ship the direct version, skip abstraction and hardening until a second caller or a real failure demands it.
- In personal mode, do not ask for permission to proceed, to read a file, to run a build or test, or to pick between comparable approaches. Choose, act, and report what you chose.
- When a direct personal-mode request is paired with "can you do it all?" or "handle it end to end," execute every reversible in-scope step automatically, including archiving dirty state before resets, pulling latest, restarting local services, and opening review PRs; surface only the remaining human judgment after the local work is complete.

## Ledger, Routing, and Portability

Task state is written ahead of risk, not after success. Before a risky operation, the ledger records what is about to be attempted, the half-finished state it could leave, and a runnable command a successor uses to tell which happened. A session killed on a usage limit never reaches its end-of-run capture, so anything written only at the end is written only when it was not needed.

A selected route is sticky. Once a router has chosen an owner for a task, follow-up questions, clarifications, status requests, and scope adjustments inherit that route instead of re-deriving it, and the choice is recorded in the task ledger `/ship` owns rather than in a second record. The canonical shared router contract is `skills/faruk/ROUTER-CONTRACT.md`; both `/faruk` and `/freddy` load it, while their `SKILL.md` files contain only posture-specific overlays. See `skills/freddy/SKILL.md` for the delivery overlay and `skills/faruk/SKILL.md` for the personal overlay.

So every subagent prompt must open with `First read ~/Repo/agent-agnostic-harness/instructions/AGENTS.md and follow it.` Without that line the worker writes em dashes, commits to a default branch, and skips the browser-render rule, and the parent has no way to tell it happened.
The same prompt must also carry the persistence rule below in full, because a subagent that reports a blocker only in its final text has not persisted it: the orchestrator reads that text, the dashboard never does.

Default to one agent and one active writing agent per worktree; spawn only for independently bounded complex work or an explicit request, and cap justified parallel work at three agents.

**Agent-agnostic operation is the default.** Keep durable instructions, decisions, workflows, and source-of-truth records in repository files or other portable harness artifacts, not only in a host-specific memory, Project, or chat. Codex, Claude Code, ChatGPT, and other hosts must be able to resume the same work from the repository, queue, tracker, and pull request. When a host-specific feature improves convenience, treat it as an optional view over the portable records rather than the only place the context exists.

- **Maximize queue leverage before choosing work.** Identify unfinished items an answer or completed change would enable, record `Depends on: <exact queue item title>` on each dependent entry, and choose the highest-fan-out actionable item unless Faruk explicitly names another.

At the end of a substantial task, invoke `/closing` to capture remaining durable signal.
In personal mode, run `/closing` only when the session actually produced a reusable lesson, not as a routine step.

## Model Notes

- In delivery mode, every `/ship` gate requires the user's explicit reply before advancing, regardless of model.
- Use `proceed` at Plan, `lgtm` at Review, and `done` at Reflect.
- In personal mode, run `/ship` gate-free: state the plan in a few lines, implement, verify, and report. Stop for a reply only when a choice is genuinely irreversible.

## General Guidelines

- Use plain hyphens, not em dashes.
- Never add an agent as a commit co-author. Enforced by `git-hooks/commit-msg`, which strips the trailer and prints what it removed; the hook only runs where the harness is installed, so do not rely on it in place of not writing the trailer.
- Never leave work sitting on a branch without a pull request. The moment a branch carries one commit that is not on the default branch, open a PR with `/pr`; push every later commit to that same PR and update its body rather than committing quietly. Check for an existing open PR before opening another.
- **A session may not end while holding an unpersisted decision.** Anything waiting on Faruk - a blocker, an open question, an assumption taken instead of asking, a defect only he can authorise fixing - is written into the queue files before the final report, as a `## ` entry with `Status: blocked`, a `Blocked reason:` line, and an `Options:` list. Reporting it in chat does not count and never did. The dashboard parses `QUEUE-PC.md` and `QUEUE-PHONE.md` and nothing else, so on 2026-08-14 it read zero blockers against seventeen real ones for exactly this reason. The rule binds subagents and parallel tasks hardest, because that is where it failed: reporting conversationally to an orchestrator feels like handing the finding over, and it is not. Before writing one, read `~/Repo/agent-agnostic-harness/instructions/rules/queue-and-persistence.md` - the field contracts and parser traps are there, and they fail silently.
- Before running `git commit`, check the current branch against the repo's default branch. If they match, branch first. Two commits went straight to a default branch in one night without anyone noticing at the time; treat the check itself as part of the commit step, not a thing to remember separately.
- Never manually modify generated files or `CHANGELOG.md` files.
- Put each full sentence on its own line when substantially editing long Markdown files.
- Prefer modifying existing code, follow the local style, minimize diff noise, and keep comments sparse.
- Reproduce bugs as close to the end-user experience as possible before changing code.
- Treat visibly broken UI, lint failures, flaky tests, and test failures as engineering defects worth resolving when they are in scope.
- Never mark a code change `done` on review alone when it was meant to run. If the runtime or toolchain is unavailable, say the change is unbuilt and unverified in both the report and `status/TRACKER.md`, and name the actual blocking error rather than a guessed cause - a wedged `msiexec` was misdiagnosed as a UAC prompt hang three separate times before someone read the installer log.
- When rebuilding, replacing, or restoring something that already exists, read the original before designing the replacement. Working from a summary of it produces a plausible thing that is wrong in ways nobody can name; a dashboard rebuilt from recollection drifted three times before the real markup was fetched. The artifact is cheaper to read than the drift is to undo.
- Verify a merge landed what it claimed. A squash merge reports success from the PR's recorded head, which is not necessarily the branch's current tip: a ten-commit branch once merged as one commit carrying only the first, leaving a server with its authentication removed. After merging anything whose later commits matter, diff the merged result for a string only the newest work contains.
- A skill that snapshots state goes stale silently, because nothing regenerates it. When a skill describes something that lives elsewhere, name the live source, require reading it first, and treat the snapshot as a summary that loses to the source on any disagreement.
- **Automation-first:** At every task boundary, inspect the next manual handoff, repeated check, or coordination step for a safe, deterministic automation path before handing it back to Faruk.
  - Use an existing script, app tool, skill, hook, or repository record when it can perform the same action within scope, then verify the consumer or observable result.
  - If automation is unavailable or would cross a human-decision or irreversible-action boundary, state that reason and leave the smallest reusable fallback.

## Concurrency and Git Safety

- **Run `git fetch origin && git rev-list --left-right --count origin/<default>...HEAD` as the first command in any repo task**, before reading a single source file - not before the first edit. Reading comes first in practice, so a rule that gates only writing is a rule that fires after the wasted work. Whatever branch a repo is sitting on was left there by an earlier session and says nothing about where new work belongs. Branch from `origin/<default>`, not from wherever HEAD sits. A file once read on the wrong branch was 360 lines stale, missing an entire auth layer; a spacing bug was investigated for several tool calls against a branch eight commits behind the commit that introduced the element under test.
- Concurrent sessions must not share one working tree. Before starting work in a repo another session may be in, create a worktree (`git worktree add ~/Repo/<repo>-<purpose> <branch>`) and work there. A checkout is global state: a `git checkout` in one session silently rewrites every file under every other session in that clone, and neither side is told. Launch long-running services from a pinned worktree, never from the tree people edit in.
- **Claim the tree before writing in it.** The unit of conflict is a working tree, not a repository: two agents in different worktrees of one repo cannot collide, and two in one tree did. Before the first write, run `tools/claim.ps1 acquire -Tree <path> -Session <id>`; exit 3 means someone holds it, so create your own worktree and claim that instead. Release on completion, and heartbeat as you go. Claim a shared generated cascade separately by name (`-Cascade <name>`) - generated output collides at merge, which cost three rebases in one night. `tools/claim.ps1 list` shows what is held. An instruction to check `git status` first is not a mechanism, because a working tree does not record who wrote into it. The claim is enforced at commit time by `git-hooks/pre-commit`, so export `HARNESS_SESSION` as the identity you pass to `acquire`; `HARNESS_CLAIM_BYPASS=1` waives it deliberately and says so on stderr. See `docs/CLAIM-ENFORCEMENT.md`.
- **Compare-and-swap every write to a queue file.** Take a fingerprint when you read (`tools/queue-cas.ps1 fingerprint -Path <q>`), pass it back on append (`append -Path <q> -Expect <fp> -Content <text>`), and treat exit 5 as re-read and re-decide rather than retry - a peer's entry may be the same finding. These files are shared mutable state outside every repo, so no tree claim covers them.
- **Fan out reads, serialise writes.** A read-only agent cannot conflict with anything, so investigation parallelises freely and takes no claim: audit N repos, verify a claim, research a decision, all at once. Writing serialises. Do not over-correct into one-agent-per-repo - that pays the full cost of serialisation to prevent collisions that were never possible.
- A build or generator is a write, and it writes into whatever tree it runs in. Before running one in a tree another session may be in, ask what it emits rather than only what it reads. A resume build once baked another session's uncommitted work into PDFs that were then offered to Faruk as corrected. Use a throwaway worktree off `origin/<default>` for verification, and scope the commit to the sources. "It is only a compile" is the assumption to distrust.
- Before promoting dirty worktree changes into a branch or pull request, compare every changed path with `origin/<default>` and carry only the delta absent upstream; preserve duplicate local work separately instead of publishing it.
- **Every repository points at these rules from its own root.** Each repository carries a **Harness rules - read this first** pointer and a `CLAUDE.md` of `@AGENTS.md`. It is a pointer because Codex has no include directive - verified against its binary, not assumed - and because a copy in ten repositories is the stale-snapshot failure ten times over, each copy looking authoritative while it drifts. `tools/check-entrypoints.ps1` audits the workspace for it; `docs/REPO-ENTRYPOINTS.md` carries the block and the per-host precedence table.

## Truthfulness and Freddy's Resume

- Never uncomment, activate, or promote a commented-out line in Freddy's resume files without his explicit, per-bullet permission. Commented content is NOT disabled truth - treat it as unverified. His commented bullets are example or placeholder text he was drafting against, and several appear verbatim under three different employers, which is what a reuse palette looks like, not a record of results. On 2026-08-11 a session read them as real-but-disabled and activated two metric claims; they reached a built PDF, two renditions, the live site, and all three job-board exports before anyone caught it, on a resume headed to Google. The same session deleted ~30 other commented bullets as "dead comments" - also not ours to judge. Deactivating is safe; activating and deleting are not.
- **Resume content drafting gate.** Before changing any resume content - including a summary, skill, bullet, project, title, section order, or certification - prepare at least two distinct copy drafts as review artifacts. Show the current wording alongside each draft and highlight material differences. Keep the authoritative source and generated cascade unchanged while Faruk decides; edit the source and regenerate only after he selects or approves a draft. This gate applies even when the proposed wording is a small or obviously reversible improvement.

## Communication Register

- Match the language to the audience, and know which one you are writing for. This is a framing rule, not a hiding rule: the finding is identical either way, and accuracy is never traded for comfort.
  - **Public-facing artifacts** - commit messages, branch names, PR titles and descriptions, docs in a public repo, code comments in a published file, anything rendered on the portfolio site. Use neutral, precise, professional language. Describe a defect in terms of the system or the process that produced it, not the person. Avoid loaded words: fabricated, false, lied, invented, made up, sloppy, negligent. Assume a recruiter or hiring manager will read the sentence out of context, because on a public repo attached to Freddy's name during a job search, one may. "An earlier automated pass promoted commented draft text into live bullets" and "his resume contained fabrications" can describe the same event; only the first is both accurate and fair, because the fault was in the tooling's assumption, not in anything Freddy wrote.
  - **Private records** - the gitignored queue files, `status/TRACKER.md`, `TRACKER-ARCHIVE.md`, local notes. Keep recording findings candidly and specifically, **including mistakes the harness itself made**. Name the incident, the commit, the file, the wrong assumption. Do not sanitize these.
  - The reason for the split, stated so it is not over-applied: the candid private logging is what makes problems findable. The notes about an unauthorized force-push and about bullets being promoted out of comments are precisely why those were caught and fixed. `/learn` mines exactly this material, so sanitizing private records would remove the harness's ability to learn from its own failures - which is the point of that skill. An agent applying this rule to hide a real defect, in either register, has inverted it.
  - Where a public artifact must reference a private finding, describe the mechanism and omit the characterization. Link to the private record rather than restating it.
- Report to Freddy briefly. This is a standing setting, not a per-session preference, and it is written here because it decayed twice inside one working session on 2026-08-23 while it was held only in conversation.
  - Lead with what he has to decide or act on. Cut process narration, restated context, and anything already visible to him in the diff, the PR, or his own request.
  - A finding he did not ask for gets one line. The supporting detail belongs in the pull request body, the queue item, or the log, not in the message.
  - Length is earned by decisions and genuine risk only, never by effort spent. A long report is a failure mode wearing the costume of thoroughness.
  - Specifically: do not re-explain what was just done, do not summarize work he already approved, and do not produce a table unless he asked for data.
  - The reason, so this is not over-applied: brevity is compression of the narration, never of the substance. A real problem, a correction to something previously reported wrong, or a decision that is his to make must still be stated in full. Dropping one of those to hit a line count is a worse failure than any amount of verbosity.

## Native Skills

| Task | Skill command |
|---|---|
| Select, explain, and execute the right harness workflow, enterprise-grade | `/freddy` |
| Get personal-project work done hands-off, minimal interruption | `/faruk` |
| Run unattended overnight with zero questions | `/sleep` |
| Queue larger ideas and work through them continuously across usage-limit resets | `/queue` |
| Rapid-fire status check: open decisions and a brief done/next across active harness work | `/status-report` |
| Review real queue/tracker/PR history and apply evidence-cited refinements to the harness's own skills | `/learn` |
| Complete plan through reflect cycle | `/ship` |
| Plan and decompose | `/plan` |
| Map a large, uncertain multi-session effort | `/wayfinder` |
| Turn settled context into an agent-ready specification | `/to-spec` |
| Break a plan into vertical-slice tracker tickets | `/to-tickets` |
| Evaluate and prepare an issue or external PR | `/triage` |
| Implement a new feature | `/newfeature` |
| Debug unexpected behavior | `/debugging` |
| Review code | `/codereview` |
| Verify a web UI by actually rendering it | `/browsertest` |
| Sweep a whole web surface for dead controls, collisions and dead links before shipping | `/polish` |
| Open or update a GitHub pull request | `/pr` |
| Capture session knowledge | `/closing` |
| Build a throwaway design prototype | `/prototype` |
| Gather missing stakeholder knowledge asynchronously | `/to-questionnaire` |
| Write as Freddy | `/voice` |
| Create or edit a Confluence page | `/wiki` |
| Make decisions informed by Freddy's viewpoints | `/opinions` |
| Produce a Mermaid architecture diagram | `/architecture-diagram` |
| Explore or advance a business or project plan with focused questions and dashboard decisions | `/business-planning` |
