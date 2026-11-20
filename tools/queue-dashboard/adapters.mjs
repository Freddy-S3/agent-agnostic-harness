const DEFAULT_TIMEOUT_MS = 10_000;

export class AdapterConfigError extends Error {
  constructor(message) {
    super(message);
    this.name = "AdapterConfigError";
    this.code = "ADAPTER_CONFIG_INVALID";
  }
}

function required(value, name) {
  if (typeof value !== "string" || !value.trim()) {
    throw new AdapterConfigError(`${name} is required when the adapter is configured`);
  }
  return value.trim();
}

function validateUrl(raw, name, allowInsecureLocal) {
  let url;
  try {
    url = new URL(required(raw, name));
  } catch {
    throw new AdapterConfigError(`${name} must be a valid https URL`);
  }
  const local = ["localhost", "127.0.0.1", "::1"].includes(url.hostname);
  if (url.protocol !== "https:" && !(allowInsecureLocal && local && url.protocol === "http:")) {
    throw new AdapterConfigError(`${name} must use https; insecure http is allowed only for local tests`);
  }
  return url;
}

export function createHttpAdapter({ name, url, token, fetchImpl = globalThis.fetch, timeoutMs = DEFAULT_TIMEOUT_MS, allowInsecureLocal = false }) {
  const adapterName = required(name, "adapter name");
  const endpoint = validateUrl(url, `${adapterName} adapter URL`, allowInsecureLocal);
  const secret = required(token, `${adapterName} adapter token`);
  if (typeof fetchImpl !== "function") throw new AdapterConfigError("fetch is unavailable for the configured adapter");

  return {
    async deliver(action, routing) {
      const controller = new AbortController();
      const timer = setTimeout(() => controller.abort(), timeoutMs);
      try {
        const response = await fetchImpl(endpoint, {
          method: "POST",
          headers: {
            accept: "application/json",
            "content-type": "application/json",
            authorization: `Bearer ${secret}`,
            "idempotency-key": action.actionId,
          },
          body: JSON.stringify({ schemaVersion: 1, action, routing }),
          signal: controller.signal,
        });
        if (!response.ok) {
          return { accepted: false, reason: `${adapterName} adapter returned HTTP ${response.status}` };
        }
        let body = {};
        try { body = await response.json(); } catch { /* a missing receipt is still a rejection */ }
        if (body && (body.accepted === true || body.delivered === true)) {
          return { accepted: true, receipt: body.receipt || null };
        }
        return { accepted: false, reason: `${adapterName} adapter did not accept the action` };
      } catch (error) {
        const reason = error?.name === "AbortError" ? "adapter request timed out" : "adapter request failed";
        return { accepted: false, reason: `${adapterName} ${reason}` };
      } finally {
        clearTimeout(timer);
      }
    },
  };
}

function configuredAdapter(env, worker, options) {
  const prefix = worker === "cloud-session" ? "QUEUE_CLOUD" : "QUEUE_DESKTOP";
  const url = env[`${prefix}_ADAPTER_URL`];
  const token = env[`${prefix}_ADAPTER_TOKEN`];
  if (!url && !token) return null;
  return createHttpAdapter({
    name: worker,
    url,
    token,
    fetchImpl: options.fetchImpl,
    timeoutMs: options.timeoutMs,
    allowInsecureLocal: options.allowInsecureLocal,
  });
}

export function createConfiguredAdapters(env = process.env, options = {}) {
  const adapters = {};
  for (const worker of ["cloud-session", "desktop-connector"]) {
    const adapter = configuredAdapter(env, worker, options);
    if (adapter) adapters[worker] = adapter;
  }
  return adapters;
}
