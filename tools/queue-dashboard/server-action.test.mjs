import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, unlink, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { writeEncryptedSnapshot } from "./action-contract.mjs";

async function request(handler, { method = "GET", url, headers = {}, body = "" }) {
  const req = {
    method,
    url,
    headers,
    async *[Symbol.asyncIterator]() {
      if (body) yield body;
    },
  };
  const response = {
    status: 200,
    headers: {},
    body: "",
    writeHead(status, responseHeaders = {}) {
      this.status = status;
      this.headers = responseHeaders;
      return this;
    },
    end(value = "") {
      this.body += value;
      return this;
    },
  };
  await handler(req, response);
  return { ...response, json: () => JSON.parse(response.body || "{}") };
}

test("authenticated actions are durable, forged actions are rejected, and offline reads are encrypted", async () => {
  const directory = await mkdtemp(join(tmpdir(), "queue-server-actions-"));
  const envNames = {
    queueDir: "QUEUE_DIR",
    token: "QUEUE_TOKEN",
    noListen: "QUEUE_DASHBOARD_NO_LISTEN",
    offline: "QUEUE_OFFLINE",
    snapshotKey: "QUEUE_SNAPSHOT_KEY",
  };
  const previous = Object.fromEntries(Object.entries(envNames).map(([key, name]) => [key, process.env[name]]));
  const queue = `## Synthetic queue item\nStatus: blocked\nProject: harness\nRepo: C:/Users/example/Repo/harness\nSession: session-1\nRun: run-1\nBlocked reason: Choose a safe action.\nOptions:\n- Approve the item\nLog:\n- 2026-11-19: waiting for the owner.\n`;
  await writeFile(join(directory, "QUEUE-PC.md"), queue, "utf8");
  await writeFile(join(directory, "QUEUE-PHONE.md"), "", "utf8");
  process.env.QUEUE_DIR = directory;
  process.env.QUEUE_TOKEN = "synthetic-token";
  process.env.QUEUE_DASHBOARD_NO_LISTEN = "1";
  delete process.env.QUEUE_OFFLINE;
  try {
    const { handler, initializeDashboardForTests } = await import(`./server.mjs?test=${Date.now()}`);
    await initializeDashboardForTests();
    const unauthenticated = await request(handler, { url: "/api/queue" });
    assert.equal(unauthenticated.status, 401);
    const unauthenticatedAction = await request(handler, {
      method: "POST", url: "/api/action", body: "{}",
    });
    assert.equal(unauthenticatedAction.status, 401);

    const context = {
        target: { file: "QUEUE-PC.md", title: "Synthetic queue item" },
        owner: { project: "harness", repository: "C:/Users/example/Repo/harness" },
        sessionRef: { sessionId: "session-1", runId: "run-1" },
        requirements: { localFiles: false, localCredentials: false, freshestSync: false, requiredTools: [] },
    };
    const post = (body) => request(handler, {
      method: "POST", url: "/api/action",
      headers: { "content-type": "application/json", cookie: "qd=synthetic-token" },
      body: JSON.stringify(body),
    });

    const forged = await post({
        actionId: "forged-action",
        kind: "approve",
        ...context,
        owner: { project: "harness", repository: "C:/Users/other/repo" },
        payload: { note: "forged owner" },
    });
    assert.equal(forged.status, 403);

    const forbidden = await post({
        actionId: "forbidden-action",
        kind: "deploy",
        ...context,
        payload: { command: "publish" },
    });
    assert.equal(forbidden.status, 403);

    const body = {
        actionId: "synthetic-action",
        kind: "approve",
        ...context,
        payload: { note: "Approved from synthetic data" },
    };
    const first = await post(body);
    const firstJson = first.json();
    assert.equal(first.status, 200);
    assert.equal(firstJson.applied, true);
    assert.equal(firstJson.status, "deferred");
    const second = await post(body);
    const secondJson = second.json();
    assert.equal(second.status, 200);
    assert.equal(secondJson.duplicate, true);
    const updated = await readFile(join(directory, "QUEUE-PC.md"), "utf8");
    assert.equal((updated.match(/\[action:synthetic-action\]/g) || []).length, 2);
    const audit = await readFile(join(directory, ".queue-action-audit.jsonl"), "utf8");
    assert.match(audit, /"event":"duplicate"/);

    const key = Buffer.alloc(32, 9).toString("base64url");
    const snapshot = {
        groups: [{ file: "QUEUE-PHONE.md", gate: "On your phone", hint: "browser", items: [{ title: "Offline item" }], mtime: 1, error: null }],
        study: { sections: [], total: 0, done: 0, error: null },
        jobs: { sections: [], total: 0, error: null },
        prs: [], triage: [], answerLedger: "ANSWERS.jsonl", archiveRecentDays: 7,
        readAt: 123, queueDir: "hidden-local-path", control: { actions: [] }, offline: false,
    };
    await writeEncryptedSnapshot(join(directory, ".queue-snapshot.enc"), snapshot, key);
    await unlink(join(directory, "QUEUE-PC.md"));
    await unlink(join(directory, "QUEUE-PHONE.md"));
    process.env.QUEUE_OFFLINE = "1";
    process.env.QUEUE_SNAPSHOT_KEY = key;
    const offlineResponse = await request(handler, {
      url: "/api/queue", headers: { cookie: "qd=synthetic-token" },
    });
    const offlineBody = offlineResponse.json();
    assert.equal(offlineResponse.status, 200);
    assert.equal(offlineBody.offline, true);
    assert.equal(offlineBody.groups[0].items[0].title, "Offline item");
  } finally {
    for (const [key, value] of Object.entries(previous)) {
      const name = envNames[key];
      if (value === undefined) delete process.env[name];
      else process.env[name] = value;
    }
    await rm(directory, { recursive: true, force: true });
  }
});
