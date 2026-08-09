---
name: resolving-merge-conflicts
description: "Use when you need to resolve an in-progress git merge/rebase conflict."
---

# Resolving Merge Conflicts

## Workflow

### 1. See the current state
- Check `git status` for the list of conflicting files and whether this is a merge or a rebase.
- Check history around the conflict: `git log --oneline --graph --all -20`, `git log --merge` for the commits in conflict.
- Open each conflicting file and read the `<<<<<<<` / `=======` / `>>>>>>>` markers to understand the shape of the conflict before editing anything.

### 2. Find the primary sources for each conflict (intent-tracing)
- For every conflicting hunk, find the **original intent** behind each side - do not resolve blind.
- Read the commit messages for both sides: `git log -p <commit>` or `git show <commit>`.
- Check the originating PR description and review comments when available. For Jira links, use the configured Jira MCP route; for repository history, use git and repository metadata.
- Check the original issue/ticket referenced by the commit or PR for the "why", not just the "what".
- If intent cannot be determined from history, say so explicitly rather than guessing.

### 3. Resolve each hunk (source-of-truth, hunk-by-hunk)
- Work through conflicts one hunk at a time - do not bulk-accept "ours" or "theirs" across a whole file without reading each hunk.
- Preserve **both** intents where they are compatible (e.g. two unrelated additions in the same region).
- Where intents are genuinely incompatible, pick the side that matches the merge/rebase's stated goal (the reason the merge is happening), and leave a short note (commit message or inline comment) explaining the trade-off that was made.
- Do **not** invent new behavior to "split the difference" - a conflict resolution should only recombine code that already exists on one side or the other, plus the minimal glue needed to make both compile/run together.
- Always resolve. **Never destructively abort** (`git merge --abort` / `git rebase --abort`) to escape a hard conflict - that discards work. If you get stuck, stop and ask the user before abandoning the operation; do not decide unilaterally to abort.

### 4. Run automated checks
- Discover the project's checks (README, `package.json` scripts, `*.sln`/`*.csproj`, `tox.ini`, CI config) and run them in this order: typecheck/build, then tests, then format/lint.
- Fix anything the merge broke - a clean conflict resolution still needs to compile and pass tests.
- PowerShell examples for this repo's stacks:
  ```powershell
  # .NET project/solution
  dotnet build <Project>.sln
  dotnet test <Project>.sln

  # Vue / Node
  npm run lint
  npm run test:unit

  # Python
  tox
  ```

### 5. Hand back safely
- Stage the resolved files only when the user asked for staging: `git add <file>` (or `git add .` once every conflict is confirmed resolved).
- Verify nothing unintended is staged: `git status` and `git diff --staged`.
- Do not run `git commit`, `git merge --continue`, or `git rebase --continue` unless the user explicitly asked to complete the operation; these commands create commits or advance repository history.
- Otherwise, report the resolved state and the exact next command the user can run when they are ready to complete the merge or rebase.

## Guardrails

- Never run `--abort` as a shortcut past a difficult conflict; treat it the same as any other destructive/irreversible git operation and get explicit human confirmation before using it, even when asked.
- Before force-pushing a rebased branch, confirm with the user - rewritten history on a shared branch is a risky, hard-to-reverse operation.
- If a hunk's correct resolution is ambiguous even after checking commits/PR/ticket, present the options and ask rather than guessing.
