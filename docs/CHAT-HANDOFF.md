Continue the agent-agnostic-harness-factory-runner project.

Purpose: Resume coordination
Repository: C:\Users\faruk\Repo\agent-agnostic-harness-factory-runner
Current branch: feat/software-factory-runner
Read AGENTS.md before acting.
No docs/PROJECT-CONTEXT.md exists yet; use docs/PROJECT-CONTEXT-TEMPLATE.md from the harness when creating one.

Result: PR #100 adds a resumable one-item software-factory runner, queue CAS replacement, checkpoints, routing, bounded handoff, human gates, and the long-running checkpoint rule.
Verification: Queue-CAS 22 assertions, queue-runner 22 assertions, converge 38 assertions, cache checks 18 assertions, rule-trigger validation, and git diff --check passed.
Remaining risk: No deployment or credential blocker remains; the local commit hook and SSH signing helper could not start because of the host's Git-for-Windows MSYS permission error, so the documented per-commit signing fallback was used.
Next action: Review PR #100, merge only with the human gate, then refresh the canonical checkout so the active schedule can use the runner.

Operating rules:
- Keep work agent-agnostic and use repository files, queue, tracker, and pull requests as the source of truth.
- Inspect the repository before planning or editing.
- Keep this chat focused on coordination; create a separate outcome chat for implementation.

Recent commits:
- be5b0d7 Implement resumable one-item queue runner
- 7821ec77 Give the no-agent-attribution rule a mechanism for pull requests (#99)
- 38a4f08 Make dashboard job ordering culture first (#98)

Working-tree status:
- Clean

First action: read the repository guidance and report the current goals, blockers, and next recommended action.
