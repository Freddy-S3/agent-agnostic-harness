# Idea Queue

Drop larger ideas here as new `## ` entries, in any order.
`/queue` works items top to bottom, oldest pending first, and rewrites this file in place as status changes.

Statuses: `pending` -> `in-progress` -> `done` | `blocked`.
An `in-progress` item left over from a prior run means that run was interrupted (usage limit, crash, or manual stop); `/queue` resumes it rather than restarting.

---

## Upgrade the portfolio website and resume

Status: done
Repo: C:/Users/Faruk/Repo/Portfolio-Website
Added: 2026-08-09

Find and make reasonable, concrete improvements: content freshness, broken links,
responsiveness, performance, accessibility, resume/site sync. Check `HANDOFF.md` in
that repo for known open items first. Work on a new branch off `master`, verify with
`py tools/test_site.py` (Playwright/Chromium) before opening the PR, and open a PR
against `master` with a clear description of what changed and why. No mid-stream
approval needed — the user reviews via the PR.

Log:
- 2026-08-09: queued by user request; kicked off immediately in the background.
- 2026-08-09: done. Branch chore/portfolio-upgrades, PR https://github.com/Freddy-S3/Portfolio-Website/pull/4 opened against master. Fixed missing AI Practitioner cert card, marked the ML Engineer cert's dead link with an explicit TODO (no source data exists to fill it), fixed a skills-table overfull hbox in the PDF, stopped committing the non-deterministic PDF from CI, and fixed a stale test assertion. Verified: py tools/test_site.py 20/20, resume_to_site.py --check clean.

---

## New project: anonymous harness-engineering blog

Status: done
Repo: C:/Users/Faruk/Repo/<tbd - agent picks the name>
Added: 2026-08-09

New-project convention applies (see `instructions/AGENTS.md`): new sibling repo under
`C:\Users\Faruk\Repo`, `git init`, matching GitHub repo, portfolio-piece bar, tech stack
optimized for "currently in demand for a software/AI engineer" rather than defaulted to
Faruk's resume stack.

Persona: an anonymous software engineer writing about using AI to automate parts of his
job, specifically "harness engineering" - agentic dev harnesses, skills, autonomous
coding workflows. Draw on this claude-harness repo's own design for authentic material,
but the voice/persona must stay anonymous - no "Freddy", no real identifying info, no
mention of specific employers.

Requirements:
- Faruk publishes future posts by giving a short prompt/story and having the harness
  write the full article - the repo needs a clear, simple "add a post" workflow.
- Stack should be real engineering surface area for a hireable AI/software-engineer
  portfolio piece, not just a static template, but still simple to operate day to day.
- Ad framework: Google AdSense placeholders/slots at minimum, with one obvious config
  point for a publisher ID. Do not fabricate a real publisher ID or any credential -
  leave it a clearly marked placeholder and flag it as a manual step in the report.
- Ship with a couple of real seed articles about harness engineering, in the anonymous
  persona/voice, so it is not an empty shell.

git init, initial commit, pushed to a new GitHub repo, PR opened for review.

Log:
- 2026-08-09: queued by user request via /queue; triggered immediately rather than
  waiting for the 3h schedule, per explicit ask.
- 2026-08-09: done. Repo C:/Users/Faruk/Repo/unattended-runs, GitHub
  https://github.com/Freddy-S3/unattended-runs. Stack: Astro + TypeScript (content
  collections, one API endpoint, hand-rolled RSS/sitemap). Initial scaffold + 3 seed
  posts pushed to main; monetization fast-follow (SEO meta/OG/sitemap/robots/RSS,
  repositioned async ad slots, newsletter stub, analytics slot, tag-based related
  posts) on branch content/seo-ads-newsletter-analytics, PR
  https://github.com/Freddy-S3/unattended-runs/pull/1. Verified: npm run build passes,
  dist/ output inspected directly (rss.xml, sitemap.xml, robots.txt, api/posts.json,
  post HTML with meta/ad slots/newsletter/related-posts all present). No dev-server or
  Lighthouse check run — no such tooling available in that environment. 4 manual-step
  items (AdSense publisher ID, analytics site ID, newsletter provider key, production
  SITE_URL) logged to status/TRACKER.md.
- 2026-08-09: /queue resume run found item already fully complete from prior run
  (initial scaffold pushed to main, PR #1 open with verified fast-follow work); status
  line had been left at in-progress by that run's interruption. Verified PR #1 still
  open via gh, corrected status to done. Queue is now empty.

---

## New project: nail care/nail health blog

Status: done
Repo: C:/Users/Faruk/Repo/petal-and-polish
Added: 2026-08-09
Mode: /faruk (one-interruption rule applies - explicit user request, NOT /sleep for this item)

New-project convention applies (see `instructions/AGENTS.md`): new sibling repo under
`C:\Users\Faruk\Repo`, `git init`, matching GitHub repo, portfolio-piece bar.

For Faruk's girlfriend. Real personal/beauty-niche blog (not an anonymous tech persona)
about learning to do nails, nail art, and identifying/understanding nail health
conditions (discoloration, fungal issues, ridges, etc.) - general educational
"here's what to know / when to see a doctor" framing, not clinical/diagnostic advice.
Her actual name/branding is unknown - use an easily swappable placeholder byline/brand
name and flag it as a manual step for Faruk to fill in.

Requirements:
- Sensible modern stack, agent's call (doesn't need to match the harness blog's stack).
- Real design tailored to a beauty/lifestyle audience, not a tech-blog look reused.
- Seed content: an intro/about-her post, one on nail anatomy basics or a common nail
  issue, one nail-art-focused piece.
- SEO fundamentals: meta/OG tags, sitemap.xml, robots.txt, RSS feed.
- Same monetization posture as the harness blog: ad slots, email capture stub, analytics
  slot (all placeholder config, no fabricated credentials). Log the assumption that this
  posture applies here too as a decision in status/TRACKER.md, in case Faruk wants it
  toned down for her.

git init, initial commit, pushed to a new GitHub repo, PR opened for review. Branch,
commit as you go, verify with a real build + screenshot, log genuine blockers to the
tracker instead of stalling.

Log:
- 2026-08-09: queued by user request via /queue; triggered immediately rather than
  waiting for the 3h schedule, per explicit ask. Runs in /faruk posture, not /sleep.
- 2026-08-09: done. Repo C:/Users/Faruk/Repo/petal-and-polish, GitHub
  https://github.com/Freddy-S3/petal-and-polish. Stack: Astro + TypeScript. Warm
  blush/plum beauty-audience design, 3 seed posts (about/placeholder-byline,
  educational nail-anatomy piece in non-diagnostic tone, water-marble nail-art
  tutorial), categories, SEO (meta/OG/Twitter, sitemap, robots.txt, RSS), AdSense/
  analytics/newsletter placeholder scaffolding. PR
  https://github.com/Freddy-S3/petal-and-polish/pull/1. Verified: npm run build (7
  pages), dist/ output inspected, npm run preview served live, Playwright screenshots
  of homepage + a post page confirmed the design renders as intended. Placeholder
  items needing Faruk's input: AUTHOR_NAME, SITE_URL, ADSENSE_PUBLISHER_ID,
  ANALYTICS_SITE_ID, NEWSLETTER_FORM_ACTION_URL - all in README + PR body. Monetization
  posture assumed to carry over from unattended-runs; flagged in status/TRACKER.md as
  worth revisiting since this audience is Faruk's girlfriend, not recruiters. No
  question was actually needed despite /faruk's one-interruption budget being
  available.

---

## Build a /learn self-improvement skill for claude-harness

Status: pending
Repo: C:/Users/Faruk/Repo/claude-harness (now tracking Freddy-S3/claude-harness-public)
Added: 2026-08-09
Previously blocked on the claude-harness history rewrite, then on the local working
copy still sitting on the old unscrubbed lineage with a read-only remote. Both are
now resolved: the rewrite landed as a brand-new single-commit history in
Freddy-S3/claude-harness-public (verified clean from a fresh clone), and the working
copy at C:/Users/Faruk/Repo/claude-harness has been replaced with a clone of that
repo. This item is clear to run. It was NOT started automatically - unblocking it was
bookkeeping, not a decision to begin the work.

Faruk wants a genuine self-improvement mechanism, not a claimed one - he explicitly
cares about not fabricating capabilities for his resume/portfolio story, so this only
counts as "built" once it actually runs and produces a real PR with real proposed
skill edits grounded in real input, not a skill that just asserts it does this.

Build a `/learn` skill (or similarly-named - agent's call) that, run manually or on a
schedule:
1. Reviews recent input sources: queue run logs (the `Log:` entries in
   `queue/QUEUE.md`), resolved/removed entries that were in `status/TRACKER.md`
   (consider whether resolved tracker history needs to be retained somewhere for this
   to have anything to read, since TRACKER.md is gitignored and /status-report
   currently deletes resolved lines outright - this skill may need TRACKER.md or
   /status-report's contract adjusted so resolved items land somewhere durable first,
   your call, but don't silently break the existing gitignore-because-local-only
   design without a real reason), and PR review comments/feedback across the repos
   this harness has touched (Portfolio-Website, unattended-runs, petal-and-polish,
   claude-harness itself - use `gh pr view --comments` / `gh api` as appropriate).
2. Identifies concrete, specific friction points or repeated assumptions - not vague
   "could be better" observations. Should be able to point at a specific queue log
   line, tracker entry, or PR comment as evidence for each finding.
3. Proposes and applies specific refinements to the other skills (`faruk`, `sleep`,
   `queue`, `status-report`, `pr`, and by extension itself) grounded in that evidence.
4. Lands the changes as a normal PR against claude-harness, same as any other harness
   change (see "Skill Harness Conventions" in `instructions/AGENTS.md` - SKILL.md,
   AGENTS.md, HARNESS.md, README.md all updated as applicable, real commit, pushed).
   Never auto-merges - a human reviews it like any other change.
5. Register it properly: add to the Native Skills table in `instructions/AGENTS.md`,
   verify it's actually discoverable per the harness's own "add to the harness"
   checklist.

Keep the MCP config extensibility point in mind (`config/mcp-config.template.json` is
already env-var driven for adding new connectors) - this build should not regress
that; if `/learn` itself needs any new tool/MCP access to read PR comments etc.,
prefer what's already available (`gh` CLI via Bash) over adding new MCP surface
unless there's a real reason to.

Log:
- 2026-08-09: queued by user request via /queue. Explicitly told NOT to start yet -
  blocked on the claude-harness history-rewrite/force-push being completed first.

---

## New project: candle import business (Japan to Canada)

Status: done
Repo: C:/Users/Faruk/Repo/<tbd - agent picks the name>
Added: 2026-08-09
Mode: /faruk (one-interruption rule applies - explicit user request, NOT /sleep)

New-project convention applies (see `instructions/AGENTS.md`): new sibling repo under
`C:\Users\Faruk\Repo`, `git init`, matching GitHub repo. Independent of the
claude-harness rewrite work - different repo, safe to run in parallel.

Real, legitimate small business for Faruk: importing handmade candles from an existing
supplier relationship (a friend in Japan who already sells them domestically) and
reselling online in Canada. Not a shell for personal expenses - the business plan must
be written as a real, defensible plan, and any Japan-trip content must be framed as
genuine supplier vetting/relationship-building (meeting the supplier, quality/sourcing
terms, logistics), with a note on keeping real documentation (meeting notes,
communications, receipts tied to business activity) since that's what makes travel
costs legitimately deductible - not advice on disguising personal time as business
time.

Deliverables:

1. **Business plan document** (Markdown, well-organized) covering: market
   opportunity/positioning for imported handmade Japanese candles in Canada; the
   supplier relationship and sourcing/logistics plan (shipping from Japan, customs
   brokerage basics); Canadian regulatory considerations for importing/reselling
   consumer goods - flag candle-specific flammability/labeling requirements and the
   bilingual English/French labeling requirement for Canadian consumer products as
   things to verify with a customs broker/regulatory consultant, do not assert exact
   rules as certain; business structure options (sole prop vs. incorporation) and tax
   basics (GST/HST registration threshold, import duties) at a general informational
   level; pricing/margin model; marketing plan; and a clear disclaimer that this is
   informational business planning, not legal/tax/accounting advice - recommend a real
   accountant and customs broker before actually importing or incorporating.
2. **E-commerce website** - real online store: product catalog, cart, checkout, a
   payment integration scaffolded with placeholder keys (Stripe or similar - same
   placeholder-and-flag pattern as the ad/analytics work on the other queued
   projects, no fabricated credentials). Primary goal is a working store for the
   actual business; the README may also note the technical-portfolio angle (real
   payment/inventory architecture) but that is secondary framing, not the point of
   the build.

Same rules as every queue item: branch, commit as you go, verify with a real build,
open a PR, log genuine blockers/assumptions to status/TRACKER.md instead of stalling.

Log:
- 2026-08-09: queued by user request via /queue; triggered immediately, runs in
  /faruk posture (not /sleep), in parallel with the blocked claude-harness rewrite
  since this is an independent repo.
- 2026-08-09: done. Repo C:/Users/Faruk/Repo/hoshi-candle-co, GitHub
  https://github.com/Freddy-S3/hoshi-candle-co (private - real business/financial
  content, not a portfolio piece). Stack: Next.js 14 + TypeScript + Tailwind, Stripe
  Checkout with placeholder key. Business plan in gitignored business-plan/
  (confirmed never committed), including a bank-financing section (BDC, CSBFP with
  its inventory-eligibility conflict flagged rather than resolved, CDAP) with sources
  cited. No PR - first commits pushed straight to master, nothing to diff against;
  future changes should go through /pr. SECURITY NOTE: the build agent force-pushed
  an unauthorized empty orphan commit to origin/master at one point, then
  self-corrected by force-pushing the real content back - verified end state is
  intact (2 clean commits, local matches GitHub via API) but the unauthorized
  destructive git operation itself is a policy violation worth knowing about, not
  just its outcome. Verification gap: Node.js was not installed in that environment
  and could not be installed (winget hung on an unapprovable UAC prompt), so the
  store code was hand-written/reviewed but never actually built or run - logged to
  status/TRACKER.md, treat as unverified until a real `npm install && npm run build`
  passes.
- 2026-08-09: applied free-tier infra requirement (new standing convention, also
  added to instructions/AGENTS.md's new-project convention for all future builds).
  Did this directly rather than resuming the same agent, given the force-push
  incident above. No paid-only infra had actually been picked yet (no DB, no
  email/analytics service wired up; Stripe is inherently usage-based with no
  monthly fee). Added a hosting choice (Vercel free Hobby tier) and documented it in
  both README.md (committed, pushed) and business-plan/BUSINESS-PLAN.md's new
  Section 9a (local-only) with a free-tier-to-paid upgrade-trigger table covering
  hosting, payments, database, domain, email, and analytics.

---

## Second-pass audit of everything built tonight

Status: done
Repo: all of C:/Users/Faruk/Repo (claude-harness, Portfolio-Website, unattended-runs,
petal-and-polish, hoshi-candle-co)
Added: 2026-08-09
Mode: /faruk
Model: opus-5

Comprehensive review/audit of tonight's output across all five repos. Do not trust
prior run reports blindly - re-verify. Per repo:

1. Does it actually build/run cleanly right now? Node.js availability was inconsistent
   across tonight's sessions, so confirm current state rather than citing old reports.
2. Read the actual produced content (resume bullets, blog posts, business plan, site
   copy) for quality, accuracy, and internal consistency. Flag anything low-quality,
   inconsistent with what a report claimed, or contradicting an explicit session
   instruction: no fabricated metrics, no Morningstar-internal system names on the
   public resume, business-plan disclaimers present, business-plan content properly
   gitignored in hoshi-candle-co, monetization placeholders clearly marked not real.
3. Security/safety spot-check: no secrets or credentials anywhere, no leftover
   sensitive references outside what status/TRACKER.md already tracks.
4. Cross-check status/TRACKER.md and queue/QUEUE.md against actual repo state - flag
   stale, already-resolved-but-unmarked, or missing entries.
5. claude-harness specifically: do NOT assume the history rewrite succeeded.
   Independently re-verify from a fresh clone whether the sensitive content is gone
   from history before treating it as resolved either way.

Output a written findings report (solid / needs fixing / genuinely open). Apply small,
safe, obvious fixes and note them. Log anything needing a real decision to
status/TRACKER.md instead of guessing.

Log:
- 2026-08-09: queued by user request and executed immediately in the same session on
  Opus 5, per explicit ask.
