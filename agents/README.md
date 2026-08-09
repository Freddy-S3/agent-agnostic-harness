# Agents

Custom agent (or "agent mode") definitions live here, one Markdown file per agent.
This file documents the format; it is not itself an agent and `install.ps1` skips it.

## Format

Write each agent as `<name>.md` with neutral frontmatter:

```markdown
---
name: <short-kebab-case-name>
description: "One line: what this agent is scoped to and when to select it."
---

You are working in <scope>. Your primary scope is:
- `path/to/area/` - what lives here

## Available Tools

| Tool | How to use | When |
|---|---|---|

## Conventions

...
```

`name` must match the filename stem. Both keys are required: Claude Code needs
`name`, and every host uses `description` to decide when the agent applies.

## Host mapping

`install.ps1` renames the file per host, so keep the source neutral:

| Host | Installed as |
|---|---|
| Copilot | `~/.copilot/agents/<name>.agent.md` |
| Claude Code | `~/.claude/agents/<name>.md` |
| Codex | `~/.codex/agents/<name>.md` |

## Guidance

- Keep an agent to a real scope boundary — a codebase or a product area. One agent per repo you work in is usually right; one per task is not.
- Put durable conventions in the agent file and reusable workflow in a skill. An agent that restates a skill will drift from it.
- Name the validation commands (build, test, lint) explicitly. That is the single highest-value thing an agent file provides.
