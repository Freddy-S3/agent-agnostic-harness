import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import {
  ActionContractError,
  ActionStore,
  actionLogNames,
  createAction,
  decryptSnapshot,
  encryptSnapshot,
  readEncryptedSnapshot,
  selectWorker,
  writeEncryptedSnapshot,
} from "./action-contract.mjs";

const owner = { project: "harness", repository: "C:/Users/example/Repo/harness" };
const sessionRef = { sessionId: "cloud-session-1", runId: "run-42" };

function action(overrides = {}) {
  return {
    actionId: "action-1",
    kind: "approve",
    target: { file: "QUEUE-PHONE.md", title: "Synthetic queue item" },
    owner,
    sessionRef,
    requirements: {},
    payload: { note: "Approved from synthetic data" },
    ...overrides,
  };
}

test("the contract binds one owner and one session, and rejects browser executor actions", () => {
  const result = createAction(action());
  assert.deepEqual(result.owner, owner);
  assert.deepEqual(result.sessionRef, sessionRef);
  for (const [kind, payload] of [
    ["answer", { text: "Keep the item" }],
    ["approve", { note: "Approve the item" }],
    ["skip", { reason: "Skip the item" }],
    ["unblock", { note: "Unblock the item" }],
  ]) {
    assert.equal(createAction(action({ actionId: `action-${kind}`, kind, payload })).kind, kind);
  }
  assert.throws(
    () => createAction(action({ kind: "shell", payload: { command: "dir" } })),
    (error) => error instanceof ActionContractError && error.status === 403,
  );
  assert.throws(
    () => createAction(action({ owner: { project: "harness" } })),
    (error) => error.code === "INVALID_ACTION",
  );
});

test("worker selection is cloud-first, desktop-only for local requirements, and deferred without capability", () => {
  const remote = createAction(action());
  assert.equal(selectWorker(remote, {
    cloud: { available: true, repositories: [owner.repository], tools: [] },
    desktop: { available: false },
  }).worker, "cloud-session");

  const local = createAction(action({
    actionId: "action-local",
    requirements: { localFiles: true, freshestSync: true },
  }));
  assert.equal(selectWorker(local, {
    cloud: { available: true, repositories: [owner.repository], tools: [] },
    desktop: { available: true, repositories: [owner.repository], tools: [] },
  }).worker, "desktop-connector");

  const unavailableTool = createAction(action({
    actionId: "action-tool",
    requirements: { requiredTools: ["local-gui"] },
  }));
  const deferred = selectWorker(unavailableTool, {
    cloud: { available: true, repositories: [owner.repository], tools: ["queue-actions"] },
    desktop: { available: false },
  });
  assert.equal(deferred.worker, "deferred");
  assert.equal(deferred.queue, "desktop");
});

test("duplicate action ids are idempotent and leave audit evidence", async () => {
  const directory = await mkdtemp(join(tmpdir(), "queue-actions-"));
  let deliveries = 0;
  let applications = 0;
  try {
    const store = new ActionStore({
      directory,
      capabilities: { cloud: { available: true, repositories: [owner.repository], tools: [] } },
      adapters: {
        "cloud-session": { deliver: async () => { deliveries += 1; return { delivered: true, receipt: "synthetic-1" }; } },
      },
    });
    const first = await store.submit(action(), {
      apply: async () => { applications += 1; return { applied: true, evidence: "synthetic queue write" }; },
    });
    const second = await store.submit(action(), {
      apply: async () => { applications += 1; return { applied: true }; },
    });
    assert.equal(first.status, "delivered");
    assert.equal(second.duplicate, true);
    assert.equal(deliveries, 1);
    assert.equal(applications, 1);

    const concurrentAction = action({ actionId: "action-concurrent" });
    const [concurrentFirst, concurrentSecond] = await Promise.all([
      store.submit(concurrentAction, {
        apply: async () => { applications += 1; return { applied: true }; },
      }),
      store.submit(concurrentAction, {
        apply: async () => { applications += 1; return { applied: true }; },
      }),
    ]);
    assert.equal([concurrentFirst, concurrentSecond].filter((result) => result.duplicate).length, 1);
    assert.equal(deliveries, 2);
    assert.equal(applications, 2);

    await assert.rejects(
      store.submit(action({ payload: { note: "forged replacement" } })),
      (error) => error.code === "ACTION_REPLAY" && error.status === 409,
    );
    const audit = await readFile(join(directory, actionLogNames.audit), "utf8");
    assert.match(audit, /"event":"accepted"/);
    assert.match(audit, /"event":"applied"/);
    assert.match(audit, /"event":"duplicate"/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("missing live delivery is recorded for the next authorized session", async () => {
  const directory = await mkdtemp(join(tmpdir(), "queue-actions-deferred-"));
  try {
    const store = new ActionStore({ directory, capabilities: {} });
    const result = await store.submit(action({ actionId: "action-deferred" }));
    assert.equal(result.status, "deferred");
    assert.equal(result.routing.queue, "desktop");
    const audit = await readFile(join(directory, actionLogNames.audit), "utf8");
    assert.match(audit, /"event":"deferred"/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("encrypted snapshots can be read offline and fail closed with the wrong key", async () => {
  const directory = await mkdtemp(join(tmpdir(), "queue-snapshot-"));
  const path = join(directory, ".queue-snapshot.enc");
  const key = Buffer.alloc(32, 7);
  const snapshot = { groups: [{ file: "QUEUE-PHONE.md", items: [{ title: "Offline item" }] }], readAt: 123 };
  try {
    const encrypted = encryptSnapshot(snapshot, key, () => "2026-11-19T00:00:00.000Z");
    assert.notEqual(encrypted.ciphertext, JSON.stringify(snapshot));
    assert.deepEqual(decryptSnapshot(encrypted, key), snapshot);
    await writeEncryptedSnapshot(path, snapshot, key, () => "2026-11-19T00:00:00.000Z");
    assert.deepEqual(await readEncryptedSnapshot(path, key), snapshot);
    assert.throws(() => decryptSnapshot(encrypted, Buffer.alloc(32, 8)), /Unsupported state|unable to authenticate/i);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
