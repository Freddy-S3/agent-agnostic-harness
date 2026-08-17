# Freddy's Agent Instructions

These common instructions apply across Freddy's workspaces.

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

### New project convention

When Faruk describes a new project idea rather than a change to an existing one, treat it as a request to found a new sibling repo, not to extend an existing one:

1. Create `C:\Users\Faruk\Repo\<new-repo-name>` alongside `agent-agnostic-harness` and `Portfolio-Website`, pick the name from the idea, and `git init` it.
2. Create the matching GitHub repository (`gh repo create`) and set it as `origin`.
3. Treat it as a portfolio piece: something a hiring engineer or manager would look at and come away impressed.
4. Do not default the tech stack to whatever is already on Faruk's resume. Pick whatever language/framework combination is currently in demand and salary-boosting for a software/AI engineer, and vary the choice project to project so the portfolio shows range rather than one repeated stack. State the pick and the one-line reason in the report.
5. Build it autonomously under whichever contract is active, `/faruk` or `/sleep` — no mid-build check-ins, own branch, real commits, `/pr` to open the PR for review.
6. Default every piece of infrastructure to its free tier: hosting (Vercel/Netlify/Cloudflare Pages over paid platforms), database (Supabase/Neon free tier over a paid instance), email/newsletter service, analytics, and anything else with a metered cost. Only reach for a paid tier when the project has a specific, stated requirement the free tier genuinely cannot meet. Note in the README (and business plan, if the project has one) exactly which pieces are on free tiers and what the upgrade path looks like once volume outgrows the free limits, so it is a planned step later, not a surprise.

This convention governs how `/queue` should treat any queued item that describes a new project, not only a one-off request.

The invoked command wins over the directory.
`/freddy` runs delivery mode even in a personal repository; `/faruk` runs personal mode even outside one.
When neither is invoked and the mode is ambiguous, assume personal mode and say so in one line.
When personal-mode work turns out to be high-stakes or genuinely irreversible, say so and recommend `/freddy` rather than quietly switching.

## The Agentic Loop

Use this six-phase cycle for substantial tasks in delivery mode.
In personal mode, treat it as a checklist to borrow from rather than a sequence to complete: orient enough to be correct, implement, verify, and stop.
Skip a phase whenever its cost exceeds its value.

| Phase | Name | What happens |
|---|---|---|
| 1 | Orient | Explore affected code, find the reference sibling, define done |
| 2 | Decompose | Break work into parallel and sequential sub-tasks; confirm plans over three files |
| 3 | Implement | Execute against existing code patterns |
| 4 | Synthesize | Wire pieces together, build, test, resolve conflicts |
| 5 | Evaluate | Review the full diff adversarially |
| 6 | Reflect | Capture durable harness improvements |

At the end of each agentic loop, provide one standalone commit comment of no more than 15 words, ready to copy and paste.

Keep scaffolding minimal, give the model control, and invest in agent-computer interfaces as deliberately as human-computer interfaces.
Fewer, deeper skills are preferable to a large library.

## Token Budget And Context

When trade-offs arise, prefer lower token cost, then less human effort, then faster execution.
If the user alone has the answer to a requirement, business decision, or stakeholder context, ask once.
If the answer is available in code, read the code instead of asking.
State grounded assumptions explicitly instead of asking speculative implementation questions.
Ask at most one question per checkpoint; when several unknowns exist, ask only the single most blocking one.
Never ask how to implement something - that is the agent's job, and the question spends a checkpoint on nothing.

The installed skill catalog is progressive-disclosure context: load a skill's body when its route fires, not to decide whether it is relevant.
Acquire it through the skill loader or its registered path rather than asking for it to be pasted in, and treat a one-time file-access confirmation as a tool security check rather than a decision gate.

A selected route is sticky. Once a router has chosen an owner for a task, follow-up questions, clarifications, status requests, and scope adjustments inherit that route instead of re-deriving it, and the choice is recorded in the task ledger `/ship` owns rather than in a second record. See `skills/freddy/SKILL.md` for the release triggers and how the route interacts with personal and delivery mode.

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

At the end of a substantial task, invoke `/closing` to capture remaining durable signal.
In personal mode, run `/closing` only when the session actually produced a reusable lesson, not as a routine step.

## Model Notes

- In delivery mode, every `/ship` gate requires the user's explicit reply before advancing, regardless of model.
- Use `proceed` at Plan, `lgtm` at Review, and `done` at Reflect.
- In personal mode, run `/ship` gate-free: state the plan in a few lines, implement, verify, and report. Stop for a reply only when a choice is genuinely irreversible.

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

## General Guidelines

- Use plain hyphens, not em dashes.
- Never add an agent as a commit co-author. Enforced by `git-hooks/commit-msg`, which strips the trailer and prints what it removed; `install.ps1` points global `core.hooksPath` at that directory. The hook rewrites rather than rejects, so it cannot be worked around by habit, but it only runs where the harness is installed - do not rely on it in place of not writing the trailer.
- Never leave work sitting on a branch without a pull request. The moment a branch carries one commit that is not on the default branch, open a PR with `/pr`; push every later commit to that same PR and update its body rather than committing quietly. Check for an existing open PR before opening another.
- **A session may not end while holding an unpersisted decision.** Anything waiting on Faruk - a blocker, an open question, an assumption taken instead of asking, a defect only he can authorise fixing - is written into the queue files before the final report, as a `## ` entry with `Status: blocked`, a `Blocked reason:` line, and an `Options:` list. Reporting it in chat does not count and never did. Faruk's dashboard (`tools/queue-dashboard`) parses `QUEUE-PC.md` and `QUEUE-PHONE.md` and nothing else, so a decision that lives only in a reply is a decision he cannot see, and on 2026-08-14 he had a dashboard reading zero blockers against seventeen real ones for exactly this reason. The rule binds subagents and parallel tasks hardest, because that is where it failed: reporting conversationally to an orchestrator feels like handing the finding over, and it is not.
	- **Write to the queue files, not to `status/TRACKER.md`, when only one is possible.** `TRACKER.md` remains the right place for assumptions and skips, and `/status-report` still reads it, but it is not on the dashboard's path. Keep writing both; if a session can only manage one, the queue file is the one that reaches him.
	- **A queue item must be self-contained.** The description is read cold, on a phone, by someone who has never seen the session that wrote it. Write it so that reader can decide without opening a repo, scrolling the log, or remembering a previous conversation. State the actual decision in full: what is being asked, what it affects, and what happens either way. An item that requires context to interpret is an item Faruk cannot action, which makes it identical to one that was never persisted - the failure this whole rule exists to prevent, arriving one step later.
		- **The fields have different readers. Do not conflate them.** `Blocked reason:` and `Options:` are for Faruk deciding now; they carry the question and the choices, in full, in the present tense. `Log:` is the audit trail, for an agent or a future session reconstructing history; it carries dates, what changed, what was measured, and what a prior session concluded. Same item, two audiences. Writing history into the decision field is the root cause of every unreadable item on that dashboard.
		- **Banned in `Blocked reason:` and `Options:`:** back-references with no referent (`the four fixes`, `see above`, `as previously noted`, `the item below`), continuity claims (`unchanged since`, `still outstanding from`, `restating the earlier answer`), bare dates pointing at earlier prose (`the 2026-08-11 partial answer`), and any meta-commentary about why the item was rewritten or reformatted. That last one is process narration; it belongs in `Log:` or nowhere. If a phrase only makes sense to someone who read the log, it is a log line.
		- **Options must be complete, self-describing sentences.** They render as the only labels on the answer buttons, so each one has to state what it does on its own terms. `Apply all four fixes` is not an option, it is a pointer to a list the reader cannot see.
		- **Worked example.** This item was live on the dashboard on 2026-08-14 and is the reason this rule exists.

			Bad, as it actually rendered - every sentence is about the item rather than about the decision:

			> 2026-08-14: DECISION NEEDED FROM FARUK. Restating the 2026-08-11 partial answer as an actual blocker, because "not yet authorised" recorded in prose kept the item reading as ordinary pending work and it never surfaced as something waiting on him. The four fixes are unchanged and still unauthorised. `Options:` added above.

			It names no fix, points at another date's answer, and spends its last clause narrating its own edit. The reader learns that a decision exists and nothing about what it is.

			Good - the same decision, stated so it can be answered cold:

			> Blocked reason: The Google-targeted resume rendition (`resume/renditions/google-concorde`) has two content defects left. Its Projects section lists only one project, Agentic Engineering Harness, which looks thin for a Google application; The Compounding Engineer was there previously and can be restored from PR #7. And the Santoku VR bullet trails off with "...launch, and five and a half years of production maintenance", where the date range already conveys the duration. Both need your sign-off because you asked to be consulted before content changes to this rendition.
			>
			> Options:
			> - Restore The Compounding Engineer and cut the Santoku maintenance tail
			> - Restore The Compounding Engineer only, leave the Santoku bullet as it is
			> - Cut the Santoku maintenance tail only, leave Projects with one entry
			> - Leave both as they are

		- **Two format traps, both of which fail silently.** The parser drops what it cannot match, and nothing warns you - the item simply renders wrong. First, `Options:` must be a run of `- ` bullets with **each option on exactly one line**; the match is `((?:[ \t]*-[^\n]*\n?)+)`, so a numbered list (`1.`) yields no options at all, and a wrapped bullet ends the run there and silently truncates every option after it. Five items on 2026-08-15 had written good options as numbered lists and had been rendering with no buttons at all. Second, `Blocked reason:` runs until the next line matching `^[A-Z][a-z]+ ?[a-z]*:`, so **the field block must be contiguous**: put `Options:`, `Repo:` and `Added:` directly under it, before any free prose. With prose in between, the whole body is absorbed into the description - one item was rendering 2164 characters of margin measurements onto a phone card.
		- **The renderer takes the field, not the log.** `tools/queue-dashboard/server.mjs` renders `blockedReason || asks[0] || ''`, so a well-written `Blocked reason:` is what Faruk sees. Before 2026-08-15 the precedence was reversed and any log line matching `DECISION NEEDED` shadowed the field entirely, which is how audit prose reached the card in the first place. Do not rely on a log line to carry a question.
	- **Confirm the write landed by reading it back.** A session on 2026-08-14 had a `TRACKER.md` append refused by a permission classifier and carried on as though the record existed. The file is writable in the ordinary case - verified by probe - so the block was situational, most likely a session whose working directory was a different repo writing to a path outside it, which is precisely the shape of every parallel run. A blocked write must be reported as a blocked write, naming the exact path and the actual error, so the parent session can persist it instead. Silence after a failed write is the failure mode this whole rule exists to end.
- Before running `git commit`, check the current branch against the repo's default branch. If they match, branch first. This was written as a rule, not enforced, and got skipped twice in one night (Portfolio-Website `f2b2127`, hoshi-candle-co `eb0e0fb` both went straight to a default branch) without anyone noticing at the time — treat the check itself as part of the commit step, not a thing to remember separately.
- Never manually modify generated files or `CHANGELOG.md` files.
- Put each full sentence on its own line when substantially editing long Markdown files.
- In delivery mode, prefer quality, simplicity, robustness, scalability, and long-term maintainability over development cost.
- In personal mode, prefer simplicity and speed: ship the direct version, skip abstraction and hardening until a second caller or a real failure demands it.
- In personal mode, do not ask for permission to proceed, to read a file, to run a build or test, or to pick between comparable approaches. Choose, act, and report what you chose.
- For a request to complete a ticket, authenticate using MCP to the configured Jira instance (`JIRA_URL`) and Confluence instance (`CONFLUENCE_URL`) before planning or implementation; if either authentication fails, stop immediately and do not proceed. When neither is configured, treat the work as ticketless and stay local rather than blocking.
- When retrieving any Jira ticket, request and read all comments as part of the requirements before planning or implementing.
- Treat ticket comments as acceptance criteria, and surface conflicts between a comment and the ticket description before proceeding.
- For every pull request review, retrieve and read all available comments and activity before forming findings; treat them as review context and acceptance criteria.
- Match the language to the audience, and know which one you are writing for. This is a framing rule, not a hiding rule: the finding is identical either way, and accuracy is never traded for comfort.
  - **Public-facing artifacts** - commit messages, branch names, PR titles and descriptions, docs in a public repo, code comments in a published file, anything rendered on the portfolio site. Use neutral, precise, professional language. Describe a defect in terms of the system or the process that produced it, not the person. Avoid loaded words: fabricated, false, lied, invented, made up, sloppy, negligent. Assume a recruiter or hiring manager will read the sentence out of context, because on a public repo attached to Freddy's name during a job search, one may. "An earlier automated pass promoted commented draft text into live bullets" and "his resume contained fabrications" can describe the same event; only the first is both accurate and fair, because the fault was in the tooling's assumption, not in anything Freddy wrote.
  - **Private records** - the gitignored queue files, `status/TRACKER.md`, `TRACKER-ARCHIVE.md`, local notes. Keep recording findings candidly and specifically, **including mistakes the harness itself made**. Name the incident, the commit, the file, the wrong assumption. Do not sanitize these.
  - The reason for the split, stated so it is not over-applied: the candid private logging is what makes problems findable. The notes about an unauthorized force-push and about bullets being promoted out of comments are precisely why those were caught and fixed. `/learn` mines exactly this material, so sanitizing private records would remove the harness's ability to learn from its own failures - which is the point of that skill. An agent applying this rule to hide a real defect, in either register, has inverted it.
  - Where a public artifact must reference a private finding, describe the mechanism and omit the characterization. Link to the private record rather than restating it.
- Never uncomment, activate, or promote a commented-out line in Freddy's resume files without his explicit, per-bullet permission. Commented content is NOT disabled truth - treat it as unverified. His commented bullets are example/placeholder text he was drafting against, and several appear verbatim under three different employers, which is what a reuse palette looks like, not a record of results. On 2026-08-11 a session read them as real-but-disabled and activated two metric claims (75% repetitive-task reduction, 75% downtime reduction); they reached a built PDF, two renditions, the live site, and all three job-board exports before anyone caught it, on a resume headed to Google. The same session deleted ~30 other commented bullets as "dead comments" - also not ours to judge. Deactivating is safe; activating and deleting are not.
- **Fan out reads, serialise writes.** A read-only agent cannot conflict with anything, so investigation parallelises freely and takes no claim: audit N repos, verify a claim, research a decision, all at once. Writing serialises. Do not over-correct into one-agent-per-repo - that pays the full cost of serialisation to prevent collisions that were never possible.
- **Claim the tree before writing in it.** The unit of conflict is a working tree, not a repository: two agents in different worktrees of one repo cannot collide, and two in one tree did. Before the first write, run `tools/claim.ps1 acquire -Tree <path> -Session <id>`; exit 3 means someone holds it, so create your own worktree and claim that instead. Release on completion, and heartbeat as you go. Claim a shared generated cascade separately by name (`-Cascade <name>`) - generated output does not corrupt on concurrent edit, it collides at merge, which cost three rebases in one night. `tools/claim.ps1 list` shows what is held. An instruction to check `git status` first is not a mechanism: every agent that day was told to, and none could tell whose changes it was looking at, because a working tree does not record who wrote into it.
- **Compare-and-swap every write to a queue file.** Take a fingerprint when you read (`tools/queue-cas.ps1 fingerprint -Path <q>`), pass it back on append (`append -Path <q> -Expect <fp> -Content <text>`), and treat exit 5 as re-read and re-decide rather than retry - a peer's entry may be the same finding. These files are shared mutable state outside every repo, so no tree claim covers them.
- Concurrent sessions must not share one working tree. Before starting work in a repo another session may be in, create a worktree (`git worktree add ~/Repo/<repo>-<purpose> <branch>`) and work there. A checkout is global state: a `git checkout` in one session silently rewrites every file under every other session in that clone, and neither side is told. On 2026-08-11 one session moved `agent-agnostic-harness` through four branches while another was mid-task, which replaced a server file that had just gained an authentication check with the pre-auth version of itself, minutes before a network proxy was pointed at its port. It was caught only because the tree was re-read before publishing. Long-running services in particular should be launched from a pinned worktree, never from the tree people edit in.
- Before building on a file, check the checked-out copy against the default branch: `git diff --stat origin/<default> -- <path>`. Whatever branch a repo is sitting on was left there by an earlier session; it is not a statement about where new work belongs, and the file open in front of you may not be the current one. On 2026-08-11 `tools/queue-dashboard/server.mjs` was read in full on the branch that happened to be checked out, and was 360 lines behind `origin/main` - missing the entire auth layer, the tailnet bind, and the `Options:` handling. A feature built on it would have been written against a version that no longer existed and would have reverted the auth layer on merge. Branch from `origin/<default>`, not from wherever HEAD sits. Run `git fetch origin && git rev-list --left-right --count origin/<default>...HEAD` as the **first** command in any repo task, before reading a single source file - not before the first edit. Reading comes first in practice, so a rule that gates only writing is a rule that fires after the wasted work. On 2026-08-14 a spacing bug was investigated for several tool calls against a branch eight commits behind, missing the very commit that introduced the element being investigated; the measurements all came back clean because the page under test did not contain the bug, and Faruk had to point out the branch. This is the read-side counterpart to the worktree rule above: that one stops another session from changing your files, this one stops you from starting on the wrong ones.
- A build or generator is a write, and it writes into whatever tree it runs in. Before running one in a tree another session may be in, ask what it emits rather than only what it reads. On 2026-08-15 `tools/build-resume.ps1` was run in Portfolio-Website while a dispatch session held the same tree; it rewrote `Certificates/*.pdf`, `index.html` and `exports/`, baking that session's uncommitted font and text-layer work into PDFs that were then offered to Faruk as a corrected resume. The correct shape is a throwaway worktree off `origin/<default>` for verification, and a commit scoped to the sources with generated output left for whoever owns it. "It is only a compile" is the assumption to distrust.
- A skill that snapshots state goes stale silently, because nothing regenerates it. `skills/job-search/SKILL.md` carried a "Current Resume State" table saying Google Drive Clone was the only project and an open item asking for an AI/agentic project to be added; the real `resume.data.json` had listed the agent-agnostic harness as project #1 for days, propagated to the site and every export. Advice was given from the table to do work already finished. When a skill describes something that lives elsewhere, name the live source, require reading it first, and treat the snapshot as a summary that loses to the source on any disagreement.
- When rebuilding, replacing, or restoring something that already exists, read the original before designing the replacement. Working from a summary of it produces a plausible thing that is wrong in ways nobody can name, and the correction arrives as "this is worse" rather than as a list. On 2026-08-11 a dashboard was rebuilt from a recollection of an artifact and drifted three times - content collapsed behind disclosures, bespoke per-item choices replaced by a generic approve/reject, answered items hidden instead of faded. Fetching the artifact's actual markup surfaced all three in one pass, plus three more nobody had mentioned. This applies to a UI, a document, a config, or an API shape: the artifact is cheaper to read than the drift is to undo.
- Verify a merge landed what it claimed. A squash merge reports success from the PR's recorded head, which is not necessarily the branch's current tip: on 2026-08-11 a ten-commit branch merged as one commit carrying only the first, and the result on the default branch was a server with its authentication removed. The `gh pr view --json commits` count had shown one commit for hours and was dismissed as a stale read. After merging anything whose later commits matter, diff the merged result for a string only the newest work contains.
- Reproduce bugs as close to the end-user experience as possible before changing code.
- Treat visibly broken UI, lint failures, flaky tests, and test failures as engineering defects worth resolving when they are in scope.
- Never mark a code change `done` on review alone when it was meant to run. If the runtime/toolchain isn't available (e.g. Node.js missing), say the change is unbuilt and unverified in both the report and `status/TRACKER.md`, and name the actual blocking error rather than a guessed cause. A Node install got misdiagnosed as a UAC prompt hang three separate times before someone checked the actual installer log and found a wedged `msiexec`; log what the error message says, not what it looks like.
- Never report a change to HTML, CSS, or client-side JS as done without rendering the page in a real browser; run `/browsertest` and say so plainly when it has not been rendered.
- On any page work, press every control and require an observable change. Asserting that a control exists and has a listener is not a test of the control: on 2026-08-15 the portfolio's primary "Route this task" button did nothing when pressed with an empty box - the state every visitor arrives in - while `tools/test_site.py` stayed green at 37/37, and Faruk found it on the live site during a job search. A control that renders and does nothing is invisible to a diff, invisible to a presence check, and the first thing a real visitor notices. `/browsertest` carries the mechanism and the three calibrations that decide whether it works; the rule here is that the check is not optional and that a new control is added to it. Verify any such guard by constructing the failure, since one that has only been observed passing has not been tested. Before shipping a page, run `/polish`, which sweeps the whole surface for this and its sibling classes - elements that collide, links that go nowhere, forms with no backend - rather than only the control you touched. Rendering means a Playwright sweep across the widths in that skill, with the checker's output in the report - not one screenshot at whatever width the window happened to be. A single width is how content ended up underneath the portfolio's fixed control rail on 2026-08-14: the page looked correct at 1280 and was broken at 1920 and at 970, and Faruk found it rather than the harness. Look at a screenshot as well as the assertions, and judge it against the taste rubric in `/browsertest`; the assertions catch broken, only the screenshot catches ugly.
- When a skill's output is a list of discrete items each awaiting Faruk's call, render it as clickable cards as well as text, following `instructions/WIDGETS.md`. Always emit the text report too: the widget is an affordance layered on the report, not a replacement, and it is the text that survives a headless run, an unavailable tool, or a later session reading the transcript back. Never add a button whose sentence is not already in that file's action vocabulary and already handled by the receiving skill - a control that looks live and does nothing is worse than no control.
- Prefer modifying existing code, follow the local style, minimize diff noise, and keep comments sparse.
- Renaming a shared identifier - a repo, a directory, a package, a URL - is never a rename. It is a migration with a consumer list, and the consumers are almost never all inside the thing being renamed. Grepping the renamed repo is the part that feels like the job and is the part that finds the least. Before declaring a rename done, enumerate and check each class below by name, and say in the report which ones were clean rather than only listing what changed:
  - **Inside the repo** - source, docs, scripts, generated output.
  - **Machine wiring** - junctions and symlinks, `core.hooksPath`, `~/.claude/settings.json` hook commands, scheduled tasks, startup entries, environment variables, worktree `.git` gitdir pointers.
  - **Processes already running against the old path** - a repaired link does not reach a session that read it at startup. Verify the consumer, not the artifact: after the 2026-08-12 junction repair the target resolved and all 34 skills were on disk, while the session that had started during the outage still answered `Unknown skill: freddy` for every one of them and silently fell back to built-ins. Checking `Get-Item ... Target` confirmed the filesystem and proved nothing about the thing using it. Exercise the mechanism end to end - invoke the skill, fire the hook, hit the endpoint - and restart anything long-lived that caches a path.
  - **Sibling repos that consume it** - a generator that clones it by URL, a cached checkout of it, a settings allowlist naming its path. On 2026-08-12 the rename to `agent-agnostic-harness` was clean inside the harness and stale in every one of these: `Portfolio-Website/tools/skills_to_site.py` still cloned the old URL into a `.harness-cache/claude-harness-public/` copy, and `.claude/settings.local.json` still allowlisted the old path.
  - **Published artifacts** - the live site, resume renditions and their built PDFs, job-board exports, PR and issue bodies, the old host's repo description. GitHub redirects an old repo URL, so these keep working and therefore never fail loudly; they just display the wrong name until someone reads them.
  A redirect or a still-resolving path is not completion. Ask, per consumer, "would this break if the redirect were removed tomorrow", and fix every yes.

## Skill Harness Conventions

### What "add to the harness" means

Treat the phrase as covering every artifact below, not just the one that is convenient.
A change that lands in only some of them is half-applied and will drift.

The harness lives at `~/Repo/agent-agnostic-harness`, alongside the projects it serves.
Always edit it there, never the `~/.claude` projection.

| Artifact | Update when |
|---|---|
| `skills/<name>/SKILL.md` | The change is a workflow. Create the directory for a new skill. |
| `instructions/AGENTS.md` | The change adds a skill to the Native Skills table, or adds or alters a standing rule. |
| `instructions/WIDGETS.md` | The change adds, removes, or renames a clickable card button in any skill. The action vocabulary there is the contract; a button whose sentence is not in that table is a dead control. |
| `HARNESS.md` | The change affects day-to-day use: the selection table, the gates, or a worked example. |
| `README.md` | The change adds a new top-level path or alters install behaviour. |
| Git | Always. Commit in `agent-agnostic-harness` with a real message, and push. An uncommitted harness edit is lost the next time the machine is reimaged. |

Verify a new skill is actually discoverable before reporting it added: `skills/` is a
directory junction into `~/.claude`, so a new `SKILL.md` registers live, but a skill
absent from the `AGENTS.md` table will not be routed to.

Every skill in this harness is model-invocable. Do not set `disable-model-invocation: true` on
a new one. That flag makes a skill reachable only by a slash command the human types into the
CLI, which silently removes it from every other surface: the desktop and web apps, background
jobs, and subagents all reach skills through the Skill tool, not through slash expansion.
Eleven skills carried the flag - both mode routers among them - and were invisible outside the
terminal until 2026-08-11. Keep `user-invocable: true` so the slash command still works, and
write the `description` as a model-facing pointer stating its trigger conditions, because it is
now the index entry the agent routes on rather than a human-facing summary.

- When adapting an imported harness, validate that the native files neither mention nor require the source archive before treating that archive as removable.
- This harness is linked into `~/.claude`, not copied. `skills/` and `memories/` are directory junctions, so an edit on either side is the same file. `~/.claude/CLAUDE.md` is a stub that imports this file with `@~/Repo/agent-agnostic-harness/instructions/AGENTS.md`, so it is read live and never needs syncing.
- A single file cannot be linked reliably on Windows: symlinks need admin or Developer Mode, and a hard link does not survive an editor that writes by replace-and-rename. The import stub sidesteps both, because the stub itself is never edited.
- Edit `instructions/AGENTS.md` and restart the host. Never edit `~/.claude/CLAUDE.md`; it holds only the import.
- `~/.claude/settings.json` is not managed by this repository and stays a local file.

### Conventions need an enforcing mechanism

A convention that lives only in prose is one that tooling will quietly violate.
`install.ps1` copied `AGENTS.md` over `~/.claude/CLAUDE.md` while this file said the
opposite, then printed a note telling the user to hand-rebuild the stub it had just
destroyed. The knowledge was there; it was written as advice to a human instead of as
behaviour in code.

- When you document a convention here, make the tool that touches those files enforce it. If no tool owns it, say plainly that it is manual.
- Treat a tool that asks the user to undo what it just did as a defect, not a note. That instruction belongs in the code path.
- Prefer generating a derived file over copying a source file whenever the host resolves it live. A copy is indistinguishable from the real thing on install day and diverges silently afterwards.
- A generator or installer is verified by running it against a throwaway target and reading what it produced, never by reading its source. Check idempotency on a second run, and check that it leaves a hand-edited target alone.
- Put a guard where the failure actually happens, not where it reads well. The queue dashboard's stale-checkout check has to run before the launcher's "is the port already up" early exit, because the failure mode is a healthy-looking port serving old code - placed after that exit, in the natural-reading position, it would never run in the one case it exists for. Ask this of any new check: is there an early return upstream of it that the failure passes through first?
- Verify a predicate by constructing the failure, not by re-reading the line. That same guard's first draft asked `git merge-base --is-ancestor HEAD origin/main`, which is the intuitive direction and is backwards: a branch that was merged and then left behind is still an ancestor of `main`, so it reported healthy for precisely the stale checkout it was written to catch. A throwaway worktree at the old commit exposed it in one command.
- An idempotency check must compare the target state, not the shape. Distrust every "already linked", "already installed", "already exists" branch and ask what it does when the thing exists but is wrong. `install.ps1` skipped relinking on `Test-IsJunction`, which asks "is this a link" and never "does it point at this repo" - its own docstring claimed the stronger meaning the code did not implement. When the harness repository was renamed on disk on 2026-08-12, the installer re-ran, found both junctions present but dangling, printed "already linked", and reported a clean install while all 34 skills and every memory were unreachable. The weaker test is always the cheaper one to write, and it is the one that reports success during an outage. Fixed by `Test-JunctionPointsTo`.
- A rename is a first-class test case for anything that links, caches, or records a path. Three separate mechanisms broke on the same rename: the `skills` junction, the `memories` junction, and - hours earlier, for the same underlying reason - a dashboard worktree left on a merged branch. When adding a path-dependent mechanism, ask what happens when that path moves, and prefer a check that self-heals over one that reports success.
- Worked example: "Never add an agent as a commit co-author" was prose only, and ten commits carried the trailer before the history rewrite stripped them. It is now `git-hooks/commit-msg`, wired by `install.ps1`. Enforcement that rewrites beats enforcement that rejects: a hook that blocks the commit teaches the author to reach for `--no-verify`.
- Do not pass a regex to `awk` with `-v`. awk expands escape sequences in a `-v` assignment, so `\[bot\]` arrives as the character class `[bot]` and matches almost every address. Write the pattern as a regex constant in the awk program. This was a live bug in the first draft of `commit-msg`, caught only by testing it against a message with human co-authors.
