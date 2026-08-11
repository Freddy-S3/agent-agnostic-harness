---
name: domain-modeling
description: Build and sharpen a project's domain model. Use when the user wants to pin down domain terminology or a ubiquitous language, record an architectural decision, or when another skill needs to maintain the domain model.
user-invocable: true
---

# Domain Modeling

Actively build and sharpen the project's domain model as you design. This is the *active* discipline — challenging terms, inventing edge-case scenarios, and writing the glossary and decisions down the moment they crystallise. (Merely *reading* `CONTEXT.md` for vocabulary is not this skill — that's a one-line habit any skill can do. This skill is for when you're changing the model, not just consuming it.)

## File structure

Most repos have a single context:

```
/
├── CONTEXT.md
├── docs/
│   └── adr/
│       ├── 0001-event-sourced-orders.md
│       └── 0002-postgres-for-write-model.md
└── src/
```

If a `CONTEXT-MAP.md` exists at the root, the repo has multiple contexts. The map points to where each one lives:

```
/
├── CONTEXT-MAP.md
├── docs/
│   └── adr/                          ← system-wide decisions
├── src/
│   ├── ordering/
│   │   ├── CONTEXT.md
│   │   └── docs/adr/                 ← context-specific decisions
│   └── billing/
│       ├── CONTEXT.md
│       └── docs/adr/
```

Create files lazily — only when you have something to write. If no `CONTEXT.md` exists, create one when the first term is resolved. If no `docs/adr/` exists, create it when the first ADR is needed.

## Existing repo compatibility

This skill layers onto whatever a repo already has — it never overwrites existing sources of truth:

- **Existing `CONTEXT.md` / `CONTEXT-MAP.md`** — if a repo already has one (root or per-context, e.g. under a shared `Libraries/` or a per-service folder), treat it as the live glossary and edit it in place using the format below. Never replace its structure or wipe prior entries; append/refine.
- **Existing `docs/adr/`** — look for an existing ADR log (often under `docs/` or `infra/`) before creating a new `docs/adr/` directory; reuse and continue its numbering instead of starting a parallel one.
- **Instructions files** (`.github/copilot-instructions.md`, `AGENTS.md`, `CLAUDE.md`, `*.instructions.md`) — these carry standing architecture, naming, and workflow conventions. They are a *complement* to `CONTEXT.md`, not a duplicate: instructions files describe how to build and deploy; `CONTEXT.md` defines what the domain terms mean. Don't migrate content between them — cross-reference instead if a term and a convention are related.
- **User/repo memory** (any persisted agent memory, prior session notes, or workspace-level preferences) — read it for already-resolved terminology or decisions before asking the user again, but don't duplicate it into `CONTEXT.md`/ADRs unless it's genuinely a domain term or an architectural decision. Never overwrite memory entries this skill didn't create.
- When in doubt about whether a file is already the project's glossary or decision log, read it first; only create a new one if nothing suitable exists.

## During the session

### Challenge against the glossary

When the user uses a term that conflicts with the existing language in `CONTEXT.md`, call it out immediately. "Your glossary defines 'cancellation' as X, but you seem to mean Y — which is it?"

### Sharpen fuzzy language

When the user uses vague or overloaded terms, propose a precise canonical term. "You're saying 'account' — do you mean the Customer or the User? Those are different things."

### Discuss concrete scenarios

When domain relationships are being discussed, stress-test them with specific scenarios. Invent scenarios that probe edge cases and force the user to be precise about the boundaries between concepts.

### Cross-reference with code

When the user states how something works, check whether the code agrees. If you find a contradiction, surface it: "Your code cancels entire Orders, but you just said partial cancellation is possible — which is right?"

### Update CONTEXT.md inline

When a term is resolved, update `CONTEXT.md` right there. Don't batch these up — capture them as they happen. Use the format in [CONTEXT-FORMAT.md](./CONTEXT-FORMAT.md).

`CONTEXT.md` should be totally devoid of implementation details. Do not treat `CONTEXT.md` as a spec, a scratch pad, or a repository for implementation decisions. It is a glossary and nothing else.

### Offer ADRs sparingly

Only offer to create an ADR when all three are true:

1. **Hard to reverse** — the cost of changing your mind later is meaningful
2. **Surprising without context** — a future reader will wonder "why did they do it this way?"
3. **The result of a real trade-off** — there were genuine alternatives and you picked one for specific reasons

If any of the three is missing, skip the ADR. Use the format in [ADR-FORMAT.md](./ADR-FORMAT.md).
