# Skill Widgets

How a harness skill renders its output as clickable cards in the Claude desktop app instead of a wall of text.

Faruk reads most skill output on a phone, once, between other things.
A report whose only affordance is "type a reply describing which of these eleven things you meant" spends his attention on transcription rather than on the decision.
A card with two buttons spends it on the decision.

This document is the shared contract.
`/status-report` and `/queue` implement it; any skill whose output is a list of things awaiting Faruk's call should too.

## Mechanism

Render with the `mcp__visualize__show_widget` tool.
It renders raw HTML inline in the conversation and exposes one global:

```js
sendPrompt(text)   // sends `text` to the chat exactly as if Faruk had typed it
```

That is the whole interaction model.
A button does not call an API, mutate a file, or hold state — it composes a message and sends it.
Everything after that is the ordinary skill contract handling an ordinary user turn.

This matters more than it looks. It means:

- A widget can never take an action Faruk did not click, because the click only produces a prompt.
- A button is only real if the receiving skill already understands the sentence it sends. Adding a button is therefore two changes, not one: the card, and the skill instruction that handles its text. A button that sends a sentence no skill parses is a dead control that looks live, which is worse than no button.
- Nothing is lost if the widget fails to render. See Fallback.

## When to render

Render a widget when the output is **a list of discrete items, each awaiting a decision**.

Do not render one for:

- A single answer, a paragraph, or a yes/no. Text is faster to read than a card.
- Output with nothing to click. A status line with no available action is prose; leave it as prose.
- An unattended run (`/sleep`, a scheduled `/queue`). There is nobody there to click. Write the text report to the log and skip the widget entirely.

## Card anatomy

Each card carries, in this order:

1. **A state chip** — `pending`, `in-progress`, `blocked`, `done`, or for a decision, its source skill and repo.
2. **A title** — the item, five words or fewer where possible.
3. **One line of context** — the latest `Log:` line, or the blocking reason. One line, not the entry.
4. **Its buttons** — at most three per card, ordered with the recommended action first.

Detail beyond that one line goes behind a button (`sendPrompt("Tell me more about …")`), never onto the card.
The complexity budget is real: a card that has to be read carefully has failed at the only thing it was for.

## Action vocabulary

Buttons send these sentences. Keep them verbatim so the receiving skill's instructions can match on them.

**Decision cards** (`/status-report`):

| Button | Sends |
| --- | --- |
| Approve | `Answer <n>: approve.` |
| Reject | `Answer <n>: reject.` |
| Explain | `Explain decision <n> in more detail before I answer.` |

**Queue item cards** (`/queue`):

| Button | Sends |
| --- | --- |
| Run next | `Run the queue item "<title>" next.` |
| Skip | `Skip the queue item "<title>" for this run.` |
| Requeue | `Move the queue item "<title>" to the <pc\|phone> queue.` |
| Unblock | `Unblock the queue item "<title>": <the fix from the BLOCKED ON YOU line>.` |

**Blocker cards** (`/status-report`'s `BLOCKED ON YOU`):

| Button | Sends |
| --- | --- |
| I did this | `<blocker> is resolved. Re-check it and continue the items it gates.` |
| Not now | `Leave <blocker> blocked; keep it on the list.` |

Add a row here before adding a button, not after.

## Style

Use the host's own design-system variables so the widget reads as part of the app rather than as an embedded page.
Never hardcode a hex colour; the variables already resolve correctly in light and dark themes, and a hardcoded value is the single most common way a widget ends up unreadable in one of them.

| Purpose | Variable |
| --- | --- |
| Card surface | `--surface-1`, nested detail on `--surface-2` |
| Card border | `--border`, `--border-strong` on hover |
| Title text | `--text-primary` |
| Context line | `--text-secondary`, muted metadata `--text-muted` |
| Primary button | `--fill-primary` on `--on-primary` |
| Secondary button | `--fill-secondary` on `--text-primary` |
| `blocked` chip | `--bg-danger` / `--text-danger` |
| `in-progress` chip | `--bg-warning` / `--text-warning` |
| `done` chip | `--bg-success` / `--text-success` |
| Corner radius, control height | `--radius`, `--h-control` |

Flat surfaces only: no gradients, shadows beyond `--shadow-sm`, or decorative effects.
Begin the widget with a visually hidden `<h2 class="sr-only">` summarising what the card list contains.
Buttons must be real `<button>` elements so they are reachable by keyboard, not styled `<div>`s.

## Fallback

**Always emit the text report as well.**

The widget is an affordance layered on the report, not a replacement for it.
Write the normal text format in the response, then render the widget alongside it.

Three reasons this is not redundancy:

- The widget tool may be unavailable — a different client, a headless or scheduled run, a tool-permission denial. The text report is what survives.
- Widget contents are not part of the conversation transcript in the way response text is, so a later session reading back the session cannot recover what a widget-only report said.
- Freddy reads the text faster than he clicks when the answer is obvious, and reaches for the buttons when it is not. Both paths should exist in the same reply.

There is a real tension here, found by rendering one rather than by reasoning about it: the widget tool's own guidance says not to restate content it has already shown visually, and this rule says always emit text as well.

Resolve it by making the text a **digest, not a duplicate**.
The card list carries the per-item context and the buttons; the text carries the counts, the item titles, and anything Faruk must act on outside the app.
One line per item is enough, and headline counts alone are enough when the list runs long.
Shorten the text report when it gets noisy - never drop it, because it is the only half that survives a headless run or a transcript read back later.
