---
name: business-planning
description: Inspect an existing business or project plan, identify the smallest missing decision, and ask focused questions or bounded choices. Use when planning, refining, validating, or restarting a business plan without inventing facts, and persist unanswered decisions to the dashboard queue.
---

# Business Planning

Use this workflow for a business, product, or project plan when the repository may already contain context and Faruk wants the next useful step without writing a speculative plan.

## Workflow

1. Identify the exact repository root and read existing project briefs, business plans, README files, queue entries, tracker records, and recent pull requests before asking anything.
2. Treat existing artifacts as source material, not automatically correct decisions. Preserve settled facts and label assumptions.
3. Build a short gap list across customer and problem, value proposition, target market, business model, differentiation, distribution, operations, risks, validation, and next milestone.
4. Choose the single highest-leverage unanswered decision. Ask at most one question at a time unless Faruk explicitly requests a questionnaire.
5. When choices are useful, offer two or three materially different, self-contained options with a recommendation and the trade-off for each.
6. After Faruk answers, record the decision in the project brief or business-plan file and summarize the next action in the coordination record.
7. If Faruk has not answered, persist the question to the appropriate queue file using compare-and-swap. Write a complete `Blocked reason:` and one-line `Options:` bullets so the dashboard can render it on a phone.
8. Keep all outputs agent-agnostic. Repository files, queue, tracker, and pull requests must carry anything another host needs to resume.

## Do not invent

- Do not fabricate market sizes, customer evidence, pricing, traction, credentials, or financial projections.
- Mark unknowns as unknowns and convert them into research or validation tasks.
- Do not create a business plan from a blank repository without first asking for the missing facts.

## Dashboard handoff

Use the queue when the next step requires Faruk's choice, research access, or a future session. Use the repository when the result is a durable plan, decision, experiment, or artifact. Keep the dashboard entry short and actionable; put history in the project file or log.

## Agent-agnostic execution

The same workflow must work in Codex, Claude Code, ChatGPT, or another host. Never make a host-specific Project, memory, or chat the sole location of a business decision.
