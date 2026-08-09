---
name: to-spec
description: Synthesize settled context into an agent-ready implementation spec.
user-invocable: true
disable-model-invocation: true
---

Turn the decisions already settled in this conversation into a concise, implementation-ready spec.
Do not reopen settled decisions or begin an interview.
Record unresolved facts as assumptions or open questions.

## Process

1. Gather only the relevant repository evidence needed to confirm the current shape of the affected area.
   Use the project's established domain vocabulary.
   Read and honor applicable ADRs, architectural guidance, and existing contracts.

2. Identify the highest useful test seams for the change.
   Prefer existing public boundaries, workflows, or contracts over new seams.
   Name the observable behavior each seam verifies and any relevant test prior art.

3. Draft the spec in the response using this structure:

```markdown
# <Concise title>

## Problem

## Desired Outcome

## Scope

## Implementation Decisions

## Test Strategy

## Acceptance Criteria

## Out of Scope

## Assumptions and Open Questions
```

Make scope boundaries explicit, including affected capabilities, preserved behavior, and exclusions.
Keep implementation decisions durable: describe responsibilities, contracts, data, and integration behavior rather than volatile file-level detail.

4. Present the result as a draft and request explicit confirmation before creating or updating any tracker issue.
   Include the intended tracker action and target when known.
   Take no external action until the user confirms that exact draft and action.

5. After explicit confirmation, publish only to the confirmed target.
   When the target is a self-hosted tracker, use its dedicated MCP server (for Jira Data Center, the Jira Data Center MCP for `JIRA_URL`).
   If that MCP is unavailable, stop with: `Publishing is blocked: the configured tracker MCP is unavailable. No substitute tracker was used.`
   Do not substitute a cloud tracker or another publishing path.