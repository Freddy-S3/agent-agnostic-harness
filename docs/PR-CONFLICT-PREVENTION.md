# Conflict-resistant pull request workflow

Use one pull request per logical task.

When a follow-up changes the same task, push it to the existing branch and update that pull request.

When work depends on another unfinished change, create a stacked branch from the dependency and set the pull request base to that dependency branch.

When work is independent and touches different paths, use a separate branch from the current remote base.

When independent work touches the same hotspot, serialize it or make the dependency explicit with a stacked pull request.

Before opening or updating a pull request, fetch the base branch and run `tools/check-pr-readiness.ps1`.

The check blocks stale branches, reports exact path overlaps with other open pull requests, and blocks generated coordination files.

The `Pull request readiness` check runs the same gate against every proposed head with read-only permissions.

`docs/CHAT-HANDOFF.md` is generated coordination state.

It stays local to the coordination checkout and is not feature-branch content.

The `Pull request freshness` workflow asks GitHub to update clean branches after `main` moves.

If GitHub cannot update a branch without a semantic conflict, the workflow reports the conflict for human resolution.

The `Queue factory boundary` workflow also runs for merge-group refs so required checks can participate in a merge queue.

The merge queue remains the final serialization point for changes that have passed review and required checks.

The versioned ruleset at `config/github/main-ruleset.json` keeps `main` pull-request-only, requires the queue factory check, prevents force pushes, and serializes one squash merge at a time.

It intentionally does not require a GitHub approval count because the professional `/ship` review gate is the human approval boundary for this single-owner repository.
