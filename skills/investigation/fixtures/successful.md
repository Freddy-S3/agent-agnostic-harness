# Investigation report: Why did the synthetic draft miss the acceptance check?

Status: complete

Summary: The draft omitted one acceptance criterion because the worker loaded the ticket summary but not the acceptance-criteria section.
The evidence supports a context-loading fix rather than a model-quality conclusion.

Question: Why did the synthetic draft miss one acceptance criterion?

Scope: The synthetic repository, ticket snapshot, worker trace, and generated draft were included.
Provider reliability and model selection were excluded.

Methods: Compared the ticket snapshot with the draft, inspected the worker trace, and replayed the context-loading step.

## Findings

### Observed facts

- [F1] The ticket snapshot contains four acceptance criteria, while the draft addresses three. Evidence: [E1].
- [F2] The trace shows the worker loaded the ticket summary and stopped before loading the acceptance-criteria section. Evidence: [E2].

### Inferences

- [I1] The missing criterion is explained by incomplete context loading in this run. Evidence: [E1], [E2].

### Hypotheses

- None material to the scoped question.

### Unresolved questions

- None within the scoped question.

## Evidence

- [E1] Synthetic ticket snapshot at `fixtures/ticket-041.md`, lines 1-18.
- [E2] Trace segment `trace://run-041/context-load`, steps 2-4.

## Uncertainty

- Confidence is high for this synthetic run, but the same check should be repeated on a second ticket before changing the production loader.

## Recommended next steps

1. Require the worker context loader to report the acceptance-criteria section before drafting.

## Recovery and follow-up

- The investigation completed.
- A follow-up implementation can start from the trace segment and rerun the acceptance-criteria fixture.
