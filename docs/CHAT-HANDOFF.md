Continue the agent-agnostic-harness project.

Purpose: Resume coordination
Repository: agent-agnostic-harness
Current branch: codex/investigation-reports
Read AGENTS.md before acting.
No docs/PROJECT-CONTEXT.md exists yet; use docs/PROJECT-CONTEXT-TEMPLATE.md from the harness when creating one.

Result: PR #86 adds the asynchronous `/investigation` workflow, evidence-linked report contract, fixtures, and focused validator.
Verification: Focused report validation, existing converge, queue-CAS, and skill-cache tests, plus `git diff --check`, passed.
Remaining risk: Q18 remains open on whether investigation tickets also create companion wiki drafts.
Next action: Review PR #86, then decide whether to merge it and settle Q18 in the Agent Operations Console queue.

Operating rules:
- Keep work agent-agnostic and use repository files, queue, tracker, and pull requests as the source of truth.
- Inspect the repository before planning or editing.
- Keep this chat focused on coordination; create a separate outcome chat for implementation.

Recent commits:
- b9b8bff Add evidence-linked investigation report workflow
- 17e094e Give every job card a Glassdoor link and stop ranking unrated employers as bad (#85)
- bc23442 Track the daily job-discovery task prompt as a template (#84)

Working-tree status:
- Clean

First action: read the repository guidance and report the current goals, blockers, and next recommended action.
