---
name: deploy-nonprod
description: "When a user asks whether a change can be deployed, plans a sandbox run, or explicitly requests a nonproduction execution, resolve the provider-neutral pipeline contract and keep planning, authorization, execution, reconciliation, and application verification separate."
user-invocable: true
---

# Deploy Nonproduction

Use [integration contracts](../../docs/INTEGRATION-CONTRACTS.md) for source binding, authorization, and duplicate prevention.

## Run

1. Resolve project, component, configured provider, exact pipeline, and owning task.
2. Discover the current pipeline definition and runtime input schema.
3. Resolve application source to one immutable revision and keep it separate from the pipeline-definition revision.
4. Inspect effective environment, stages, downstream targets, and source-selection support.
5. Default to a read-only plan and render exact source, target, effects, and limitations.
6. For a run, require fresh human-origin authorization bound to the exact task, configuration revision, pipeline, source revision, target, operation, and expiry.
7. Persist launch intent, execute once, and capture the provider execution ID immediately.
8. On timeout, reconcile bounded history; continue one unique match and block when no reliable or multiple matches exist.
9. Read back source and target inputs, report mismatches as failures, and distinguish pipeline lifecycle from application verification.
10. Persist sanitized evidence and leave production, promotion, notifications, and automatic retries disabled.

Planning, watching, and ordinary diagnosis are read-only.
Demo authorization never applies to a live provider.
Do not silently substitute a provider, repository, environment, credentials, or source revision.

## Completion

The response names mode, provider/pipeline, source and resolved revision, separate definition revision, effective environment/effects, execution ID, lifecycle, input read-back, application verification, and one next action.
Fixture evidence is labeled offline DEMO; live host/provider verification is reported separately.
