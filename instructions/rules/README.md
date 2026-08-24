# Conditional Rule Files

`instructions/AGENTS.md` is the always-loaded core. Everything here is conditional: it is loaded
only when a trigger in the core's **Rule files - read on trigger** table fires.

Codex has no import, include, or `@file` directive - verified against its binary, not assumed - so
no file in this directory is ever pulled in automatically on that host. A pointer with no trigger is
a file nobody opens. Every file here must therefore be named by an explicit trigger row in the core,
phrased as an action the agent is about to take, and referenced by absolute path so it resolves from
any host and any working directory.

When adding a rule file:

1. Give it a trigger row in the core table. Without one it is dead weight.
2. Open the file with a one-line statement of when to read it, so an agent that lands here directly
   can tell whether it is in the right place.
3. Keep each rule's incident evidence in the same file as the rule. A rule separated from the
   incident that produced it is a rule that gets argued away later.

`tools/check-rule-triggers.ps1` verifies that every file here has a trigger row and that every
referenced path exists.
