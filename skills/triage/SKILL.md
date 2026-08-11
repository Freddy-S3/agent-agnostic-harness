---
name: triage
description: "Triage a tracker request into a verified category, state recommendation, and agent-ready brief."
user-invocable: true
---

# Triage

Use `/triage` to evaluate an issue or pull request without blindly changing its tracker state.
Default to read-only investigation and a recommendation.

## Tracker Routing

- Use the Jira Data Center MCP for a self-hosted Jira at `JIRA_URL`; use the Atlassian MCP for a real Atlassian Cloud site.
- Use the Atlassian MCP for Confluence at `CONFLUENCE_URL`.
- Inspect the available tracker capabilities and the item's existing fields before proposing labels, fields, comments, links, or dependency changes.
- Treat `bug` and `enhancement` as category concepts, and `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix` as state concepts.
  Map them to tracker-native values only when that mapping exists and is confirmed.

## Triage Flow

1. Gather the full item: description, all comments, current category/state values, linked work, author, and dates.
   For a pull request, read the diff and relevant checks.
   Preserve prior triage answers instead of asking them again.
2. Check redundancy by searching the codebase for the requested behavior by domain concept, not only by the reporter's wording.
   Report the locations searched and whether the behavior already exists.
3. Check `.out-of-scope/` for a materially similar rejected request.
   Surface the prior decision and distinguish a rejected request from an already implemented one.
4. Verify the claim before categorizing it.
   Reproduce a bug from the reported steps, or confirm a pull request's claimed behavior through its diff and focused validation.
   Record the result as confirmed, not reproduced, or insufficient detail, with the relevant code path or missing information.
5. Recommend exactly one category and one state concept, with concise reasoning.
   Insufficient detail usually recommends `needs-info`; an already implemented request recommends `wontfix` with the implementation location.
   Do not transition an item merely because a recommendation was made.

## Agent-Ready Brief

For a verified `ready-for-agent` recommendation, draft an agent-ready brief before any tracker update.
Include the objective, evidence from verification, relevant code locations, acceptance criteria, constraints, focused validation, and unresolved risks or decisions.
For `ready-for-human`, use the same structure and state why human judgment, access, or manual work is required.

## Mutating A Tracker

Treat comments, state transitions, category changes, labels, custom fields, links, dependency operations, closures, and reopenings as tracker mutations.
Never infer that any of those operations, fields, or labels exist.

Immediately before each mutation, show the exact target item and proposed operation, then obtain explicit confirmation.
Only after that confirmation, use the correctly routed MCP and report the completed action.
For a direct request such as "move ISSUE-42 to ready-for-agent", still inspect capabilities, state the exact mapped operation, and request confirmation immediately before applying it.

When a request is rejected, draft a concise rationale; only record it in `.out-of-scope/` when that local knowledge-base workflow is explicitly available and confirmed.
When information is missing, draft specific, actionable questions and retain all established facts in the triage notes.