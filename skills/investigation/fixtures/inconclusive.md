# Investigation report: Is the intermittent queue delay caused by provider throttling?

Status: inconclusive

Summary: The available run evidence shows queue delay and one provider warning, but it does not establish throttling as the cause.
The next check must correlate provider response timing with queue wait time across more than one run.

Question: Is provider throttling the cause of the intermittent queue delay?

Scope: Three synthetic runs, queue timestamps, and provider response metadata were included.
Network infrastructure and unrelated worker latency were excluded.

Methods: Compared queue timestamps with provider response metadata and inspected the warning trace segment.

Output route: report
Wiki destination: none selected

## Findings

### Observed facts

- [F1] Two of three runs exceeded the queue-delay threshold. Evidence: [E1].
- [F2] One run contains a provider warning, but its response metadata does not include a throttle code. Evidence: [E2].

### Inferences

- [I1] Provider throttling is plausible but not established by the current sample. Evidence: [E1], [E2].

### Hypotheses

- [H1] A worker-side retry delay may account for the observed queue time. Evidence: [E3].

### Unresolved questions

- [U1] Did the provider reject or delay the requests during the two slow runs?

## Evidence

- [E1] Synthetic queue timing table at `fixtures/queue-timing.md`, lines 2-10.
- [E2] Provider metadata trace `trace://run-018/provider-response`, fields `warning` and `status`.
- [E3] Worker trace `trace://run-018/retry-loop`, steps 5-9.

## Uncertainty

- Confidence is low because the sample is small and the provider metadata lacks a throttle-specific signal.

## Recommended next steps

1. Capture provider response codes and retry delay for five additional synthetic runs.

## Recovery and follow-up

- The investigation is inconclusive, not failed.
- Resume by collecting the missing provider timing evidence and updating this report with the same evidence identifiers where possible.
