const READINESS_STATUS = Object.freeze({
  optionalSkipped: "Optional, skipped",
  unsupported: "Unsupported",
  notInstalled: "Not installed",
  notRegistered: "Not registered",
  needsConfiguration: "Needs configuration",
  needsSignIn: "Needs sign-in",
  permissionDenied: "Blocked by permission",
  stale: "Stale",
  verified: "Verified for read",
  readyToPlan: "Ready to plan",
});

export class RevisionConflict extends Error {
  constructor(message = "Readiness state changed; reread before updating") {
    super(message);
    this.name = "RevisionConflict";
  }
}

export class WorkspaceConflict extends Error {
  constructor(message) {
    super(message);
    this.name = "WorkspaceConflict";
  }
}

export class DeploymentBlocked extends Error {
  constructor(message) {
    super(message);
    this.name = "DeploymentBlocked";
  }
}

function required(capability, workflow) {
  return capability.requiredFor?.includes(workflow) ?? false;
}

function capabilityStatus(capability, workflow) {
  if (capability.availability === "optional-skipped") return READINESS_STATUS.optionalSkipped;
  if (capability.availability === "unsupported") return READINESS_STATUS.unsupported;
  if (capability.installation === "absent") return READINESS_STATUS.notInstalled;
  if (capability.registration === "missing") return READINESS_STATUS.notRegistered;
  if (["missing", "invalid"].includes(capability.configuration)) return READINESS_STATUS.needsConfiguration;
  if (["required", "expired"].includes(capability.authentication)) return READINESS_STATUS.needsSignIn;
  if (capability.readProbe === "failed" && capability.evidence?.code === "permission_denied") {
    return READINESS_STATUS.permissionDenied;
  }
  if (capability.readProbe === "failed") return "Read verification failed";
  if (capability.freshness === "stale") return READINESS_STATUS.stale;
  if (capability.readProbe === "passed") {
    return required(capability, workflow) && workflow === "deployment-plan"
      ? READINESS_STATUS.readyToPlan
      : READINESS_STATUS.verified;
  }
  return "Configured, not verified";
}

function nextAction(capability, status) {
  if (capability.nextAction) return capability.nextAction;
  if (status === READINESS_STATUS.notRegistered) return "Register the configured server through the selected host, then recheck it.";
  if (status === READINESS_STATUS.needsSignIn) return "Sign in through the selected host's credential flow, then run a scoped read verification.";
  if (status === READINESS_STATUS.needsConfiguration) return "Select the provider and scope in private configuration, then recheck it.";
  if (status === READINESS_STATUS.stale) return "Reverify this capability because its host, scope, or credential marker changed.";
  if (status === READINESS_STATUS.permissionDenied) return "Choose an authorized project or request access through the provider's normal process.";
  return "Run the smallest scoped read verification.";
}

export function inspectReadiness({ projectId, hostId, mode = "demo", configRevision, capabilities, workflow = "local-engineering" }) {
  const rows = Object.entries(capabilities).map(([name, capability]) => {
    const status = capabilityStatus(capability, workflow);
    return {
      capability: name,
      required: required(capability, workflow),
      status,
      unlocks: capability.requiredFor ?? [],
      nextAction: nextAction(capability, status),
      evidence: capability.evidence ?? null,
    };
  }).sort((a, b) => Number(b.required) - Number(a.required) || a.capability.localeCompare(b.capability));

  const blockers = rows
    .filter((row) => row.required && ![READINESS_STATUS.verified, READINESS_STATUS.readyToPlan].includes(row.status))
    .map((row) => ({ blocker: `${row.capability}: ${row.status}`, nextAction: row.nextAction, unlocks: row.unlocks }));
  const available = rows
    .filter((row) => row.required && [READINESS_STATUS.verified, READINESS_STATUS.readyToPlan].includes(row.status))
    .map((row) => row.capability);

  return {
    projectId,
    hostId,
    mode: mode.toUpperCase(),
    configRevision,
    rows,
    blockers,
    available,
    next: blockers[0]?.nextAction ?? (available.length ? "Continue the requested workflow." : "Select a project or enable demo mode."),
    mutatingCalls: 0,
  };
}

export function renderReadiness(report) {
  const lines = [
    `Connection check - ${report.projectId} / ${report.hostId}`,
    `Mode: ${report.mode}`,
    "",
    "Capability | Status | Unlocks",
    ...report.rows.map((row) => `${row.capability} | ${row.status} | ${row.unlocks.join(", ") || "optional"}`),
  ];
  if (report.blockers.length) {
    lines.push("", "BLOCKED ON YOU", ...report.blockers.map((item) => `- ${item.blocker} | ${item.nextAction} | ${item.unlocks.join(", ")}`));
  }
  lines.push("", `Available now: ${report.available.join(", ") || "none"}`, `Next: ${report.next}`);
  return lines.join("\n");
}

export function updateReadiness(record, expectedRevision, patch) {
  if (record.revision !== expectedRevision) throw new RevisionConflict();
  return {
    ...record,
    ...patch,
    revision: record.revision + 1,
  };
}

export function slugify(value) {
  return value.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 48);
}

export class GitFixture {
  constructor({ name = "example-app", baseRef = "origin/main", baseCommit = "base-001", originalCheckout = {} } = {}) {
    this.name = name;
    this.baseRef = baseRef;
    this.baseCommit = baseCommit;
    this.originalCheckout = {
      path: originalCheckout.path ?? "/fixtures/example-app",
      branch: originalCheckout.branch ?? "main",
      dirty: originalCheckout.dirty ?? false,
      files: [...(originalCheckout.files ?? ["README.md"])],
      index: [...(originalCheckout.index ?? [])],
    };
    this.branches = new Map();
    this.remoteBranches = new Map();
    this.worktrees = new Map();
  }

  addBranch(name, details) {
    this.branches.set(name, { ...details });
  }

  addRemoteBranch(name, details) {
    this.remoteBranches.set(name, { ...details });
  }

  addWorktree(path, details) {
    this.worktrees.set(path, { ...details });
  }

  createBranch(name, commit, ticketKey) {
    if (this.branches.has(name)) throw new WorkspaceConflict(`Branch already exists: ${name}`);
    this.branches.set(name, { commit, ticketKey });
  }

  createWorktree(path, branch, commit, ticketKey) {
    const existing = this.worktrees.get(path);
    if (existing) {
      if (existing.dirty) throw new WorkspaceConflict(`Target worktree is dirty: ${path}`);
      throw new WorkspaceConflict(`Target worktree is occupied: ${path}`);
    }
    this.worktrees.set(path, { branch, commit, ticketKey, dirty: false });
  }
}

function matchingTicketBranches(git, ticketKey) {
  return [...git.branches.entries()].filter(([, details]) => details.ticketKey === ticketKey);
}

export function startTicket({ ticket, git, workspacePath, workspaceMode = "isolated" }) {
  if (!ticket?.key || !ticket.summary) throw new WorkspaceConflict("Ticket key and summary are required");
  if (workspaceMode === "current") throw new WorkspaceConflict("Current-workspace activation requires an explicit host decision; use isolated mode for the demo");

  const branchMatches = matchingTicketBranches(git, ticket.key);
  if (branchMatches.length > 1) throw new WorkspaceConflict(`Multiple branches match ticket exactly: ${ticket.key}`);

  const branchName = branchMatches[0]?.[0] ?? `feature/${ticket.key}-${slugify(ticket.summary)}`;
  const branch = branchMatches[0]?.[1];
  const existingWorktree = [...git.worktrees.entries()].find(([, details]) => details.branch === branchName);
  if (existingWorktree) {
    if (existingWorktree[1].ticketKey !== ticket.key) throw new WorkspaceConflict(`Target worktree is bound to a different task: ${existingWorktree[0]}`);
    if (existingWorktree[1].dirty) throw new WorkspaceConflict(`Target worktree is dirty: ${existingWorktree[0]}`);
    return receipt(git, ticket, branchName, existingWorktree[0], existingWorktree[1].commit, "existing-worktree", workspaceMode);
  }

  const commit = branch?.commit ?? git.remoteBranches.get(branchName)?.commit ?? git.baseCommit;
  const origin = branch ? "reused-local" : git.remoteBranches.has(branchName) ? "reused-remote" : "created";
  if (!branch) git.createBranch(branchName, commit, ticket.key);
  git.createWorktree(workspacePath, branchName, commit, ticket.key);
  return receipt(git, ticket, branchName, workspacePath, commit, origin, workspaceMode);
}

function receipt(git, ticket, branch, workspacePath, headCommit, origin, workspaceMode) {
  return {
    ticket: ticket.key,
    repository: git.name,
    workspaceMode,
    workspacePath,
    branch,
    origin,
    baseRef: git.baseRef,
    baseCommit: git.baseCommit,
    headCommit,
    originalCheckout: {
      path: git.originalCheckout.path,
      branch: git.originalCheckout.branch,
      dirty: git.originalCheckout.dirty,
      files: [...git.originalCheckout.files],
      index: [...git.originalCheckout.index],
      preserved: true,
    },
    activation: "git-verified",
    next: "Inspect the closest reference implementation.",
  };
}

export class DemoDeploymentAdapter {
  constructor({ pipeline = {}, outcome = "succeeded", history = [] } = {}) {
    this.pipeline = {
      id: pipeline.id ?? "example-service-ci",
      definitionRevision: pipeline.definitionRevision ?? "pipeline-001",
      sourceRepository: pipeline.sourceRepository ?? "example-app",
      allowedEnvironments: pipeline.allowedEnvironments ?? ["sandbox"],
      prohibitedTargets: pipeline.prohibitedTargets ?? [],
      supportsSource: pipeline.supportsSource ?? ["commit", "branch", "tag", "pr"],
    };
    this.outcome = outcome;
    this.history = [...history];
    this.executeCalls = [];
    this.sequence = 0;
  }

  discoverPipeline() {
    return structuredClone(this.pipeline);
  }

  execute(intent) {
    this.executeCalls.push(structuredClone(intent));
    this.sequence += 1;
    const run = {
      id: `demo-run-${String(this.sequence).padStart(3, "0")}`,
      pipeline: intent.pipeline,
      sourceRepository: intent.sourceRepository,
      sourceCommit: intent.sourceCommit,
      environment: intent.environment,
      status: this.outcome === "timeout" ? "launch-uncertain" : this.outcome === "queued" ? "queued" : this.outcome === "succeeded" ? "succeeded" : "running",
      inputReadback: this.outcome === "mismatch" ? "mismatched" : "matched",
      applicationVerification: "not-run",
    };
    if (this.outcome !== "timeout") this.history.push(structuredClone(run));
    if (this.outcome === "timeout") {
      this.history.push(structuredClone({ ...run, status: "succeeded", applicationVerification: "passed" }));
      const error = new Error("Synthetic launch timeout after provider accepted the request");
      error.code = "LAUNCH_TIMEOUT";
      throw error;
    }
    return run;
  }

  findMatches(intent) {
    return this.history.filter((run) => run.pipeline === intent.pipeline && run.sourceRepository === intent.sourceRepository && run.sourceCommit === intent.sourceCommit && run.environment === intent.environment);
  }

  readBack(run) {
    return structuredClone(run);
  }

  smoke(run) {
    if (this.outcome === "smoke-fail") return { status: "failed", reason: "Synthetic health check failed" };
    return { status: "passed", runId: run.id };
  }
}

function intentKey(intent) {
  return [intent.taskId, intent.pipeline, intent.sourceRepository, intent.sourceCommit, intent.environment, intent.configRevision].join("|");
}

function exactAuthorization(plan, authorization) {
  return authorization && authorization.taskId === plan.taskId && authorization.configRevision === plan.configRevision && authorization.pipeline === plan.pipeline && authorization.sourceRepository === plan.sourceRepository && authorization.sourceCommit === plan.sourceCommit && authorization.environment === plan.environment && authorization.operation === "run" && authorization.expiry > plan.now;
}

export class DeploymentWorkflow {
  constructor(adapter, { now = 1_700_000_000_000 } = {}) {
    this.adapter = adapter;
    this.now = now;
    this.intents = new Map();
  }

  plan({ taskId, projectId = "demo-app", component = "example-service", sourceRepository, sourceCommit, sourceType = "commit", environment = "sandbox", configRevision = "demo-config-001" }) {
    const pipeline = this.adapter.discoverPipeline();
    if (pipeline.sourceRepository !== sourceRepository) throw new DeploymentBlocked("Pipeline source repository does not match the requested application source");
    if (!pipeline.supportsSource.includes(sourceType)) throw new DeploymentBlocked(`Pipeline does not support source selector: ${sourceType}`);
    if (!pipeline.allowedEnvironments.includes(environment)) throw new DeploymentBlocked(`Environment is not allowed by the nonproduction policy: ${environment}`);
    if (pipeline.prohibitedTargets.includes(environment)) throw new DeploymentBlocked(`Effective pipeline target is prohibited: ${environment}`);
    if (!sourceCommit) throw new DeploymentBlocked("An immutable source revision is required before planning");
    return {
      mode: "DEMO",
      taskId,
      projectId,
      component,
      pipeline: pipeline.id,
      sourceRepository,
      sourceType,
      sourceCommit,
      definitionRevision: pipeline.definitionRevision,
      environment,
      configRevision,
      operation: "run",
      now: this.now,
      intentId: intentKey({ taskId, pipeline: pipeline.id, sourceRepository, sourceCommit, environment, configRevision }),
      executionId: null,
      status: "planned",
      inputReadback: "unavailable",
      applicationVerification: "not-run",
    };
  }

  authorize(plan, humanOriginReference = "demo-user-request") {
    return {
      taskId: plan.taskId,
      humanOriginReference,
      projectId: plan.projectId,
      configRevision: plan.configRevision,
      pipeline: plan.pipeline,
      sourceRepository: plan.sourceRepository,
      sourceCommit: plan.sourceCommit,
      environment: plan.environment,
      operation: "run",
      expiry: plan.now + 60_000,
    };
  }

  run(plan, authorization) {
    if (!exactAuthorization(plan, authorization)) throw new DeploymentBlocked("Exact run authorization is absent, expired, or no longer matches the plan");
    const existing = this.intents.get(plan.intentId);
    if (existing?.status === "succeeded" || existing?.status === "failed" || existing?.status === "queued" || existing?.status === "running") {
      return { ...existing, duplicatePrevented: true };
    }

    const settle = (run, duplicatePrevented) => {
      const readback = this.adapter.readBack(run);
      const mismatch = readback.sourceCommit !== plan.sourceCommit || readback.environment !== plan.environment;
      const smoke = mismatch ? { status: "not-run" } : this.adapter.smoke(readback);
      const result = {
        ...plan,
        executionId: readback.id,
        status: mismatch ? "verification-mismatch" : readback.status === "queued" || readback.status === "running" ? readback.status : smoke.status === "failed" ? "failed" : "succeeded",
        inputReadback: mismatch ? "mismatched" : "matched",
        applicationVerification: smoke.status,
        next: mismatch ? "Stop and investigate the source or environment mismatch." : smoke.status === "failed" ? "Investigate the failed application verification." : "No further action is required for this demo run.",
        duplicatePrevented,
      };
      this.intents.set(plan.intentId, result);
      return result;
    };

    if (existing?.status === "launch-uncertain") {
      const matches = this.adapter.findMatches(plan);
      if (matches.length !== 1) return { ...existing, next: "Reconcile manually; automatic duplicate launch is blocked.", duplicatePrevented: true };
      return settle(matches[0], true);
    }

    this.intents.set(plan.intentId, { ...plan, status: "launch-uncertain" });
    let run;
    try {
      run = this.adapter.execute(plan);
    } catch (error) {
      if (error.code !== "LAUNCH_TIMEOUT") throw error;
      const matches = this.adapter.findMatches(plan);
      if (matches.length !== 1) return { ...plan, status: "launch-uncertain", executionId: null, next: "Reconcile manually; automatic duplicate launch is blocked.", duplicatePrevented: true };
      run = matches[0];
    }
    return settle(run, false);
  }
}

export function formatDeployment(result) {
  return [
    `Mode: ${result.mode}`,
    `Provider/pipeline: fixture/${result.pipeline}`,
    `Source: ${result.sourceRepository}, ${result.sourceType} ${result.sourceCommit}`,
    `Definition revision: ${result.definitionRevision}`,
    `Environment/effects: ${result.environment} / synthetic application deployment`,
    `Execution: ${result.executionId ?? "none"}`,
    `Lifecycle: ${result.status}`,
    `Input read-back: ${result.inputReadback}`,
    `Application verification: ${result.applicationVerification}`,
    `Next: ${result.next ?? "Continue the owning task."}`,
    "Evidence: offline synthetic fixture; no live deployment was run.",
  ].join("\n");
}
