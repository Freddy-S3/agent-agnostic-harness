# Idea Queue — PC (EXAMPLE)

This is a template/example, not real backlog content. It exists to show the shape of
the PC queue and how `/queue` and `/status-report` read it — the actual queue files
(`QUEUE-PC.md` / `QUEUE-PHONE.md`) are gitignored and live outside this repo; see
`queue/README.md` for why and where.

Items that need Faruk physically at his PC: local toolchain (Node/Python/etc.),
software installs, folder-access approvals, a running build he needs eyes on, or a
browser session driven through his own logged-in Chrome.

Same format and rules as `queue/QUEUE-PHONE.example.md` — see that file's header for
the shared mechanics (statuses, `/queue` contract, resuming).

**Moving an item to the other queue:** cut the whole `## ` entry (including its `Log:`)
and paste it into the phone queue, or vice versa. No format change needed — a queue
entry is self-contained. Do this when a blocked PC item turns out to have a
phone-doable half worth splitting out; leave a one-line `Log:` note on the move.

Statuses: `pending` -> `in-progress` -> `done` | `blocked`.
An `in-progress` item left over from a prior run means that run was interrupted (usage limit, crash, or manual stop); `/queue` resumes it rather than restarting.

---

## Install a system-wide runtime toolchain

Status: blocked
Repo: machine-wide
Added: 2026-01-01
Blocked reason: the installer needs a reboot first — a stuck installer process is
holding a system service and a non-admin shell can't clear it. Flag it, don't retry in
a loop.

Log:
- 2026-01-01: queued, root-caused the installer failure, documented the exact unblock
  steps for whoever runs this next.

---

## Rebuild the personal-site resume PDF pipeline

Status: pending
Repo: C:/Users/example/Repo/personal-site
Added: 2026-01-02

Install the PDF toolchain locally, rebuild the resume, and verify it holds at the
target page count before opening a PR.

Log:
- 2026-01-02: queued, PC — needs a local binary install and eyes on the rendered
  output, not just a diff review.

---

## Supervised job-board profile sync

Status: pending
Repo: n/a (external job boards)
Added: 2026-01-03

Run through the user's own logged-in browser session to sync a public profile to the
latest resume content. Needs local supervision per site, not just after-the-fact
approval, since a bulk edit can silently reorder pinned fields.

Log:
- 2026-01-03: queued, PC — needs the user's own logged-in browser and live
  supervision of each edit.
