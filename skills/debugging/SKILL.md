---
name: debugging
description: "Systematic debugging workflow. Use when investigating bugs, unexpected behavior, or errors in any codebase."
user-invocable: true
---

# Debugging Skill

## Workflow

### 1. Build a Feedback Loop First
- Before hypotheses or code changes, create and run a tight pass/fail signal that goes red on this bug and asserts the user's exact symptom.
- Construct it at the nearest reliable seam: a failing test, focused HTTP or command-line repro, replayed redacted request/log, or a minimal harness with fixture data.
- Make the loop tight: minimize setup and scope, assert the specific symptom, and control time, randomness, filesystem state, and network dependencies where practical.
- If the bug is non-deterministic, repeat and stress the trigger until the reproduction rate is high enough to compare changes; record the conditions and observed rate.
- If no usable loop is possible, state what was tried and request the needed access, redacted artifact, or temporary instrumentation. Do not form a root-cause hypothesis or change code without a signal that can distinguish the outcome.

### 2. Reproduce and Minimize
- Reproduce the bug as close to the actual user experience as possible and define the expected behavior, actual behavior, and triggering inputs/state.
- Minimize the red repro one input, step, caller, configuration value, or data dependency at a time. Re-run the loop after each removal and keep only load-bearing elements.

### 3. Narrow the Layer and Hypothesize
- Identify which layer the bug lives in: frontend (Vue/TS), BFF, API, service, database, external API.
- Read existing logs first: CloudWatch, New Relic, browser console, Lambda logs.
- Generate 3-5 ranked hypotheses before instrumentation or code changes - do not anchor on the first plausible idea.
- Each hypothesis must be falsifiable: state the prediction it makes (e.g. "if X is the cause, changing Y will make the bug disappear").

### 4. Instrument Precisely
- Add the minimum probe to confirm or refute one hypothesis - use a debugger when available or one targeted log at the ambiguous point.
- Change one variable at a time and run the feedback loop after every probe.
- C#: `LOGGER.Debug("StepName: value={Value}", val)` (NLog structured logging).
- Vue/TS: `console.log('[ComponentName]', payload)` - always remove before committing.
- Log safe identifiers and metadata only; redact secrets, credentials, authorization headers, cookies, tokens, passwords, API keys, and personal data.
- Tag every temporary debug log/instrumentation with a unique prefix (e.g. `[DEBUG-a4f2]`) so cleanup is a single grep.
- Do not scatter log statements across multiple files speculatively.

### 5. Identify Root Cause
- Root cause is the code that **caused** the bug, not the symptom.
- Root-cause families worth checking before deeper investigation:
  - **Null/empty from an upstream lookup** - an invalid or missing identifier silently yielding no record rather than an error
  - **Missing environment config key** - a per-environment config or secret absent, returning null through a fallback path instead of failing loudly
  - **Startup/initialization race** - cold-start or async dependency-registration ordering, surfacing as an intermittent first-call failure
  - **Unregistered dependency** - a type never registered in the IoC container, giving a null-reference at first use
  - **Environment/tenant mismatch** - the feature exists only in one environment or tenant, and the client is pointed at another
  - **Content-type / contract mismatch** - a request rejected (e.g. `415`) because the declared contract does not match what the endpoint accepts

### 6. Fix Minimally
- Fix the root cause, not the symptom.
- Prefer modifying existing code over adding defensive wrappers around it.
- If a fix requires more than ~20 lines, re-examine whether you have the true root cause.
- Add or update a regression test at the seam that exercises the real bug pattern.
- If no valid test seam exists, document that architectural gap rather than adding a shallow test that cannot catch the regression.

### 7. Verify
- Re-run the original reproduction and feedback loop - both must go green.
- Check other callers of the fixed method or similar endpoints for the same bug pattern.
- Run the affected project's test suite.
- Confirm all tagged debug instrumentation (e.g. `[DEBUG-a4f2]`) has been removed - grep the prefix to verify.
- Record the test-seam or architecture lesson: what enabled the regression test, or what coupling/hidden dependency prevented one.
