import { appendFile, mkdir, open, readFile, unlink } from "node:fs/promises";
import { dirname } from "node:path";
import { pathToFileURL } from "node:url";

const DEFAULT_REPOSITORY = "Freddy-S3/agent-agnostic-harness";
const MAIN_REF = "refs/heads/main";

function usage(message) {
  if (message) console.error(`queue factory hook: ${message}`);
  console.error("usage: node tools/queue-factory-hook.mjs --repository owner/name --ref refs/heads/main --sha 40-hex [--emit --signal-file path]");
  process.exitCode = 2;
}

function parseArgs(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (!["--repository", "--ref", "--sha", "--expected-repository", "--signal-file"].includes(arg)) {
      if (arg === "--emit") { values.emit = true; continue; }
      usage(`unsupported option ${arg}`);
      return null;
    }
    const value = argv[index + 1];
    if (!value || value.startsWith("--")) { usage(`${arg} requires a value`); return null; }
    values[arg.slice(2)] = value;
    index += 1;
  }
  return values;
}

export function validateMainSignal({ repository, ref, sha, expectedRepository = DEFAULT_REPOSITORY }) {
  if (repository !== expectedRepository) throw new Error("repository is not the configured queue repository");
  if (ref !== MAIN_REF) throw new Error("only refs/heads/main may signal the factory");
  if (!/^[0-9a-f]{40}$/i.test(sha || "")) throw new Error("sha must be a full 40-character commit id");
  return {
    schemaVersion: 1,
    type: "main-validated",
    repository,
    ref,
    sha: sha.toLowerCase(),
    maxItems: 1,
    status: "pending-human-gate",
    requires: ["authenticated-queue", "capability-gates", "human-gates", "aws-controls"],
  };
}

async function existingSignal(path, record) {
  try {
    const text = await readFile(path, "utf8");
    return text.split(/\r?\n/).filter(Boolean).some((line) => {
      try {
        const current = JSON.parse(line);
        return current.repository === record.repository && current.ref === record.ref && current.sha === record.sha;
      } catch {
        return false;
      }
    });
  } catch (error) {
    if (error.code === "ENOENT") return false;
    throw error;
  }
}

async function acquireLock(path) {
  const lockPath = `${path}.lock`;
  for (let attempt = 0; attempt < 40; attempt += 1) {
    try {
      return { handle: await open(lockPath, "wx"), lockPath };
    } catch (error) {
      if (error.code !== "EEXIST") throw error;
      await new Promise((resolve) => setTimeout(resolve, 25));
    }
  }
  throw new Error("signal file is busy");
}

export async function emitSignal(path, record) {
  if (!path) throw new Error("a signal file is required");
  await mkdir(dirname(path), { recursive: true, mode: 0o700 });
  const lock = await acquireLock(path);
  try {
    if (await existingSignal(path, record)) return { emitted: false, duplicate: true };
    await appendFile(path, `${JSON.stringify(record)}\n`, { encoding: "utf8", mode: 0o600 });
    return { emitted: true, duplicate: false };
  } finally {
    await lock.handle.close();
    await unlink(lock.lockPath).catch(() => undefined);
  }
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = parseArgs(process.argv.slice(2));
  if (!args) process.exit();
  try {
    const record = validateMainSignal({
      repository: args.repository || process.env.GITHUB_REPOSITORY,
      ref: args.ref || process.env.GITHUB_REF,
      sha: args.sha || process.env.GITHUB_SHA,
      expectedRepository: args["expected-repository"] || process.env.QUEUE_FACTORY_REPOSITORY || DEFAULT_REPOSITORY,
    });
    const result = args.emit
      ? await emitSignal(args["signal-file"] || process.env.QUEUE_FACTORY_SIGNAL_FILE, record)
      : { emitted: false, duplicate: false };
    console.log(JSON.stringify({ validated: true, ...result, record }));
  } catch (error) {
    console.error(`queue factory hook: ${error.message}`);
    process.exitCode = 1;
  }
}
