# New Machine Setup

One-time checklist for moving to a new PC.
Not a zip: repos already live on GitHub, so a zip would only drag along `.git` bloat, `node_modules`, and build artifacts, and it would force a manual USB/cloud transfer for no reason.
This is "clone one repo, run one script" instead.

## 1. Install prerequisites

- [Git](https://git-scm.com/) and the [GitHub CLI](https://cli.github.com/) (`gh`).
- [Claude Code](https://claude.com/claude-code) (or the desktop app).
- Node.js - several repos here need it (`unattended-runs` is Astro/TypeScript, `Portfolio-Website`'s tooling uses `py`/Node both). Get it from [nodejs.org](https://nodejs.org/), not a portable zip - a portable copy only lives in one shell's `PATH` and doesn't survive a fresh terminal.
- Python, if you'll touch `Portfolio-Website` (`py tools/build-resume.ps1`, `py tools/test_site.py`).

## 2. Sign in

Auth never travels in a zip or a repo - re-authenticate fresh on the new machine:

```powershell
gh auth login
claude
```

`claude` on first run walks through login and writes `~/.claude/.credentials.json` itself.

## 3. Run the bootstrap script

Clone just `agent-agnostic-harness` first, then let it clone everything else (the login from step 2 is still needed, because the bootstrap script clones private sibling repos too):

```powershell
gh repo clone Freddy-S3/agent-agnostic-harness "$env:USERPROFILE\Repo\agent-agnostic-harness"
& "$env:USERPROFILE\Repo\agent-agnostic-harness\bootstrap-new-machine.ps1" -Target codex
```

This clones every other repo under the `Freddy-S3` GitHub account into `C:\Users\Faruk\Repo` (skipping any already present) and runs the Codex installer to set up the harness skills and instructions.
Use `-Target claude` for Claude Code or `-Target both` when both hosts are installed.

Pass `-Only agent-agnostic-harness,Portfolio-Website,unattended-runs` if you only want the active workspaces and not the older practice/test repos also on the account.
Pass `-DryRun` first if you want to see what it would do before it does it.

## 4. Confirm skills resolve

Restart the host, then in a Claude Code session:

```powershell
Test-Path "$env:USERPROFILE\.claude\CLAUDE.md"
Test-Path "$env:USERPROFILE\.claude\skills\ship\SKILL.md"
```

Then ask it to run `/faruk` and `/pr` - if both are recognized, the install is live.

## 5. Restore the portable Project layout

Read [`docs/PROJECT-OPERATING-MODE.md`](docs/PROJECT-OPERATING-MODE.md).
Create or verify the one `00 Control Center` chat, one host Project per business or durable
domain, and `00 Main - Coordination` inside each Project.
The host account's Projects and chat history are not created by `install.ps1`, so this is a
manual account step that must be repeated when the account or host changes.
Confirm the one-agent default and the three-agent maximum for exceptional parallel work.

## What this can't automate

- **`~/.claude/.credentials.json`** - never copy this file between machines. Sign in fresh (step 2). This is a security boundary, not a convenience gap.
- **`~/.claude/settings.json`** - permission allow/deny lists, model choice, effort level, theme, notification prefs. This file is deliberately local-only (see `instructions/AGENTS.md`'s harness-conventions table) and is not reproduced by `install.ps1` or the bootstrap script. Either copy the file over by hand (it holds no credentials, just preferences) or let the defaults re-prompt and re-approve as you go.
- **MCP server credentials** - `config/mcp-config.template.json` is env-var driven and carries no secrets, but the env vars it reads (`JIRA_URL`, `JIRA_PERSONAL_TOKEN`, `CONFLUENCE_URL`, `CONFLUENCE_PERSONAL_TOKEN`, `AGENT_CA_BUNDLE`) need to be set on the new machine if you use the Atlassian MCP server. Nothing to do here if you don't.
- **Any repo outside the `Freddy-S3` GitHub account.** If a project only ever existed locally and was never pushed, no script here can recover it - check the old machine before wiping it.
