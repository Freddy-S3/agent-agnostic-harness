# Queue

`/queue` is the backlog for ideas too large to run inline — see `skills/queue/SKILL.md`
for the full contract. This directory documents one design decision worth calling out:
the queue is split in two, by what gates the work.

## Why two queues

The user gets limited PC time per day but plenty of phone time. A single queue means a
phone-doable item (research, drafting, a PR waiting on review) sits behind whatever's
next in line even when it needs nothing but a thumbs-up, and a PC-bound item (a local
install, a build he needs to watch) can't jump ahead just because he happens to be at
his desk. Splitting by gate — not by project, not by priority — lets each queue move at
the pace its own approval channel actually allows:

- **`QUEUE-PC.md`** — needs local toolchain, software installs, folder-access
  approvals, or eyes on a running build.
- **`QUEUE-PHONE.md`** — research, drafting, review, PR merges, anything an agent can
  drive to completion with only phone-based approval.

Items move between the two when reality doesn't match the original classification — a
blocked PC item can have a phone-doable half worth splitting out. See either file's
header for the move mechanic; it's just cut-and-paste of a self-contained `## ` entry
plus a one-line log note explaining why.

`/status-report` reads both files and reports them as separate groups (NEEDS PC /
NEEDS PHONE) so a phone check-in surfaces exactly what a thumbs-up can unblock, without
mixing in items that need the desk.

## Declaring answer options on a blocker

Any item that needs a decision from Faruk carries an `Options:` field: a bullet list of the
answers that actually fit the question it is asking.

```
Status: pending
Options:
- Branch, commit, push, PR
- Show me the diff first
- Leave it
```

`tools/queue-dashboard` renders those as one-click choices. Without them a blocker offers
only a free-text box, because a generic approve/reject is not an answer to "which resume
rendition is the default" and pretending otherwise wastes the decision.

The field belongs next to `Status:` and above `Log:`. Writing it is the job of whichever run
logs the blocker, because that run is the one that knows what the alternatives are; a later
reader has to reconstruct them from prose. Options are also the cheapest handoff to the next
agent: they record which paths were considered, not just which was chosen.

## Declaring downstream impact

When one queue item must be answered or completed before another can move, add a
`Depends on: <exact queue item title>` line to the dependent item.
The dashboard reads both queue files on every poll, follows these dependency edges, and
puts the item with the largest unfinished direct and transitive fan-out first.
It shows the count on the source card without changing the hand-authored file order.
Use one `Depends on:` line per prerequisite.
Keep the title exact and unique; unresolved or ambiguous references are ignored rather
than guessed.

```
## Choose the deployment target
Status: blocked
Blocked reason: Pick the hosting target.
Options:
- Use Cloudflare Pages
- Use Vercel

## Deploy the dashboard
Status: pending
Depends on: Choose the deployment target
```

## Write the decision, not its history

`Blocked reason:` and `Options:` are read cold, on a phone, by someone who has never seen the
session that wrote them. They must state the whole decision on their own: what is being asked,
what it affects, and what happens either way. `Log:` is the other audience - dates, measurements,
what a previous run concluded, what changed. Keep them apart. Audit prose written into the
decision field is why the dashboard filled with items nobody could action.

Do not write into `Blocked reason:` or `Options:`: back-references with no referent (`the four
fixes`, `see above`, `as previously noted`), continuity claims (`unchanged since`, `restating the
earlier answer`), bare dates pointing at earlier prose (`the 2026-08-11 partial answer`), or any
narration of why the item was rewritten. Each option is a complete sentence describing what it
does, because the button label is all the reader gets - `Apply all four fixes` names nothing.

The dashboard renders `blockedReason || asks[0] || ''`, so a good `Blocked reason:` is what
reaches the card. Do not leave a question in a log line and expect it to be seen.

Two format rules, because the parser drops what it cannot match and never says so:

- Write options as `- ` bullets, one line each. A numbered list produces no buttons at all,
  and a bullet that wraps onto a second line silently truncates every option after it.
- Keep `Blocked reason:`, `Options:`, `Repo:` and `Added:` contiguous, with no free prose
  between them. `Blocked reason:` runs until the next `Field:` line, so prose placed under it
  is swallowed into the description and lands on the card.

The full rule, with a worked good/bad example taken from a real item, is in
`instructions/AGENTS.md` under the unpersisted-decision rule.

## Where the real queue files live

`QUEUE-PC.md` and `QUEUE-PHONE.md` are gitignored and not tracked in this repo. Real
backlog content — project names, notes on real incidents, anything specific to one
person's actual work — has no business in a public git history. The skills
(`skills/queue/SKILL.md`, `skills/status-report/SKILL.md`) read from a configurable
path: an env var if set, falling back to `~/.claude-harness/queue/` outside any git
repo, falling back to this directory (`queue/`) if files exist here — gitignored either
way, so an accidental `queue/QUEUE-PC.md` in this directory never gets committed, it
just isn't the primary location.

What *is* tracked here, because it's the actual portfolio artifact:

- The `/queue` and `/status-report` skill mechanics that know about the PC/phone split.
- `QUEUE-PC.example.md` / `QUEUE-PHONE.example.md` — invented illustrative items
  showing the pattern in use, safe to publish.
- This file.
