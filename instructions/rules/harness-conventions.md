# Harness Conventions

Read this before adding, editing, or removing a skill, an instruction file, an installer path, or any harness-enforcing mechanism.

### What "add to the harness" means

Treat the phrase as covering every artifact below, not just the one that is convenient.
A change that lands in only some of them is half-applied and will drift.

The harness lives at `~/Repo/agent-agnostic-harness`, alongside the projects it serves.
Always edit it there, never the `~/.claude` projection.

| Artifact | Update when |
|---|---|
| `skills/<name>/SKILL.md` | The change is a workflow. Create the directory for a new skill. |
| `instructions/AGENTS.md` | The change adds a skill to the Native Skills table, or adds or alters a rule that applies to essentially every task. This file is the always-loaded core, so a rule earns its place here only by being unconditional; anything conditional belongs in `instructions/rules/` with a trigger row here. |
| `instructions/rules/<topic>.md` | The change adds or alters a rule that applies only under a nameable condition. Give it a trigger row in the core table phrased as an action the agent is about to take, keep the rule's incident evidence in the same file, and run `tools/check-rule-triggers.ps1`. A rule file with no trigger is never opened, on Codex especially, which has no import directive. |
| `instructions/WIDGETS.md` | The change adds, removes, or renames a clickable card button in any skill. The action vocabulary there is the contract; a button whose sentence is not in that table is a dead control. |
| `HARNESS.md` | The change affects day-to-day use: the selection table, the gates, or a worked example. |
| `README.md` | The change adds a new top-level path or alters install behaviour. |
| Git | Always. Commit in `agent-agnostic-harness` with a real message, and push. An uncommitted harness edit is lost the next time the machine is reimaged. |

Verify a new skill is actually discoverable before reporting it added: `skills/` is a
directory junction into `~/.claude`, so a new `SKILL.md` registers live, but a skill
absent from the `AGENTS.md` table will not be routed to.

Every skill in this harness is model-invocable. Do not set `disable-model-invocation: true` on
a new one. That flag makes a skill reachable only by a slash command the human types into the
CLI, which silently removes it from every other surface: the desktop and web apps, background
jobs, and subagents all reach skills through the Skill tool, not through slash expansion.
Eleven skills carried the flag - both mode routers among them - and were invisible outside the
terminal until 2026-08-11. Keep `user-invocable: true` so the slash command still works, and
write the `description` as a model-facing pointer stating its trigger conditions, because it is
now the index entry the agent routes on rather than a human-facing summary.

- When adapting an imported harness, validate that the native files neither mention nor require the source archive before treating that archive as removable.
- This harness is linked into `~/.claude`, not copied. `skills/` and `memories/` are directory junctions, so an edit on either side is the same file. `~/.claude/CLAUDE.md` is a stub that imports this file with `@~/Repo/agent-agnostic-harness/instructions/AGENTS.md`, so it is read live and never needs syncing.
- A single file cannot be linked reliably on Windows: symlinks need admin or Developer Mode, and a hard link does not survive an editor that writes by replace-and-rename. The import stub sidesteps both, because the stub itself is never edited.
- Edit `instructions/AGENTS.md` and restart the host. Never edit `~/.claude/CLAUDE.md`; it holds only the import.
- `~/.claude/settings.json` is not managed by this repository and stays a local file.
- **Codex gets a copy, and the copy is kept honest by a hook, not by memory.** Codex has no import directive, so `~/.codex/AGENTS.md` must be a real copy of this file. A link is not a substitute: a directory junction cannot stand in for a single file, a file symlink needs administrator rights or Developer Mode (this machine grants neither - `New-Item -ItemType SymbolicLink` returns "Administrator privilege required"), and a hard link does not survive an editor that writes by replace-and-rename. So the copy is refreshed mechanically. `git-hooks/post-commit`, `post-merge` and `post-checkout` call `tools/sync-codex-rulebook.sh`, and `core.hooksPath` is global, so any commit in any repository re-syncs it; `install.ps1` refreshes it too, whatever the target, for a machine whose hooks were skipped. Run `sh tools/sync-codex-rulebook.sh --check` to report drift without writing. The rule exists because the copy sat 31 diff lines and two days behind on 2026-08-23 while every other host was current, which meant Codex was running an older rulebook than the sessions it was working alongside - and nothing said so.
- **Codex truncates an oversized project doc silently.** Its `project_doc_max_bytes` bounds what it reads from `AGENTS.md`; past that it logs `project doc exceeds remaining budget; truncating` (`core/src/agents_md.rs`) and carries on. The truncation takes the tail, which is where the queue-format rules and the rename consumer checklist live - the two sections whose absence costs the most and shows the least. The default is not exposed in the config surface and was not determined from the binary, so `~/.codex/config.toml` sets `project_doc_max_bytes = 262144` explicitly rather than relying on it. Since the 2026-08-23 progressive-disclosure split the core is ~23 KB rather than ~49 KB, so truncation is no longer a live risk - but keep the explicit setting. It costs nothing, the default remains unknown rather than known-large, the failure it guards is silent, and the core is the one file whose tail must never be cut. `tools/check-rule-triggers.ps1` holds the core under its own ceiling, which is the mechanism that keeps this true; if that ceiling is ever raised toward 262144, raise this number rather than trimming the tail. The observable test, should the setting ever be in doubt: launch Codex with `RUST_LOG=codex_core=warn`, check `~/.codex/log/` for that message, and ask a session to quote the final line of its instructions.

### Conventions need an enforcing mechanism

A convention that lives only in prose is one that tooling will quietly violate.
`install.ps1` copied `AGENTS.md` over `~/.claude/CLAUDE.md` while this file said the
opposite, then printed a note telling the user to hand-rebuild the stub it had just
destroyed. The knowledge was there; it was written as advice to a human instead of as
behaviour in code.

- When you document a convention here, make the tool that touches those files enforce it. If no tool owns it, say plainly that it is manual.
- Treat a tool that asks the user to undo what it just did as a defect, not a note. That instruction belongs in the code path.
- Prefer generating a derived file over copying a source file whenever the host resolves it live. A copy is indistinguishable from the real thing on install day and diverges silently afterwards.
- A generator or installer is verified by running it against a throwaway target and reading what it produced, never by reading its source. Check idempotency on a second run, and check that it leaves a hand-edited target alone.
- Put a guard where the failure actually happens, not where it reads well. The queue dashboard's stale-checkout check has to run before the launcher's "is the port already up" early exit, because the failure mode is a healthy-looking port serving old code - placed after that exit, in the natural-reading position, it would never run in the one case it exists for. Ask this of any new check: is there an early return upstream of it that the failure passes through first?
- Verify a predicate by constructing the failure, not by re-reading the line. That same guard's first draft asked `git merge-base --is-ancestor HEAD origin/main`, which is the intuitive direction and is backwards: a branch that was merged and then left behind is still an ancestor of `main`, so it reported healthy for precisely the stale checkout it was written to catch. A throwaway worktree at the old commit exposed it in one command.
- An idempotency check must compare the target state, not the shape. Distrust every "already linked", "already installed", "already exists" branch and ask what it does when the thing exists but is wrong. `install.ps1` skipped relinking on `Test-IsJunction`, which asks "is this a link" and never "does it point at this repo" - its own docstring claimed the stronger meaning the code did not implement. When the harness repository was renamed on disk on 2026-08-12, the installer re-ran, found both junctions present but dangling, printed "already linked", and reported a clean install while all 34 skills and every memory were unreachable. The weaker test is always the cheaper one to write, and it is the one that reports success during an outage. Fixed by `Test-JunctionPointsTo`.
- A rename is a first-class test case for anything that links, caches, or records a path. Three separate mechanisms broke on the same rename: the `skills` junction, the `memories` junction, and - hours earlier, for the same underlying reason - a dashboard worktree left on a merged branch. When adding a path-dependent mechanism, ask what happens when that path moves, and prefer a check that self-heals over one that reports success.
- Worked example: "Never add an agent as a commit co-author" was prose only, and ten commits carried the trailer before the history rewrite stripped them. It is now `git-hooks/commit-msg`, wired by `install.ps1`. Enforcement that rewrites beats enforcement that rejects: a hook that blocks the commit teaches the author to reach for `--no-verify`.
- Do not pass a regex to `awk` with `-v`. awk expands escape sequences in a `-v` assignment, so `\[bot\]` arrives as the character class `[bot]` and matches almost every address. Write the pattern as a regex constant in the awk program. This was a live bug in the first draft of `commit-msg`, caught only by testing it against a message with human co-authors.
