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

`/queue` is the backlog for ideas too large to run inline: drop an entry into `queue/QUEUE.md`, and `/queue` works through pending items in `/sleep` posture, one per run, resuming automatically on the next scheduled firing after a usage-limit reset.

### New project convention

When Faruk describes a new project idea rather than a change to an existing one, treat it as a request to found a new sibling repo, not to extend an existing one:

1. Create `C:\Users\Faruk\Repo\<new-repo-name>` alongside `claude-harness` and `Portfolio-Website`, pick the name from the idea, and `git init` it.
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

Load only files that will be changed or directly referenced.
Prefer targeted reads.
Give subagents only the assigned sub-task, handoff artifact, and reference path.
Treat each completed phase handoff as the context summary; do not carry unnecessary history forward.

## Self-Improvement

Update the relevant native instruction or skill immediately when the user corrects style, architecture, or approach; when a task reveals missing reusable context; or when a skill is ambiguous.
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
| Open or update a GitHub pull request | `/pr` |
| Capture session knowledge | `/closing` |
| Build a throwaway design prototype | `/prototype` |
| Gather missing stakeholder knowledge asynchronously | `/to-questionnaire` |
| Write as Freddy | `/voice` |
| Create or edit a Confluence page | `/wiki` |
| Make decisions informed by Freddy's viewpoints | `/opinions` |
| Produce a Mermaid architecture diagram | `/architecture-diagram` |
| Work on career materials | `/pdev` |

## General Guidelines

- Use plain hyphens, not em dashes.
- Never add an agent as a commit co-author.
- Never leave work sitting on a branch without a pull request. The moment a branch carries one commit that is not on the default branch, open a PR with `/pr`; push every later commit to that same PR and update its body rather than committing quietly. Check for an existing open PR before opening another.
- Never manually modify generated files or `CHANGELOG.md` files.
- Put each full sentence on its own line when substantially editing long Markdown files.
- In delivery mode, prefer quality, simplicity, robustness, scalability, and long-term maintainability over development cost.
- In personal mode, prefer simplicity and speed: ship the direct version, skip abstraction and hardening until a second caller or a real failure demands it.
- In personal mode, do not ask for permission to proceed, to read a file, to run a build or test, or to pick between comparable approaches. Choose, act, and report what you chose.
- For a request to complete a ticket, authenticate using MCP to the configured Jira instance (`JIRA_URL`) and Confluence instance (`CONFLUENCE_URL`) before planning or implementation; if either authentication fails, stop immediately and do not proceed. When neither is configured, treat the work as ticketless and stay local rather than blocking.
- When retrieving any Jira ticket, request and read all comments as part of the requirements before planning or implementing.
- Treat ticket comments as acceptance criteria, and surface conflicts between a comment and the ticket description before proceeding.
- For every pull request review, retrieve and read all available comments and activity before forming findings; treat them as review context and acceptance criteria.
- Reproduce bugs as close to the end-user experience as possible before changing code.
- Treat visibly broken UI, lint failures, flaky tests, and test failures as engineering defects worth resolving when they are in scope.
- Never report a change to HTML, CSS, or client-side JS as done without rendering the page in a real browser; run `/browsertest` and say so plainly when it has not been rendered.
- Prefer modifying existing code, follow the local style, minimize diff noise, and keep comments sparse.

## Skill Harness Conventions

### What "add to the harness" means

Treat the phrase as covering every artifact below, not just the one that is convenient.
A change that lands in only some of them is half-applied and will drift.

The harness lives at `~/Repo/claude-harness`, alongside the projects it serves.
Always edit it there, never the `~/.claude` projection.

| Artifact | Update when |
|---|---|
| `skills/<name>/SKILL.md` | The change is a workflow. Create the directory for a new skill. |
| `instructions/AGENTS.md` | The change adds a skill to the Native Skills table, or adds or alters a standing rule. |
| `HARNESS.md` | The change affects day-to-day use: the selection table, the gates, or a worked example. |
| `README.md` | The change adds a new top-level path or alters install behaviour. |
| Git | Always. Commit in `claude-harness` with a real message, and push. An uncommitted harness edit is lost the next time the machine is reimaged. |

Verify a new skill is actually discoverable before reporting it added: `skills/` is a
directory junction into `~/.claude`, so a new `SKILL.md` registers live, but a skill
absent from the `AGENTS.md` table will not be routed to.

- When adapting an imported harness, validate that the native files neither mention nor require the source archive before treating that archive as removable.
- This harness is linked into `~/.claude`, not copied. `skills/` and `memories/` are directory junctions, so an edit on either side is the same file. `~/.claude/CLAUDE.md` is a stub that imports this file with `@~/Repo/claude-harness/instructions/AGENTS.md`, so it is read live and never needs syncing.
- A single file cannot be linked reliably on Windows: symlinks need admin or Developer Mode, and a hard link does not survive an editor that writes by replace-and-rename. The import stub sidesteps both, because the stub itself is never edited.
- Edit `instructions/AGENTS.md` and restart the host. Never edit `~/.claude/CLAUDE.md`; it holds only the import.
- `~/.claude/settings.json` is not managed by this repository and stays a local file.