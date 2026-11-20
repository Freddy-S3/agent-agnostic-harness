# Interactive queue control

The queue dashboard is an authenticated decision surface, not a general-purpose remote shell.

It lets the owner answer, approve, skip, or unblock a queue item and records the durable action for the owning session.

The implementation is provider-neutral and does not provision AWS, DNS, a cloud account, paid infrastructure, or repository connections.

## Action and session contract

Every browser action has the following shape:

```json
{
  "schemaVersion": 1,
  "actionId": "portal-unique-id",
  "kind": "answer | approve | skip | unblock",
  "target": {
    "file": "QUEUE-PC.md",
    "title": "Exact queue item title"
  },
  "owner": {
    "project": "agent-agnostic-harness",
    "repository": "C:/Users/faruk/Repo/agent-agnostic-harness"
  },
  "sessionRef": {
    "sessionId": "codex-session-id",
    "runId": "queue-run-id"
  },
  "requirements": {
    "localFiles": false,
    "localCredentials": false,
    "freshestSync": false,
    "requiredTools": []
  },
  "payload": {
    "text": "The complete owner decision"
  }
}
```

`actionId` is the idempotency key.

`owner` and `sessionRef` are copied from the targeted queue item and the portal rejects a request whose values do not match exactly.

The action log records the action, its fingerprint, the selected worker, application status, delivery status, and audit timestamps.

The audit log records accepted, applied, duplicate, delivered, and deferred outcomes.

Retrying the same action with the same `actionId` returns the existing record and does not apply or deliver it again.

Reusing an `actionId` for a different owner, target, session, or payload is rejected as an action replay.

## Worker selection

The selector chooses exactly one worker for each action.

Cloud delivery is first for a connected remote repository when the cloud worker has the required tools.

The outbound desktop connector is selected when the action requires local files, local credentials, freshest synchronization, or a tool the cloud worker does not have.

If the required desktop capability is unavailable, the action remains deferred for desktop instead of being attempted by a second worker.

When cloud delivery is unavailable for an otherwise remote action, an authorized desktop connector may be selected as the single fallback.

This is not active-active execution.

The adapter receives the complete action and the selected routing record through `deliver(action, routing)`.

An adapter must treat `actionId` as its own idempotency key and return an acceptance receipt without executing arbitrary browser input.

`tools/queue-dashboard/adapters.mjs` provides the live HTTP adapter boundary.
It sends the action to a server-side HTTPS endpoint with a bearer token and an `Idempotency-Key` header.
The bearer token never reaches the browser or the action log.

Configure `QUEUE_CLOUD_ADAPTER_URL` with `QUEUE_CLOUD_ADAPTER_TOKEN`, or `QUEUE_DESKTOP_ADAPTER_URL` with `QUEUE_DESKTOP_ADAPTER_TOKEN`, only after the corresponding host is authorized.
The matching capability JSON is still required, so an endpoint without a capability record cannot receive work.
Local HTTP endpoints are accepted only when `QUEUE_ALLOW_INSECURE_ADAPTERS=1` is explicitly set for local testing.

Without an authorized adapter, the durable action and audit records remain available for the next authorized session.

## Offline snapshots

When a live queue read succeeds and `QUEUE_SNAPSHOT_KEY` is configured, the dashboard writes an AES-256-GCM encrypted snapshot beside the queue files as `.queue-snapshot.enc`.

When the live queue is unavailable, the authenticated owner can read the newest valid encrypted snapshot.

The page labels that state as `OFFLINE - ENCRYPTED SNAPSHOT` and tells the owner that new actions are recorded for the next authorized session.

The encryption key is never sent to the browser.

Provide it through `QUEUE_SNAPSHOT_KEY` or a local `.queue-snapshot-key` file with access restricted to the dashboard account.

An invalid key or tampered snapshot fails closed and is not rendered as queue data.

## Browser security boundary

Every request, including loopback requests, requires the dashboard token cookie.

The browser can submit only `answer`, `approve`, `skip`, and `unblock` actions for an exact queue item.

Shell, merge, deploy, secret, credential, billing, and public-publishing actions are rejected by the contract.

The old direct-answer endpoint is disabled so browser writes pass through the action contract and audit log.

The queue write remains guarded by the existing mtime check, backup, and temp-file rename flow.

The dashboard never grants repository, host, cloud, credential, billing, or publishing permissions.

## Queue metadata

Add these optional fields to a queue item when a live session should receive a decision directly:

```text
Project: agent-agnostic-harness
Repo: C:/Users/faruk/Repo/agent-agnostic-harness
Session: codex-session-id
Run: queue-run-id
Requires local files: false
Requires local credentials: false
Requires freshest sync: false
Required tools: queue-actions
```

Items without these fields use a safe queue-dashboard owner and next-session reference so the portal remains usable while still binding every action to exactly one project and repository.

## Remaining host authorization

Before cloud delivery can resume a real Codex or cloud session, the host must authorize one adapter for the intended repository and session namespace.

That authorization must identify the repository connection, the allowed action consumer, and the capabilities reported to worker selection.

Before desktop delivery can resume local-only work, the desktop connector must be installed and authorized for the local files, credentials, and tools named by the queue item.

Those permissions are intentionally not created by this change.

The reproducible Lightsail path is in [deploy/queue-relay/README.md](../deploy/queue-relay/README.md).
It stages the authenticated service on loopback before DNS or TLS, uses the Lightsail browser session instead of copying an SSH private key, and leaves only 443 open after activation.
The private address `queue.alazyengineer.com` still requires that staged authentication check before its DNS and TLS activation steps.

The public blog on Amplify is a separate surface and is not changed by this repository.

## Verification

Run `node --test tools/queue-dashboard/action-contract.test.mjs tools/queue-dashboard/server-action.test.mjs` for the synthetic contract, worker, idempotency, authentication, forged-action, and offline-snapshot checks.

Run `python tools/queue-dashboard/test_dashboard.py` for the authenticated Chromium render and interaction sweep.

The browser test uses a throwaway queue directory and synthetic data.
