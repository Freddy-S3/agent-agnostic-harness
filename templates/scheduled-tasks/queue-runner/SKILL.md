---
name: queue-runner
description: Runs Faruk's /queue skill to work the personal-idea backlog and resume it across usage-limit resets.
---

Invoke the `/queue` skill and follow it. Read these two files first, in this order, and treat them as the contract rather than anything restated here:

1. `~/Repo/agent-agnostic-harness/instructions/AGENTS.md`
2. `~/Repo/agent-agnostic-harness/skills/queue/SKILL.md`

Work `/queue phone` unless this task was created for a different gate. Everything else - which queue file to read and where it lives, how to pick the next item, what to write before starting, what a blocker must carry, when to stop - comes from those two files as they stand today.

Deliberately no summary of the contract here. The previous version of this prompt restated it, and the restatement rotted: it named a repository that had been renamed and a single combined queue file that had since been split in two and moved outside the repo, so a firing would have looked for a file at a path that was gone. A pointer cannot drift from its target in that way. `tools/check-skill-caches.ps1` fails if this file stops matching the template it is generated from.
