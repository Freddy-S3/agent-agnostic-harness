---
name: to-tickets
description: Turn a plan, specification, or conversation into reviewed tracer-bullet ticket drafts.
user-invocable: true
disable-model-invocation: true
---

# To Tickets

Turn a plan, specification, or the current conversation into a reviewable set of tracer-bullet tickets with real blocking edges.

## Process

1. Gather the available context.
   Read a referenced specification, issue, or handoff completely, including comments when available.
   Explore the relevant code only when needed to understand the current state.
   Use the project's domain vocabulary and applicable ADRs in titles, descriptions, and acceptance criteria.

2. Shape the work into tickets.
   Make each ticket a **tracer bullet**: a narrow, complete, independently demoable or verifiable path through the necessary layers and tests.
   Size each ticket for one fresh context window.
   Add a blocking edge only when the blocker genuinely prevents the ticket from starting; tickets without blockers can start immediately.

   Treat a broad mechanical refactor as an **expand-contract** sequence rather than forcing vertical slices:
   - Expand by introducing the new form alongside the old one.
   - Migrate callers in blast-radius-sized batches, each blocked by expand.
   - Contract by removing the old form after every migration batch completes.
   - When batches cannot remain green independently, add a final integration-and-verification ticket blocked by all batches.

3. Present a numbered draft before any side effect.
   For each ticket include its title, end-to-end delivery, acceptance criteria, and `Blocked by` ticket numbers or `None`.
   Ask the user to review granularity and confirm that each blocking edge is real.
   Revise, merge, or split tickets until the user approves the draft.

4. Publish only after an explicit user choice.
   To create Jira tickets, obtain explicit confirmation to create the approved draft, then verify that the internal Jira Data Center capability is available and authenticated.
   Create tickets in dependency order and use native internal-Jira blocking links where supported.
   Keep the approved draft unchanged when that capability is unavailable; do not use a cloud Jira fallback.

   Create local Markdown tickets only when the user explicitly chooses that alternative.
   Write one dependency-ordered file per ticket under `.scratch/<feature-slug>/issues/<NN>-<slug>.md`, including its delivery, acceptance criteria, and `Blocked by` entries.