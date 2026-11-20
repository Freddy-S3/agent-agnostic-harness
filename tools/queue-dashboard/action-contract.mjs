import { createCipheriv, createDecipheriv, createHash, randomBytes } from "node:crypto";
import { appendFile, mkdir, readFile, rename, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";

export const ACTION_SCHEMA_VERSION = 1;
export const SAFE_ACTION_KINDS = Object.freeze(["answer", "approve", "skip", "unblock"]);

const ACTION_LOG = ".queue-actions.jsonl";
const AUDIT_LOG = ".queue-action-audit.jsonl";
const ACTION_ID_RE = /^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$/;
const FORBIDDEN_KEY_RE = /shell|command|script|merge|deploy|secret|credential|billing|publish/i;

export class ActionContractError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.name = "ActionContractError";
    this.code = code;
    this.status = status;
  }
}

function requiredString(value, name, { max = 256 } = {}) {
  if (typeof value !== "string" || !value.trim() || value.length > max) {
    throw new ActionContractError("INVALID_ACTION", `${name} must be a non-empty string`);
  }
  return value.trim();
}

function identifier(value, name) {
  const out = requiredString(value, name, { max: 128 });
  if (!ACTION_ID_RE.test(out)) {
    throw new ActionContractError("INVALID_ACTION", `${name} contains unsupported characters`);
  }
  return out;
}

function sortedJson(value) {
  if (Array.isArray(value)) return `[${value.map(sortedJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${sortedJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

function normalizeOwner(owner) {
  if (!owner || typeof owner !== "object") {
    throw new ActionContractError("OWNER_REQUIRED", "exactly one owning project and repository are required");
  }
  return {
    project: requiredString(owner.project, "owner.project"),
    repository: requiredString(owner.repository, "owner.repository", { max: 512 }),
  };
}

function normalizeSession(session) {
  if (!session || typeof session !== "object") {
    throw new ActionContractError("SESSION_REQUIRED", "sessionRef with sessionId and runId is required");
  }
  return {
    sessionId: identifier(session.sessionId, "sessionRef.sessionId"),
    runId: identifier(session.runId, "sessionRef.runId"),
  };
}

function normalizeTarget(target) {
  if (!target || typeof target !== "object") {
    throw new ActionContractError("TARGET_REQUIRED", "a queue-item target is required");
  }
  const file = requiredString(target.file, "target.file", { max: 64 });
  if (!/^QUEUE-(?:PC|PHONE)\.md$/.test(file)) {
    throw new ActionContractError("TARGET_FORBIDDEN", "actions may target only QUEUE-PC.md or QUEUE-PHONE.md");
  }
  return { file, title: requiredString(target.title, "target.title", { max: 400 }) };
}

function normalizeRequirements(requirements = {}) {
  if (!requirements || typeof requirements !== "object") {
    throw new ActionContractError("INVALID_ACTION", "requirements must be an object");
  }
  const tools = Array.isArray(requirements.requiredTools) ? requirements.requiredTools : [];
  const requiredTools = [...new Set(tools.map((tool) => requiredString(tool, "requirements.requiredTools", { max: 128 })))]
    .sort();
  return {
    localFiles: requirements.localFiles === true,
    localCredentials: requirements.localCredentials === true,
    freshestSync: requirements.freshestSync === true,
    requiredTools,
  };
}

function assertSafePayload(payload) {
  if (!payload || typeof payload !== "object" || Array.isArray(payload)) {
    throw new ActionContractError("INVALID_ACTION", "payload must be an object");
  }
  for (const key of Object.keys(payload)) {
    if (FORBIDDEN_KEY_RE.test(key)) {
      throw new ActionContractError("FORBIDDEN_ACTION", `${key} actions are not available from the queue portal`, 403);
    }
  }
}

function normalizePayload(kind, payload = {}) {
  assertSafePayload(payload);
  if (kind === "answer") return { text: requiredString(payload.text, "payload.text", { max: 4000 }) };
  if (kind === "approve") return { note: requiredString(payload.note || "Approved from the queue portal", "payload.note", { max: 1000 }) };
  if (kind === "skip") return { reason: requiredString(payload.reason || "Skipped from the queue portal", "payload.reason", { max: 1000 }) };
  return { note: requiredString(payload.note || "Unblocked from the queue portal", "payload.note", { max: 1000 }) };
}

function normalizeCapabilities(capabilities = {}) {
  const normalizeWorker = (worker = {}) => ({
    available: worker.available === true,
    repositories: Array.isArray(worker.repositories) ? worker.repositories.map(String) : [],
    tools: Array.isArray(worker.tools) ? worker.tools.map(String) : [],
  });
  return { cloud: normalizeWorker(capabilities.cloud), desktop: normalizeWorker(capabilities.desktop) };
}

function hasRepository(worker, repository) {
  return worker.repositories.includes("*") || worker.repositories.includes(repository);
}

function hasTools(worker, requiredTools) {
  return requiredTools.every((tool) => worker.tools.includes("*") || worker.tools.includes(tool));
}

export function selectWorker(action, capabilities = {}) {
  const available = normalizeCapabilities(capabilities);
  const requirements = action.requirements;
  const localOnly = requirements.localFiles || requirements.localCredentials || requirements.freshestSync;
  const cloudReady = available.cloud.available
    && hasRepository(available.cloud, action.owner.repository)
    && hasTools(available.cloud, requirements.requiredTools);
  const desktopReady = available.desktop.available
    && hasRepository(available.desktop, action.owner.repository)
    && hasTools(available.desktop, requirements.requiredTools);

  if (localOnly) {
    return desktopReady
      ? { worker: "desktop-connector", reason: "local capability or freshest synchronization is required" }
      : { worker: "deferred", queue: "desktop", reason: "desktop capability is unavailable for a local-only action" };
  }
  if (cloudReady) return { worker: "cloud-session", reason: "connected remote repository can run cloud-first" };
  if (desktopReady) return { worker: "desktop-connector", reason: "cloud delivery is unavailable and the desktop connector is available" };
  return { worker: "deferred", queue: "desktop", reason: "no authorized worker has the repository and required tools" };
}

export function createAction(input) {
  const kind = requiredString(input.kind, "kind", { max: 32 }).toLowerCase();
  if (!SAFE_ACTION_KINDS.includes(kind)) {
    throw new ActionContractError("FORBIDDEN_ACTION", `${kind} actions are not available from the queue portal`, 403);
  }
  const actionId = identifier(input.actionId || `portal-${randomBytes(12).toString("hex")}`, "actionId");
  const createdAt = input.createdAt || new Date().toISOString();
  if (Number.isNaN(Date.parse(createdAt))) {
    throw new ActionContractError("INVALID_ACTION", "createdAt must be an ISO timestamp");
  }
  const queueMtime = input.queueMtime === undefined ? 0 : Number(input.queueMtime);
  if (!Number.isFinite(queueMtime) || queueMtime < 0) {
    throw new ActionContractError("INVALID_ACTION", "queueMtime must be a non-negative number");
  }
  return {
    schemaVersion: ACTION_SCHEMA_VERSION,
    actionId,
    kind,
    actor: identifier(input.actor || "authenticated-owner", "actor"),
    target: normalizeTarget(input.target),
    owner: normalizeOwner(input.owner),
    sessionRef: normalizeSession(input.sessionRef),
    requirements: normalizeRequirements(input.requirements),
    consistency: {
      queueMtime,
    },
    payload: normalizePayload(kind, input.payload),
    createdAt,
  };
}

export function actionFingerprint(action) {
  const stable = {
    schemaVersion: action.schemaVersion,
    actionId: action.actionId,
    kind: action.kind,
    actor: action.actor,
    target: action.target,
    owner: action.owner,
    sessionRef: action.sessionRef,
    requirements: action.requirements,
    payload: action.payload,
  };
  return createHash("sha256").update(sortedJson(stable)).digest("hex");
}

async function appendRecord(path, record) {
  await mkdir(dirname(path), { recursive: true });
  await appendFile(path, `${JSON.stringify(record)}\n`, "utf8");
}

async function readRecords(path) {
  try {
    const text = await readFile(path, "utf8");
    return text.split(/\r?\n/).filter(Boolean).flatMap((line) => {
      try { return [JSON.parse(line)]; } catch { return []; }
    });
  } catch (error) {
    if (error.code === "ENOENT") return [];
    throw error;
  }
}

function foldActions(records) {
  const current = new Map();
  for (const record of records) {
    if (!record.actionId) continue;
    if (record.type === "action") current.set(record.actionId, {
      action: record.action,
      fingerprint: record.fingerprint,
      routing: record.routing,
      status: "accepted",
      applied: false,
      delivery: null,
    });
    const item = current.get(record.actionId);
    if (!item) continue;
    if (record.type === "applied") { item.applied = true; item.status = "applied"; }
    if (record.type === "apply-deferred") item.applyReason = record.reason;
    if (record.type === "delivery") {
      item.delivery = record.delivery;
      item.status = record.delivery.status;
    }
  }
  return current;
}

export class ActionStore {
  constructor({ directory, capabilities = {}, adapters = {}, actor = "authenticated-owner", clock = () => new Date().toISOString() }) {
    this.directory = directory;
    this.capabilities = normalizeCapabilities(capabilities);
    this.adapters = adapters;
    this.actor = actor;
    this.clock = clock;
    this.locks = new Map();
  }

  get actionPath() { return join(this.directory, ACTION_LOG); }
  get auditPath() { return join(this.directory, AUDIT_LOG); }

  async audit(actionId, event, details = {}) {
    await appendRecord(this.auditPath, { at: this.clock(), actionId, event, ...details });
  }

  async records() {
    return foldActions(await readRecords(this.actionPath));
  }

  async markApplied(actionId, details = {}) {
    const current = (await this.records()).get(actionId);
    if (!current) throw new ActionContractError("ACTION_NOT_FOUND", `action ${actionId} is not recorded`, 404);
    if (current.applied) return current;
    await appendRecord(this.actionPath, { type: "applied", actionId, at: this.clock(), details });
    await this.audit(actionId, "applied", details);
    return (await this.records()).get(actionId);
  }

  async submit(input, options = {}) {
    const lockKey = String(input.actionId || "generated-action");
    const previous = this.locks.get(lockKey) || Promise.resolve();
    const current = previous.catch(() => undefined).then(() => this.#submit(input, options));
    this.locks.set(lockKey, current);
    try {
      return await current;
    } finally {
      if (this.locks.get(lockKey) === current) this.locks.delete(lockKey);
    }
  }

  async #submit(input, { apply } = {}) {
    const action = createAction({ ...input, actor: input.actor || this.actor });
    const fingerprint = actionFingerprint(action);
    const existing = (await this.records()).get(action.actionId);
    if (existing) {
      if (existing.fingerprint !== fingerprint) {
        throw new ActionContractError("ACTION_REPLAY", "actionId was already used for a different action", 409);
      }
      await this.audit(action.actionId, "duplicate", { fingerprint });
      if (!existing.applied && apply) {
        const applied = await apply(existing.action);
        if (applied?.applied !== false) await this.markApplied(action.actionId, applied || {});
        else await appendRecord(this.actionPath, { type: "apply-deferred", actionId: action.actionId, at: this.clock(), reason: applied.reason });
      }
      return { ...((await this.records()).get(action.actionId)), duplicate: true };
    }

    const routing = selectWorker(action, this.capabilities);
    await appendRecord(this.actionPath, {
      type: "action",
      actionId: action.actionId,
      fingerprint,
      action,
      routing,
      at: this.clock(),
    });
    await this.audit(action.actionId, "accepted", { fingerprint, routing });

    if (apply) {
      const applied = await apply(action);
      if (applied?.applied !== false) await this.markApplied(action.actionId, applied || {});
      else await appendRecord(this.actionPath, { type: "apply-deferred", actionId: action.actionId, at: this.clock(), reason: applied.reason });
    }

    const adapter = this.adapters[routing.worker];
    if (routing.worker === "deferred" || !adapter || typeof adapter.deliver !== "function") {
      const delivery = { status: "deferred", reason: routing.reason };
      await appendRecord(this.actionPath, { type: "delivery", actionId: action.actionId, delivery, at: this.clock() });
      await this.audit(action.actionId, "deferred", delivery);
    } else {
      try {
        const result = await adapter.deliver(action, routing);
        const delivery = result?.delivered === true || result?.accepted === true
          ? { status: "delivered", worker: routing.worker, receipt: result.receipt || null }
          : { status: "deferred", worker: routing.worker, reason: result?.reason || "adapter did not accept the action" };
        await appendRecord(this.actionPath, { type: "delivery", actionId: action.actionId, delivery, at: this.clock() });
        await this.audit(action.actionId, delivery.status, delivery);
      } catch (error) {
        const delivery = { status: "deferred", worker: routing.worker, reason: error.message || "adapter delivery failed" };
        await appendRecord(this.actionPath, { type: "delivery", actionId: action.actionId, delivery, at: this.clock() });
        await this.audit(action.actionId, "deferred", delivery);
      }
    }
    return { ...((await this.records()).get(action.actionId)), duplicate: false };
  }
}

function snapshotKeyBytes(key) {
  if (Buffer.isBuffer(key) || key instanceof Uint8Array) {
    if (key.length === 32) return Buffer.from(key);
  } else if (typeof key === "string") {
    const trimmed = key.trim();
    const decoded = /^[0-9a-f]{64}$/i.test(trimmed)
      ? Buffer.from(trimmed, "hex")
      : Buffer.from(trimmed, "base64url");
    if (decoded.length === 32) return decoded;
  }
  throw new ActionContractError("SNAPSHOT_KEY_INVALID", "snapshot key must decode to 32 bytes", 500);
}

export function encryptSnapshot(snapshot, key, clock = () => new Date().toISOString()) {
  const actualIv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", snapshotKeyBytes(key), actualIv);
  const ciphertext = Buffer.concat([cipher.update(JSON.stringify(snapshot), "utf8"), cipher.final()]);
  return {
    schemaVersion: 1,
    algorithm: "aes-256-gcm",
    createdAt: clock(),
    iv: actualIv.toString("base64url"),
    authTag: cipher.getAuthTag().toString("base64url"),
    ciphertext: ciphertext.toString("base64url"),
  };
}

export function decryptSnapshot(record, key) {
  if (!record || record.schemaVersion !== 1 || record.algorithm !== "aes-256-gcm") {
    throw new ActionContractError("SNAPSHOT_INVALID", "unsupported encrypted snapshot", 500);
  }
  const decipher = createDecipheriv("aes-256-gcm", snapshotKeyBytes(key), Buffer.from(record.iv, "base64url"));
  decipher.setAuthTag(Buffer.from(record.authTag, "base64url"));
  const plain = Buffer.concat([
    decipher.update(Buffer.from(record.ciphertext, "base64url")),
    decipher.final(),
  ]);
  return JSON.parse(plain.toString("utf8"));
}

export async function writeEncryptedSnapshot(path, snapshot, key, clock) {
  const temp = `${path}.tmp-${process.pid}`;
  await mkdir(dirname(path), { recursive: true });
  await writeFile(temp, JSON.stringify(encryptSnapshot(snapshot, key, clock)) + "\n", { encoding: "utf8", mode: 0o600 });
  await rename(temp, path);
}

export async function readEncryptedSnapshot(path, key) {
  return decryptSnapshot(JSON.parse(await readFile(path, "utf8")), key);
}

export const actionLogNames = Object.freeze({ action: ACTION_LOG, audit: AUDIT_LOG });
