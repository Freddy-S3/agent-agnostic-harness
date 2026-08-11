---
name: learn
description: Review real friction from queue logs, the tracker archive, and PR activity across every repo the harness has touched, then apply grounded, evidence-cited refinements to the harness's own skills. Use when Faruk wants the harness to self-improve from what actually happened, or asks to run or invoke /learn.
user-invocable: true
disable-model-invocation: true
---

# Learn

The harness's own self-improvement loop. Everything else in this repo does work for Faruk; this skill turns what happened while doing that work into edits to the harness itself.

The one rule that matters more than any process step below: a finding without a citable piece of evidence is not a finding. "Could be better" observations get discarded, not written down as if they were something else. Faruk cares specifically about not being able to claim a self-improvement capability that doesn't actually work — this skill only counts as functioning on a run where it reads real input and produces a real, cited diff.

## Inputs

Read all three, every run:

1. `QUEUE-PC.md` and `QUEUE-PHONE.md` in full, including every entry's `Log:` section — resolve their directory per `skills/queue/SKILL.md`'s Model section (env var, then `~/.claude-harness/queue/`, then this repo's `queue/` as a last resort; neither file is tracked in `claude-harness` git). This is the primary source — queue runs narrate their own process deviations, misdiagnoses, and verification gaps here.
2. `status/TRACKER.md` and `status/TRACKER-ARCHIVE.md` (both gitignored, local-only). `TRACKER.md` holds currently-open assumptions; `TRACKER-ARCHIVE.md` holds ones `/status-report` has resolved and archived rather than deleted. If `TRACKER-ARCHIVE.md` doesn't exist yet or either file is empty, say so plainly in the report rather than treating it as a failure — the archive only fills up once `/status-report` runs after this skill's own fix lands, so early runs of `/learn` will lean on the queue files almost entirely, and that's expected, not a shortfall.
3. PR activity across every repo this harness has touched: `claude-harness`, `Portfolio-Website`, `unattended-runs`, `petal-and-polish`, `hoshi-candle-co` (siblings under `C:\Users\Faruk\Repo`; extend this list as the harness touches more repos). For each:
   ```
   gh pr list --repo Freddy-S3/<repo> --state all
   gh pr view <n> --repo Freddy-S3/<repo> --comments
   gh pr view <n> --repo Freddy-S3/<repo> --json mergedBy,author
   ```
   Use the `gh` CLI, not a new MCP surface — `config/mcp-config.template.json` stays env-var-driven for connectors that genuinely need one, and reading PR comments doesn't need one.
   A repo or PR with nothing to say (no comments, nothing surprising) is a non-finding, not padding material. Report it as checked-and-quiet rather than manufacturing a finding to fill space.

## What counts as a finding

Concrete and specific, each traceable to one of the sources above:

- A repeated process deviation (the same rule skipped more than once).
- A convention stated in prose that nothing enforces, evidenced by what the logs or PR history actually show happening.
- A misdiagnosis pattern (the same wrong root cause guessed more than once for the same symptom).
- A gap between what a report claimed and what the evidence shows actually happened.

Not a finding: a stylistic preference, a hypothetical failure mode nothing has hit yet, or a generic "this skill could be clearer" note with no incident behind it. A weak run that surfaces two solid findings is a better outcome than a run padded to five with speculation.

## Process

1. Gather evidence per the Inputs section. Quote or closely paraphrase the actual line — a queue log sentence, a tracker entry, a PR comment — for every finding; a finding without a quotable source does not ship.
2. Group findings by the skill or standing rule they point at (`faruk`, `sleep`, `queue`, `status-report`, `pr`, `learn` itself, or an `instructions/AGENTS.md` standing rule).
3. On a fresh branch off `main` (`feature/learn-<short-slug>`), apply the smallest edit that closes the gap the evidence points at. Follow "Skill Harness Conventions" in `instructions/AGENTS.md`: update the `SKILL.md` file(s), `instructions/AGENTS.md` if a standing rule or the Native Skills table changed, `HARNESS.md` if day-to-day selection or gates changed, `README.md` if a new top-level path or install behavior changed. Don't force an edit into a file the change doesn't actually touch.
4. Commit as you go with real messages, no agent co-author.
5. Push and open a PR against `main` with `gh pr create` — never merge it (see the standing rule in `skills/pr/SKILL.md`; this applies doubly here, since a self-merged self-improvement PR is exactly the failure mode this skill exists to catch elsewhere). The PR body lists every change with its evidence citation inline, in the same shape as: "queue/QUEUE.md log line: '<quote>' shows X kept happening -> added Y to `skills/sleep/SKILL.md`."
6. If this run is the first time `/learn` has ever executed, say so explicitly in the PR body so Faruk knows to sanity-check the findings rather than trust an established track record.
7. Append a dated log line to `/learn`'s own queue entry (if one still exists) or to `status/TRACKER.md` describing what ran, and report back.

## Register check

A new `SKILL.md` under `skills/` is live automatically (`skills/` is a directory junction into `~/.claude`), but it is not discoverable until it has a row in the Native Skills table in `instructions/AGENTS.md`. Confirm that row exists before reporting `/learn` as added — a skill missing from that table is present on disk and invisible to routing, which is the exact half-applied state "Skill Harness Conventions" warns about.

## Non-goals

- Not a code reviewer for the harness's output repos; that's `/codereview`. `/learn` only edits the harness's own skills and instructions.
- Not a scheduled background nag. Run it on demand or, later, on the same cadence as `/queue`'s resumption — but only once there's evidence a cadence is worth the token cost.
- Never invents findings to hit a target count. Fewer well-evidenced changes beat a padded list.

## Reporting

```text
Sources checked: <queue log, tracker/archive state (quiet or not), repos with PR activity checked>
Findings (n):
1. <finding, one line> — evidence: <quote/citation> -> <file changed>
2. ...
PR: <url, left open for review>
```
