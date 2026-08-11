# Idea Queue — Phone/Anytime (EXAMPLE)

This is a template/example, not real backlog content. It exists to show the shape of
the phone queue and how `/queue` and `/status-report` read it — the actual queue files
(`QUEUE-PC.md` / `QUEUE-PHONE.md`) are gitignored and live outside this repo; see
`queue/README.md` for why and where.

Items an agent can drive to completion with only phone-based approval: research,
drafting, review, PR merges, CI-verified changes — nothing that needs the user's local
toolchain, a software install, or eyes on a running build.

Same format and rules as `queue/QUEUE-PC.example.md`. Drop larger ideas here (or in the
PC queue, whichever gate fits) as new `## ` entries, in any order. `/queue` works items
top to bottom, oldest pending first, and rewrites the file it's working in place as
status changes.

**Moving an item to the other queue:** cut the whole `## ` entry (including its `Log:`)
and paste it into the PC queue, or vice versa. Leave a one-line `Log:` note on the move.

Statuses: `pending` -> `in-progress` -> `done` | `blocked`.
An `in-progress` item left over from a prior run means that run was interrupted (usage limit, crash, or manual stop); `/queue` resumes it rather than restarting.

---

## Fix a stale doc claim about CI coverage

Status: done
Repo: C:/Users/example/Repo/personal-site
Added: 2026-01-01

A handoff doc claimed a test suite runs in CI; the workflow file had no such step.
Added the missing CI step and a manifest listing the actual dependencies, which had
only existed in docstrings.

Log:
- 2026-01-01: queued, phone — a CI-workflow/manifest edit; verification is the CI run
  itself, driven and reviewed from a phone via the PR.
- 2026-01-01: done. PR opened, CI green.

---

## Write three seed blog posts for a new project

Status: pending
Repo: C:/Users/example/Repo/new-blog
Added: 2026-01-02

Draft three posts in the established voice, open a PR for review.

Log:
- 2026-01-02: queued, phone — pure drafting/review, no local build required.

---

## Build a small dashboard widget for the harness skills

Status: pending
Repo: C:/Users/example/Repo/harness
Added: 2026-01-03

Agent-side build work reviewable and approvable from a phone via the PR diff.

Log:
- 2026-01-03: queued, phone — no local install required to review or merge.
