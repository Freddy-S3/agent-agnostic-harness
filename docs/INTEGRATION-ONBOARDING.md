# Chat-first integration onboarding

Use the existing agent chat as the default connection interface.
No dashboard or second state store is required.
The optional queue dashboard remains independent and is not a prerequisite.

## Requests

- `/connect-workspace` or “What do I still need to connect?” shows status only.
- “Verify the tracker connection” runs one selected harmless read probe.
- “Use demo mode” selects synthetic adapters and disables network writes.
- “Continue setup” resumes the earliest required unresolved step.
- “Skip notifications” records an optional skip and keeps local work available.
- “Can I start this ticket?” checks only ticket-start dependencies.
- “Can I deploy this?” checks planning readiness separately from run authorization.

## Checklist shape

```text
Connection check - <project> / <host>
Mode: DEMO | LIVE
<capability> | <evidence-based status> | <workflow unlocked>

BLOCKED ON YOU
<blocker> | <exact next action> | <dependent workflows>

Available now: <workflows>
Next: <one action>
```

Required capabilities appear first.
Optional connectors are visible but nonblocking when skipped.
Every blocker has one concrete next action; if unknown, say `Unknown; needs investigation.`
Demo evidence is labeled `DEMO` in every receipt.

## Resume behavior

Readiness state and the task ledger are separate.
Readiness answers “can this workflow run here?”
The task ledger answers “what work is in progress?”
The queue answers “who may use this shared resource next?”
On a new chat, read the private readiness record, recheck freshness, then continue from the recorded next action.
Authentication does not travel in Git or public fixtures.

## Offline demo

Run the deterministic interview fixture:

```powershell
node tools/integration-demo/demo.mjs
node --test tools/integration-demo/*.test.mjs
```

The fixture demonstrates a synthetic readiness checklist, an isolated ticket worktree that preserves unrelated dirty files, an authorized sandbox plan/run, timeout reconciliation, and duplicate prevention.
It performs no network calls, creates no real ticket or branch, and runs no deployment.

Live host discovery, registration, authenticated reads, and authorized nonproduction writes remain separate verification categories.
Do not claim them from the fixture output.

## Practical coding assessment readiness

When the next task is a live coding assessment, use `/interview-readiness` after the generic connection check.
The checklist is provider-neutral and keeps private interview logistics outside the repository.

```text
Interview readiness - DEMO | LIVE
Node.js current LTS runtime | Ready | node/npm evidence
Preferred AI coding tool | Ready | installed, authenticated, callable
IDE and test project | Ready | opened fixture
Test command | Ready | command ran
Local development server | Ready | start and smoke evidence

Next: clarify the requested behavior, restate assumptions, then implement the smallest testable step.
```

The fixture covers missing runtime/tool, sign-in and callability, missing test command, server start failure, stale evidence, clarification-before-write, visible parallel tasks, and evidence-backed wrap-up.
The live checklist should also confirm the exact current Node.js LTS, IDE, test command, server port, and AI-tool callability on the supplied codebase.
