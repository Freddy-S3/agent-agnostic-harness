---
name: wayfinder
description: Plan a long-horizon effort as a map of decisions. Use when an effort is too foggy or too large to plan or finish in one session, and the open decisions matter more than the implementation steps.
user-invocable: true
---

# Wayfinder

Use `/wayfinder` when an effort is too foggy or large to plan or finish in one session.
Wayfinder finds the route to a **destination**.
It plans decisions, not implementation deliverables.

## Start With The Artifact

First, choose and get approval for the artifact that will hold the map.

- Use a configured tracker only after the user explicitly confirms it and the required MCP capability and authentication checks succeed.
- Otherwise, ask the user to approve a local Markdown map and its location.
- Keep every decision ticket and the map in that chosen artifact target.

Do not create tickets, modify deliverables, or take external actions before this choice is settled.
Before every tracker mutation after the initial artifact choice, show the exact operation and affected map or tickets, then get fresh explicit confirmation.
For internal Jira, perform the confirmed operation only through the Jira Data Center MCP.

## Chart The Map

1. State the **destination** in one or two sentences: the decision, specification, or implementation plan the map must make clear.
2. Add the known **decision tickets**. Each ticket asks one precise question whose answer changes the plan; it is not a work item to implement.
3. Mark each ticket's dependencies. The **frontier** is the unblocked, undecided tickets that can be taken next.
4. Record the in-scope but still imprecise questions as **fog-of-war**. Graduate an item into a decision ticket only when its question can be stated precisely.
5. Record deliberately excluded work as **out-of-scope**. It does not graduate from fog-of-war unless the destination is redrawn.

Keep the map low-resolution: link each resolved decision ticket with a one-line conclusion rather than duplicating its evidence.

## Work One Decision

1. Re-read the destination and map, then choose one frontier ticket.
2. Resolve only that decision in this session. Draft the question, evidence considered, answer, and planning consequence; for a tracker-backed map, preview the exact update and get explicit confirmation before recording it.
3. Update the frontier, add newly visible decision tickets, and promote any newly precise fog-of-war.
4. Stop when the decision is recorded. Hand implementation planning or delivery to the appropriate next effort.

Research may be delegated to a research subagent when factual evidence is needed.
Give it the decision question, bounded sources, and the expected finding.
Its findings inform the current ticket; delegation does not turn the session into multiple decision resolutions.

## Done

The map is complete when the destination has a clear route, every necessary decision is resolved or explicitly owned by a future effort, and implementation can begin without reopening fog-of-war.

Before closing, verify that the frontmatter name matches the `wayfinder` folder and that the invocation fields explicitly make this a human-invoked skill.