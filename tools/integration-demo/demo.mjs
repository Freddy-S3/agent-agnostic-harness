import {
  DeploymentWorkflow,
  DemoDeploymentAdapter,
  GitFixture,
  inspectReadiness,
  renderReadiness,
  startTicket,
  formatDeployment,
} from "./core.mjs";

const capabilities = {
  local_git: {
    requiredFor: ["local-engineering", "ticket-start"],
    installation: "present",
    registration: "not-applicable",
    configuration: "valid",
    authentication: "not-required",
    readProbe: "passed",
    freshness: "fresh",
    availability: "available",
    evidence: { summary: "synthetic Git probe passed" },
  },
  issue_tracker: {
    requiredFor: ["ticket-start"],
    installation: "not-applicable",
    registration: "not-applicable",
    configuration: "valid",
    authentication: "not-required",
    readProbe: "passed",
    freshness: "fresh",
    availability: "available",
    evidence: { summary: "synthetic issue and comments read" },
  },
  deployment: {
    requiredFor: ["deployment-plan", "deployment-run"],
    installation: "not-applicable",
    registration: "not-applicable",
    configuration: "valid",
    authentication: "not-required",
    readProbe: "passed",
    freshness: "fresh",
    availability: "available",
    evidence: { summary: "synthetic pipeline schema read" },
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

console.log(renderReadiness(inspectReadiness({
  projectId: "demo-app",
  hostId: "fixture-host",
  mode: "demo",
  configRevision: "demo-config-001",
  capabilities,
  workflow: "ticket-start",
})));

const git = new GitFixture({ originalCheckout: { dirty: true, files: ["README.md", "local-note.txt"] } });
const ticket = { key: "APP-101", summary: "Export status" };
const ticketReceipt = startTicket({ ticket, git, workspacePath: "/fixtures/worktrees/APP-101" });
console.log("\nTicket workspace\n" + JSON.stringify(ticketReceipt, null, 2));

const adapter = new DemoDeploymentAdapter();
const workflow = new DeploymentWorkflow(adapter);
const plan = workflow.plan({ taskId: "task-101", sourceRepository: "example-app", sourceCommit: "app-commit-001" });
const deployment = workflow.run(plan, workflow.authorize(plan));
console.log("\nDeployment\n" + formatDeployment(deployment));
