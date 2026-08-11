# Harness TODO

Open work on the harness itself. One line per item, with the reason it exists, so a cold
reader can pick it up without the conversation that produced it.

**This repository is public.** The real backlog lives outside git, in the queue directory
resolved by `skills/queue/SKILL.md` (`~/.claude-harness/queue/` by default). Items there
carry real project names, real incident notes, and open decisions that are not for a public
page. So: this file records *harness engineering work*, and points at the queue by item
title for anything whose detail is private. Do not copy queue content in here. Two items in
the current backlog exist precisely because that line was crossed before.

Cross-reference discipline: when an item here is closed, close it in the queue too, and
vice versa. Two lists that drift are worse than one.

## Open

1. **Add a "BLOCKED ON YOU" footer to `/status-report`.**
   Requested directly by Faruk. The skill already surfaces blocked items, but not the
   *blocking relationship*: which single action unsticks a thing, and what is queued behind
   it. Add a closing section, after `NEEDS PC` / `NEEDS PHONE`, with one line per blocker
   carrying three fields - the blocker, its one-line fix, and which items it gates.
   Motivating case: a queue item sat blocked for hours on one missing local binary. The
   blocked reason was recorded correctly, but nothing surfaced it as *the* blocker whose
   removal released three downstream items, so a reader had to reconstruct that chain
   across two files by hand. The format should do that work.
   Constraints: derive it from the two files `/status-report` already reads, do not add a
   third source of truth; omit the section entirely when nothing is blocked, consistent with
   the existing "do not print DECISIONS (0)" rule; and print a blocker whose fix is unknown
   with the fix field reading "unknown, needs investigation" rather than dropping the line -
   silently omitting the hard ones is the exact failure this is meant to fix.
   Per the conventions in `instructions/AGENTS.md`, update `HARNESS.md` too if this changes
   what a day-to-day `/status-report` looks like.
   Queue: `QUEUE-PHONE.md`, "Add a BLOCKED ON YOU footer to /status-report".

2. **Interactive clickable skill widgets in the Claude desktop app.**
   Start with `/status-report` and `/queue` rendering clickable cards (run/skip/requeue,
   approve/reject) instead of walls of text.
   Build against the real skill inventory - enumerate `skills/*/SKILL.md` - not against
   whichever subset carries a given frontmatter flag today. See item 3 for why that
   distinction matters.
   Queue: `QUEUE-PHONE.md`, "Interactive clickable widgets for harness skills".

3. **Skill frontmatter coverage.**
   `skills/` holds 34 skill directories. Exactly 13 carry `user-invocable: true`; 14 carry
   `disable-model-invocation: true`. The portfolio site's skill catalog was reported as
   showing a wrong count, but it is not a badge bug - the site faithfully reports a field
   that 21 skills simply omit. The defect is in the frontmatter.
   Backfill `user-invocable: true` where it belongs, as its own PR separate from item 2.
   Doing it alone is useful: the site's number moving is independent evidence the fix
   worked.

4. **Decide whether `/triage`, `/to-spec`, and `/to-tickets` stay model-blocked.**
   All three carry `disable-model-invocation: true`, which means `/freddy` - whose entire
   job is routing into the right workflow - cannot route into most of the planning and spec
   workflows. Faruk has to invoke each by name, which defeats the router.
   The flag exists for a real reason (stop the model wandering into a heavyweight ceremony
   workflow unprompted), so this is a trade-off, not an obvious bug. Needs Faruk's call;
   after that it is a frontmatter-only PR.
   Queue: `QUEUE-PHONE.md`, blocked decision.

5. **Push the public mirror; it is stale.**
   `SKILL.md` bodies for `learn`, `queue`, and `status-report`, plus
   `instructions/AGENTS.md`, have moved since the last sync, so the published skill catalog
   still describes the old single-queue model and a `queue/QUEUE.md` that no longer exists.
   Two hard exclusions, and they are the reason this is a read-the-diff job rather than a
   blind mirror: never sync `skills/pdev/` (gitignored, private career material), and never
   sync real queue contents - only the sanitized `queue/QUEUE-PC.example.md` and
   `queue/QUEUE-PHONE.example.md` belong here. Check both against the actual diff, not
   against intent.
   Queue: `QUEUE-PHONE.md`, "Push the harness public mirror".

6. **Attribution consent for a named third party in `skills/opinions/SKILL.md`.**
   That skill attributes viewpoints to a real person by first name, and it is surfaced on a
   public catalog. Either get explicit consent or anonymise to a role. Flagged separately
   from the other open decisions because the exposed party is not Faruk, so "accept it" is
   not a call he can make alone.
   Queue: `QUEUE-PHONE.md`, blocked decision.

7. **Two history-exposure decisions on this repository.**
   Both are recorded in `QUEUE-PHONE.md` as blocked decisions with their options spelled
   out. Deliberately not detailed here - writing them out in a public file would repeat the
   original mistake. Each comes down to the same three options: rewrite history and
   force-push, flip the repo private, or accept.

## Recently closed

- Enforced the no-agent-co-author rule as a `commit-msg` hook rather than prose (PR #7).
- `/learn` self-improvement skill, grounded in a real first run (PR #6).
- `install.ps1` writes `CLAUDE.md` as an import stub instead of copying `AGENTS.md` (PR #2).
- Split the backlog into PC-gated and phone-gated queues and moved real contents out of git
  (PR #10).
- Untracked the private career skill and its references (PR #11). Note this is a
  delete-forward only; see item 7.
