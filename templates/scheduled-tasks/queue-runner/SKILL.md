---
name: queue-runner
description: Runs Faruk's /queue skill to work the personal-idea backlog and resume it across usage-limit resets.
---

Invoke the `/queue` skill and follow it. Read these two files first, in this order, and treat them as the contract rather than anything restated here:

1. `~/Repo/agent-agnostic-harness/instructions/AGENTS.md`
2. `~/Repo/agent-agnostic-harness/skills/queue/SKILL.md`

Work `/queue phone` unless this task was created for a different gate. Start by selecting exactly one actionable item with `tools/queue-runner.ps1`; if no item has one valid owning Git repository, exit without starting model work. Everything else - which queue file to read and where it lives, how to pick the next item, what to write before starting, how to checkpoint risky work, what a blocker must carry, when to stop, and how to resume - comes from those two files as they stand today.

If the host exposes model and effort controls, select `gpt-5.6-luna` at `xhigh`. If it does not expose that choice, use the host default without trying to encode the preference in the prompt or a repository file.

Each firing owns one item only. On usage, permission, network, or tool failure, leave the item `in-progress` through the runner's `stop` action so a later firing resumes its checkpoint. Open or update a PR after bounded verification when code changed; never merge, publish publicly, pay for infrastructure, send external messages, or deploy production from this unattended task.

Deliberately no summary of the contract here. The previous version of this prompt restated it, and the restatement rotted: it named a repository that had been renamed and a single combined queue file that had since been split in two and moved outside the repo, so a firing would have looked for a file at a path that was gone. A pointer cannot drift from its target in that way. `tools/check-skill-caches.ps1` fails if this file stops matching the template it is generated from.
