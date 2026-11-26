# Software factory contract

The software factory is a versioned loop from intake through monitoring and feedback.

`/ship` owns the interactive six-phase execution loop.
`tools/queue-runner.ps1` owns one-item selection, checkpointing, and resumability.
`tools/validate-factory-result.ps1` owns the machine-checkable handoff contract.
`tools/check-factory-progress.ps1` detects idle or repeating worker event sequences.
`tools/evaluate-factory.ps1` replays representative local cases and records outcome, latency, and optional run metrics.

## Result contract

Every phase or worker result should carry `schemaVersion: 1`, a `runId`, a `phase`, an explicit `status`, timestamps, a summary, and evidence.

Valid statuses are `completed`, `partial`, `failed`, `blocked`, `cancelled`, `rejected`, `stale`, and `unknown`.
An incomplete result carries a `nextAction`.
Failed, blocked, stale, and unknown results also carry a `failureReason`.
Unknown results carry an `unknownReason`; a timeout is not silently converted into failure.

Evidence carries a kind, reference, source, revision, and `asOf` timestamp so a later decision can check provenance and freshness.

Side effects carry an identity, operation, idempotency key, and confirmation read-back.
A result is not complete while a side effect is only planned, submitted, or unknown.

Progress records event count and can mark a repeated signature or a stall.
Completed results cannot claim to be stalled or repeating.
The independent JSONL progress check fails after a configured idle or repeated-signature threshold, so a worker cannot certify its own lack of progress as success.

Resources record fan-out and its budget, plus any available token, latency, or cost measurements.
The validator refuses a result that exceeds the configured fan-out budget.

## Manifest and replay

Start from [`templates/software-factory/factory.manifest.json`](../templates/software-factory/factory.manifest.json).
Keep the manifest in the project repository beside the workflow it describes.
Review commands before running them because evaluation cases are executable local commands.

Run a replay evaluation with:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/evaluate-factory.ps1 `
  -Manifest templates/software-factory/factory.manifest.json `
  -Output .software-factory/runs/latest.json
```

The report preserves case origin, expected and actual exit status, latency, bounded output, and optional metrics loaded from a case `metricsPath`.
Use the report to compare harness changes against a representative baseline.

## Human decisions

The factory keeps human gates for product intent, security, destructive effects, review, and reflection.
The gate text must be emitted as a standalone visible response so a host's progress UI cannot hide the approval boundary.
Every approved `/ship` implementation also refreshes or creates `docs/PROJECT-CONTEXT.md`.
