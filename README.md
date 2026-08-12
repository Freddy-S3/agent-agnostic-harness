# Agent-Agnostic Harness

A portable, agent-agnostic harness: instructions, skills, agents, hooks, and memory notes that run the same across GitHub Copilot, Claude Code, and Codex.

Agent-agnostic means the workflows are not tied to one vendor's assistant. A skill is authored once, in one format, and any supported host gets the same behavior; adding a host is a change to the installer, not a rewrite of the content.

This repository is the single source of truth. You write a skill once, in one format, and `install.ps1` projects it into whatever layout a given host expects. Nothing here is host-specific except the installer.

## Contents

| Path | What it holds |
|---|---|
| `instructions/AGENTS.md` | The always-loaded root instructions. Renamed per host at install time. |
| `instructions/*.instructions.md` | Optional path-scoped instructions (Copilot `applyTo` frontmatter). |
| `agents/` | Custom agent definitions, one per file. See `agents/README.md` for the format. |
| `skills/` | Reusable workflows, one directory per skill with a `SKILL.md`. |
| `hooks/` | Optional lifecycle hook scripts. |
| `git-hooks/` | Git hooks, host-independent. `commit-msg` strips agent co-author trailers. `install.ps1` points global `core.hooksPath` here. |
| `memories/` | Durable user and repo context notes. |
| `config/mcp-config.template.json` | Sanitized MCP server template, env-var driven. |
| `HARNESS.md` | How to actually use the harness day to day - start here after installing. |
| `install.ps1` | Projects this repo into a host's layout. |
| `bootstrap-new-machine.ps1` | One-time setup for a fresh PC: clones every repo and runs `install.ps1`. See `NEW-MACHINE-SETUP.md`. |

## Install

```powershell
.\install.ps1 -Target copilot            # or claude, or codex
.\install.ps1 -Target claude -Link       # the usual Claude Code install (live junctions)
.\install.ps1 -Target claude -Link -Mcp  # also emit MCP configuration
.\install.ps1 -Target codex -DryRun      # show every action, write nothing
```

Then restart the host so it rediscovers instructions and skills.

Moving to a new machine entirely, not just installing into a new host? See `NEW-MACHINE-SETUP.md` - `bootstrap-new-machine.ps1` clones every repo and runs the install above in one pass.

Useful flags:

- `-DryRun` - report every action without writing. Run this first.
- `-Link` - junction `skills/` and `memories/` into the destination instead of copying, so the installed harness stays a live view of this repo. Without it they are copied and drift. This is the intended mode for Claude Code.
- `-Mcp` - also emit MCP server config for the target host.
- `-DestRoot <path>` - install somewhere other than the host's default directory.
- `-IncludeMemories:$false` - skip `memories/` when the host has its own durable memory store.
- `-Force` - overwrite differing files instead of backing them up.
- `-SkipGitHooks` - leave global `core.hooksPath` alone.

The installer is idempotent: files whose content already matches are skipped. A destination file that differs from source is copied to `<name>.bak-<timestamp>` before being replaced, so a hand-edit on the host side is never silently destroyed.

### Git hooks

Every step writes inside the host's harness directory except one: the installer sets global `core.hooksPath` to `git-hooks/`, so `commit-msg` runs in every repository on the machine and strips agent co-author trailers. That setting is global and replaces per-repo `.git/hooks`, so a repository that needs its own hooks (husky, lefthook) must set a local `core.hooksPath` - a local value wins. If `core.hooksPath` is already set to something else, the installer reports it and changes nothing.

## Host mapping

| Source | Copilot | Claude Code | Codex |
|---|---|---|---|
| `instructions/AGENTS.md` | `.copilot/instructions/copilot-instructions.md` | `.claude/CLAUDE.md` | `.codex/AGENTS.md` |
| `instructions/*.instructions.md` | `.copilot/instructions/` (auto-applies) | copied as reference only | copied as reference only |
| `agents/<name>.md` | `.copilot/agents/<name>.agent.md` | `.claude/agents/<name>.md` | `.codex/agents/<name>.md` |
| `skills/` | `.copilot/skills/` | `.claude/skills/` | `.codex/skills/` |
| `hooks/` | `.copilot/hooks/` (auto-runs) | `.claude/hooks/` + register in `settings.json` | `.codex/hooks/` |
| `memories/` | `.copilot/memories/` | `.claude/memories/` | `.codex/memories/` |
| `config/mcp-config.template.json` | `mcp-config.json` | `mcp-servers.generated.json` | `mcp-servers.generated.toml` |

Two host limitations worth knowing:

- **Scoped instructions.** Only Copilot understands `applyTo` frontmatter for path-scoped instruction files. On Claude Code and Codex they install as reference material and will not auto-apply; reference them from the root instruction file, or use a per-directory `CLAUDE.md` / `AGENTS.md` instead.
- **MCP registration.** For Copilot the generated `mcp-config.json` is used directly. For Claude Code the config is written beside the harness rather than merged into `~/.claude.json`, which holds live session state - register it with `claude mcp add --scope user ...`. For Codex, merge the generated TOML into `~/.codex/config.toml`; note that Codex does not expand `${env:NAME}` placeholders, so substitute literals or export the variables before launch.

## Configuration

The MCP template reads everything from the environment, so no credentials live in this repo:

| Variable | Purpose |
|---|---|
| `JIRA_URL` | Jira base URL |
| `JIRA_PERSONAL_TOKEN` | Jira personal access token |
| `CONFLUENCE_URL` | Confluence base URL |
| `CONFLUENCE_PERSONAL_TOKEN` | Confluence personal access token |
| `AGENT_CA_BUNDLE` | Path to a corporate root CA bundle, if TLS is intercepted |

Skills refer to the tracker generically via `JIRA_URL` / `CONFLUENCE_URL`. When neither is configured, ticket-backed workflows degrade to ticketless rather than blocking.

## Adding to the harness

- **A new skill** - create `skills/<name>/SKILL.md` with `name` and `description` frontmatter. That format is native to both Copilot and Claude Code and readable by Codex, so no per-host variant is needed. Add `user-invocable: true` for a slash command.
- **A new agent** - see `agents/README.md`.
- **Keep it neutral** - never hardcode a host path, a tracker URL, or a specific project's file layout into a skill. Those belong in the installer, the environment, or a scoped instructions file respectively.
- Use `/writing-for-agents` when editing any agent-facing document here.

## Deliberately excluded

Credentials, certificates, logs, chat history, session databases, caches, trusted-folder approvals, permissions, and machine-specific settings. The memory export contains durable Markdown only - no session database or transient task state.

The `herdr-agent-state.ps1` hook ships as source but only runs when the Herdr integration environment variables and command are available.

## Validation

After installing, confirm the host-specific entry points exist. For Copilot:

```powershell
Test-Path "$env:USERPROFILE\.copilot\instructions\copilot-instructions.md"
Test-Path "$env:USERPROFILE\.copilot\skills\freddy\SKILL.md"
Test-Path "$env:USERPROFILE\.copilot\skills\ship\SKILL.md"
```

For Claude Code, check `$env:USERPROFILE\.claude\CLAUDE.md` and `.claude\skills\ship\SKILL.md`; for Codex, `$env:USERPROFILE\.codex\AGENTS.md` and `.codex\skills\ship\SKILL.md`.

Then confirm the harness is live by invoking `/freddy` and describing a task.
