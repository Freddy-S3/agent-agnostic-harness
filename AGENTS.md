# Agent entry point

## Harness rules - read this first

This is the harness repository itself. Its operating rules live one directory down:

    instructions/AGENTS.md

Read that file before your first write here. This root file exists because Codex resolves
`AGENTS.md` from the working directory up to the repository root and stops there - it never
looks in `instructions/`, and without this pointer a session working in this repository
would see no project instructions at all.

The same file is installed to `~/.codex/AGENTS.md` and imported by `~/.claude/CLAUDE.md`,
so a session usually has it already. "Usually" is the reason for the pointer.

Before your first write in this working tree:

    pwsh -NoProfile -File tools/claim.ps1 acquire -Tree <this tree> -Session $HARNESS_SESSION

Exit code 3 means a peer holds it: create your own worktree off `origin/main` and claim
that instead. `git-hooks/pre-commit` enforces this.

## Repository specifics

- Edit `instructions/AGENTS.md` here, never the `~/.claude` or `~/.codex` projection.
- `skills/` and `memories/` are directory junctions into the host's harness directory, so an
  edit on either side is the same file.
- `docs/REPO-ENTRYPOINTS.md` explains the entry-point convention this file is an instance of.
