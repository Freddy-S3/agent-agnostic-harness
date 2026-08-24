# New Projects and Mixed Harness/Product Work

Read this when Faruk describes a new project idea, or when a request mixes a harness change with a business or product idea.

### New project convention

When Faruk describes a new project idea rather than a change to an existing one, treat it as a request to found a new sibling repo, not to extend an existing one:

1. Create `C:\Users\Faruk\Repo\<new-repo-name>` alongside `agent-agnostic-harness` and `Portfolio-Website`, pick the name from the idea, and `git init` it.
2. Create the matching GitHub repository (`gh repo create`) and set it as `origin`.
3. Treat it as a portfolio piece: something a hiring engineer or manager would look at and come away impressed.
4. Do not default the tech stack to whatever is already on Faruk's resume. Pick whatever language/framework combination is currently in demand and salary-boosting for a software/AI engineer, and vary the choice project to project so the portfolio shows range rather than one repeated stack. State the pick and the one-line reason in the report.
5. Build it autonomously under whichever contract is active, `/faruk` or `/sleep` — no mid-build check-ins, own branch, real commits, `/pr` to open the PR for review.
6. Default every piece of infrastructure to its free tier: hosting (Vercel/Netlify/Cloudflare Pages over paid platforms), database (Supabase/Neon free tier over a paid instance), email/newsletter service, analytics, and anything else with a metered cost. Only reach for a paid tier when the project has a specific, stated requirement the free tier genuinely cannot meet. Note in the README (and business plan, if the project has one) exactly which pieces are on free tiers and what the upgrade path looks like once volume outgrows the free limits, so it is a planned step later, not a surprise.

7. Give it a root `AGENTS.md` opening with a **Harness rules - read this first** section that points at `$HOME/Repo/agent-agnostic-harness/instructions/AGENTS.md`, and a root `CLAUDE.md` containing `@AGENTS.md`. Point, never copy. See `docs/REPO-ENTRYPOINTS.md` for the block and for what each host actually reads.

This convention governs how `/queue` should treat any queued item that describes a new project, not only a one-off request.

### Mixed harness and product work

When a request combines a harness change with a business or product idea, split the work by owning repository before editing or opening a pull request.

- Harness behavior, skills, instructions, and user preferences belong in `agent-agnostic-harness`.
- Business models, product concepts, customer offers, and project documentation belong in the dedicated sibling product repository.
- Verify the local folder and `origin` remote before committing, and open each pull request against the repository that owns its changed files.
