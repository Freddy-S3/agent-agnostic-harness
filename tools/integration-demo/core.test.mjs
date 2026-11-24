import assert from "node:assert/strict";
import test from "node:test";

import {
  DeploymentBlocked,
  DeploymentWorkflow,
  DemoDeploymentAdapter,
  GitFixture,
  RevisionConflict,
  WorkspaceConflict,
  inspectReadiness,
  inspectInterviewReadiness,
  renderInterviewReadiness,
  prepareCodingTask,
  createInterviewWorkboard,
  updateInterviewTask,
  renderInterviewWorkboard,
  buildInterviewWrapUp,
  renderReadiness,
  startTicket,
  updateReadiness,
} from "./core.mjs";

const capabilities = {
  local_git: {
    requiredFor: ["local-engineering"],
    installation: "present",
    registration: "not-applicable",
    configuration: "valid",
    authentication: "not-required",
    readProbe: "passed",
    freshness: "fresh",
    availability: "available",
    evidence: { summary: "fixture Git probe passed" },
  },
  issue_tracker: {
    requiredFor: ["ticket-start"],
    installation: "not-applicable",
    registration: "present",
    configuration: "valid",
    authentication: "required",
    readProbe: "not-run",
    freshness: "unknown",
    availability: "blocked",
  },
  notifications: {
    requiredFor: [],
    installation: "not-applicable",
    registration: "not-applicable",
    configuration: "not-applicable",
    authentication: "not-required",
    readProbe: "not-run",
    freshness: "unknown",
    availability: "optional-skipped",
  },
};

test("readiness shows required blockers and performs no mutations", () => {
  const report = inspectReadiness({ projectId: "demo-app", hostId: "fixture-host", configRevision: "demo-1", capabilities, workflow: "ticket-start" });
  assert.equal(report.mode, "DEMO");
  assert.equal(report.mutatingCalls, 0);
  assert.match(renderReadiness(report), /Needs sign-in/);
  assert.match(renderReadiness(report), /Sign in through the selected host/);
  assert.equal(report.rows.find((row) => row.capability === "notifications").status, "Optional, skipped");
});

test("readiness updates use compare-and-swap semantics", () => {
  const current = { revision: 2, capabilities: { issue_tracker: { authentication: "required" } } };
  const next = updateReadiness(current, 2, { capabilities: { issue_tracker: { authentication: "valid" } } });
  assert.equal(next.revision, 3);
  assert.throws(() => updateReadiness(next, 2, {}), RevisionConflict);
});

test("new ticket worktree preserves a dirty original checkout", () => {
  const git = new GitFixture({ originalCheckout: { dirty: true, files: ["README.md", "local-note.txt"], index: ["README.md"] } });
  const receipt = startTicket({
    ticket: { key: "APP-101", summary: "Export status" },
    git,
    workspacePath: "/fixtures/worktrees/APP-101",
  });
  assert.equal(receipt.origin, "created");
  assert.equal(receipt.headCommit, "base-001");
  assert.equal(receipt.originalCheckout.preserved, true);
  assert.deepEqual(receipt.originalCheckout.files, ["README.md", "local-note.txt"]);
  assert.equal(git.originalCheckout.dirty, true);
});

test("repeating a ticket request reuses its existing worktree", () => {
  const git = new GitFixture();
  const input = { ticket: { key: "APP-101", summary: "Export status" }, git, workspacePath: "/fixtures/worktrees/APP-101" };
  const first = startTicket(input);
  const second = startTicket(input);
  assert.equal(first.branch, second.branch);
  assert.equal(second.origin, "existing-worktree");
  assert.equal(git.worktrees.size, 1);
});

test("similar ticket keys do not reuse the wrong branch", () => {
  const git = new GitFixture();
  git.addBranch("feature/APP-100-export", { ticketKey: "APP-100", commit: "other-001" });
  const receipt = startTicket({ ticket: { key: "APP-10", summary: "Export" }, git, workspacePath: "/fixtures/worktrees/APP-10" });
  assert.equal(receipt.origin, "created");
  assert.equal(receipt.branch, "feature/APP-10-export");
});

test("dirty target worktree blocks without discarding changes", () => {
  const git = new GitFixture();
  git.addWorktree("/fixtures/worktrees/APP-101", { branch: "feature/APP-101-export", commit: "old-001", dirty: true });
  assert.throws(() => startTicket({ ticket: { key: "APP-101", summary: "Export" }, git, workspacePath: "/fixtures/worktrees/APP-101" }), WorkspaceConflict);
  assert.equal(git.worktrees.get("/fixtures/worktrees/APP-101").dirty, true);
});

test("occupied worktree bound to another task is not reused", () => {
  const git = new GitFixture();
  git.addWorktree("/fixtures/worktrees/APP-101", { branch: "feature/APP-101-export", commit: "old-001", ticketKey: "APP-100", dirty: false });
  assert.throws(() => startTicket({ ticket: { key: "APP-101", summary: "Export" }, git, workspacePath: "/fixtures/worktrees/APP-101" }), WorkspaceConflict);
});

function plan(workflow, overrides = {}) {
  return workflow.plan({
    taskId: "task-101",
    sourceRepository: "example-app",
    sourceCommit: "app-commit-001",
    ...overrides,
  });
}

test("deployment planning is read-only and does not execute", () => {
  const adapter = new DemoDeploymentAdapter();
  const workflow = new DeploymentWorkflow(adapter);
  const result = workflow.plan({ taskId: "task-101", sourceRepository: "example-app", sourceCommit: "app-commit-001" });
  assert.equal(result.status, "planned");
  assert.equal(adapter.executeCalls.length, 0);
});

test("deployment refuses an absent or changed exact authorization", () => {
  const adapter = new DemoDeploymentAdapter();
  const workflow = new DeploymentWorkflow(adapter);
  const result = plan(workflow);
  assert.throws(() => workflow.run(result), DeploymentBlocked);
  const authorization = workflow.authorize(result);
  const changed = { ...result, sourceCommit: "app-commit-002" };
  assert.throws(() => workflow.run(changed, authorization), DeploymentBlocked);
  assert.equal(adapter.executeCalls.length, 0);
});

test("authorized deployment executes once and prevents duplicate launch", () => {
  const adapter = new DemoDeploymentAdapter();
  const workflow = new DeploymentWorkflow(adapter);
  const result = plan(workflow);
  const authorization = workflow.authorize(result);
  const first = workflow.run(result, authorization);
  const second = workflow.run(result, authorization);
  assert.equal(first.status, "succeeded");
  assert.equal(second.duplicatePrevented, true);
  assert.equal(second.executionId, first.executionId);
  assert.equal(adapter.executeCalls.length, 1);
});

test("unfinished running deployment is reported without a second launch", () => {
  const adapter = new DemoDeploymentAdapter({ outcome: "running" });
  const workflow = new DeploymentWorkflow(adapter);
  const result = plan(workflow);
  const authorization = workflow.authorize(result);
  const first = workflow.run(result, authorization);
  const second = workflow.run(result, authorization);
  assert.equal(first.status, "running");
  assert.equal(second.duplicatePrevented, true);
  assert.equal(adapter.executeCalls.length, 1);
});

test("launch timeout reconciles one matching run without a second execute", () => {
  const adapter = new DemoDeploymentAdapter({ outcome: "timeout" });
  const workflow = new DeploymentWorkflow(adapter);
  const result = plan(workflow);
  const completed = workflow.run(result, workflow.authorize(result));
  assert.equal(completed.status, "succeeded");
  assert.equal(completed.executionId, "demo-run-001");
  assert.equal(adapter.executeCalls.length, 1);
});

test("ambiguous timeout history blocks automatic retry", () => {
  const existing = {
    id: "older-run",
    pipeline: "example-service-ci",
    sourceRepository: "example-app",
    sourceCommit: "app-commit-001",
    environment: "sandbox",
  };
  const adapter = new DemoDeploymentAdapter({ outcome: "timeout", history: [existing] });
  const workflow = new DeploymentWorkflow(adapter);
  const result = plan(workflow);
  const blocked = workflow.run(result, workflow.authorize(result));
  assert.equal(blocked.status, "launch-uncertain");
  assert.equal(blocked.executionId, null);
  assert.equal(adapter.executeCalls.length, 1);
  assert.match(blocked.next, /duplicate launch is blocked/);
  const resumed = workflow.run(result, workflow.authorize(result));
  assert.equal(resumed.status, "launch-uncertain");
  assert.equal(resumed.duplicatePrevented, true);
  assert.equal(adapter.executeCalls.length, 1);
});

test("deployment policy rejects a prohibited effective target", () => {
  const adapter = new DemoDeploymentAdapter({ pipeline: { prohibitedTargets: ["sandbox"] } });
  const workflow = new DeploymentWorkflow(adapter);
  assert.throws(() => plan(workflow), DeploymentBlocked);
  assert.equal(adapter.executeCalls.length, 0);
});

test("interview readiness reports missing runtime and AI tool evidence", () => {
  const report = inspectInterviewReadiness({ runtime: { available: false }, aiTool: { installed: false }, ide: { available: true } });
  assert.equal(report.ready, false);
  assert.equal(report.rows.find((row) => row.id === "node-runtime").status, "Missing");
  assert.equal(report.rows.find((row) => row.id === "ai-tool").status, "Missing");
  assert.match(renderInterviewReadiness(report), /Install current Node.js LTS/);
});

test("interview readiness separates authentication from tool callability", () => {
  const signedOut = inspectInterviewReadiness({ aiTool: { installed: true, authenticated: false, callable: false } });
  const uncallable = inspectInterviewReadiness({ aiTool: { installed: true, authenticated: true, callable: false } });
  assert.equal(signedOut.rows.find((row) => row.id === "ai-tool").status, "Needs sign-in");
  assert.equal(uncallable.rows.find((row) => row.id === "ai-tool").status, "Not callable");
});

test("interview readiness reports missing test command and server start failure", () => {
  const report = inspectInterviewReadiness({ testCommand: "", serverCommand: "npm run dev", serverProbe: { status: "failed", evidence: { summary: "port already in use" } } });
  assert.equal(report.rows.find((row) => row.id === "test-command").status, "Missing command");
  assert.equal(report.rows.find((row) => row.id === "dev-server").status, "Server start failed");
});

test("interview readiness invalidates stale evidence", () => {
  const report = inspectInterviewReadiness({
    now: 10_000,
    ttlMs: 1_000,
    currentRevision: "fixture-2",
    aiTool: { installed: true, authenticated: true, callable: true, evidence: { checkedAt: 1_000, revision: "fixture-1", summary: "old tool probe" } },
    runtime: { available: true, lts: true, evidence: { checkedAt: 9_500, revision: "fixture-2", summary: "fresh runtime probe" } },
  });
  assert.equal(report.rows.find((row) => row.id === "ai-tool").status, "Stale evidence");
  assert.equal(report.rows.find((row) => row.id === "node-runtime").status, "Ready");
});

test("coding task asks clarifying questions before authorizing writes", () => {
  const plan = prepareCodingTask({ request: "Add a filter", questions: ["Which fields are filterable?"] });
  assert.equal(plan.writeAuthorized, false);
  assert.equal(plan.writes, 0);
  assert.deepEqual(plan.targetFiles, []);
  const clarified = prepareCodingTask({ request: "Add a filter", clarified: true, assumptions: ["Filter by status"], targetFiles: ["src/App.jsx"] });
  assert.equal(clarified.writeAuthorized, true);
  assert.deepEqual(clarified.targetFiles, ["src/App.jsx"]);
});

test("parallel interview tasks remain visible with status and evidence", () => {
  let board = createInterviewWorkboard([
    { id: "ui", title: "Implement the filter control", owner: "agent-ui" },
    { id: "tests", title: "Add focused filter tests", owner: "agent-tests" },
  ]);
  board = updateInterviewTask(board, "ui", { status: "in-progress", evidence: { summary: "component target identified" } });
  board = updateInterviewTask(board, "tests", { status: "blocked", evidence: { summary: "waiting for clarified behavior" } });
  const rendered = renderInterviewWorkboard(board);
  assert.match(rendered, /ui \| in-progress \| agent-ui/);
  assert.match(rendered, /tests \| blocked \| agent-tests/);
  assert.match(rendered, /waiting for clarified behavior/);
});

test("wrap-up requires test and server evidence before claiming completion", () => {
  const incomplete = buildInterviewWrapUp({ scope: "status filter", completed: ["UI control"], testEvidence: { summary: "2 tests passed" } });
  assert.equal(incomplete.status, "incomplete");
  assert.deepEqual(incomplete.missing, ["server evidence"]);
  const complete = buildInterviewWrapUp({
    scope: "status filter",
    completed: ["UI control", "focused tests"],
    testEvidence: { summary: "2 tests passed" },
    serverEvidence: { summary: "local server started and smoke check passed" },
    remaining: ["No live deployment verification"],
  });
  assert.equal(complete.status, "ready");
  assert.deepEqual(complete.remaining, ["No live deployment verification"]);
});
