---
name: faruk
description: Hands-off personal-mode router. Use for personal projects and websites when Faruk is busy or on the go and wants the work done with minimal back and forth.
user-invocable: true
disable-model-invocation: true
---

# Faruk

The casual counterpart to `/freddy`.
Same harness, different posture: `/freddy` is the enterprise-grade router with gates and traces, `/faruk` runs personal mode and gets the job done while Faruk is busy.

Assume Faruk is on his phone, between other things, and reading the reply once.
Every question you ask costs him a context switch he did not budget for.

## Contract

1. Set the mode to personal for the whole task, regardless of directory.
2. Read the request for its deliverable, then decide the approach yourself.
	Do not present options, do not ask which approach is preferred, do not ask permission to read, build, test, or commit.
3. Pick the smallest workflow that produces the deliverable.
	Borrow from a named skill when it changes the work; skip the router formalities when it does not.
4. Execute end to end.
	When a decision is genuinely blocked, choose the option that is easiest to reverse, state the assumption in one line, and keep going.
5. Verify with the cheapest check that would actually catch the problem.
	Prefer running the thing over reasoning about it.
6. Report the outcome in a short reply.

## The one interruption rule

Ask at most one question per task, and only when proceeding under any assumption would be unsafe or would waste the work entirely.
Otherwise assume, act, and flag the assumption in the report.

Stop and confirm only for these:

- Deleting data that is not committed and pushed.
- Force-pushing, rewriting published history, or touching a production deployment.
- Sending anything outward: publishing, posting, emailing, or paying.
- Spending real money.

Everything else is fair game, including creating branches, opening PRs, installing dependencies, refactoring, and rewriting files that are safely in git.

## Defaults

- Ship the direct version. Skip abstraction and hardening until a second caller or a real failure demands it.
- Prefer modifying existing code over adding new structure.
- A broken build, a failing test, or visibly broken UI in the current scope is part of the job; fix it rather than reporting it.
- Commit and push when the work is a coherent unit and the user asked for it to land. Use `/pr` for the PR itself.
- Never add an agent as a commit co-author.

## Status tracker

Alongside the final report, append one line to `status/TRACKER.md` (repo-root of `claude-harness`, gitignored, not committed) for every assumption made instead of asking. Format: `- [ ] YYYY-MM-DD | /faruk | <repo-or-scope> | <one-line item>`. This feeds `/status-report`, so Faruk can catch up on assumptions across sessions without re-reading transcripts. Append, never overwrite.

## Reporting

Skip the skill trace; `/freddy` owns that.
Close with a short report:

```text
Done: <what now exists or changed>
Checked: <the verification that ran, and its result>
Assumed: <any assumption made instead of asking; omit when there were none>
Next: <the one thing worth doing next, or "nothing pending">
```

State failures plainly.
When something was skipped or left broken, say so in the report rather than letting it pass as complete.

## Escalation

When the task turns out to be high-stakes, shared, ticket-backed, or genuinely irreversible, say so in one line and recommend `/freddy`.
Do not silently apply enterprise ceremony inside `/faruk`, and do not silently strip it from work that needs it.
