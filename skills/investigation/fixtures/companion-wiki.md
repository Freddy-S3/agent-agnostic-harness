# Investigation report: Which evidence should accompany the selected wiki draft?

Status: complete

Summary: The selected wiki page receives a companion draft that preserves the report's evidence and remains unpublished until operator approval.

Question: Which evidence should accompany the selected wiki draft?

Scope: The investigation report, evidence bundle, and one explicitly selected synthetic wiki page were included.
The publication action and unrelated wiki pages were excluded.

Methods: Compared the report evidence index with the draft fields and checked the publication gate.

Output route: report-and-wiki-draft
Wiki destination: Synthetic Operations / Investigation Notes / Run 041
Publication: pending operator approval

## Findings

### Observed facts

- [F1] The report and companion draft reference the same evidence identifiers.

### Inferences

- [I1] A shared evidence index lets an engineer review the draft without losing trace drill-down. Evidence: [E1].

### Hypotheses

- None material to the scoped question.

### Unresolved questions

- None within the scoped question.

## Evidence

- [E1] Synthetic report and draft comparison at `trace://run-041/wiki-draft-check`, fields `evidence` and `destination`.

## Uncertainty

- The synthetic check does not verify provider permissions or the eventual publication response.

## Recommended next steps

1. Ask the operator to approve or reject publication to the selected page.

## Recovery and follow-up

- The companion draft is complete and unpublished.
- If approval is rejected or the page changes, retain the report and regenerate only after selecting the new exact destination.
