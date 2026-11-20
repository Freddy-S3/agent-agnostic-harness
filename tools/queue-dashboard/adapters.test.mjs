import assert from "node:assert/strict";
import { test } from "node:test";
import { createConfiguredAdapters, createHttpAdapter } from "./adapters.mjs";

const action = { actionId: "adapter-test-1", schemaVersion: 1, target: { file: "QUEUE-PHONE.md", title: "Synthetic" } };
const routing = { worker: "cloud-session", reason: "test" };

test("configured HTTP adapters authenticate requests and preserve idempotency", async () => {
  let request;
  const adapters = createConfiguredAdapters({
    QUEUE_CLOUD_ADAPTER_URL: "https://cloud.example.test/adapter",
    QUEUE_CLOUD_ADAPTER_TOKEN: "cloud-test-token",
  }, {
    fetchImpl: async (url, options) => {
      request = { url: String(url), options };
      return { ok: true, status: 202, json: async () => ({ accepted: true, receipt: "local-receipt-1" }) };
    },
  });
  const result = await adapters["cloud-session"].deliver(action, routing);
  assert.deepEqual(result, { accepted: true, receipt: "local-receipt-1" });
  assert.equal(request.url, "https://cloud.example.test/adapter");
  assert.equal(request.options.headers.authorization, "Bearer cloud-test-token");
  assert.equal(request.options.headers["idempotency-key"], action.actionId);
  assert.deepEqual(JSON.parse(request.options.body), { schemaVersion: 1, action, routing });
});

test("adapter configuration fails closed when a token is missing or the URL is insecure", () => {
  assert.throws(
    () => createConfiguredAdapters({ QUEUE_DESKTOP_ADAPTER_URL: "https://desktop.example.test" }),
    /adapter token is required/,
  );
  assert.throws(
    () => createHttpAdapter({ name: "cloud-session", url: "http://adapter.example.test", token: "secret" }),
    /must use https/,
  );
});

test("adapter rejection never exposes its bearer token", async () => {
  const adapter = createHttpAdapter({
    name: "desktop-connector",
    url: "https://desktop.example.test",
    token: "do-not-leak",
    fetchImpl: async () => ({ ok: false, status: 403, json: async () => ({ error: "no" }) }),
  });
  const result = await adapter.deliver(action, routing);
  assert.deepEqual(result, { accepted: false, reason: "desktop-connector adapter returned HTTP 403" });
  assert.doesNotMatch(result.reason, /do-not-leak/);
});
