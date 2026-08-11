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

const today = () => new Date().toISOString().slice(0, 10);

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

  // A DECIDED block runs from its marker to the next top-level field.
  const decided = body.match(/^(DECIDED\b[^\n]*(?:\n(?![A-Z][a-z]+ ?[a-z]*:|\s*$)[^\n]*)*)/m)?.[1];

  // "Blocked reason:" and "Blocked reason (RESOLVED ...):" are both used in the queues.
  const blockedRaw = body.match(
    /^Blocked reason\b[^\n:]*:\s*((?:.|\n(?![A-Z][a-z]+ ?[a-z]*:))*)/m
  )?.[1];
  const blockedReason = blockedRaw && !/RESOLVED/i.test(blockedRaw.slice(0, 80)) ? blockedRaw.trim() : null;

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
    decided: decided ? decided.trim() : null,
    blockedReason,
    asks,
    needsDecision,
    log: log.slice(-3),
  };
}

// gh is slow enough that hammering it on every poll is rude; 60s is well inside
// "live" for PR state while keeping the queue read itself uncached.
let prCache = { at: 0, data: [] };

async function openPrs() {
  if (Date.now() - prCache.at < 60_000) return prCache.data;
  const repos = [
    "Portfolio-Website",
    "claude-harness-public",
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
      const items = splitBlocks(text).map(parseItem).filter((i) => i.status !== "done");
      groups.push({ gate, hint, file, items, mtime: st.mtimeMs, error: null });
    } catch (err) {
      groups.push({ gate, hint, file, items: [], mtime: 0, error: err.message });
    }
  }

  let triage = [];
  try {
    triage = (await readdir(QUEUE_DIR)).filter((f) => /^TRIAGE-.*\.md$/.test(f)).sort();
  } catch {
    /* nothing to add */
  }

  return { groups, prs: await openPrs(), triage, readAt: Date.now(), queueDir: QUEUE_DIR };
}

// ---------------------------------------------------------------- write-back

// Insert an answer into the item's own Log section, after the last existing entry and
// its indented continuation lines. Falls back to creating a Log section.
function insertLogLine(body, line) {
  const lines = body.split("\n");
  let last = -1;
  for (let i = 0; i < lines.length; i++) {
    if (/^-\s/.test(lines[i])) last = i;
    else if (/^\s+\S/.test(lines[i]) && last === i - 1) last = i;
  }
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
  body = body.replace(/^Status:.*$/m, (m) => `${m}\n${decidedLine}`);
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
  await rename(tmp, path);

  await appendTriage(title, answer);
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
.chip{align-self:flex-start;font-family:ui-monospace,Consolas,monospace;font-size:.65rem;
letter-spacing:.1em;text-transform:uppercase;padding:.15rem .45rem;border-radius:2px;
background:var(--surface-2);color:var(--ink-2)}
.chip.decide{color:#fff;background:var(--blocked)}.chip.pending{color:var(--waiting)}
.ask{font-size:.86rem;color:var(--ink);background:var(--surface-2);border-radius:2px;
padding:.5rem .6rem;white-space:pre-wrap}
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
code{font-family:ui-monospace,Consolas,monospace;font-size:.82em;background:var(--surface-2);
padding:.05rem .28rem;border-radius:2px}
details summary{cursor:pointer;font-family:ui-monospace,Consolas,monospace;font-size:.78rem;
letter-spacing:.08em;text-transform:uppercase;color:var(--ink-3);margin-bottom:.8rem}
footer{color:var(--ink-3);font-size:.78rem;border-top:1px solid var(--rule);padding-top:.7rem}
.empty{color:var(--ink-3);font-size:.9rem}
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

  <section>
    <h2 class="sec">Blocked on you <span class="count hot" id="dcount">0</span></h2>
    <div class="col" id="decisions"></div>
  </section>

  <details id="restwrap">
    <summary>Everything else in the queue</summary>
    <div class="cols" id="cols"></div>
  </details>

  <div class="prs" id="prs"></div>
  <footer id="foot"></footer>
</div>
<script>
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const PRESETS = ['Approved - go ahead', 'Rejected - do not do this', 'Defer - leave it queued', 'Ask me again with more detail'];

let paused = false;   // stop the 5s repaint from wiping what is being typed
let mtimes = {};

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

function decisionCard(g, i){
  const el = document.createElement('article');
  el.className = 'card decide';
  el.innerHTML = '<span class="chip decide">decide</span>'
    + '<h3>' + esc(i.title) + '</h3>'
    + (i.asks.length ? i.asks.map(a => '<div class="ask">' + esc(a) + '</div>').join('') : '')
    + (i.blockedReason ? '<div class="ask">' + esc(i.blockedReason) + '</div>' : '')
    + '<div class="meta">' + esc(g.file) + (i.repo ? ' &middot; ' + esc(i.repo) : '') + '</div>';

  const box = document.createElement('div');
  box.className = 'answer';
  const presets = document.createElement('div');
  presets.className = 'presets';
  const ta = document.createElement('textarea');
  ta.placeholder = 'Your answer - written into this item as a DECIDED line';
  // Pause polling while typing so a repaint cannot wipe the box - but a focused, empty
  // box left alone must not freeze the dashboard silently.
  ta.addEventListener('focus', () => { paused = true; });
  ta.addEventListener('blur', () => { if (!ta.value.trim()) paused = false; });
  const note = document.createElement('span');
  note.className = 'said';

  for (const p of PRESETS){
    const b = document.createElement('button');
    b.textContent = p.split(' - ')[0];
    b.title = p;
    b.onclick = () => send(g.file, i.title, ta.value.trim() ? p + '. ' + ta.value.trim() : p, note);
    presets.appendChild(b);
  }
  const go = document.createElement('button');
  go.className = 'go'; go.textContent = 'Send answer';
  go.onclick = () => send(g.file, i.title, ta.value, note);

  const row = document.createElement('div');
  row.className = 'row';
  row.append(go, note);
  box.append(presets, ta, row);
  el.appendChild(box);
  return el;
}

async function tick(){
  if (paused) return;
  let d;
  try { d = await (await fetch('/api/queue', {cache:'no-store'})).json(); }
  catch { document.getElementById('pulse').textContent = 'SERVER UNREACHABLE'; return; }

  document.getElementById('pulse').textContent = 'LIVE - READ FROM DISK';
  document.getElementById('dir').textContent = d.queueDir;
  document.getElementById('read').textContent = 'read at ' + new Date(d.readAt).toLocaleTimeString();
  mtimes = Object.fromEntries(d.groups.map(g => [g.file, g.mtime]));

  const decisions = d.groups.flatMap(g => g.items.filter(i => i.needsDecision).map(i => [g, i]));
  document.getElementById('dcount').textContent = decisions.length;
  const host = document.getElementById('decisions');
  host.innerHTML = '';
  if (!decisions.length) host.innerHTML = '<p class="empty">Nothing is waiting on you. Every open item has a DECIDED line.</p>';
  for (const [g, i] of decisions) host.appendChild(decisionCard(g, i));
  document.getElementById('restwrap').open = decisions.length === 0;

  document.getElementById('cols').innerHTML = d.groups.map(g => {
    const rest = g.items.filter(i => !i.needsDecision);
    return \`<section class="col">
      <div class="col-head"><h2>\${esc(g.gate)}</h2>
        <span class="count">\${rest.length}</span>
        <span class="gate">\${esc(g.hint)}</span></div>
      \${g.error ? '<p class="err">Cannot read ' + esc(g.file) + ': ' + esc(g.error) + '</p>' : ''}
      \${rest.map(i => \`
        <article class="card \${i.status === 'pending' ? 'pending' : ''}">
          <span class="chip \${i.status === 'pending' ? 'pending' : ''}">\${esc(i.status)}</span>
          <h3>\${esc(i.title)}</h3>
          \${i.decided ? '<div class="decided"><b>' + esc(i.decided) + '</b></div>' : ''}
          \${i.repo ? '<div class="meta">' + esc(i.repo) + '</div>' : ''}
          \${i.log.length ? '<ul class="log">' + i.log.map(l => '<li>' + esc(l) + '</li>').join('') + '</ul>' : ''}
        </article>\`).join('')}
      <div class="meta">\${esc(g.file)} last written \${g.mtime ? new Date(g.mtime).toLocaleString() : 'n/a'}</div>
    </section>\`;
  }).join('');

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

const server = createServer(async (req, res) => {
  try {
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
      let raw = "";
      for await (const chunk of req) raw += chunk;
      const { file, title, answer, mtime } = JSON.parse(raw || "{}");
      if (!FILES.some((f) => f.file === file) || !title || !answer) {
        res.writeHead(400, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: "file, title and answer are required" }));
      }
      await writeAnswer({ file, title, answer, mtime });
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify({ ok: true }));
    }
    res.writeHead(404).end("not found");
  } catch (err) {
    const code = err && err.code === 409 ? 409 : err && err.code === 404 ? 404 : 500;
    res.writeHead(code, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: String(err && err.message) }));
  }
});

// Loopback only. This reads private queue content; it must not be reachable off-box.
server.listen(PORT, "127.0.0.1", () => {
  console.log(`queue dashboard: http://127.0.0.1:${PORT}`);
  console.log(`reading: ${QUEUE_DIR}`);
  console.log(`repo root: ${REPO_ROOT}`);
});
