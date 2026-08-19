---
name: faruk
description: Hands-off personal-mode router. Use for personal projects and websites when Faruk is busy or on the go and wants the work done with minimal back and forth.
user-invocable: true
---

# Faruk

`/faruk` is the personal-mode adapter over the shared router contract in `ROUTER-CONTRACT.md`.
`/freddy` and `/sleep` load that same contract and apply their delivery and unattended overlays.
This makes shared routing changes carry over to all three routers without making Faruk invoke another router as a second step.

Faruk bypasses delivery ceremony, not the selected owner's workflow, validation, persistence, or safety rules.
It bypasses human approval gates in the workflow, not host-level tool permissions or security controls.
Read `ROUTER-CONTRACT.md` first, then apply this personal overlay for the whole task.

## Personal overlay

1. Set `mode: personal` and `director: /faruk` in the task ledger, regardless of directory.
2. Select and load the execution owner from the shared contract, then apply that owner's `SKILL.md` directly.
3. Run end to end without delivery approval gates, operational traces, or unnecessary progress pauses.
4. When a decision is ambiguous, choose the easiest-to-reverse option, record the assumption, and continue.
5. Verify with the cheapest check that would actually catch the problem.
6. Preserve the shared route across follow-ups and use `REALIGN` to recover from the ledger rather than re-routing.

## The one interruption rule

Ask at most one question per task, and only when every reasonable assumption would be unsafe or would waste the work entirely.
Otherwise assume, act, and flag the assumption in the report.

Stop and confirm only for these:

- Deleting data that is not committed and pushed.
- Force-pushing, rewriting published history, or touching a production deployment.
- Sending anything outward: publishing, posting, emailing, or paying.
- Spending real money.

Everything else is fair game, including creating branches, installing dependencies, refactoring, and opening pull requests.
Creating a branch, pushing its commits, and opening a pull request are repository workflow actions, not public release or personal communication.

## Broad completion authorization

When a direct task request is paired with language such as "can you do it all?" or "handle it end to end," treat it as authorization for every reversible, in-scope execution step.
Archive dirty state before resets or consolidation, preserve exact paths and commits, pull latest, restart local services, commit coherent changes, push, and open pull requests without asking the user to choose among those steps.
Surface only the remaining human judgment after local work is complete, such as reviewing or merging an open pull request.

## Defaults and recoverability

- Ship the direct version.
- Prefer modifying existing code over adding new structure.
- Fix broken builds, failing tests, and visibly broken UI that are in scope.
- When work creates or updates a non-default branch, commit and push coherent changes and open or update its pull request with `/pr`.
- Never leave a branch with unpublished work and no pull request unless a stop condition forbids the outward action; record that block.
- Never add an agent as a commit co-author.

## Persist decisions before reporting

Personal mode trades approval gates for speed, so every assumption made instead of asking must survive the session.

Before the final report, write every open decision, blocker, and assumption into the queue file matching its gate (`QUEUE-PC.md` or `QUEUE-PHONE.md`, resolved per `skills/queue/SKILL.md`) as a `## ` entry with `Status: blocked`, a complete `Blocked reason:`, and an `Options:` list phrased as instructions Faruk could give.
The blocked reason and every option must be readable cold on a phone, while dates and history belong in `Log:`.
Write the same items to `status/TRACKER.md`, one line each: `- [ ] YYYY-MM-DD | /faruk | <repo-or-scope> | <one-line item>`.
Read both writes back before reporting.
If either write is refused, report the exact path and actual error instead of claiming it landed.

The queue file is the primary record because Faruk's dashboard parses those files and nothing else.
This requirement also applies to subagents and parallel tasks; telling an orchestrator is not persistence.

## Reporting

Skip the operational trace; `/freddy` owns that delivery-only output.
Close with:

```text
Done: <what now exists or changed>
Checked: <the verification that ran, and its result>
Assumed: <any assumption made instead of asking; omit when there were none>
Next: <the one thing worth doing next, or "nothing pending">
```

State failures plainly.
When something was skipped or left broken, say so in the report.

## Escalation

When a task turns out to be high-stakes, shared, ticket-backed, or genuinely irreversible, say so and recommend `/freddy` rather than silently changing posture.
