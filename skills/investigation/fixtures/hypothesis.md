# Investigation report: What explains the duplicate synthetic branch?

Status: partial

Summary: The trace confirms that two workers attempted the same branch operation, but the cause of the duplicate assignment remains unverified.
The leading explanation is a stale retry after the first worker lost its acknowledgement.

Question: What explains the duplicate synthetic branch assignment?

Scope: The branch-assignment events and worker traces for the synthetic run were included.
Provider webhook delivery and repository-host internals were excluded.

Methods: Compared event identifiers, worker timestamps, and the branch-assignment trace.

Output route: report
Wiki destination: none selected

## Findings

### Observed facts

- [F1] Two branch-assignment attempts use the same ticket revision. Evidence: [E1].
- [F2] The first worker records a timeout before the second attempt begins. Evidence: [E2].

### Inferences

- [I1] The duplicate assignment likely occurred during retry recovery, but the evidence does not identify which component retried. Evidence: [E1], [E2].

### Hypotheses

- [H1] The first worker completed the assignment but lost its acknowledgement, causing a stale retry. Evidence: [E2].

### Unresolved questions

- [U1] Which component owns the retry after an assignment acknowledgement timeout?

## Evidence

- [E1] Synthetic assignment event log `trace://run-022/branch-events`, events 11-12.
- [E2] Worker trace `trace://run-022/ack-timeout`, steps 7-13.

## Uncertainty

- [H1] is a hypothesis, not a confirmed root cause.
- The repository-host acknowledgement record is outside the current scope.

## Recommended next steps

1. Inspect the repository-host acknowledgement record and retry-owner configuration before changing deduplication behavior.

## Recovery and follow-up

- The investigation is partial because the retry owner was not inspected.
- Resume from [U1] without creating another branch or rerunning the completed trace review.
