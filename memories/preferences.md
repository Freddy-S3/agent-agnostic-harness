# User Preferences

## Workflow
- Run /SHIP automatically after any task that results in file changes in the workspace (features, bug fixes, refactors, tests, infrastructure, config, dependency updates, PR feedback, Jira tickets).
- Do NOT run /SHIP for read-only tasks (research, answering questions, explaining code).

## Access-Controlled Systems
- Reach any SSO-protected tracker or wiki exclusively through its MCP server. An embedded editor browser cannot complete an SSO redirect, so browser automation is only for public sources.

## Code Quality
- **Never silently fail.** Any downstream failure (HTTP, DB, AWS, external API) must re-throw after logging — never swallow into a null/empty return. An explicit 5xx is always better than a success response with empty/null data.

## Code Organisation
- **Group related constants by logical dimension first, then by prod/nonprod within each group.** e.g. when defining identity-provider group sets: US-prod, US-nonprod, then INTL-prod, INTL-nonprod — not all prod first then all nonprod. Blank lines between each logical section. Apply this consistently to any `Set`, `enum`, or config block with multiple axes of variation.

## Harness / Reflect discipline
- At Gate 3, **proactively identify organisation or style corrections made during the task** (not just feature facts) and propose them as harness updates — don't wait to be told.
- If the user had to correct something that should already have been a known preference, add it to harness immediately without prompting.

