# Worktree and Folder Hygiene

Read this before adding, retaining, archiving, or removing a project checkout under `~/Repo`.

## Active-folder limit

Keep no more than three active folders for one project family.

The intended shape is one canonical checkout, one pinned long-running service checkout, and one active task checkout.

The guard groups Git folders by their `origin` repository, so aliases such as `aah-*`, `agent-agnostic-harness-*`, `PW-*`, and `Portfolio-Website-*` count together even when their folder names differ.

Dot-folders, underscore-folders, attachments, screenshots, temporary folders, and `unattended-runs` are not active project checkouts and are excluded explicitly.

## Required mechanism

Before creating a worktree, use the guarded command:

```powershell
powershell -NoProfile -File tools\worktree-add.ps1 -RepoRoot <repo> -Path <new-path> -Branch <branch> -StartPoint origin/main -Family <family>
```

`tools/check-folder-hygiene.ps1 -Action assert-add` is the underlying reservation check.
`tools/claim.ps1 acquire` and the pre-commit hook enforce the same limit for sessions that bypass the wrapper.

If a family is already over the limit, stop and classify the folders before doing more work.
Read each folder's status and active claims, preserve dirty work, and use `git worktree remove` for clean registered worktrees.

Removing a local worktree does not delete its remote branch.
Do not delete a remote branch as part of folder hygiene unless that separate action is explicitly requested.

Run the inventory when auditing the workspace:

```powershell
powershell -NoProfile -File tools\check-folder-hygiene.ps1 -Action list -WorkspaceRoot $env:USERPROFILE\Repo
```

The three-folder limit exists because a stale sibling checkout can serve an older feature after that feature has merged.
The queue dashboard did exactly that: its archive view was present, while the current Control Center was absent from the checkout serving the phone.
