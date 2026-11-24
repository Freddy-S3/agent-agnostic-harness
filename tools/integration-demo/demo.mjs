import {
  DeploymentWorkflow,
  DemoDeploymentAdapter,
  GitFixture,
  inspectReadiness,
  renderReadiness,
  inspectInterviewReadiness,
  renderInterviewReadiness,
  prepareCodingTask,
  createInterviewWorkboard,
  updateInterviewTask,
  renderInterviewWorkboard,
  buildInterviewWrapUp,
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

const interviewReadiness = inspectInterviewReadiness({
  mode: "demo",
  runtime: { available: true, lts: true, evidence: { summary: "synthetic node/npm version check passed" } },
  aiTool: { installed: true, authenticated: true, callable: true, evidence: { summary: "synthetic coding-tool call passed" } },
  ide: { available: true, evidence: { summary: "synthetic fixture opened in IDE" } },
  testCommand: "npm test",
  testEvidence: { summary: "synthetic test command passed" },
  serverCommand: "npm run dev",
  serverProbe: {
    status: "passed",
    evidence: { summary: "synthetic server smoke check passed" },
  },
});
console.log("\n" + renderInterviewReadiness(interviewReadiness));

const clarification = prepareCodingTask({ request: "Add a status filter", questions: ["Which statuses are in scope?"] });
const clarified = prepareCodingTask({ request: clarification.request, clarified: true, assumptions: ["Filter is client-side"], targetFiles: ["src/App.jsx", "src/App.test.jsx"] });
let workboard = createInterviewWorkboard([
  { id: "ui", title: "Implement the status filter", owner: "agent-ui" },
  { id: "tests", title: "Add focused filter tests", owner: "agent-tests" },
]);
workboard = updateInterviewTask(workboard, "ui", { status: "done", evidence: { summary: "fixture component updated" } });
workboard = updateInterviewTask(workboard, "tests", { status: "done", evidence: { summary: "2 focused tests passed" } });
console.log("\nClarification\n" + JSON.stringify({ beforeWrite: clarification.writeAuthorized, afterClarification: clarified.writeAuthorized }, null, 2));
console.log("\nParallel workboard\n" + renderInterviewWorkboard(workboard));
console.log("\nWrap-up\n" + JSON.stringify(buildInterviewWrapUp({
  scope: clarified.request,
  completed: ["status filter", "focused tests"],
  testEvidence: { summary: "2 focused tests passed" },
  serverEvidence: { summary: "synthetic server smoke check passed" },
  remaining: ["No live host or provider verification"],
}), null, 2));

const git = new GitFixture({ originalCheckout: { dirty: true, files: ["README.md", "local-note.txt"] } });
const ticket = { key: "APP-101", summary: "Export status" };
const ticketReceipt = startTicket({ ticket, git, workspacePath: "/fixtures/worktrees/APP-101" });
console.log("\nTicket workspace\n" + JSON.stringify(ticketReceipt, null, 2));

const adapter = new DemoDeploymentAdapter();
const workflow = new DeploymentWorkflow(adapter);
const plan = workflow.plan({ taskId: "task-101", sourceRepository: "example-app", sourceCommit: "app-commit-001" });
const deployment = workflow.run(plan, workflow.authorize(plan));
console.log("\nDeployment\n" + formatDeployment(deployment));
