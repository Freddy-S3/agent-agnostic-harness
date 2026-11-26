# Conflict-resistant pull request workflow

Use one pull request per logical task.

When a follow-up changes the same task, push it to the existing branch and update that pull request.

Every pull request targets the repository default branch.

When work is independent and touches different paths, use a separate branch from the current remote base.

When work depends on another unfinished change, include the complete intended change set in one pull request to the default branch, or wait for the dependency to land before opening the follow-up.

When independent work touches the same hotspot, serialize it or update the existing pull request.

Before opening or updating a pull request, resolve the repository default branch, fetch it, and run `tools/check-pr-readiness.ps1 -BaseBranch <default> -DefaultBranch <default>`.

The check blocks non-default targets, stale branches, path overlaps with other open pull requests, and generated coordination files.

Professional-mode callers pass `-ProfessionalMode -CurrentPullRequestNumber <number>` to block enabled auto-merge before human review.

Personal-mode callers omit `-ProfessionalMode`, so GitHub auto-merge remains available for fast, automated work.

The `Pull request readiness` workflow checks the actual PR base against the repository default and runs the same readiness gate against every proposed head with read-only permissions.

The `mainline-target` status is required before a PR can merge into any non-default branch.

This prevents a green-looking feature-branch merge from being mistaken for delivery to the default branch.

`docs/CHAT-HANDOFF.md` is generated coordination state.

It stays local to the coordination checkout and is not feature-branch content.

The `Pull request freshness` workflow asks GitHub to update clean branches after `main` moves.

If GitHub cannot update a branch without a semantic conflict, the workflow reports the conflict for human resolution.

The `Queue factory boundary` workflow also runs for merge-group refs so required checks can participate in a merge queue.

When GitHub supports it for this repository, the merge queue remains the final serialization point for changes that have passed review and required checks.

The desired versioned ruleset at `config/github/main-ruleset.json` keeps `main` pull-request-only, requires the readiness check, prevents force pushes, and serializes one squash merge at a time.

The versioned ruleset at `config/github/non-default-branch-target-ruleset.json` requires both `check` and `mainline-target` before any non-default branch can accept a pull request.

It intentionally does not require a GitHub approval count because the professional `/ship` review gate is the human approval boundary for this single-owner repository.

GitHub rejected the merge-queue rule for this public personal repository through the available ruleset API.

The compatible live fallback is versioned at `config/github/main-protection-ruleset.json` and keeps pull requests, readiness, squash-only merges, and no force pushes enforced on `main`.
