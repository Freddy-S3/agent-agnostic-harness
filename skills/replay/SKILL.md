---
name: replay
description: "Run the software factory's local replay evaluator for a project manifest. Use when the user invokes replay or closing needs regression evidence for a factory change."
user-invocable: true
---

# Replay

Accept `$replay [case-id]` or `$replay --manifest <path> [case-id]`.
Resolve the target project from the current task and use its worktree, including proposed changes when closing is evaluating them.
Use the project manifest named in its instructions or ledger, then a root `factory.manifest.json` if present.
For the harness repository itself, fall back to `templates/software-factory/factory.manifest.json`.
If no manifest can be resolved, report the missing manifest and link to the harness template.

Read each selected case command and confirm it is in scope before execution.
Manifest commands are executable local work and do not grant permission for unrelated effects.
Resolve the evaluator at `tools/evaluate-factory.ps1` in the harness checkout that supplies this skill, or use the task worktree's evaluator when that worktree is the harness under test.
Always pass the target worktree explicitly as `-RepoRoot`.
Choose a unique report path outside version control and keep the report for the handoff.

```powershell
pwsh -NoProfile -File <evaluator> -RepoRoot <worktree> -Manifest <manifest> -Output <report>
```

Pass `-CaseId <id>` when one case is selected.
Read the report even if the evaluator exits nonzero.
Report passed, failed, and timed-out case counts, elapsed time, and the report path.
If the evaluator exits before writing a report, report its error.
Compare results to a prior run only when the cases and measurement conditions are comparable.
