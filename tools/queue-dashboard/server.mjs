// Live queue dashboard. Reads the real queue files on EVERY request - no snapshot,
// no cache, no republish step. This is the answer to "an artifact cannot autoupdate":
// the page polls a local server that re-reads disk, so it is never stale.
//
//   node tools/queue-dashboard/server.mjs
//
// Queue location resolves the same way the skills do: QUEUE_DIR env var, else
// ~/.claude-harness/queue.
//
// Answering a decision writes back into the item it belongs to, because that is where
// the next agent run will actually read it. Every write is guarded three ways:
//   - a .bak copy of the file is taken first
//   - the write is temp-file-plus-rename, so a crash cannot leave a half file
//   - the client sends the mtime it read; a newer mtime on disk rejects the write,
//     so a concurrent session or dispatch run cannot be clobbered
// Each answer is also appended to TRIAGE-<date>.md as a flat record of the session.

import { createServer } from "node:http";
import { readFile, writeFile, copyFile, appendFile, rename, stat, readdir } from "node:fs/promises";
import { execFile } from "node:child_process";
import { randomBytes, timingSafeEqual } from "node:crypto";
import { homedir } from "node:os";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const run = promisify(execFile);
const PORT = Number(process.env.PORT || 4317);
const REPO_ROOT = join(dirname(fileURLToPath(import.meta.url)), "..", "..");

const QUEUE_DIR = process.env.QUEUE_DIR || join(homedir(), ".claude-harness", "queue");

const FILES = [
  { file: "QUEUE-PC.md", gate: "At the PC", hint: "shell, git, builds" },
  { file: "QUEUE-PHONE.md", gate: "On your phone", hint: "browser, GitHub app" },
];

// The study checklist is read-and-write like the queues, but it is not a queue: nothing in
// it is blocked on a decision and ticking a box is not an answer, so it never reaches the
// decision cards or TRIAGE. It lives here because this is the page already open on the
// phone, which is where the studying actually happens.
const STUDY_FILE = "STUDY.md";
const JOBS_FILE = "JOBS.md";
const JOB_STATUSES = ["new", "interested", "applied", "pass"];

const today = () => new Date().toISOString().slice(0, 10);

async function renameWithRetry(source, target) {
  const attempts = process.platform === "win32" ? 6 : 1;
  for (let attempt = 0; attempt < attempts; attempt++) {
    try {
      await rename(source, target);
      return;
    } catch (err) {
      if (!(["EACCES", "EBUSY", "EPERM"].includes(err.code)) || attempt === attempts - 1) {
        throw err;
      }
      await new Promise((resolve) => setTimeout(resolve, 25 * (attempt + 1)));
    }
  }
}

// ---------------------------------------------------------------- auth
//
// Every request needs the token, including loopback ones. That is deliberate: under
// `tailscale serve` the phone's requests arrive FROM 127.0.0.1, so exempting loopback
// would exempt the phone too, and distinguishing them would mean trusting a header the
// server cannot verify. One unlock per browser, remembered for a year, is the cheaper
// side of that trade.

const TOKEN_FILE = join(QUEUE_DIR, ".dashboard-token");

async function loadToken() {
  if (process.env.QUEUE_TOKEN) return process.env.QUEUE_TOKEN.trim();
  try {
    const t = (await readFile(TOKEN_FILE, "utf8")).trim();
    if (t) return t;
  } catch {
    /* first run */
  }
  const t = randomBytes(24).toString("base64url");
  await writeFile(TOKEN_FILE, t + "\n", { encoding: "utf8", mode: 0o600 });
  return t;
}

let TOKEN = "";

function sameToken(given) {
  if (typeof given !== "string") return false;
  const a = Buffer.from(given);
  const b = Buffer.from(TOKEN);
  // Compare lengths separately; timingSafeEqual throws on a length mismatch.
  return a.length === b.length && timingSafeEqual(a, b);
}

function cookieToken(req) {
  const raw = req.headers.cookie || "";
  for (const part of raw.split(";")) {
    const [k, ...v] = part.trim().split("=");
    if (k === "qd") return decodeURIComponent(v.join("="));
  }
  return null;
}

const authed = (req) => sameToken(cookieToken(req));

const UNLOCK_PAGE = /* html */ `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Queue - unlock</title>
<style>
:root{--ground:#F7F8FA;--surface:#fff;--ink:#171A1F;--ink-3:#767E8B;--rule:#DEE2E9;--blocked:#B24632}
@media(prefers-color-scheme:dark){:root{--ground:#0E1116;--surface:#161A21;--ink:#E8EBF0;
--ink-3:#79818E;--rule:#272D38;--blocked:#E4795F}}
*{box-sizing:border-box}
body{background:var(--ground);color:var(--ink);margin:0;min-height:100vh;display:flex;
align-items:center;justify-content:center;padding:1.5rem;
font-family:ui-sans-serif,system-ui,"Segoe UI",sans-serif}
form{background:var(--surface);border:1px solid var(--rule);border-radius:4px;padding:1.5rem;
width:100%;max-width:24rem;display:flex;flex-direction:column;gap:.8rem}
h1{margin:0;font-size:1.2rem;letter-spacing:-.02em}
p{margin:0;font-size:.85rem;color:var(--ink-3);line-height:1.5}
input{font:inherit;padding:.6rem;border:1px solid var(--rule);border-radius:2px;
background:var(--ground);color:var(--ink);width:100%}
button{font:inherit;font-weight:600;padding:.6rem;border:none;border-radius:2px;
background:var(--ink);color:var(--ground);cursor:pointer}
.bad{color:var(--blocked);font-size:.85rem}
</style></head><body>
<form method="POST" action="/unlock">
  <h1>Queue dashboard</h1>
  <p>Paste the token from <code>.dashboard-token</code> in your queue directory. This
  browser stays unlocked for a year.</p>
  <input type="password" name="token" autocomplete="current-password" autofocus
         placeholder="token" required>
  <button type="submit">Unlock</button>
  __ERR__
</form></body></html>`;

// ---------------------------------------------------------------- parsing

// Split on the `## ` item delimiter, keeping each block's offset so a write-back can
// target the exact item without re-parsing or reflowing anything around it.
function splitBlocks(text) {
  const out = [];
  const re = /^## (.+)$/gm;
  let m;
  const heads = [];
  while ((m = re.exec(text))) heads.push({ title: m[1].trim(), at: m.index, bodyAt: re.lastIndex });
  for (let i = 0; i < heads.length; i++) {
    const end = i + 1 < heads.length ? heads[i + 1].at : text.length;
    out.push({ ...heads[i], end, body: text.slice(heads[i].bodyAt, end) });
  }
  return out;
}

// The freshest context lives in the trailing log lines; continuation lines are indented.
function logEntries(body) {
  const tail = body.split(/^Log:\s*$/m)[1];
  if (!tail) return [];
  const entries = [];
  for (const line of tail.split(/\r?\n/)) {
    if (/^-\s/.test(line)) entries.push(line.replace(/^-\s*/, "").trim());
    else if (/^\s+\S/.test(line) && entries.length) entries[entries.length - 1] += " " + line.trim();
  }
  return entries;
}

function parseItem(block) {
  const { title, body } = block;
  const status = (body.match(/^Status:\s*(.+)$/m)?.[1] || "unknown").trim();
  const repo = (body.match(/^Repo:\s*(.+)$/m)?.[1] || "").trim();
  const dependsOn = [...body.matchAll(/^Depends on:\s*(.+)$/gm)]
    .map((match) => match[1].trim())
    .filter(Boolean);

  // A DECIDED block runs from its marker to the next top-level field.
  const decided = body.match(/^(DECIDED\b[^\n]*(?:\n(?![A-Z][a-z]+ ?[a-z]*:|\s*$)[^\n]*)*)/m)?.[1];

  // "Blocked reason:" and "Blocked reason (RESOLVED ...):" are both used in the queues.
  const blockedRaw = body.match(
    /^Blocked reason\b[^\n:]*:\s*((?:.|\n(?![A-Z][a-z]+ ?[a-z]*:))*)/m
  )?.[1];
  const blockedReason = blockedRaw && !/RESOLVED/i.test(blockedRaw.slice(0, 80)) ? blockedRaw.trim() : null;

  // An item may declare its own answer options, so a decision offers real choices
  // ("Branch, commit, push, PR") instead of a generic Approve/Reject that means nothing
  // for the question actually being asked. Absent, the client falls back to presets.
  const optBlock = body.match(/^Options:\s*$\n((?:[ \t]*-[^\n]*\n?)+)/m)?.[1];
  const options = optBlock
    ? optBlock.split(/\r?\n/).filter((l) => /^\s*-\s/.test(l)).map((l) => l.replace(/^\s*-\s*/, "").trim())
    : [];

  const log = logEntries(body);
  // The live blockers are written as log lines, not as a field. Miss these and the
  // dashboard shows cards but none of the actual decisions.
  const asks = log.filter((l) => /DECISION NEEDED|BLOCKED ON (YOU|FARUK)|NEEDS? (YOUR )?(DECISION|ANSWER)/i.test(l));
  const answered = Boolean(decided) || log.some((l) => /^ANSWERED\b/i.test(l));

  const needsDecision = !answered && status !== "done" && (asks.length > 0 || Boolean(blockedReason));

  return {
    title,
    status,
    repo,
    dependsOn,
    decided: decided ? decided.trim() : null,
    answered,
    blockedReason,
    asks,
    options,
    needsDecision,
    impact: { direct: 0, unblocks: 0 },
    log: log.slice(-3),
  };
}

function itemKey(entry) {
  return `${entry.file}\u0000${entry.item.title}`;
}

function normalizedTitle(title) {
  return String(title).trim().toLocaleLowerCase();
}

function compareEntries(a, b) {
  return b.item.impact.unblocks - a.item.impact.unblocks
    || b.item.impact.direct - a.item.impact.direct
    || a.index - b.index;
}

// Queue files stay hand-authored and preserve their source order. The dashboard derives
// a live order from declared dependencies so the same answer can surface the work it
// enables without rewriting or racing the queue files.
function applyImpactOrdering(groups) {
  let index = 0;
  const entries = groups.flatMap((group) => group.items.map((item) => ({
    file: group.file,
    item,
    index: index++,
  })));
  const active = entries.filter(({ item }) => !item.answered && item.status !== "done");
  const targets = new Map();
  for (const entry of active) {
    const title = normalizedTitle(entry.item.title);
    const list = targets.get(title) || [];
    list.push(entry);
    targets.set(title, list);
  }

  const dependents = new Map(active.map((entry) => [itemKey(entry), []]));
  for (const entry of active) {
    for (const dependency of entry.item.dependsOn) {
      const matches = targets.get(normalizedTitle(dependency)) || [];
      if (matches.length !== 1 || matches[0] === entry) continue;
      dependents.get(itemKey(matches[0])).push(entry);
    }
  }

  function descendantsOf(entry) {
    const descendants = new Set();
    const pending = [...(dependents.get(itemKey(entry)) || [])];
    while (pending.length) {
      const child = pending.pop();
      const key = itemKey(child);
      if (descendants.has(key)) continue;
      descendants.add(key);
      pending.push(...(dependents.get(key) || []));
    }
    return descendants;
  }

  for (const entry of active) {
    const direct = dependents.get(itemKey(entry)) || [];
    entry.item.impact = { direct: direct.length, unblocks: descendantsOf(entry).size };
  }

  for (const group of groups) {
    group.items = entries
      .filter((entry) => entry.file === group.file)
      .sort(compareEntries)
      .map((entry) => entry.item);
  }
  return groups;
}

// A GFM task line, at any indent. The index is assigned in file order across the whole
// file rather than per section, so a tick identifies its line without the client needing
// to know anything about the section structure.
const TASK_RE = /^(\s*)- \[([ xX])\]\s?(.*)$/;

function parseStudy(text) {
  const sections = [];
  let current = null;
  let index = 0;
  for (const line of text.split(/\r?\n/)) {
    const head = line.match(/^## (.+)$/);
    if (head) {
      current = { title: head[1].trim(), tasks: [] };
      sections.push(current);
      continue;
    }
    const t = line.match(TASK_RE);
    if (!t) continue;
    // A task before any heading still counts; give it a home rather than dropping it.
    if (!current) sections.push((current = { title: "Unsorted", tasks: [] }));
    current.tasks.push({ index: index++, done: t[2] !== " ", text: t[3].trim() });
  }
  const tasks = sections.flatMap((s) => s.tasks);
  return { sections, total: tasks.length, done: tasks.filter((t) => t.done).length };
}

async function studySnapshot() {
  const path = join(QUEUE_DIR, STUDY_FILE);
  try {
    const [text, st] = await Promise.all([readFile(path, "utf8"), stat(path)]);
    return { file: STUDY_FILE, ...parseStudy(text), mtime: st.mtimeMs, error: null };
  } catch (err) {
    return { file: STUDY_FILE, sections: [], total: 0, done: 0, mtime: 0, error: err.message };
  }
}

function fieldValue(body, name) {
  return (body.match(new RegExp(`^${name}:\\s*(.*)$`, "m"))?.[1] || "").trim();
}

function numericValue(value) {
  const match = String(value).match(/\d+(?:\.\d+)?/);
  return match ? Number(match[0]) : 0;
}

function salaryValue(value) {
  const values = String(value)
    .match(/\d[\d,]*(?:\.\d+)?\s*[kK]?/g)
    ?.map((raw) => {
      const amount = Number(raw.replace(/[,\s]/g, "").replace(/[kK]$/, ""));
      return /[kK]$/i.test(raw) ? amount * 1000 : amount;
    }) || [];
  return values.length ? Math.max(...values) : 0;
}

function parseJobs(text) {
  const sections = [];
  const sectionRe = /^## (Tier .+|Contract - secondary priority)$/gm;
  const sectionHeads = [];
  let match;
  while ((match = sectionRe.exec(text))) {
    sectionHeads.push({ title: match[1].trim(), at: match.index, bodyAt: sectionRe.lastIndex });
  }

  for (let i = 0; i < sectionHeads.length; i++) {
    const section = sectionHeads[i];
    const end = i + 1 < sectionHeads.length ? sectionHeads[i + 1].at : text.length;
    const body = text.slice(section.bodyAt, end);
    const jobRe = /^### (.+)$/gm;
    const jobHeads = [];
    let jobMatch;
    while ((jobMatch = jobRe.exec(body))) {
      jobHeads.push({ title: jobMatch[1].trim(), at: jobMatch.index, bodyAt: jobRe.lastIndex });
    }

    const jobs = jobHeads.map((job, jobIndex) => {
      const jobEnd = jobIndex + 1 < jobHeads.length ? jobHeads[jobIndex + 1].at : body.length;
      const jobBody = body.slice(job.bodyAt, jobEnd);
      const rawStatus = fieldValue(jobBody, "Status").toLowerCase();
      const status = JOB_STATUSES.find((candidate) => rawStatus.startsWith(candidate)) || "new";
      const fit = fieldValue(jobBody, "Fit");
      const culture = fieldValue(jobBody, "Culture");
      const salary = fieldValue(jobBody, "Salary");
      return {
        title: job.title,
        tier: section.title,
        company: fieldValue(jobBody, "Company"),
        location: fieldValue(jobBody, "Location"),
        salary,
        salaryValue: salaryValue(salary),
        culture,
        cultureScore: numericValue(culture),
        fit,
        fitScore: numericValue(fieldValue(jobBody, "Fit score")) || numericValue(fit),
        posted: fieldValue(jobBody, "Posted"),
        url: fieldValue(jobBody, "URL"),
        glassdoorUrl: fieldValue(jobBody, "Glassdoor"),
        status,
      };
    });

    // Tier remains the primary recommendation. Within a tier, the requested order is
    // salary, Glassdoor culture, then estimated likelihood of success.
    jobs.sort((a, b) =>
      b.salaryValue - a.salaryValue ||
      b.cultureScore - a.cultureScore ||
      b.fitScore - a.fitScore ||
      a.title.localeCompare(b.title)
    );
    sections.push({ title: section.title, jobs });
  }

  const tierOrder = { S: 0, A: 1, B: 2, C: 3 };
  sections.sort((a, b) => {
    const aTier = a.title.match(/^Tier ([SABC])\b/i)?.[1]?.toUpperCase();
    const bTier = b.title.match(/^Tier ([SABC])\b/i)?.[1]?.toUpperCase();
    const aOrder = /^Contract - secondary priority$/i.test(a.title) ? 4 : (tierOrder[aTier] ?? 99);
    const bOrder = /^Contract - secondary priority$/i.test(b.title) ? 4 : (tierOrder[bTier] ?? 99);
    return aOrder - bOrder
      || a.title.localeCompare(b.title);
  });

  return {
    sections,
    total: sections.reduce((sum, section) => sum + section.jobs.length, 0),
  };
}

async function jobsSnapshot() {
  const path = join(QUEUE_DIR, JOBS_FILE);
  try {
    const [text, st] = await Promise.all([readFile(path, "utf8"), stat(path)]);
    return { file: JOBS_FILE, ...parseJobs(text), mtime: st.mtimeMs, error: null };
  } catch (err) {
    return { file: JOBS_FILE, sections: [], total: 0, mtime: 0, error: err.message };
  }
}

// gh is slow enough that hammering it on every poll is rude; 60s is well inside
// "live" for PR state while keeping the queue read itself uncached.
let prCache = { at: 0, data: [] };

async function openPrs() {
  if (Date.now() - prCache.at < 60_000) return prCache.data;
  const repos = [
    "Portfolio-Website",
    "agent-agnostic-harness",
    "tewaza-market",
    "mottainai-market",
    "hoshi-candle-co",
    "unattended-runs",
    "petal-and-polish",
    "kaidan-travel",
  ];
  const out = [];
  await Promise.all(
    repos.map(async (r) => {
      try {
        const { stdout } = await run(
          "gh",
          ["pr", "list", "--repo", `Freddy-S3/${r}`, "--state", "open", "--json", "number,title,url"],
          { timeout: 15_000, windowsHide: true }
        );
        for (const pr of JSON.parse(stdout || "[]")) {
          out.push({ repo: r, number: pr.number, title: pr.title, url: pr.url });
        }
      } catch {
        /* repo missing, gh unauthenticated, or timeout - just omit it */
      }
    })
  );
  out.sort((a, b) => a.repo.localeCompare(b.repo) || a.number - b.number);
  prCache = { at: Date.now(), data: out };
  return out;
}

async function snapshot() {
  const groups = [];
  for (const { file, gate, hint } of FILES) {
    const path = join(QUEUE_DIR, file);
    try {
      const [text, st] = await Promise.all([readFile(path, "utf8"), stat(path)]);
      const items = splitBlocks(text).map(parseItem);
      groups.push({ gate, hint, file, items, mtime: st.mtimeMs, error: null });
    } catch (err) {
      groups.push({ gate, hint, file, items: [], mtime: 0, error: err.message });
    }
  }

  applyImpactOrdering(groups);

  let triage = [];
  try {
    triage = (await readdir(QUEUE_DIR)).filter((f) => /^TRIAGE-.*\.md$/.test(f)).sort();
  } catch {
    /* nothing to add */
  }

  return {
    groups,
    study: await studySnapshot(),
    jobs: await jobsSnapshot(),
    prs: await openPrs(),
    triage,
    readAt: Date.now(),
    queueDir: QUEUE_DIR,
  };
}

// ---------------------------------------------------------------- write-back

// Insert an answer into the item's own Log section, after the last existing entry and
// its indented continuation lines. Falls back to creating a Log section.
function insertLogLine(body, line) {
  const lines = body.split("\n");
  // Scan only from the Log: marker. An item that declares Options: also has bullet lines,
  // and appending an ANSWERED entry into the option list would turn it into a choice.
  const logAt = lines.findIndex((l) => /^Log:\s*$/.test(l));
  let last = -1;
  for (let i = logAt === -1 ? 0 : logAt + 1; i < lines.length; i++) {
    if (/^-\s/.test(lines[i])) last = i;
    else if (/^\s+\S/.test(lines[i]) && last === i - 1) last = i;
  }
  if (logAt === -1) last = -1;
  if (last === -1) {
    // No log yet. Insert before any trailing `---` separator.
    const sep = lines.findIndex((l, i) => i > 0 && l.trim() === "---");
    const at = sep === -1 ? lines.length : sep;
    lines.splice(at, 0, "Log:", `- ${line}`, "");
    return lines.join("\n");
  }
  lines.splice(last + 1, 0, `- ${line}`);
  return lines.join("\n");
}

function applyAnswer(text, title, answer) {
  const block = splitBlocks(text).find((b) => b.title === title);
  if (!block) return null;

  const stamp = today();
  let body = block.body;

  // Flatten to one line. A multi-line answer would run past the DECIDED field and, if a
  // line happened to start "Word: ", would parse as a new item field.
  const flat = String(answer).replace(/\s+/g, " ").trim();

  // The DECIDED marker goes on the item itself, directly under Status, because that is
  // the first thing an agent run reads. The log line is the audit trail.
  // Function replacer, not a string: `$&` or `$1` inside an answer would otherwise be
  // expanded by replace() and corrupt the file.
  const decidedLine = `DECIDED ${stamp} by Faruk, via the queue dashboard: ${flat}`;
  const existing = body.match(/^DECIDED\b[^\n]*(?:\n(?![A-Z][a-z]+ ?[a-z]*:|\s*$)[^\n]*)*/m);
  if (existing) {
    // Changing your mind replaces the decision rather than stacking a second DECIDED
    // block. The superseded text is not lost: the log below keeps every answer in order.
    body = body.replace(existing[0], decidedLine);
  } else {
    body = body.replace(/^Status:.*$/m, (m) => `${m}\n${decidedLine}`);
  }
  body = insertLogLine(body, `${stamp}: ANSWERED by Faruk via the queue dashboard: ${flat}`);

  return text.slice(0, block.bodyAt) + body + text.slice(block.end);
}

async function writeAnswer({ file, title, answer, mtime }) {
  const path = join(QUEUE_DIR, file);
  const st = await stat(path);
  // Someone else wrote since the page read. Refuse rather than overwrite their work.
  if (mtime && st.mtimeMs > Number(mtime) + 1) {
    const e = new Error("queue file changed on disk since this page loaded - reload and retry");
    e.code = 409;
    throw e;
  }

  const text = await readFile(path, "utf8");
  const next = applyAnswer(text, title, answer);
  if (next === null) {
    const e = new Error(`no queue item titled "${title}" in ${file}`);
    e.code = 404;
    throw e;
  }

  await copyFile(path, path + ".bak");
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, next, "utf8");
  await renameWithRetry(tmp, path);

  await appendTriage(title, answer);
  return true;
}

// Ticking a box rewrites exactly one character on one line. The index locates the line and
// the text the client saw confirms it: if the file was reordered or edited between the read
// and the tick, the texts disagree and the write is refused rather than ticking whatever
// item happens to sit at that index now.
function applyTick(text, index, done, expected) {
  const nl = text.includes("\r\n") ? "\r\n" : "\n";
  const lines = text.split(/\r?\n/);
  let n = 0;
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(TASK_RE);
    if (!m) continue;
    if (n++ !== index) continue;
    if (typeof expected === "string" && m[3].trim() !== expected.trim()) return { mismatch: true };
    lines[i] = `${m[1]}- [${done ? "x" : " "}] ${m[3]}`;
    return { text: lines.join(nl) };
  }
  return { missing: true };
}

async function writeTick({ index, done, text: expected, mtime }) {
  const path = join(QUEUE_DIR, STUDY_FILE);
  const st = await stat(path);
  if (mtime && st.mtimeMs > Number(mtime) + 1) {
    const e = new Error("STUDY.md changed on disk since this page loaded - reload and retry");
    e.code = 409;
    throw e;
  }

  const current = await readFile(path, "utf8");
  const out = applyTick(current, index, done, expected);
  if (out.missing) {
    const e = new Error(`no task at index ${index} in ${STUDY_FILE}`);
    e.code = 404;
    throw e;
  }
  if (out.mismatch) {
    const e = new Error("that task moved in the file - reload and retry");
    e.code = 409;
    throw e;
  }

  await copyFile(path, path + ".bak");
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, out.text, "utf8");
  await renameWithRetry(tmp, path);
  return true;
}

function applyJobStatus(text, title, status) {
  const nl = text.includes("\r\n") ? "\r\n" : "\n";
  const lines = text.split(/\r?\n/);
  const headingAt = lines.findIndex((line) => line === "### " + title);
  if (headingAt === -1) return null;

  let end = lines.length;
  for (let i = headingAt + 1; i < lines.length; i++) {
    if (/^### /.test(lines[i]) || /^## /.test(lines[i])) {
      end = i;
      break;
    }
  }
  const block = lines.slice(headingAt, end);
  const statusAt = block.findIndex((line) => /^Status:\s*/.test(line));
  if (statusAt === -1) block.push("Status: " + status);
  else block[statusAt] = "Status: " + status;
  lines.splice(headingAt, end - headingAt, ...block);
  return lines.join(nl);
}

async function writeJobStatus({ title, status, mtime }) {
  if (!JOB_STATUSES.includes(status)) {
    const e = new Error(`status must be one of: ${JOB_STATUSES.join(", ")}`);
    e.code = 400;
    throw e;
  }

  const path = join(QUEUE_DIR, JOBS_FILE);
  const st = await stat(path);
  if (mtime && st.mtimeMs > Number(mtime) + 1) {
    const e = new Error(`${JOBS_FILE} changed on disk since this page loaded - reload and retry`);
    e.code = 409;
    throw e;
  }

  const current = await readFile(path, "utf8");
  const next = applyJobStatus(current, title, status);
  if (next === null) {
    const e = new Error(`no job titled "${title}" in ${JOBS_FILE}`);
    e.code = 404;
    throw e;
  }

  await copyFile(path, path + ".bak");
  const tmp = `${path}.tmp-${process.pid}`;
  await writeFile(tmp, next, "utf8");
  await renameWithRetry(tmp, path);
  return true;
}

// Flat per-day record, matching the TRIAGE-<date>.md format the queue already uses.
// A TRIAGE file for today may already exist and may have prose after its table, so the
// dashboard always writes into its own trailing section rather than the file's table.
const TRIAGE_SECTION = "## Answers from the live dashboard";

async function appendTriage(title, answer) {
  const path = join(QUEUE_DIR, `TRIAGE-${today()}.md`);
  let head = "";
  let existing = "";
  try {
    existing = await readFile(path, "utf8");
  } catch {
    head =
      `# Queue triage - ${today()}\n\n` +
      "Faruk's answers from the live queue dashboard (tools/queue-dashboard).\n" +
      "Each answer is also written into the item it belongs to.\n\n" +
      "**Nothing here has been executed.** These are recorded decisions, not completed work.\n\n";
  }
  if (!existing.includes(TRIAGE_SECTION)) {
    head += `\n${TRIAGE_SECTION}\n\n| Item | Answer |\n|---|---|\n`;
  }
  const cell = (s) => String(s).replace(/\|/g, "\\|").replace(/\n/g, " ");
  await appendFile(path, `${head}| ${cell(title)} | ${cell(answer)} |\n`, "utf8");
}

// ---------------------------------------------------------------- server

const PAGE = /* html */ `<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Queue - live</title>
<style>
:root{--ground:#F7F8FA;--surface:#fff;--surface-2:#EFF1F5;--ink:#171A1F;--ink-2:#4A515C;
--ink-3:#767E8B;--rule:#DEE2E9;--accent:#8A6220;--blocked:#B24632;--waiting:#9A6C15;--clear:#256B5E}
@media(prefers-color-scheme:dark){:root{--ground:#0E1116;--surface:#161A21;--surface-2:#1D222B;
--ink:#E8EBF0;--ink-2:#A8B0BC;--ink-3:#79818E;--rule:#272D38;--accent:#D3A257;
--blocked:#E4795F;--waiting:#DCA845;--clear:#57B29D}}
*{box-sizing:border-box}
body{background:var(--ground);color:var(--ink);margin:0;padding:2rem 1.25rem 4rem;
font-family:ui-sans-serif,system-ui,"Segoe UI",sans-serif;line-height:1.5}
.wrap{max-width:1180px;margin:0 auto;display:flex;flex-direction:column;gap:1.5rem}
header{border-bottom:2px solid var(--ink);padding-bottom:.9rem}
h1{margin:0;font-size:1.9rem;letter-spacing:-.022em}
.stamp{font-family:ui-monospace,Consolas,monospace;font-size:.74rem;color:var(--ink-3);
display:flex;gap:1rem;flex-wrap:wrap;margin-top:.4rem}
.live{color:var(--clear);font-weight:700}
.tabs{display:flex;gap:.35rem;overflow-x:auto;border-bottom:1px solid var(--rule);padding-bottom:.35rem}
.tab{display:inline-flex;align-items:center;gap:.45rem;white-space:nowrap;border:1px solid transparent;
background:transparent;color:var(--ink-2);padding:.5rem .7rem;border-radius:3px 3px 0 0;font-weight:600}
.tab:hover{border-color:var(--rule);color:var(--ink)}
.tab[aria-selected="true"]{background:var(--surface);border-color:var(--rule);border-bottom-color:var(--surface);
color:var(--ink);margin-bottom:-.4rem}
.tab:focus-visible{outline:2px solid var(--accent);outline-offset:2px}
.tab .count{font-size:.66rem;padding:.08rem .35rem}
.panel[hidden]{display:none}
.panel-head{display:flex;align-items:baseline;gap:.7rem;flex-wrap:wrap}
.panel-note{margin:.2rem 0 0;color:var(--ink-3);font-size:.86rem}
h2.sec{font-family:ui-monospace,Consolas,monospace;font-size:.8rem;letter-spacing:.13em;
text-transform:uppercase;margin:0 0 .1rem;border-bottom:1px solid var(--rule);padding-bottom:.45rem}
.cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:1.5rem;align-items:start}
.col{display:flex;flex-direction:column;gap:.8rem}
.col-head{display:flex;gap:.6rem;align-items:baseline;border-bottom:1px solid var(--rule);padding-bottom:.45rem;flex-wrap:wrap}
.col-head h2{font-family:ui-monospace,Consolas,monospace;font-size:.8rem;letter-spacing:.13em;
text-transform:uppercase;margin:0}
.count{font-family:ui-monospace,Consolas,monospace;font-size:.74rem;background:var(--ink);
color:var(--ground);border-radius:2px;padding:.1rem .42rem}
.count.hot{background:var(--blocked);color:#fff}
.gate{color:var(--ink-3);font-size:.8rem}
.card{background:var(--surface);border:1px solid var(--rule);border-left:3px solid var(--ink-3);
border-radius:3px;padding:.85rem 1rem;display:flex;flex-direction:column;gap:.5rem}
.card.decide{border-left-color:var(--blocked);border-left-width:4px}
.card.pending{border-left-color:var(--waiting)}
.card h3{margin:0;font-size:.97rem;line-height:1.3;letter-spacing:-.01em}
.impact{font-size:.78rem;color:var(--clear);font-family:ui-monospace,Consolas,monospace}
.chip{align-self:flex-start;font-family:ui-monospace,Consolas,monospace;font-size:.65rem;
letter-spacing:.1em;text-transform:uppercase;padding:.15rem .45rem;border-radius:2px;
background:var(--surface-2);color:var(--ink-2)}
.chip.decide{color:#fff;background:var(--blocked)}.chip.pending{color:var(--waiting)}
.ask{font-size:.86rem;color:var(--ink);background:var(--surface-2);border-radius:2px;
padding:.5rem .6rem;white-space:pre-wrap;overflow-wrap:anywhere}
.decided{font-size:.84rem;color:var(--ink-2);background:var(--surface-2);border-radius:2px;
padding:.45rem .55rem;white-space:pre-wrap}
.decided b{color:var(--clear)}
.meta{font-size:.78rem;color:var(--ink-3);font-family:ui-monospace,Consolas,monospace}
.log{margin:0;padding-left:1rem;font-size:.82rem;color:var(--ink-2);display:flex;
flex-direction:column;gap:.2rem}
.answer{display:flex;flex-direction:column;gap:.45rem;border-top:1px dashed var(--rule);padding-top:.55rem}
.presets{display:flex;gap:.35rem;flex-wrap:wrap}
button{font:inherit;font-size:.78rem;padding:.28rem .6rem;border:1px solid var(--rule);
background:var(--surface-2);color:var(--ink);border-radius:2px;cursor:pointer}
button:hover{border-color:var(--ink-3)}
button.go{background:var(--ink);color:var(--ground);border-color:var(--ink);font-weight:600}
textarea{font:inherit;font-size:.86rem;padding:.45rem .55rem;border:1px solid var(--rule);
border-radius:2px;background:var(--surface);color:var(--ink);resize:vertical;min-height:3.2rem;width:100%}
.row{display:flex;gap:.5rem;align-items:center}
.said{font-size:.78rem;color:var(--clear)}
.said.bad{color:var(--blocked)}
.err{color:var(--blocked);font-size:.85rem}
.prs{background:var(--surface);border:1px solid var(--rule);border-left:3px solid var(--waiting);
border-radius:3px;padding:.85rem 1rem}
.prs ul{margin:.4rem 0 0;padding-left:1rem;font-size:.86rem;color:var(--ink-2)}
.prs a{color:inherit}
.history{display:flex;flex-direction:column;gap:1rem;margin-top:1rem}
.history-group{display:flex;flex-direction:column;gap:.8rem}
.history-group .col-head{margin-bottom:0}
.history-card{border-left-color:var(--clear);opacity:.8}
.history-card:hover{opacity:1}
code{font-family:ui-monospace,Consolas,monospace;font-size:.82em;background:var(--surface-2);
padding:.05rem .28rem;border-radius:2px}
details summary{cursor:pointer;font-family:ui-monospace,Consolas,monospace;font-size:.78rem;
letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3);margin-bottom:.8rem}
footer{color:var(--ink-3);font-size:.78rem;border-top:1px solid var(--rule);padding-top:.7rem}
.empty{color:var(--ink-3);font-size:.9rem}
body{padding-bottom:5rem}
.card[data-resolved="1"]{opacity:.58;border-left-color:var(--clear)}
.card[data-resolved="1"]:hover{opacity:1}
/* The standing decision is context, not the question. Two lines is enough to recognise
   it; the full text is in the queue file. The ask itself is never clamped. */
.decided{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;overflow:hidden;
max-height:3.2rem;margin-bottom:.15rem}
/* An open question is shown in full - that is the point of the page. Once answered, the
   question is history, so it clamps too and the card shrinks to a glance. */
.card[data-resolved="1"] .ask{display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;
overflow:hidden;max-height:3.2rem}
.lead{font-family:ui-monospace,Consolas,monospace;font-size:.66rem;letter-spacing:.1em;
text-transform:uppercase;color:var(--accent)}
.opts{display:flex;flex-wrap:wrap;gap:.4rem}
.opt{cursor:pointer;position:relative}
.opt input{position:absolute;opacity:0;width:0;height:0}
.opt span{display:inline-block;font-size:.82rem;padding:.3rem .6rem;border:1px solid var(--rule);
border-radius:2px;background:var(--surface-2);color:var(--ink-2);user-select:none}
.opt input:checked+span{background:var(--accent);border-color:var(--accent);color:var(--ground);font-weight:600}
.opt span:hover{border-color:var(--accent)}
.opt input:focus-visible+span{outline:2px solid var(--accent);outline-offset:2px}
.statusbar{position:fixed;left:0;right:0;bottom:0;z-index:20;background:var(--surface);
border-top:1px solid var(--rule);padding:.7rem 1.25rem;display:flex;align-items:center;
gap:1rem;flex-wrap:wrap}
.tally{font-family:ui-monospace,Consolas,monospace;font-size:.8rem;color:var(--ink-2);
font-variant-numeric:tabular-nums}
.tally b{color:var(--ink)}
.spacer{flex:1 1 auto}
/* Study checklist. Rows are large enough to hit with a thumb on a moving train, which is
   the only place this section is ever used. */
.study{background:var(--surface);border:1px solid var(--rule);border-left:3px solid var(--accent);
border-radius:3px;padding:.85rem 1rem;display:flex;flex-direction:column;gap:.9rem}
.study-head{display:flex;gap:.7rem;align-items:baseline;flex-wrap:wrap}
.study-head strong{font-size:.97rem}
.bar{flex:1 1 8rem;height:5px;background:var(--surface-2);border-radius:3px;overflow:hidden;min-width:6rem}
.bar i{display:block;height:100%;background:var(--accent)}
.track{display:flex;flex-direction:column;gap:.15rem}
.track h4{margin:.35rem 0 .2rem;font-family:ui-monospace,Consolas,monospace;font-size:.72rem;
letter-spacing:.1em;text-transform:uppercase;color:var(--ink-3);display:flex;gap:.5rem;flex-wrap:wrap}
.track h4 em{font-style:normal;color:var(--accent)}
.task{display:flex;gap:.6rem;align-items:flex-start;padding:.42rem .4rem;border-radius:2px;
cursor:pointer;font-size:.88rem;line-height:1.4}
.task:hover{background:var(--surface-2)}
.task input{margin:.2rem 0 0;width:1.05rem;height:1.05rem;flex:0 0 auto;accent-color:var(--accent);cursor:pointer}
.task.on{color:var(--ink-3);text-decoration:line-through;text-decoration-color:var(--rule)}
.study .empty{margin:0}
.jobs{display:flex;flex-direction:column;gap:1rem;margin-top:1rem}
.jobs-note{margin:0;color:var(--ink-3);font-size:.84rem}
.job-group{display:flex;flex-direction:column;gap:.7rem}
.job-group .col-head{margin-bottom:0}
.job-card{background:var(--surface);border:1px solid var(--rule);border-left:3px solid var(--accent);
border-radius:3px;padding:.85rem 1rem;display:flex;flex-direction:column;gap:.55rem}
.job-card.tier-s{border-left-color:var(--clear)}
.job-card.tier-a{border-left-color:var(--accent)}
.job-card.tier-b{border-left-color:var(--waiting)}
.job-card.tier-c{border-left-color:var(--ink-3);opacity:.7}
.job-card h3{margin:0;font-size:.98rem;line-height:1.3;letter-spacing:-.01em}
.job-company{font-weight:600;color:var(--ink-2)}
.job-meta{display:flex;gap:.7rem;flex-wrap:wrap}
.job-metrics{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:.45rem}
.job-metric{background:var(--surface-2);border-radius:2px;padding:.42rem .5rem;min-width:0}
.job-metric span{display:block;color:var(--ink-3);font-family:ui-monospace,Consolas,monospace;
font-size:.64rem;letter-spacing:.08em;text-transform:uppercase}
.job-metric strong{display:block;font-size:.82rem;line-height:1.25;overflow-wrap:anywhere}
.job-fit{font-size:.84rem;color:var(--ink-2);background:var(--surface-2);border-radius:2px;padding:.5rem .6rem}
.job-actions{display:flex;gap:.5rem;align-items:center;flex-wrap:wrap;border-top:1px dashed var(--rule);padding-top:.55rem}
.job-actions a{font-size:.78rem;padding:.28rem .6rem;border:1px solid var(--rule);border-radius:2px;
color:var(--ink);text-decoration:none;background:var(--surface-2)}
.job-actions a:hover{border-color:var(--ink-3)}
.job-actions select{font:inherit;font-size:.78rem;padding:.28rem .45rem;border:1px solid var(--rule);
border-radius:2px;background:var(--surface);color:var(--ink);min-width:8rem}
@media(max-width:560px){.job-metrics{grid-template-columns:1fr}.job-actions{align-items:stretch}.job-actions a,.job-actions select{flex:1 1 auto;text-align:center}}
</style></head><body>
<div class="wrap">
  <header>
    <h1>Queue &mdash; live</h1>
    <div class="stamp">
      <span class="live" id="pulse">READING FROM DISK</span>
      <span id="dir"></span>
      <span id="read"></span>
    </div>
  </header>

  <nav class="tabs" id="tabs" aria-label="Dashboard sections" role="tablist">
    <button class="tab" type="button" role="tab" id="tab-queue" aria-controls="panel-queue"
      aria-selected="true" data-panel="queue">Queue <span class="count" id="t-queue">0</span></button>
    <button class="tab" type="button" role="tab" id="tab-history" aria-controls="panel-history"
      aria-selected="false" data-panel="history">History <span class="count" id="t-history">0</span></button>
    <button class="tab" type="button" role="tab" id="tab-reading-list" aria-controls="panel-reading-list"
      aria-selected="false" data-panel="reading-list">Reading list <span class="count" id="t-reading">0</span></button>
    <button class="tab" type="button" role="tab" id="tab-jobs" aria-controls="panel-jobs"
      aria-selected="false" data-panel="jobs">Jobs <span class="count" id="t-jobs">0</span></button>
  </nav>

  <main>
    <section class="panel" id="panel-queue" role="tabpanel" aria-labelledby="tab-queue">
      <section>
        <h2 class="sec">Blocked on you <span class="count hot" id="dcount">0</span></h2>
        <p class="panel-note">Highest downstream impact first when items declare <code>Depends on:</code>.</p>
        <div class="col" id="decisions"></div>
      </section>

      <div class="cols" id="cols"></div>

      <div class="prs" id="prs"></div>
    </section>

    <section class="panel" id="panel-history" role="tabpanel" aria-labelledby="tab-history" hidden>
      <div class="panel-head">
        <h2 class="sec">Decision history</h2>
        <span class="gate" id="history-summary"></span>
      </div>
      <p class="panel-note">Answered and completed items stay here for reference. Nothing is deleted.</p>
      <div class="history" id="history"></div>
    </section>

    <section class="panel" id="panel-reading-list" role="tabpanel" aria-labelledby="tab-reading-list" hidden>
      <div class="panel-head">
        <h2 class="sec">Reading list</h2>
        <span class="gate">STUDY.md</span>
      </div>
      <p class="panel-note">Your study checklist, kept separate from queue decisions.</p>
      <section class="study" id="study"></section>
    </section>

    <section class="panel" id="panel-jobs" role="tabpanel" aria-labelledby="tab-jobs" hidden>
      <div class="panel-head">
        <h2 class="sec">Recommended jobs</h2>
        <span class="gate" id="jobs-summary"></span>
      </div>
      <p class="panel-note">Permanent tiers first. Contract roles follow in a secondary lane. Within each group: salary, Glassdoor culture, then estimated application likelihood.</p>
      <div class="jobs" id="jobs"></div>
    </section>
  </main>
  <footer id="foot"></footer>
</div>
<div class="statusbar">
  <span class="tally"><b id="t-archived">0</b> archived &middot;
    <b id="t-open">0</b> waiting on you</span>
  <span class="spacer"></span>
  <span class="said" id="bar-note"></span>
</div>
<script>
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const safeUrl = value => /^https?:\\/\\//i.test(String(value)) ? String(value) : '';

const panels = ['queue', 'history', 'reading-list', 'jobs'];

function selectPanel(name, updateHash = true){
  const active = panels.includes(name) ? name : 'queue';
  for (const button of document.querySelectorAll('[data-panel]')){
    const selected = button.dataset.panel === active;
    button.setAttribute('aria-selected', selected ? 'true' : 'false');
    button.tabIndex = selected ? 0 : -1;
  }
  for (const panel of document.querySelectorAll('.panel')){
    panel.hidden = panel.id !== 'panel-' + active;
  }
  if (updateHash && location.hash !== '#' + active) history.replaceState(null, '', '#' + active);
}

for (const button of document.querySelectorAll('[data-panel]')){
  button.addEventListener('click', () => selectPanel(button.dataset.panel));
}
selectPanel(location.hash.slice(1), false);
window.addEventListener('hashchange', () => selectPanel(location.hash.slice(1), false));

let paused = false;   // stop the 5s repaint from wiping what is being typed
let mtimes = {};
let jobsMtime = 0;

async function send(file, title, answer, note){
  if (!answer.trim()) return;
  note.className = 'said'; note.textContent = 'saving...';
  const r = await fetch('/api/answer', {
    method: 'POST', headers: {'content-type':'application/json'},
    body: JSON.stringify({file, title, answer: answer.trim(), mtime: mtimes[file]})
  });
  const body = await r.json().catch(() => ({}));
  if (!r.ok) { note.className = 'said bad'; note.textContent = body.error || ('failed: ' + r.status); return; }
  note.textContent = 'written to ' + file;
  paused = false;
  tick();
}

let studyMtime = 0;

// Optimistic: the box flips immediately because a checkbox that waits on a round trip feels
// broken on a phone. A refused write puts it straight back and says why.
async function tickTask(t, input, note){
  const want = input.checked;
  paused = true;
  note.textContent = '';
  try {
    const r = await fetch('/api/study', {
      method: 'POST', headers: {'content-type':'application/json'},
      body: JSON.stringify({index: t.index, done: want, text: t.text, mtime: studyMtime})
    });
    const body = await r.json().catch(() => ({}));
    if (!r.ok){
      input.checked = !want;
      note.className = 'said bad';
      note.textContent = body.error || ('failed: ' + r.status);
      return;
    }
  } catch {
    input.checked = !want;
    note.className = 'said bad';
    note.textContent = 'server unreachable';
    return;
  } finally {
    paused = false;
  }
  tick();
}

function renderStudy(s){
  const host = document.getElementById('study');
  host.innerHTML = '';
  if (s.error){
    host.innerHTML = '<div class="study-head"><strong>Reading list</strong></div>'
      + '<p class="empty">No ' + esc(s.file) + ' in the queue directory yet.</p>';
    return;
  }
  studyMtime = s.mtime;

  const head = document.createElement('div');
  head.className = 'study-head';
  const pct = s.total ? Math.round((s.done / s.total) * 100) : 0;
  head.innerHTML = '<strong>Reading list</strong>'
    + '<span class="meta">' + s.done + '/' + s.total + ' done &middot; ' + pct + '%</span>'
    + '<span class="bar"><i style="width:' + pct + '%"></i></span>';
  host.appendChild(head);

  const note = document.createElement('span');
  note.className = 'said';

  for (const sec of s.sections){
    const wrap = document.createElement('div');
    wrap.className = 'track';
    const done = sec.tasks.filter(t => t.done).length;
    const h = document.createElement('h4');
    h.innerHTML = esc(sec.title) + ' <em>' + done + '/' + sec.tasks.length + '</em>';
    wrap.appendChild(h);
    for (const t of sec.tasks){
      const lab = document.createElement('label');
      lab.className = 'task' + (t.done ? ' on' : '');
      const inp = document.createElement('input');
      inp.type = 'checkbox';
      inp.checked = t.done;
      inp.onchange = () => tickTask(t, inp, note);
      const sp = document.createElement('span');
      sp.textContent = t.text;
      lab.append(inp, sp);
      wrap.appendChild(lab);
    }
    host.appendChild(wrap);
  }
  host.appendChild(note);
}

async function saveJobStatus(job, status, select, note){
  const previous = job.status;
  select.disabled = true;
  note.className = 'said';
  note.textContent = 'saving...';
  try {
    const r = await fetch('/api/job-status', {
      method: 'POST', headers: {'content-type': 'application/json'},
      body: JSON.stringify({title: job.title, status, mtime: jobsMtime})
    });
    const body = await r.json().catch(() => ({}));
    if (!r.ok) throw new Error(body.error || ('failed: ' + r.status));
    job.status = status;
    note.textContent = 'written to JOBS.md';
    jobsMtime = 0;
    tick();
  } catch (err) {
    select.value = previous;
    note.className = 'said bad';
    note.textContent = err.message || 'could not save';
  } finally {
    select.disabled = false;
  }
}

function renderJobs(s){
  const host = document.getElementById('jobs');
  host.innerHTML = '';
  if (s.error){
    host.innerHTML = '<p class="empty">No ' + esc(s.file) + ' in the queue directory yet.</p>';
    document.getElementById('jobs-summary').textContent = 'unavailable';
    return;
  }
  jobsMtime = s.mtime;
  document.getElementById('jobs-summary').textContent = s.total
    + (s.total === 1 ? ' posting' : ' postings') + ' - sorted by salary, culture, fit';
  if (!s.total){
    host.innerHTML = '<p class="empty">No recommended jobs yet.</p>';
    return;
  }

  for (const section of s.sections){
    const group = document.createElement('section');
    group.className = 'job-group';
    const head = document.createElement('div');
    head.className = 'col-head';
    head.innerHTML = '<h2>' + esc(section.title) + '</h2><span class="count">' + section.jobs.length + '</span>';
    group.appendChild(head);

    for (const job of section.jobs){
      const tierClass = /^Tier S\b/i.test(section.title) ? 'tier-s'
        : /^Tier A\b/i.test(section.title) ? 'tier-a'
        : /^Tier B\b/i.test(section.title) ? 'tier-b' : 'tier-c';
      const card = document.createElement('article');
      card.className = 'job-card ' + tierClass;
      const cultureScore = job.cultureScore ? job.cultureScore.toFixed(1) + '/5' : 'not scored';
      const fitScore = job.fitScore ? Math.round(job.fitScore) + '/100' : 'not scored';
      const salary = job.salary || 'not posted';
      const applyUrl = safeUrl(job.url);
      const glassdoorUrl = safeUrl(job.glassdoorUrl);
      card.innerHTML = '<span class="chip">' + esc(job.status) + '</span>'
        + '<h3>' + esc(job.title) + '</h3>'
        + '<div class="job-company">' + esc(job.company || 'Company not listed') + '</div>'
        + '<div class="job-meta"><span class="meta">' + esc(job.location || 'Location not listed') + '</span>'
        + (job.posted ? '<span class="meta">posted ' + esc(job.posted) + '</span>' : '') + '</div>'
        + '<div class="job-metrics">'
        + '<div class="job-metric"><span>Salary</span><strong>' + esc(salary) + '</strong></div>'
        + '<div class="job-metric"><span>Glassdoor</span><strong>' + esc(cultureScore) + '</strong></div>'
        + '<div class="job-metric"><span>Fit likelihood</span><strong>' + esc(fitScore) + '</strong></div>'
        + '</div>'
        + (job.fit ? '<div class="job-fit">' + esc(job.fit) + '</div>' : '')
        + '<div class="job-actions">'
        + (applyUrl ? '<a href="' + esc(applyUrl) + '" target="_blank" rel="noreferrer">Open posting</a>' : '')
        + (glassdoorUrl ? '<a href="' + esc(glassdoorUrl) + '" target="_blank" rel="noreferrer">Glassdoor</a>' : '')
        + '<label class="meta">Status <select class="job-status"></select></label>'
        + '<span class="said job-note"></span>'
        + '</div>';
      const select = card.querySelector('.job-status');
      for (const status of ['new', 'interested', 'applied', 'pass']){
        const option = document.createElement('option');
        option.value = status;
        option.textContent = status;
        option.selected = status === job.status;
        select.appendChild(option);
      }
      select.onchange = () => saveJobStatus(job, select.value, select, card.querySelector('.job-note'));
      group.appendChild(card);
    }
    host.appendChild(group);
  }
}

// One card builder for both sections. An item that is not flagged as blocked is still
// something you may want to redirect, so every open item gets the same controls; only
// the emphasis differs.
// Everything an item needs to be answered is on the card, always visible. Nothing that
// you have to act on is ever behind a disclosure.
function card(g, i, history = false){
  const decide = i.needsDecision;
  const el = document.createElement('article');
  el.className = 'card ' + (history ? 'history-card ' : '')
    + (decide ? 'decide' : i.status === 'pending' ? 'pending' : '');
  el.dataset.resolved = i.decided ? '1' : '0';

  const chip = history && i.decided ? 'answered' : history ? 'completed' : decide ? 'blocked on you' : i.status;
  // Blocked reason first: it is the field the item convention governs, so it is the one
  // written to be read cold. asks[0] is a log line, and a log line is written for the
  // audit trail - when it won, any "DECISION NEEDED" note shadowed a well-written field
  // and put history on the card instead of the question. Still falls back to the log line
  // so an item with no Blocked reason renders its ask rather than going blank.
  const ask = i.blockedReason || i.asks[0] || '';
  const impact = i.impact?.unblocks || 0;
  const impactText = impact === 1 ? 'unblocks 1 open item' : 'unblocks ' + impact + ' open items';

  el.innerHTML = '<span class="chip ' + (decide ? 'decide' : i.status === 'pending' ? 'pending' : '') + '">'
      + esc(chip) + '</span>'
    + '<h3>' + esc(i.title) + '</h3>'
    + (impact ? '<div class="impact">' + impactText + '</div>' : '')
    + (ask ? '<div class="ask">' + esc(ask) + '</div>' : '')
    + (i.decided ? '<div class="decided"><b>' + esc(i.decided) + '</b></div>' : '')
    + '<div class="meta">' + esc(g.file) + (i.repo ? ' &middot; ' + esc(i.repo) : '') + '</div>';

  const box = document.createElement('div');
  box.className = 'answer';
  const note = document.createElement('span');
  note.className = 'said';

  const ta = document.createElement('textarea');
  ta.placeholder = i.decided
    ? 'Change the decision - replaces the DECIDED line, keeps the old one in the log'
    : 'Your answer - written into this item as a DECIDED line';
  ta.addEventListener('focus', () => { paused = true; });
  ta.addEventListener('blur', () => { if (!ta.value.trim()) paused = false; });

  const lead = document.createElement('span');
  lead.className = 'lead';
  lead.textContent = i.options.length ? 'your call' : 'your call - no options declared, answer in your own words';

  // Only the item's own Options: are offered. There is deliberately no generic fallback:
  // "Approved" is not an answer to "which resume rendition is the default", and a button
  // that looks like a decision but carries no meaning is worse than an empty box.
  const opts = document.createElement('div');
  opts.className = 'opts';
  for (const c of i.options){
    const lab = document.createElement('label');
    lab.className = 'opt';
    const inp = document.createElement('input');
    inp.type = 'radio';
    inp.name = 'o:' + g.file + ':' + i.title;
    const sp = document.createElement('span');
    sp.textContent = c;
    inp.onchange = () => send(g.file, i.title, ta.value.trim() ? c + '. ' + ta.value.trim() : c, note);
    lab.append(inp, sp);
    opts.appendChild(lab);
  }

  const go = document.createElement('button');
  go.className = 'go'; go.textContent = 'Send answer';
  go.onclick = () => send(g.file, i.title, ta.value, note);

  const row = document.createElement('div');
  row.className = 'row';
  row.append(go, note);
  box.append(lead, opts, ta, row);
  el.appendChild(box);
  return el;
}

async function tick(){
  if (paused) return;
  let d;
  try {
    const r = await fetch('/api/queue', {cache:'no-store'});
    // Cookie expired or the server restarted with a new token - go get unlocked.
    if (r.status === 401) { location.reload(); return; }
    d = await r.json();
  }
  catch { document.getElementById('pulse').textContent = 'SERVER UNREACHABLE'; return; }

  document.getElementById('pulse').textContent = 'LIVE - READ FROM DISK';
  document.getElementById('dir').textContent = d.queueDir;
  document.getElementById('read').textContent = 'read at ' + new Date(d.readAt).toLocaleTimeString();
  mtimes = Object.fromEntries(d.groups.map(g => [g.file, g.mtime]));

  const isHistory = i => i.answered || i.status === 'done';
  const current = d.groups.map(g => ({
    ...g,
    items: g.items.filter(i => !isHistory(i)),
  }));
  const historyItems = d.groups.flatMap(g => g.items
    .filter(isHistory)
    .map(i => [g, i]));
  const sortImpact = (a, b) => b.impact.unblocks - a.impact.unblocks
    || b.impact.direct - a.impact.direct;
  const decisions = current.flatMap(g => g.items.filter(i => i.needsDecision).map(i => [g, i]))
    .sort(([, a], [, b]) => sortImpact(a, b));
  document.getElementById('dcount').textContent = decisions.length;
  document.getElementById('t-queue').textContent = current.reduce((n, g) => n + g.items.length, 0);
  document.getElementById('t-history').textContent = historyItems.length;
  document.getElementById('t-archived').textContent = historyItems.length;
  const host = document.getElementById('decisions');
  host.innerHTML = '';
  if (!decisions.length) host.innerHTML = '<p class="empty">Nothing is flagged as waiting on you. Every open item below is still answerable.</p>';
  for (const [g, i] of decisions) host.appendChild(card(g, i));

  document.getElementById('t-open').textContent = decisions.length;

  const cols = document.getElementById('cols');
  cols.innerHTML = '';
  for (const g of current){
    const rest = g.items.filter(i => !i.needsDecision).sort(sortImpact);
    const sec = document.createElement('section');
    sec.className = 'col';
    const head = document.createElement('div');
    head.className = 'col-head';
    head.innerHTML = '<h2>' + esc(g.gate) + '</h2><span class="count">' + rest.length
      + '</span><span class="gate">' + esc(g.hint) + '</span>';
    sec.appendChild(head);
    if (g.error){
      const p = document.createElement('p');
      p.className = 'err';
      p.textContent = 'Cannot read ' + g.file + ': ' + g.error;
      sec.appendChild(p);
    }
    // Nothing here is waiting on you, so it collapses to one line each. Open a row and
    // it becomes the same answerable card, for changing your mind about a settled item.
    for (const i of rest) sec.appendChild(card(g, i));
    const foot = document.createElement('div');
    foot.className = 'meta';
    foot.textContent = g.file + ' last written ' + (g.mtime ? new Date(g.mtime).toLocaleString() : 'n/a');
    sec.appendChild(foot);
    cols.appendChild(sec);
  }

  const historyHost = document.getElementById('history');
  historyHost.innerHTML = '';
  document.getElementById('history-summary').textContent = historyItems.length
    + (historyItems.length === 1 ? ' item' : ' items') + ' kept for reference';
  if (!historyItems.length){
    historyHost.innerHTML = '<p class="empty">No answered or completed items yet.</p>';
  }
  for (const g of d.groups){
    const items = g.items.filter(isHistory);
    if (!items.length) continue;
    const group = document.createElement('section');
    group.className = 'history-group';
    const head = document.createElement('div');
    head.className = 'col-head';
    head.innerHTML = '<h2>' + esc(g.gate) + '</h2><span class="count">' + items.length
      + '</span><span class="gate">completed or answered</span>';
    group.appendChild(head);
    for (const i of items) group.appendChild(card(g, i, true));
    historyHost.appendChild(group);
  }

  renderStudy(d.study);
  document.getElementById('t-reading').textContent = d.study.error
    ? '0' : Math.max(0, d.study.total - d.study.done);

  renderJobs(d.jobs);
  document.getElementById('t-jobs').textContent = d.jobs.error ? '0' : d.jobs.total;

  document.getElementById('prs').innerHTML = '<strong>Open PRs</strong> <span class="meta">(gh, cached 60s)</span>'
    + (d.prs.length
       ? '<ul>' + d.prs.map(p => '<li><a href="' + esc(p.url) + '" target="_blank"><code>' + esc(p.repo) + ' #' + p.number + '</code> ' + esc(p.title) + '</a></li>').join('') + '</ul>'
       : '<ul><li>none, or gh is unavailable</li></ul>');

  document.getElementById('foot').textContent =
    'Re-reads the queue files every 5s; polling pauses while you are typing an answer. '
    + 'Answers write a DECIDED line into the item and a row into TRIAGE-' + new Date().toISOString().slice(0,10) + '.md. '
    + (d.triage.length ? 'Triage records: ' + d.triage.join(', ') : '');
}
tick(); setInterval(tick, 5000);
</script></body></html>`;

async function readBody(req) {
  let raw = "";
  for await (const chunk of req) raw += chunk;
  return raw;
}

const handler = async (req, res) => {
  try {
    if (req.method === "POST" && req.url === "/unlock") {
      const given = new URLSearchParams(await readBody(req)).get("token") || "";
      if (!sameToken(given.trim())) {
        res.writeHead(401, { "content-type": "text/html; charset=utf-8" });
        return res.end(UNLOCK_PAGE.replace("__ERR__", '<span class="bad">Wrong token.</span>'));
      }
      // Secure only when a proxy terminated TLS for us; a bare loopback visit is http.
      const secure = req.headers["x-forwarded-proto"] === "https" ? "; Secure" : "";
      res.writeHead(303, {
        location: "/",
        "set-cookie": `qd=${encodeURIComponent(TOKEN)}; Path=/; Max-Age=31536000; HttpOnly; SameSite=Strict${secure}`,
      });
      return res.end();
    }

    if (!authed(req)) {
      // An unauthenticated API call must not get the HTML page; it would parse as junk.
      if (req.url.startsWith("/api/")) {
        res.writeHead(401, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: "unlock required" }));
      }
      res.writeHead(401, { "content-type": "text/html; charset=utf-8" });
      return res.end(UNLOCK_PAGE.replace("__ERR__", ""));
    }

    if (req.url === "/" || req.url.startsWith("/?")) {
      res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
      return res.end(PAGE);
    }
    if (req.url.startsWith("/api/queue")) {
      const data = await snapshot();
      res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
      return res.end(JSON.stringify(data));
    }
    if (req.method === "POST" && req.url === "/api/answer") {
      const { file, title, answer, mtime } = JSON.parse((await readBody(req)) || "{}");
      if (!FILES.some((f) => f.file === file) || !title || !answer) {
        res.writeHead(400, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: "file, title and answer are required" }));
      }
      await writeAnswer({ file, title, answer, mtime });
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify({ ok: true }));
    }
    if (req.method === "POST" && req.url === "/api/study") {
      const { index, done, text, mtime } = JSON.parse((await readBody(req)) || "{}");
      if (!Number.isInteger(index) || index < 0 || typeof done !== "boolean") {
        res.writeHead(400, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: "index (int) and done (bool) are required" }));
      }
      await writeTick({ index, done, text, mtime });
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify({ ok: true }));
    }
    if (req.method === "POST" && req.url === "/api/job-status") {
      const { title, status, mtime } = JSON.parse((await readBody(req)) || "{}");
      if (!title || !status) {
        res.writeHead(400, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: "title and status are required" }));
      }
      await writeJobStatus({ title, status, mtime });
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify({ ok: true }));
    }
    res.writeHead(404).end("not found");
  } catch (err) {
    const code = err && err.code === 409 ? 409 : err && err.code === 404 ? 404 : 500;
    res.writeHead(code, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: String(err && err.message) }));
  }
};

// Two Claude Code sessions starting at once both find the port free and both spawn.
// The loser exiting quietly is the correct outcome, not an error worth logging loudly.
function onError(err) {
  if (err.code === "EADDRINUSE") {
    console.log(`port ${PORT} already serving a dashboard; nothing to do`);
    process.exit(0);
  }
  throw err;
}

function listenOn(host, label) {
  return new Promise((resolve) => {
    const s = createServer(handler);
    s.on("error", onError);
    s.listen(PORT, host, () => {
      console.log(`${label}: http://${host.includes(":") ? `[${host}]` : host}:${PORT}`);
      resolve(s);
    });
  });
}

// The tailnet address is a WireGuard-only interface: reachable from this user's signed-in
// devices and nothing else, with no router port opened and no public DNS name. Binding it
// directly is the alternative to `tailscale serve` when Serve is not enabled on a tailnet.
// Opt-in, because binding anything beyond loopback should never be a silent default.
async function tailnetAddress() {
  if (process.env.QUEUE_TAILSCALE !== "1") return null;
  const exe = process.env.TAILSCALE_EXE || "C:/Program Files/Tailscale/tailscale.exe";
  try {
    const { stdout } = await run(exe, ["ip", "-4"], { timeout: 10_000, windowsHide: true });
    const ip = stdout.trim().split(/\s+/)[0];
    // 100.64.0.0/10 is the CGNAT range Tailscale allocates from. Refuse anything else:
    // a surprise 0.0.0.0 or LAN address here would expose the queue to the local network.
    return /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./.test(ip) ? ip : null;
  } catch {
    return null;
  }
}

TOKEN = await loadToken();
await listenOn("127.0.0.1", "queue dashboard");

const tsIp = await tailnetAddress();
if (tsIp) await listenOn(tsIp, "tailnet");
else if (process.env.QUEUE_TAILSCALE === "1") console.log("tailnet bind requested but no tailscale IPv4 found");

console.log(`reading: ${QUEUE_DIR}`);
console.log(`repo root: ${REPO_ROOT}`);
console.log(`unlock token: ${TOKEN}`);
console.log(`token file: ${TOKEN_FILE}`);
