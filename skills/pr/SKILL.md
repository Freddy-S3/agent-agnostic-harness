---
name: pr
description: "Open or update a GitHub pull request for the current work. Use when the user asks to raise, open, or update a PR, or says \"PR this\", \"ship it to GitHub\", or \"push this up for review\"."
user-invocable: true
---

# PR Skill

Take the current working state and turn it into a reviewable pull request on GitHub.
Do the whole job: branch, commit, push, and open the PR.
Report the URL.

## Standing rule

Never merge the pull request. Not with `gh pr merge`, not by any other route.
Opening the PR is the deliverable; merging it is Faruk's call, because the gh CLI authenticates as his own account and a PR "merged by Freddy-S3" that this skill also opened is not a review by anyone.
An audit across every repo this harness has touched (`agent-agnostic-harness`, `Portfolio-Website`, `unattended-runs`, `petal-and-polish`, `hoshi-candle-co`) found every PR merged by the same account that authored it, with zero review comments on any of them — the "a human reviews it" convention was never actually enforced, only asserted.
If a PR sits open waiting on Faruk, say so in the report; do not close the loop for him.

A branch must never carry commits without an open pull request.
As soon as one commit exists that is not on the default branch, there is a PR for it.

This is not a step that waits to be asked for.
Whenever work is committed, either open the PR or push onto the one that already exists,
then update that PR's body so it still describes everything the branch now contains.
Committing without doing one of those two things is an incomplete task.

## Preconditions

Run these checks first and resolve what they surface.

1. `git rev-parse --git-dir` confirms a repository.
	If there is none, stop and say so.
2. `gh auth status` confirms an authenticated CLI.
	If not, tell the user to run `! gh auth login` and stop.
3. `git status --short` shows what is uncommitted.
4. `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` gives the base branch.
5. `gh pr list --head <branch> --state open` shows whether a PR already exists.
	A merged or closed PR does not count; its branch can still carry newer commits that need a fresh one.
	Confirm with `git log --oneline origin/<default>..HEAD` before concluding nothing is outstanding.
6. Resolve the repository default branch with `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, fetch it, and run `tools/check-pr-readiness.ps1 -BaseBranch <default-branch> -DefaultBranch <default-branch>` with the mode-appropriate flags.
	The pull request base must be the repository default branch; never target a feature branch.
	If dependent work is already committed on a feature branch, promote the complete intended change set together in one PR to the default branch.
	A stale branch must be rebased or updated onto the default branch before opening or updating the PR.
	The GitHub readiness workflow must verify the PR's actual base against the repository default branch.
	An overlap with another open PR requires an explicit workflow decision: update the existing PR for the same task or serialize independent work that shares a hotspot.
	The check also blocks `docs/CHAT-HANDOFF.md`, which is generated coordination state rather than feature content.
7. In professional mode, inspect `gh pr view <number> --json autoMergeRequest` and pass both `-ProfessionalMode` and `-CurrentPullRequestNumber <number>` to the readiness check.
	If `autoMergeRequest` is non-null, stop and report that auto-merge must be disabled before professional review continues.
	In personal mode, omit `-ProfessionalMode`; an enabled auto-merge request remains allowed.

## Branch

Never open a PR from the default branch.
If the current branch is the default, create one named `<type>/<slug>` where `type` is `feat`, `fix`, `chore`, `docs`, or `refactor`, and `slug` is a short kebab-case description of the change.

If the current branch already carries unrelated commits, check whether the new work actually depends on them.
When it does, keep one branch and describe every commit in the PR body.
When it does not, branch fresh from the base and move only the relevant change across.

The PR base is always the repository default branch, including when the work was developed on dependent feature branches.
Do not merge or report the task complete while its changes exist only on a non-default branch.

## Commit

Stage only files relevant to this change; never `git add -A` over unrelated noise.
Write a subject line of at most 15 words, imperative mood, no trailing period.
Never add an agent as a co-author.

Check for an existing PR before creating one:

```
gh pr list --head <branch> --state open
```

When a PR already exists, push the new commits and update the body rather than opening a duplicate.

Before staging a feature PR, leave generated coordination paths out of the commit.
Keep `docs/CHAT-HANDOFF.md` local to the coordination checkout, or update it separately from the feature branch.

## Body

Use this structure, dropping any section that would be empty:

```markdown
## Summary

<what changed and why, as prose or a short list; one bullet per meaningful change>

## Notes

<non-obvious context a reviewer needs: a rename, a source-of-truth file, a deliberate omission>

## Test plan

- [x] <check that was actually run, with its result>
- [ ] <check the reviewer should perform>
```

Only tick a box for a check that genuinely ran.
An unticked box is honest; a ticked one that did not run is not.

Never attribute the PR to an agent: no "Generated with Claude Code" footer or link, no
`Co-Authored-By: Claude` line, in the title or the body. This is the same rule AGENTS.md
applies to commit messages, and it covers pull requests too.

Write the body to a file and run it through the stripper before every `gh pr create` and
every `gh pr edit`:

```powershell
powershell -NoProfile -File tools\strip-pr-attribution.ps1 -Path body.md
gh pr create --body-file body.md
```

The step is mandatory rather than advisory because this instruction already existed here
as prose and was violated 33 times across three repositories before anyone noticed. A
convention with no mechanism is one the tooling quietly ignores, so the mechanism is the
rule now and this paragraph only explains it. `-Check` exits 1 without modifying anything,
for a CI gate.

## Verify

After creating or updating a PR, query `gh pr checks <number> --watch` or an equivalent check-status command and confirm the results belong to the current `headRefOid`.
Keep the task in progress while checks are pending.
When a check fails, inspect its annotations and failed job logs, identify whether the cause is code, workflow policy, or infrastructure, then fix the in-scope cause, push, and verify the new head's checks.
If a failure cannot be fixed in scope, report the exact check and evidence as blocked; do not present the PR as ready or the task as complete.
Treat `mergeable` as Git conflict state only; verify CI results separately.
After checks are resolved, report the PR URL on its own line.
When the push or the create fails, show the error and the concrete recovery step rather than retrying blindly.

For an existing PR, verify the pushed head, mergeability, and auto-merge state with `gh pr view <number> --json headRefOid,mergeable,mergeStateStatus,autoMergeRequest`.

## Mode

In personal mode this runs end to end without asking for approval, and it leaves GitHub auto-merge available.
In delivery mode, show the proposed title and body before creating, enforce the professional auto-merge guard, and honor any tracker rules the repository carries.
