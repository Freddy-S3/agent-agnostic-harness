import assert from "node:assert/strict";
import { PassThrough, Readable } from "node:stream";
import { test } from "node:test";
import { allowedWriteOrigin, readLimitedBody, validPublicOrigin } from "./request-security.mjs";

test("public origins must be canonical HTTPS origins", () => {
  assert.equal(validPublicOrigin(""), true);
  assert.equal(validPublicOrigin("https://queue.example.com"), true);
  assert.equal(validPublicOrigin("https://queue.example.com/"), false);
  assert.equal(validPublicOrigin("https://queue.example.com:443"), false);
  assert.equal(validPublicOrigin("http://queue.example.com"), false);
  assert.equal(validPublicOrigin("https://user@queue.example.com"), false);
});

test("write requests require an exact trusted origin and host", () => {
  assert.equal(allowedWriteOrigin("http://localhost:4317", "localhost:4317"), true);
  assert.equal(allowedWriteOrigin("http://127.0.0.1:4317", "127.0.0.1:4317"), true);
  assert.equal(allowedWriteOrigin("http://100.64.1.2:4317", "100.64.1.2:4317"), true);
  assert.equal(allowedWriteOrigin("https://pc.example.ts.net", "pc.example.ts.net"), true);
  assert.equal(allowedWriteOrigin("https://queue.example.com", "queue.example.com", "https://queue.example.com"), true);
  assert.equal(allowedWriteOrigin("https://attacker.example", "localhost:4317"), false);
  assert.equal(allowedWriteOrigin(undefined, "localhost:4317"), false);
  assert.equal(allowedWriteOrigin("https://attacker.example", "attacker.example"), false);
  assert.equal(allowedWriteOrigin("http://queue.example.com", "queue.example.com", "http://queue.example.com"), false);
});

test("request bodies are bounded by bytes and do not retain oversized payloads", async () => {
  assert.equal(await readLimitedBody(Readable.from(["answer", " text"])), "answer text");
  await assert.rejects(readLimitedBody(Readable.from([Buffer.alloc(65_537)])), { code: 413 });
  await assert.rejects(readLimitedBody(Readable.from([Buffer.alloc(40_000), Buffer.alloc(30_000)])), { code: 413 });
});

test("oversized streaming requests are rejected before the sender finishes", async () => {
  const stream = new PassThrough();
  const body = readLimitedBody(stream);
  stream.write(Buffer.alloc(65_537));
  await assert.rejects(body, { code: 413 });
  stream.destroy();
});
