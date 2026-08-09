---
name: writing-for-agents
description: Writing documents for agents. Use when creating or editing a SKILL.md, an instructions file, a prompt file, an agent file, copilot-instructions.md/AGENTS.md, or a task handoff.
---

Reference for writing any document an agent consumes — a `SKILL.md`, an `.instructions.md`, a `.prompt.md`, an `.agent.md`, `copilot-instructions.md` / `AGENTS.md`, or a task handoff reached by a pointer. The packaging differs — frontmatter, folder, trigger mechanism — but the writing does not: the same levers make each one predictable, the agent taking the same _process_ every run, not producing the same output.

When the document you're writing is a `SKILL.md`, read [`SKILL-MECHANICS.md`](SKILL-MECHANICS.md) for frontmatter, invocation choice, and router skills.

## Context pointers

A **context pointer** is a reference held in the agent's context that names some out-of-context material and encodes the condition for reaching it. A skill's `description`, an instruction file's `applyTo` pattern, a line in `copilot-instructions.md` naming a doc, the file path a `closing` skill writes into a task handoff — all the same object. The pointer's _wording_, not its target, decides when the agent reaches the material — and how reliably. A must-have target behind a weakly worded pointer is a variance bug: sharpen the wording first, and inline the material only if sharpening fails.

A pointer does two jobs — state what the material is, and list the **branches** that should trigger reaching it (a branch is a distinct case the document handles, so different runs take different paths through it). Every word of an always-loaded pointer costs on every turn, so it earns even harder pruning than the body:

- **Front-load the leading word** — the pointer is where it does its triggering work.
- **One trigger per branch.** Synonyms that rename a single branch are one branch written twice; collapse them and keep only genuinely distinct branches.
- **Cut identity the body already carries.**

A handoff is the limit case: no `description`, no frontmatter at all — the whole pointer is a hardcoded file path (`/memories/repo/tasks/<ticket-id>-<slug>.md`) that only the skill writing and reading it knows to reach for. All of the pointer's reliability comes from that convention being followed consistently, since there is no discovery machinery to fall back on.

## The two loads

Every document and pointer you add spends one of two budgets:

- **Context load** — the cost of always-loaded material on the agent's window: a `copilot-instructions.md` line, a skill or instruction `description`, an `applyTo: "**"` pattern, anything sitting in context every turn, spending tokens and attention whether or not it fires.
- **Cognitive load** — the cost on the human: which documents exist and when to reach for each. The human is the index. Not a cost to minimise — it is the price of human agency; spend it where human judgement matters, remove it where it does not.

Material reached only through a pointer escapes context load at the price of the pointer's own line; material with no pointer at all — a `user-invocable` skill nobody remembers, a handoff nobody re-reads — rides entirely on cognitive load.

## Information hierarchy

A document is built from two content types — **steps** (the ordered actions the agent performs) and **reference** (definitions, rules, facts consulted on demand) — that mix freely: all steps (a prompt's task template), all reference (an instruction file's coding rules, this skill), or both (most `SKILL.md` bodies). The core decision is where each piece sits on the **information hierarchy**, a ladder ranked by how immediately the agent needs the material:

1. **In-file step** — the primary tier: what the agent does, in order.
2. **In-file reference** — consulted on demand. Often a legitimately flat peer-set (every rule in an instructions file on one rung) — a fine arrangement, not a smell.
3. **Disclosed reference** — pushed out into a separate file, reached by a context pointer, loaded only when the pointer fires. Spans a sibling file in the same skill folder (`SKILL-MECHANICS.md`, a file under `references/`) through fully external reference that lives anywhere and any document can point at (another instructions file, a linked doc in a prompt).

Push too little down and the top bloats; push too much and you hide material the agent actually needs. That tension is the whole decision.

**Progressive disclosure** is the move down the ladder — out of the main file and behind a pointer — so the top stays legible. Not primarily a token optimisation: it is how the hierarchy is protected. Branching is the cleanest disclosure test: inline what every branch needs, and push behind a pointer what only some branches reach. When a document has steps, in-file reference that should be disclosed buries them and turns attending to them into a coin-flip — a variance lever, not just a legibility one.

**Co-location** is the within-file companion: where the ladder decides _how far down_ a piece sits, co-location decides _what sits beside it_ once there. Keep a concept's definition, rules, and caveats under one heading rather than scattered, so reading one part brings its neighbours with it. The test: the document should read like documentation written for the agent — grouped material reads that way; scattered material does not. (Distinct from duplication: that repeats one meaning in two places; scattering fragments one meaning across many.)

**Sprawl** is the failure mode here: a document simply too long, even when every line is live and unique — a `SKILL.md` past the size that keeps it loadable, an instructions file nobody reads in full. Attention thins across the excess, and every extra line is one more to keep relevant. The cure is the ladder: disclose reference behind pointers, and split by branch or sequence so each path carries only what it needs.

## Steps and completion criteria

Every step ends on a **completion criterion** — the condition that tells the agent the work is done. Two properties make it a lever:

- **Clarity** — can the agent tell done from not-done? A vague bound ("understanding reached") invites **premature completion**: ending the step before it is genuinely done, attention slipping to _being done_. The visible steps still ahead — the **post-completion steps** — supply the pull; the criterion's clarity is the resistance. Defend in order: **sharpen the bound first** (local and cheap — a task handoff's "Next Step" line is this instinct applied to an entire session); only if it is irreducibly fuzzy _and_ you observe the rush, hide the later steps by splitting the sequence — and hiding only works across a real context boundary (a handoff, or a custom agent dispatched as a subagent; an inline call leaves the later steps in context and clears nothing).
- **Demand** — how much it requires. "Every modified model accounted for" forces thorough work where "produce a change list" does not. Demand drives **legwork** — the digging the agent does within the work, latent in the wording rather than written as its own step — and it is not step-bound: "every rule applied" binds a body of flat reference just as "every step done" binds a sequence, which is how an all-reference instructions file still carries an exhaustiveness bar.

The strongest criteria are both checkable and exhaustive.

## When to split

Splitting one document into two spends one of the two loads, so split only when the cut earns it:

- **By sequence** — split a run of steps where the post-completion steps tempt the agent to rush the one in front of it. Keeping them out of view drives more legwork on the current task. Beware the reverse: merging sequences exposes each step's later steps to what follows, inviting premature completion.
- **By invocation** — different trigger mechanisms (skill vs. instructions vs. prompt vs. agent, or model-invoked vs. user-invoked within one of those): see [`SKILL-MECHANICS.md`](SKILL-MECHANICS.md).

## Leading words

A **leading word** is a compact concept already living in the model's pretraining that the agent thinks with while running the document (_lesson_, _fog of war_, _tracer bullets_). Repeated as a token, never as a sentence, it accumulates a distributed definition and anchors a whole region of behaviour in the fewest tokens, by recruiting priors the model already holds. Coining your own works if you define it clearly, but a made-up word recruits no priors — you pay in definition tokens what a pretrained word gives free; reach for an existing word first.

It anchors twice. In the body, _execution_: the agent reaches for the same behaviour every time the word appears, and inside flat reference it focuses attention on a class of thing to look for. In a pointer — a skill or instructions `description`, an `applyTo` comment — _invocation_: when the same word lives in your prompts, your docs, and your codebase, the agent links that shared language to the material and reaches it more reliably.

Hunt for opportunities to refactor with leading words. A triad spelled out at three sites, a pointer spending a sentence to gesture at one idea — each is a passage begging to collapse into a single token:

- "fast, deterministic, low-overhead" → _tight_ (a _tight_ loop).
- "a loop you believe in" → _red_ — a fuzzy gate becomes a binary observable state (the loop goes _red_ on the bug, or it doesn't).

You win twice: fewer tokens, and a sharper hook for the agent to hang its thinking on. Assume every document — including the `description` fields the agent scans first — is carrying restatements that leading words retire. Go find them.

## Positive instructions over negation

**Negation** is a failure mode that cuts across every document type: steering by prohibition drags the forbidden behaviour into context and makes it _more_ available, not less. _Don't think of an elephant_, and the elephant is all there is; the negation is a weak modifier the strongly-activated concept overruns, so the ban half-reads as an instruction to do the thing. This is why a `Constraints` block of pure "DO NOT" lines in an agent file, or a rule phrased as "don't do X" in an instructions file, underperforms its positive rewrite.

Prompt the **positive** — state the target behaviour ("write one-line comments") so the banned one is never spoken. A prohibition earns its place only as a hard guardrail you cannot phrase positively (a security boundary, an irreversible action); even then, pair it with the positive target so attention lands on what to do, not just what to avoid.

## Pruning

- Keep each meaning in a **single source of truth**: one authoritative place, so changing the behaviour is a one-place edit. **Duplication** — the same meaning in more than one place, such as a rule copied into both an instructions file and a skill it overlaps with — costs maintenance and tokens, and inflates a meaning's prominence on the ladder past its real rank. (The accidental inverse of a leading word, which repeats a token on purpose, never the meaning.)
- The **environment** is a source of truth too — a `package.json` script, a config file, the repo's directory layout, a CLI's `--help` output — and a document that restates it is a **cache**: a copy of a lookup, earning its load only when the lookup is expensive. Cache what the agent cannot find by looking: the unwritten convention, the reason behind a choice, the gotcha no config confesses. Leave the one-file, one-command lookups to the environment, where they cannot go stale.
- Check every line for **relevance**: does it still bear on what the document does? A line loses relevance by never bearing on the task (mere exposition, or a branch that should be disclosed) or by going stale as the behaviour or world it describes changes. Shorter documents are easier to keep relevant. Without a pruning discipline the default fate is **sediment**: stale layers that settle in a `copilot-instructions.md` or a long-lived skill because adding feels safe and removing feels risky, until you must core down through them to find what is still live.
- Hunt **no-ops** sentence by sentence: an instruction the model already obeys by default pays load to say nothing. The test — does it change behaviour versus the default? — is model-relative, not reader-relative: two people disagreeing about a no-op disagree about the default, and settle it by running the document, not by debate. When a sentence fails, delete the whole sentence rather than trim words from it. The test also grades leading words: a word too weak to beat the default (_be thorough_ when the agent is already thorough-ish) is a no-op, and the fix is a stronger word (_relentless_), not a different technique.

## Validation

Before treating a document as done, check it on two axes:

- **Mechanical.** The frontmatter parses: quote any `description` containing a colon, use spaces not tabs, and for a `SKILL.md` confirm `name` uses only lowercase letters, numbers, and hyphens and matches the containing folder exactly. For an instructions file, confirm `applyTo` is a real glob scoped to the files that need it — `applyTo: "**"` silently means "load on every single turn regardless of relevance," which is rarely what was intended. For a skill or agent, confirm `user-invocable` and `disable-model-invocation` are set deliberately, not left at their defaults by accident — each combination changes both who can reach the document and what it costs on every turn.
- **Behavioural.** Run the document — literally invoke it, or trace it step by step as the agent would — rather than debating what it should do. This settles no-op prose (does this line change behaviour or not?), confirms every completion criterion is actually checkable, and confirms the pointer that leads here fires on the branches it claims to and stays silent on the ones it doesn't. A pointer or a skill you have never seen fire under its real trigger conditions is unvalidated, no matter how carefully it reads.

Treat validation as the last step of writing, not an optional pass: a document that reads well but was never run is a guess about behaviour, not a description of it.
