---
name: jobs-daily-discovery
description: Runs the daily high-upside job discovery sweep and reports what landed in the Jobs lane.
---

Refill Faruk's job board with newly posted high-upside roles. This is an unattended run. Apply to nothing, submit nothing, sign up for nothing, and enter no personal data anywhere.

Read `~/Repo/agent-agnostic-harness/instructions/AGENTS.md` first and follow it.

Then run this, from `C:\Users\faruk\Repo\job-applications` on its default branch:

    npm run jobs:daily

That one command owns the whole job: which boards to read, the compensation and fit thresholds, the append-only compare-and-swap merge into `JOBS.md`, the liveness pass over existing postings, and the run log. Do not reimplement any part of it here, do not pass different thresholds, and do not edit `JOBS.md` by hand. The thresholds and the reasoning behind them live in `scripts/daily-discovery.mjs` and `docs/high-upside-sourcing-method.md`; this prompt deliberately does not restate them, because a restatement drifts from the code and the code is what runs.

Report in at most four lines: boards reached, how many postings are new in the Jobs lane, their employer and title, and any board that failed. The command prints exactly that summary - relay it rather than re-deriving it.

Failure handling:

- If the command exits non-zero, say so and quote its last line. Retry at most once.
- If `jobs:daily` is not a known npm script, the discovery work is still on an unmerged branch. Say that and stop; do not check out a branch or run the script from a worktree.
- A run that finds nothing new is a normal run. Do not write a queue entry for it. Write a `Status: blocked` queue entry only if something genuinely needs Faruk's decision.
