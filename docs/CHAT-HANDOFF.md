Continue the agent-agnostic-harness project.

Purpose: Resume coordination
Repository: agent-agnostic-harness
Current branch: feat/queue-control-interactive
Read AGENTS.md before acting.
No docs/PROJECT-CONTEXT.md exists yet; use docs/PROJECT-CONTEXT-TEMPLATE.md from the harness when creating one.

Result: PR #101 adds authenticated interactive queue actions, exact worker routing, idempotent audit records, encrypted offline snapshots, and a fail-closed browser boundary.
Base update: PR #100, the resumable one-item software-factory runner, is merged into main as c17ab25ee0d68d5db1ea9ae07d1b033eb5998c1f.
Verification: Node action-contract and server-action tests, syntax checks, responsive authenticated dashboard checks, and git diff --check passed before the base update.
Remaining risk: PR #101 still needs its branch refreshed against the merged runner, then its checks must pass. Live desktop/cloud adapters, repository authorization, private hosting, DNS, TLS, and deployment remain intentionally unconfigured.
Next action: Review the refreshed PR #101, then merge it if the checks and conflict resolution are acceptable.

Operating rules:
- Keep work agent-agnostic and use repository files, queue, tracker, and pull requests as the source of truth.
- Inspect the repository before planning or editing.
- Keep this chat focused on coordination; create a separate outcome chat for implementation.

Recent commits:
- 467df04 Refresh coordination handoff
- 6a8667e Add interactive queue action control
- c17ab25 PR #100 merge commit for the software-factory runner
- 7821ec77 Give the no-agent-attribution rule a mechanism for pull requests (#99)
- 38a4f08 Make dashboard job ordering culture first (#98)

Working-tree status:
- Clean after the conflict-resolution commit.

First action: read the repository guidance and report the current goals, blockers, and next recommended action.
