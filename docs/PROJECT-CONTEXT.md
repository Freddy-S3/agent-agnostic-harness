# Project Context

This repository is the portable agent-agnostic harness used by Codex, Claude Code, ChatGPT, and related hosts.

## Identity

- Project name: agent-agnostic-harness
- Purpose: reusable planning, implementation, verification, review, queue, and reflection workflows for agent-assisted engineering
- Owner repository: `freddy-s3/agent-agnostic-harness`
- Primary entry point: `/freddy` for delivery work and `/faruk` for personal work

## Current state

- Current goals: make software-factory runs evidence-carrying, bounded, replayable, and recoverable
- Current milestone: typed factory results, replay evaluation, and explicit visible `/ship` human gates
- Definition of done: focused checks and repository validation pass, the full diff receives adversarial review, and the change is handed to a pull request

## Source of truth

- Business plan or product brief: none selected
- Queue and dashboard: `queue/README.md` and the resolved external queue directory
- Tracker: none for this ticketless task
- Active pull requests: verify with the current GitHub branch before publishing

## Settled decisions

- `/ship` Gate 1, Gate 2, and Gate 3 are standalone user-visible approval messages.
- Elapsed-time and worker telemetry never replaces or hides human-gate text.
- `proceed` always creates or updates `docs/PROJECT-CONTEXT.md` after implementation state is available.
- Every pull request targets the repository default branch; dependent changes are promoted together instead of merged into a feature-branch parent.
- The `mainline-target` status and non-default branch ruleset prevent feature-branch merges from being counted as delivery.
- Factory results use explicit statuses, source-fresh evidence, progress signals, resource budgets, and side-effect confirmation.
- JSONL progress logs are checked independently for idle and repeated-signature loops before a worker lane is accepted.
- Replay evaluations use versioned manifests and preserve case origin, expected outcome, latency, and optional run metrics.

## Open questions

- Provider-specific token, turn, and cost metrics are optional because not every local run exposes them.

## Setup and operations

- Local development command: edit the repository skills and tools directly; no application server is required
- Verification command: run the focused scripts under `tools/tests/`, then the repository checks documented in `README.md`
- Deployment or publishing path: commit on a named branch, push, and open or update a pull request
- Required environment variables, without secrets: none for the local contract and replay checks

## Verification map

- Feature: visible `/ship` human gate
  - Entry point: `/ship <task>`
  - User action: reach Gate 1, Gate 2, or Gate 3
  - Expected state: the complete gate block appears as standalone response text with reply options
  - Proof artifact: `tools/tests/check-ship-contract.tests.ps1`

- Feature: evidence-carrying factory result
  - Entry point: `tools/validate-factory-result.ps1`
  - User action: validate a worker or phase JSON result
  - Expected state: invalid status, evidence, effect, progress, or budget data fails nonzero
  - Proof artifact: `tools/tests/validate-factory-result.tests.ps1`

- Feature: independent progress detection
  - Entry point: `tools/check-factory-progress.ps1`
  - User action: inspect a JSONL worker event log
  - Expected state: idle or repeated signatures fail before completion is accepted
  - Proof artifact: `tools/tests/check-factory-progress.tests.ps1`

## Continuity

Read `AGENTS.md` first, then this file, then `docs/CHAT-HANDOFF.md` if it exists.
Keep this file factual and update it when a durable project decision changes.
