---
name: pr
description: "Open or update a GitHub pull request for the current work. Use when the user asks to raise, open, or update a PR, or says \"PR this\", \"ship it to GitHub\", or \"push this up for review\"."
---

# PR Skill

Take the current working state and turn it into a reviewable pull request on GitHub.
Do the whole job: branch, commit, push, and open the PR.
Report the URL.

## Standing rule

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

## Branch

Never open a PR from the default branch.
If the current branch is the default, create one named `<type>/<slug>` where `type` is `feat`, `fix`, `chore`, `docs`, or `refactor`, and `slug` is a short kebab-case description of the change.

If the current branch already carries unrelated commits, check whether the new work actually depends on them.
When it does, keep one branch and describe every commit in the PR body.
When it does not, branch fresh from the base and move only the relevant change across.

## Commit

Stage only files relevant to this change; never `git add -A` over unrelated noise.
Write a subject line of at most 15 words, imperative mood, no trailing period.
Never add an agent as a co-author.

Check for an existing PR before creating one:

```
gh pr list --head <branch> --state open
```

When a PR already exists, push the new commits and update the body rather than opening a duplicate.

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

Never append a "Generated with Claude Code" (or similar) footer or link to the PR body.

## Verify

After `gh pr create`, report the returned URL on its own line.
When the push or the create fails, show the error and the concrete recovery step rather than retrying blindly.

## Mode

In personal mode this runs end to end without asking for approval.
In delivery mode, show the proposed title and body before creating, and honor any tracker rules the repository carries.
