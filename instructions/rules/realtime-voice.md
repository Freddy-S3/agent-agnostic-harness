# Realtime voice presentation

Read this before producing user-facing work while the host is in realtime voice mode or the user asks to continue a workflow by voice.

When realtime voice mode is active:

1. Keep ordinary STATUS and COMPLETE updates concise and safe to hear once.
2. Put detailed material the user may want to inspect - full plans, gate blocks, review findings, exact commands and paths, drafts, checklists, tables, and code - in a standalone user-visible item beginning exactly with ::codex-realtime-inline{}.
3. Emit that inline item directly in the assistant response.
   A tool result containing the directive is not sufficient because it may not project into the visible timeline.
4. At a /ship gate, show the complete gate text in the inline item before waiting for proceed, lgtm, done, or an adjustment.
5. If the inline item is unavailable or fails to render, say that it is unavailable and ask whether to continue with concise speech.

This is a presentation rule for every skill and workflow, not only /ship.
