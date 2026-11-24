---
name: connect-workspace
description: "When a user asks what remains connected, requests a tracker or deployment verification, selects demo mode, or wants to continue setup, show evidence-based workspace readiness in chat and one exact next action."
user-invocable: true
---

# Connect Workspace

Use [integration contracts](../../docs/INTEGRATION-CONTRACTS.md) for the readiness model and [chat onboarding](../../docs/INTEGRATION-ONBOARDING.md) for the response shape.

## Run

1. Resolve the project, selected host, mode, and configuration revision from the actual workspace.
2. Inventory configured capabilities without mutating external systems.
3. Inspect credential references without reading or printing secret values.
4. Distinguish installed, registered, configured, authenticated, read-verified, stale, permitted, authorized, optional-skipped, and unsupported states.
5. Show required capabilities first, each dependent workflow, and one exact unblock action.
6. For explicit verification, run only the smallest configured harmless read probe.
7. Persist private readiness with revision checking and resume from newer state after a conflict.
8. Return to the owning task only when its required prerequisites pass.

Status and verification do not create tickets, send messages, deploy, provision accounts, or grant permissions.
Authentication uses the host's approved login flow.
Fixture results are labeled DEMO and never imply a live connection.

## Completion

The response names the project, host, mode, evidence-backed status for every relevant capability, optional skips, blockers, available workflows, and one next action.
The next chat can recover the same private readiness record without copying credentials or private logs.
