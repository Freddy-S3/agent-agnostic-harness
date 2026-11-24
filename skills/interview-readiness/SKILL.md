---
name: interview-readiness
description: "When a user is preparing for a live coding assessment or practical agent-assisted session, verify runtime, IDE, AI-tool, test, and local-server readiness, then use clarification-first planning, visible parallel work, and evidence-backed wrap-up."
user-invocable: true
---

# Interview Readiness

Use the [integration onboarding guide](../../docs/INTEGRATION-ONBOARDING.md) for the checklist and the offline fixture.
Keep all project, interviewer, employer, meeting, and credential details outside public repository files.

## Before coding

1. Verify current Node.js LTS and `node`/`npm` commands.
2. Verify the IDE and fixture project open locally.
3. Verify the preferred AI coding tool is installed, signed in through its native flow, and callable on a harmless fixture.
4. Identify the repository test command and run it once.
5. Identify the local development-server command, start it, and perform one smoke check.
6. Mark evidence stale when its timestamp or configuration revision is no longer current.
7. Ask clarifying questions, restate scope and assumptions, and keep write authorization false until the answers are settled.

## During coding

Break work into small testable tasks.
Use parallel tasks only when dependencies are independent, and keep each task visible with owner, status, dependency, and evidence.
Narrate decisions and AI assistance in the chat while keeping the implementation grounded in the repository.
Recover visibly from failures and rerun the smallest discriminating check.

## Close

Wrap up with the requested scope, what works, test evidence, server evidence, remaining uncertainty, and one next action.
Use `incomplete` when test or server evidence is missing; never infer success from a file edit alone.
