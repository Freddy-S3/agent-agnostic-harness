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
