# Architecture Review

Read [Codebase Design](SKILL.md) first for the shared vocabulary and principles.

Use this review to find **deepening opportunities**: places where reshaping a shallow module could increase leverage and locality.
This is a scoped discovery activity.
Do not propose an interface or modify code until the user selects a candidate.

## 1. Set the scope

- Follow the user's direction when they name a module, subsystem, or pain point.
- Otherwise, inspect recent history for recurring paths and start with those hot spots.
  Widen only when history offers no clear focus.
- Read the relevant domain context and nearby ADRs before judging the code.
  Use the domain's terms to name seams, and treat recorded decisions as constraints unless observed friction warrants reopening one.

## 2. Inspect for friction

Trace a small, representative path through the scoped area: callers, modules, tests, and adapters.
Look for:

- Understanding one concept requiring navigation through many small modules.
- A shallow module whose interface is nearly as complex as its implementation.
- Extracted pure functions that make isolated tests easy while the real behaviour remains distributed across callers.
- Coupled modules leaking knowledge across a seam.
- Behaviour that is untested or difficult to test through its interface.

For every suspected shallow module, apply the **deletion test**: if deleting it makes complexity reappear across callers, it is providing leverage; if the complexity simply vanishes, it is likely a pass-through.

## 3. Present ranked candidates

Present only evidence-backed candidates, ordered by expected leverage, locality, and confidence.
For each candidate, state:

- **Module and seam:** the domain concept and affected paths.
- **Friction:** how the current interface is shallow or leaks implementation knowledge.
- **Deletion test:** what complexity would move, disappear, or concentrate.
- **Deepening direction:** what behaviour could move behind a smaller interface, without designing that interface yet.
- **Payoff:** expected leverage, locality, and testability.
- **Confidence:** `Strong`, `Worth exploring`, or `Speculative`, including any relevant ADR tension.

Ask the user which candidate to explore.
Only after they choose should the review move on to proposing interfaces or alternative designs.
