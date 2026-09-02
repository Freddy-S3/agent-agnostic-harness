---
name: investigation
description: "Run an asynchronous investigation and produce a concise evidence-linked report. Use for customer, repository, operational, or system investigations when an engineer needs findings without reading the full trace; use research for source-backed topic memos and debugging for unexpected behavior that needs a failing repro."
user-invocable: true
---

# Investigation

Run a bounded investigation that preserves drill-down evidence while giving the reader a short report they can act on.
The report is the decision surface; the trace and evidence items are the audit surface.

## 1. Define the investigation

Write the question as one sentence before gathering evidence.

Record the scope, the requested output route, the allowed sources, the stop condition, and the person who will act on the result.

Use one of these output routes:

- `report` - produce the report and retain the trace as drill-down evidence.
- `wiki-draft` - produce the report as a draft for one explicitly selected wiki page.
- `report-and-wiki-draft` - produce both artifacts, with the same evidence references.

Treat `report` as the default route.
Create a wiki draft only when the work item or operator explicitly selects a page.
Publication always requires operator approval after the draft is reviewable.

## 2. Gather evidence asynchronously

Capture each material source with a stable evidence identifier such as `[E1]`.
Use repository paths with line numbers, provider record identifiers, URLs, or trace segment identifiers that let an engineer inspect the underlying material.

Keep the detailed trace separate from the final report.
Record enough progress checkpoints that an interrupted run can resume from the last completed method without repeating or hiding prior work.

Classify every claim before writing it:

- **Observed fact** - directly supported by an evidence item.
- **Inference** - a conclusion derived from one or more observed facts.
- **Hypothesis** - a plausible explanation or proposal that has not been verified.
- **Unresolved question** - a material gap, conflict, or decision the evidence does not settle.

Material findings must link to one or more evidence identifiers.
If a claim has no supporting evidence, keep it as an unresolved question or hypothesis rather than presenting it as a fact.

Use the slow asynchronous route when it improves evidence quality or cost.
The report must remain useful without the reader opening the trace, and the trace must remain available for disputed findings.

## 3. Produce the bounded report

Put the conclusion and status near the top, then use short bullets for findings.
Prefer a few precise findings over a transcript summary.
Trim repeated context, model narration, and unsupported speculation.

Use this structure:

```markdown
# Investigation report: <question>

Status: complete | inconclusive | partial | cancelled | failed

Summary: <one or two sentences stating the result and its practical meaning>

Question: <the question investigated>

Scope: <what was included and excluded>

Methods: <sources, checks, interviews, or experiments actually used>

## Findings

### Observed facts

- [F1] <fact>. Evidence: [E1].

### Inferences

- [I1] <inference>. Evidence: [E1], [E2].

### Hypotheses

- [H1] <unverified explanation or proposal>. Evidence: [E2].

### Unresolved questions

- [U1] <gap, conflict, or decision that remains open>.

## Evidence

- [E1] <source or trace segment with a durable locator>.

## Uncertainty

- <what could change the conclusion, confidence, sample limitation, or source conflict>.

## Recommended next steps

1. <smallest action and owner>

## Recovery and follow-up

- <what completed, what stopped, and how to resume, retry, or close the investigation>
```

Use `Status: complete` only when the scoped question has an actionable answer.
Use `inconclusive` when evidence is insufficient or materially conflicting.
Use `partial` when some scoped methods completed and a specific remainder can still be resumed.
Use `cancelled` when an operator or scope change intentionally stopped the work.
Use `failed` when an execution error stopped the work and recovery requires a new attempt or intervention.

Every status other than `complete` needs a concrete recovery or follow-up note.
An inconclusive result is a valid report when it clearly names the missing evidence and the next discriminating check.

## 4. Route a wiki draft safely

Keep the report and its evidence bundle as the durable source of truth.

When the selected route includes `wiki-draft`:

1. Confirm the exact destination page before drafting.
2. Create a draft that preserves the report status, evidence identifiers, uncertainty, and recommended next steps.
3. Keep publication separate from draft generation.
4. Wait for an operator approval tied to that exact page.
5. Publish only after approval, then record the published page reference in the report.

Never infer a wiki destination from a ticket type, parent, epic, or linked work item.
Never turn an investigation into a companion wiki draft merely because the work item is an investigation.

## 5. Close the run

Before returning the report, check that the question, scope, methods, findings, evidence, uncertainty, and next steps are all present.
Check that every material finding has an evidence reference and that facts, inferences, hypotheses, and unresolved questions are not mixed.
Check that the status matches the actual stopping point and that a partial, cancelled, or failed run names a safe recovery action.
Check that a wiki route names one explicit page and remains unpublished until approval.

Return the bounded report first.
Offer trace identifiers and the evidence index as drill-down material, not as a substitute for the report.
