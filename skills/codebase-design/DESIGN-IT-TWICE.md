# Design It Twice

When the user wants to explore alternative interfaces for a chosen deepening candidate, use this parallel-exploration pattern. Based on "Design It Twice" (Ousterhout) — your first idea is unlikely to be the best.

Uses the vocabulary in [SKILL.md](SKILL.md) — **module**, **interface**, **seam**, **adapter**, **leverage**.

## Process

### 1. Frame the problem space

Before exploring alternatives, write a user-facing explanation of the problem space for the chosen candidate:

- The constraints any new interface would need to satisfy
- The dependencies it would rely on, and which category they fall into (see [DEEPENING.md](DEEPENING.md))
- A rough illustrative code sketch to ground the constraints — not a proposal, just a way to make the constraints concrete

Show this to the user, then immediately proceed to Step 2. The user reads and thinks while the alternatives are worked out.

### 2. Explore alternative designs

Produce 3+ candidate interfaces for the deepened module. Each must be **radically different**, not a minor variation on the others.

If the harness has a way to dispatch independent sub-agents or background tasks, run each candidate as its own dispatch in parallel, giving each a separate technical brief (file paths, coupling details, dependency category from [DEEPENING.md](DEEPENING.md), what sits behind the seam) plus a distinct design constraint. If no such dispatch mechanism is available, work through the candidates yourself one at a time, deliberately switching constraints between passes so the designs don't converge. Example constraints, one per candidate:

- Candidate 1: "Minimize the interface — aim for 1–3 entry points max. Maximise leverage per entry point."
- Candidate 2: "Maximise flexibility — support many use cases and extension."
- Candidate 3: "Optimise for the most common caller — make the default case trivial."
- Candidate 4 (if applicable): "Design around ports & adapters for cross-seam dependencies."

Include the [SKILL.md](SKILL.md) vocabulary and any project-specific domain vocabulary in the brief so every candidate names things consistently with the architecture language and the project's domain language.

Each candidate should produce:

1. Interface (types, methods, params — plus invariants, ordering, error modes)
2. Usage example showing how callers use it
3. What the implementation hides behind the seam
4. Dependency strategy and adapters (see [DEEPENING.md](DEEPENING.md))
5. Trade-offs — where leverage is high, where it's thin

### 3. Present and compare

Present designs sequentially so the user can absorb each one, then compare them in prose. Contrast by **depth** (leverage at the interface), **locality** (where change concentrates), and **seam placement**.

After comparing, give your own recommendation: which design you think is strongest and why. If elements from different designs would combine well, propose a hybrid. Be opinionated — the user wants a strong read, not a menu.
