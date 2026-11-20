import assert from "node:assert/strict";
import { mkdtemp, readFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { test } from "node:test";
import { emitSignal, validateMainSignal } from "./queue-factory-hook.mjs";

const valid = {
  repository: "Freddy-S3/agent-agnostic-harness",
  ref: "refs/heads/main",
  sha: "ABCDEF0123456789ABCDEF0123456789ABCDEF01",
};

test("factory hook validates only the configured main ref and full commit", () => {
  const record = validateMainSignal(valid);
  assert.equal(record.type, "main-validated");
  assert.equal(record.sha, valid.sha.toLowerCase());
  assert.equal(record.maxItems, 1);
  assert.deepEqual(record.requires, ["authenticated-queue", "capability-gates", "human-gates", "aws-controls"]);
  assert.throws(() => validateMainSignal({ ...valid, ref: "refs/heads/codex/private-queue-portal" }), /only refs\/heads\/main/);
  assert.throws(() => validateMainSignal({ ...valid, sha: "deadbeef" }), /full 40-character/);
  assert.throws(() => validateMainSignal({ ...valid, repository: "other/repo" }), /not the configured/);
});

test("factory signal is bounded and idempotent", async () => {
  const directory = await mkdtemp(join(tmpdir(), "queue-factory-hook-"));
  const path = join(directory, "signals.jsonl");
  try {
    const record = validateMainSignal(valid);
    assert.deepEqual(await emitSignal(path, record), { emitted: true, duplicate: false });
    assert.deepEqual(await emitSignal(path, record), { emitted: false, duplicate: true });
    const lines = (await readFile(path, "utf8")).trim().split(/\r?\n/);
    assert.equal(lines.length, 1);
    const saved = JSON.parse(lines[0]);
    assert.equal(saved.maxItems, 1);
    assert.equal(saved.status, "pending-human-gate");
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
