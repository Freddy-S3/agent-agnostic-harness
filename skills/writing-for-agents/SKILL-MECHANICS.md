# Skill mechanics

The skill-specific branch of [`writing-for-agents`](SKILL.md): what changes when the document is a `SKILL.md` — frontmatter, the invocation choice, and router skills — plus how the same invocation trade-off reappears in instructions, prompts, and agents. Everything else about writing it is the universal reference in `SKILL.md`.

## Invocation

A skill's frontmatter carries two independent switches, each trading the two loads:

- **`user-invocable`** (default `true`) — shows the skill as a slash command the human can type. Set `false` to hide it from that surface entirely; the only way in is then the model finding it via `description`, or another skill/agent invoking it.
- **`disable-model-invocation`** (default `false`) — controls whether the agent can fire the skill on its own from its `description`. Leave it unset for a **model-invoked** skill: the `description` becomes the skill's top-level context pointer, forced to stay loaded at all times — permanent context load in exchange for discoverability. Set it `true` for a **user-invoked** skill: the `description` drops out of autonomous reach, so only a typed slash command finds it. Zero context load, but it spends cognitive load — you are the index that must remember it exists.

A model-invoked skill whose content is all reference is also one home for shared reference: another skill can invoke it, so reference needed by several skills lives in one place. Mechanics for a model-invoked skill: omit `disable-model-invocation`, and write a model-facing `description` carrying the trigger branches (the pointer-writing rules in `SKILL.md` apply in full). Mechanics for a user-invoked skill: set `disable-model-invocation: true`; the `description` becomes human-facing — a one-line summary, trigger lists stripped since nothing but the human reads it.

Pick model-invocation only when the agent must reach the skill on its own, or another skill must. If it only ever fires by hand, make it user-invoked and pay no context load.

Shared reference that two user-invoked skills both need can live in neither — with `disable-model-invocation: true` on both, neither can fire the other. Push it to a plain file outside the skill system: external reference any skill can point at (a shared file under a `references/` folder, or a doc named directly in each skill body).

## The same axis in instructions, prompts, and agents

The model-invoked/user-invoked trade-off is not skill-specific; each VS Code document type exposes its own version of it:

- **Instructions (`.instructions.md`)** split the axis into two separate fields instead of one switch. `description` is the on-demand, model-invoked path — the agent decides relevance from the wording, same rules as a skill's description. `applyTo` is a deterministic, always-fires path keyed on the files already in context rather than on task relevance — closer to a standing pointer than a judged one. The two are not mutually exclusive: a file can carry both, but each still spends context load independently, and `applyTo: "**"` spends it on every single turn regardless of relevance — the instructions equivalent of leaving a model-invoked skill's description permanently loaded, but with no relevance judgement gating it at all.
- **Prompts (`.prompt.md`)** carry no model-invocation switch at all: a prompt is reached only by a human typing `/`, running `Chat: Run Prompt...`, or pressing play in the editor. Its `description` spends no context load on autonomous discovery — it only aids the human scanning the slash-command list, so it is pure cognitive-load currency, written for a person, not a trigger for the model.
- **Agents (`.agent.md`)** carry both switches at once, same names as a skill's: `user-invocable` gates the agent picker, `disable-model-invocation` gates whether another agent can dispatch it as a subagent. A `description` written for subagent discovery (the parent agent's trigger phrases) does the same pointer-writing work as a model-invoked skill's description; an `agents: [...]` allow-list is a pointer restriction in the other direction, capping which subagents a given agent may reach at all.
- **Handoffs** sit outside this axis entirely: a task handoff has no frontmatter and no invocation switch, only a file-path convention a skill hardcodes on both ends (writing it, then reading it back). There is nothing to discover and nothing to disable — the entire reliability of reaching it rides on the convention being followed, which is why the path and structure must stay exact.

## Splitting by invocation

The invocation cut of splitting (the sequence cut lives in `SKILL.md`): split off a model-invoked skill, or promote a shared instructions section to its own model-invoked one, when you have a distinct leading word that should trigger it on its own — a trigger word you actually use in your prompts — or another skill or agent must reach it independently. The same test decides when a chunk of an agent's body should instead become its own subagent: does it need a context boundary of its own (a clean return value, tool restrictions the parent doesn't have), not just a subsection. You pay context load for the new always-loaded description, so that independent reach has to be worth it.

## Router skills

When user-invoked skills multiply past what you can remember, that piled-up cognitive load is cured by a **router skill**: one user-invoked skill that names the others and when to reach for each, so the human has one skill to remember instead of many. A routing-only skill can only hint, never slash-invoke them: user-invoked skills have no live `description`, so nothing but the human can reach them through skill discovery. An execution router may instead load and apply a selected owner's `SKILL.md` directly; this adopts the documented workflow without invoking another slash command, and it preserves the selected owner's gates and interaction protocol. The same pattern works as a router instructions file or a routing section in `copilot-instructions.md` when the pile is instructions rather than skills.
