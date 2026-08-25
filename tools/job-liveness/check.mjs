#!/usr/bin/env node
// Liveness checker and content snapshotter for the job postings the dashboard renders.
//
// Postings live in $QUEUE_DIR/JOBS.md, outside every repo. This tool reads that file,
// decides for each posting whether it is still live, and writes the verdict back as
// Liveness fields the dashboard renders. It never deletes a posting: a role that
// disappeared is a fact Freddy wants to see, with the date it went.
//
// Two verdicts are deliberately distinct. "dead" means the site told us, positively,
// that the posting is gone. "unreachable" means our check failed - DNS, timeout, a 500,
// a missing renderer - and says nothing about the posting. Only the first is a takedown.
// Conflating them would drop a live job out of Freddy's pipeline on a flaky wifi night.

import { readFile, writeFile, stat, mkdir } from "node:fs/promises";
import { join } from "node:path";
import { homedir } from "node:os";
import { fileURLToPath, pathToFileURL } from "node:url";

const QUEUE_DIR = process.env.QUEUE_DIR || join(homedir(), ".claude-harness", "queue");
const JOBS_PATH = join(QUEUE_DIR, "JOBS.md");
const SNAPSHOT_DIR = process.env.JOB_SNAPSHOT_DIR || join(QUEUE_DIR, "job-snapshots");

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36";

// Politeness. These are Freddy's own bookmarks, checked at most twice a day, one at a
// time, with a gap between requests. Nothing here fans out or crawls.
const REQUEST_GAP_MS = Number(process.env.JOB_CHECK_GAP_MS || 3000);
const DEFAULT_MAX_AGE_HOURS = 12;
const NAV_TIMEOUT_MS = 30000;
const RETRY_GAP_MS = 5000;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const nowIso = () => new Date().toISOString();

// Signatures that only appear when a site is positively telling us the posting is gone.
// Deliberately narrow: "page not found" and a bare "404" are excluded because plenty of
// live pages carry those strings in nav chrome or inline scripts. HTTP 404/410 covers
// the genuinely-missing-page case without guessing from prose.
const DEAD_SIGNATURES = [
  "job not found",
  "this job may have been taken down",
  "no longer accepting applications",
  "this job is no longer available",
  "this position is no longer available",
  "this posting is no longer available",
  "job posting is no longer available",
  "this position has been filled",
  "this job has expired",
  "this posting has expired",
  "job posting has closed",
  "this role is no longer open",
  "the job you are looking for is no longer",
];

// A rendered page that comes back nearly empty tells us nothing - far more likely a bot
// wall or a renderer that gave up than a takedown.
const MIN_LIVE_BODY_CHARS = 400;

// Headless Chromium is fingerprinted by Google Careers: verified 2026-08-24, a headless
// render of a nonexistent requisition and of a real one both produced the same 3,270
// characters of page chrome with the job pane never painted, while the same navigation
// with a real browser window rendered "Job not found. This job may have been taken down".
// So the renderer runs headful by default. Set JOB_CHECK_HEADLESS=1 to override on a
// machine with no display, accepting that Google postings will come back undetermined.
const HEADLESS = process.env.JOB_CHECK_HEADLESS === "1";

// Words that carry no identifying weight when matching a posting title against a page.
const TITLE_STOPWORDS = new Set(["and", "the", "for", "with", "senior", "staff", "of", "in", "at", "a", "an"]);

function verdict(state, detail, extra = {}) {
  return { state, detail, ...extra };
}

// ---------------------------------------------------------------- JOBS.md parsing

// Mirrors tools/queue-dashboard/server.mjs: "## Tier ..." sections holding "### Title"
// postings whose bodies are bare "Key: value" lines.
export function parsePostings(text) {
  const out = [];
  const headRe = /^### (.+)$/gm;
  const heads = [];
  let m;
  while ((m = headRe.exec(text))) heads.push({ title: m[1].trim(), at: m.index, bodyAt: headRe.lastIndex });
  for (let i = 0; i < heads.length; i++) {
    const end = i + 1 < heads.length ? heads[i + 1].at : text.length;
    const body = text.slice(heads[i].bodyAt, end);
    out.push({
      title: heads[i].title,
      body,
      start: heads[i].bodyAt,
      end,
      url: field(body, "URL"),
      company: field(body, "Company"),
      liveness: field(body, "Liveness"),
      checkedAt: field(body, "Liveness checked"),
    });
  }
  return out;
}

export function field(body, key) {
  const re = new RegExp(`^${key}:[ \\t]*(.*)$`, "im");
  return (body.match(re)?.[1] || "").trim();
}

// Replace the field if present, otherwise append it after the last existing field line so
// the block stays contiguous and the dashboard's fieldValue lookup keeps matching.
export function setField(body, key, value) {
  const re = new RegExp(`^${key}:[ \\t]*.*$`, "im");
  if (re.test(body)) return body.replace(re, `${key}: ${value}`);
  const lines = body.split("\n");
  let last = -1;
  for (let i = 0; i < lines.length; i++) if (/^[A-Za-z][A-Za-z ]*:/.test(lines[i])) last = i;
  lines.splice(last + 1, 0, `${key}: ${value}`);
  return lines.join("\n");
}

// ---------------------------------------------------------------- checkers

// Ashby publishes its whole board as JSON, so both the verdict and the full posting text
// come from one authoritative request - no rendering, no scraping.
export async function checkAshby(url, fetchImpl) {
  const m = url.match(/jobs\.ashbyhq\.com\/([^/?#]+)\/([0-9a-f-]{36})/i);
  if (!m) return null;
  const [, board, id] = m;
  let res;
  try {
    res = await fetchImpl(`https://api.ashbyhq.com/posting-api/job-board/${board}?includeCompensation=true`, {
      headers: { "user-agent": UA },
    });
  } catch (err) {
    return verdict("unreachable", `ashby board request failed: ${err.message}`);
  }
  if (res.status === 404) return verdict("dead", "ashby job board no longer exists");
  if (!res.ok) return verdict("unreachable", `ashby board returned HTTP ${res.status}`);
  let data;
  try {
    data = await res.json();
  } catch (err) {
    return verdict("unreachable", `ashby board returned unparseable JSON: ${err.message}`);
  }
  const job = (data.jobs || []).find((j) => String(j.id).toLowerCase() === id.toLowerCase());
  if (!job) return verdict("dead", "posting absent from the ashby job board feed");
  if (job.isListed === false) return verdict("dead", "ashby marks this posting unlisted");
  return verdict("live", "present and listed on the ashby job board feed", { content: ashbyContent(job) });
}

function ashbyContent(job) {
  const comp = job.compensation?.compensationTierSummary
    || (job.compensation?.compensationTiers || []).map((t) => t.tierSummary).filter(Boolean).join("; ");
  const secondary = (job.secondaryLocations || []).map((l) => l?.location || l).filter(Boolean);
  return {
    title: (job.title || "").trim(),
    location: [job.location, ...secondary].filter(Boolean).join(" | "),
    employmentType: job.employmentType || "",
    salary: comp || "",
    publishedAt: job.publishedAt || "",
    body: (job.descriptionPlain || stripHtml(job.descriptionHtml || "")).trim(),
  };
}

// Greenhouse has a per-job API that answers 404 for a pulled posting, which is exactly the
// positive signal we want, and returns the description for the snapshot.
export async function checkGreenhouse(url, fetchImpl) {
  const m = url.match(/greenhouse\.io\/(?:embed\/job_app\?for=)?([^/?#&]+)(?:\/jobs\/|&token=)(\d+)/i);
  if (!m) return null;
  const [, board, id] = m;
  let res;
  try {
    res = await fetchImpl(`https://boards-api.greenhouse.io/v1/boards/${board}/jobs/${id}`, {
      headers: { "user-agent": UA },
    });
  } catch (err) {
    return verdict("unreachable", `greenhouse request failed: ${err.message}`);
  }
  if (res.status === 404) return verdict("dead", "greenhouse job API returned 404 for this posting");
  if (!res.ok) return verdict("unreachable", `greenhouse API returned HTTP ${res.status}`);
  let job;
  try {
    job = await res.json();
  } catch (err) {
    return verdict("unreachable", `greenhouse API returned unparseable JSON: ${err.message}`);
  }
  return verdict("live", "greenhouse job API returned the posting", {
    content: {
      title: (job.title || "").trim(),
      location: job.location?.name || "",
      employmentType: "",
      salary: (job.pay_input_ranges || [])
        .map((r) => `${r.title || "pay"}: ${r.min_cents / 100} - ${r.max_cents / 100} ${r.currency_type || ""}`)
        .join("; "),
      publishedAt: job.first_published || job.updated_at || "",
      body: stripHtml(decodeEntities(job.content || "")).trim(),
    },
  });
}

// Workday's CXS endpoint is the feed its own careers site reads. It answers with the
// posting when the requisition exists, and with errorCode "S21" and a
// "not found: Job_Posting_Anchor_ID" message when the requisition is gone. Any other
// failure returns null so the caller falls through to the rendered check: Workday's error
// taxonomy is undocumented, and a generic HTTP_404 more often means our guess at the
// tenant path was wrong than that the job was pulled. Only the specific signal is trusted.
export async function checkWorkday(url, fetchImpl) {
  const m = url.match(/https:\/\/([^.]+)\.[^/]*myworkdayjobs\.com\/(?:[a-z]{2}-[A-Z]{2}\/)?([^/?#]+)\/job\/([^/?#]+)/i);
  if (!m) return null;
  const [, tenant, site, anchor] = m;
  let res;
  try {
    res = await fetchImpl(`https://${new URL(url).host}/wday/cxs/${tenant}/${site}/job/${anchor}`, {
      headers: { "user-agent": UA, accept: "application/json" },
    });
  } catch {
    return null;
  }
  let payload = {};
  try {
    payload = await res.json();
  } catch {
    return null;
  }
  if (payload.errorCode === "S21" || /not found: Job_Posting_Anchor_ID/i.test(payload.message || "")) {
    return verdict("dead", "workday reports no requisition at this posting id");
  }
  if (!res.ok || !payload.jobPostingInfo) return null;
  const info = payload.jobPostingInfo;
  return verdict("live", "workday careers feed returned the requisition", {
    content: {
      title: (info.title || "").trim(),
      location: [info.location, ...(info.additionalLocations || [])].filter(Boolean).join(" | "),
      employmentType: info.timeType || "",
      salary: info.payRange ? `${info.payRange.min} - ${info.payRange.max} ${info.payRange.currency || ""}` : "",
      publishedAt: info.startDate || info.postedOn || "",
      body: stripHtml(decodeEntities(info.jobDescription || "")).trim(),
    },
  });
}

// Everything else needs the page as a browser sees it. Google Careers is the reason:
// it answers HTTP 200 for a pulled requisition and its "Job not found" text exists only
// after client-side rendering. Verified 2026-08-24 - a raw fetch of a live req and of a
// nonexistent one returned 1,255,206 and 1,255,173 bytes of identical app shell, so
// neither the status code nor any body-text signature can separate them without JS.
//
// The rendered path also refuses to call a page live merely because it lacks a takedown
// notice. A bot wall, a consent interstitial, or an app that never painted all look like
// "no bad news" while proving nothing, so we require positive evidence instead: the
// posting's own title has to appear in the rendered text. No dead signature and no
// positive evidence means undetermined, which is recorded as unreachable, not as live.
export function titleEvidence(title, bodyText) {
  const words = String(title)
    .toLowerCase()
    .split(/[^a-z0-9+#.]+/)
    .filter((w) => w.length > 2 && !TITLE_STOPWORDS.has(w));
  if (!words.length) return { matched: 0, needed: 0, ok: false };
  const hay = bodyText.toLowerCase();
  const matched = words.filter((w) => hay.includes(w)).length;
  const needed = Math.max(1, Math.ceil(words.length * 0.6));
  return { matched, needed, total: words.length, ok: matched >= needed };
}

async function checkRendered(url, browserBox, title = "") {
  const browser = await browserBox.get();
  if (!browser) {
    return verdict("unreachable", "no browser renderer available; run npm install in tools/job-liveness");
  }
  const context = await browser.newContext({ userAgent: UA });
  const page = await context.newPage();
  try {
    let response;
    try {
      response = await page.goto(url, { waitUntil: "domcontentloaded", timeout: NAV_TIMEOUT_MS });
    } catch (err) {
      return verdict("unreachable", `navigation failed: ${err.message.split("\n")[0]}`);
    }
    const status = response?.status() ?? 0;
    if (status === 404 || status === 410) return verdict("dead", `page returned HTTP ${status}`);
    if (status >= 500) return verdict("unreachable", `page returned HTTP ${status}`);
    if (status === 403 || status === 429) return verdict("unreachable", `blocked by the site (HTTP ${status})`);

    // Give the client-side app a moment to paint. networkidle is unreliable on pages that
    // poll, so treat it as a bounded settle rather than a requirement.
    await page.waitForLoadState("networkidle", { timeout: 8000 }).catch(() => {});

    // Decline non-essential cookies where a consent wall is covering the posting. This is
    // the privacy-preserving choice and it is also the only way to read the page at all -
    // Google Careers renders the banner over the job pane until it is answered.
    await dismissConsent(page);

    const body = (await page.evaluate(() => (document.body && document.body.innerText) || "")).trim();
    const hay = body.toLowerCase();
    const hit = DEAD_SIGNATURES.find((sig) => hay.includes(sig));
    if (hit) return verdict("dead", `rendered page says "${hit}"`);
    if (body.length < MIN_LIVE_BODY_CHARS) {
      return verdict("unreachable", `rendered page had only ${body.length} characters of text; cannot tell`);
    }
    const evidence = titleEvidence(title, body);
    if (!evidence.ok) {
      return verdict(
        "unreachable",
        `no takedown notice, but only ${evidence.matched}/${evidence.total} posting title words appeared on the rendered page; undetermined`
      );
    }
    const pageTitle = (await page.title()).trim();
    return verdict("live", `rendered page shows the posting (${evidence.matched}/${evidence.total} title words matched)`, {
      content: { title: pageTitle, location: "", employmentType: "", salary: "", publishedAt: "", body },
    });
  } finally {
    await context.close().catch(() => {});
  }
}

// Only ever clicks a decline control. Nothing here accepts terms or grants consent.
const CONSENT_DECLINE = [/^no thanks$/i, /^reject all$/i, /^decline all$/i, /^only necessary$/i, /^necessary cookies only$/i];

async function dismissConsent(page) {
  for (const name of CONSENT_DECLINE) {
    try {
      const control = page.getByRole("button", { name });
      if (await control.count()) {
        await control.first().click({ timeout: 3000 });
        await page.waitForTimeout(2500);
        return true;
      }
    } catch {
      // A consent control we cannot click is not fatal; the evidence check decides.
    }
  }
  return false;
}

function stripHtml(html) {
  return html
    .replace(/<(script|style)[\s\S]*?<\/\1>/gi, " ")
    .replace(/<\/(p|div|li|h[1-6]|tr)>/gi, "\n")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<[^>]+>/g, "")
    .replace(/[ \t]+\n/g, "\n")
    .replace(/\n{3,}/g, "\n\n");
}

function decodeEntities(s) {
  const map = { amp: "&", lt: "<", gt: ">", quot: '"', nbsp: " " };
  return s.replace(/&(#x?[0-9a-fA-F]+|[a-z]+);/gi, (whole, ent) => {
    if (map[ent.toLowerCase()] !== undefined) return map[ent.toLowerCase()];
    if (/^#x/i.test(ent)) return String.fromCharCode(parseInt(ent.slice(2), 16));
    if (/^#/.test(ent)) return String.fromCharCode(Number(ent.slice(1)));
    return whole;
  });
}

// ---------------------------------------------------------------- snapshots

export function slugify(title, url) {
  const base = String(title).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 70);
  let hash = 0;
  for (const ch of url) hash = (hash * 31 + ch.charCodeAt(0)) >>> 0;
  return `${base || "posting"}-${hash.toString(36)}`;
}

// A snapshot exists so the requirements survive the takedown, which means the one thing it
// must never do is overwrite good content with the husk of a pulled page. We only write
// when the posting is live, and we refuse a rewrite that would lose more than half the
// text already on disk.
const SNAPSHOT_MARKER = "\n## Posting text\n";

export function shouldReplaceSnapshot(existingBody, nextBody) {
  if (!existingBody) return true;
  return nextBody.length >= existingBody.trim().length * 0.5;
}

async function saveSnapshot({ title, url, company, content, detail }) {
  if (!content || !content.body) return null;
  const name = `${slugify(title, url)}.md`;
  const path = join(SNAPSHOT_DIR, name);
  let existingBody = "";
  try {
    const prev = await readFile(path, "utf8");
    existingBody = prev.split(SNAPSHOT_MARKER)[1] || "";
  } catch {
    // No prior snapshot; first capture.
  }
  if (!shouldReplaceSnapshot(existingBody, content.body)) {
    return { path: name, wrote: false, reason: "kept the longer existing snapshot" };
  }
  const doc = [
    `# ${title}`,
    "",
    `Company: ${company || ""}`,
    `URL: ${url}`,
    `Posting title: ${content.title || ""}`,
    `Location: ${content.location || ""}`,
    `Salary: ${content.salary || ""}`,
    `Employment type: ${content.employmentType || ""}`,
    `Published: ${content.publishedAt || ""}`,
    `Captured: ${nowIso()}`,
    `Source: ${detail}`,
    "",
    "Archived copy of a third-party job posting, kept so the requirements survive the",
    "posting being taken down. Local reference only, not for redistribution.",
    SNAPSHOT_MARKER.trim(),
    "",
    content.body,
    "",
  ].join("\n");
  await mkdir(SNAPSHOT_DIR, { recursive: true });
  await writeFile(path, doc, "utf8");
  return { path: name, wrote: true, chars: content.body.length };
}

// ---------------------------------------------------------------- driver

function lazyBrowser() {
  let promise = null;
  let browser = null;
  return {
    async get() {
      if (!promise) {
        promise = (async () => {
          // An absolute Windows path is not a valid ESM specifier, so the fallback has to
          // go through pathToFileURL rather than being handed to import() as-is.
          const candidates = [
            "playwright",
            pathToFileURL(join(homedir(), "Repo", "job-applications", "node_modules", "playwright", "index.mjs")).href,
          ];
          for (const spec of candidates) {
            try {
              const mod = await import(spec);
              const chromium = mod.chromium || mod.default?.chromium;
              if (!chromium) continue;
              browser = await chromium.launch({ headless: HEADLESS });
              return browser;
            } catch {
              // Try the next candidate; a missing renderer yields "unreachable", never "dead".
            }
          }
          return null;
        })();
      }
      return promise;
    },
    async close() {
      if (browser) await browser.close().catch(() => {});
    },
  };
}

async function checkOne(posting, { fetchImpl, browserBox }) {
  if (!posting.url) return verdict("unreachable", "no URL recorded for this posting");
  for (const checker of [checkAshby, checkGreenhouse, checkWorkday]) {
    const result = await checker(posting.url, fetchImpl);
    if (result) return result;
  }
  return checkRendered(posting.url, browserBox, posting.title);
}

// One retry, spaced, before recording a failure - a single blip should not become a week
// of "unreachable" on the card. A "dead" verdict is never retried: it was positive.
async function checkWithRetry(posting, deps) {
  const first = await checkOne(posting, deps);
  if (first.state !== "unreachable") return first;
  await sleep(RETRY_GAP_MS);
  const second = await checkOne(posting, deps);
  if (second.state !== "unreachable") return second;
  return verdict("unreachable", `${second.detail} (failed twice)`);
}

export function isFresh(checkedAt, maxAgeHours, now = Date.now()) {
  if (!checkedAt) return false;
  const t = Date.parse(checkedAt);
  if (Number.isNaN(t)) return false;
  return now - t < maxAgeHours * 3600 * 1000;
}

function parseArgs(argv) {
  const opts = { maxAgeHours: DEFAULT_MAX_AGE_HOURS, force: false, dryRun: false, only: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--force") opts.force = true;
    else if (a === "--dry-run") opts.dryRun = true;
    else if (a === "--max-age") opts.maxAgeHours = Number(argv[++i]);
    else if (a === "--only") opts.only = argv[++i];
  }
  return opts;
}

export async function run(argv = []) {
  const opts = parseArgs(argv);
  const before = await stat(JOBS_PATH);
  let text = await readFile(JOBS_PATH, "utf8");
  const postings = parsePostings(text);
  const deps = { fetchImpl: globalThis.fetch, browserBox: lazyBrowser() };
  const results = [];

  try {
    for (const posting of postings) {
      if (opts.only && !posting.title.toLowerCase().includes(opts.only.toLowerCase())) continue;
      if (!opts.force && isFresh(posting.checkedAt, opts.maxAgeHours)) {
        results.push({ title: posting.title, state: posting.liveness || "unknown", detail: "skipped; checked recently" });
        continue;
      }
      const result = await checkWithRetry(posting, deps);
      let snapshot = null;
      if (result.state === "live") {
        snapshot = await saveSnapshot({
          title: posting.title,
          url: posting.url,
          company: posting.company,
          content: result.content,
          detail: result.detail,
        }).catch((err) => ({ path: null, wrote: false, reason: err.message }));
      }
      results.push({ title: posting.title, state: result.state, detail: result.detail, snapshot });

      let body = posting.body;
      body = setField(body, "Liveness", result.state);
      body = setField(body, "Liveness checked", nowIso());
      body = setField(body, "Liveness detail", result.detail);
      if (result.state === "dead" && !field(posting.body, "Liveness gone since")) {
        body = setField(body, "Liveness gone since", nowIso().slice(0, 10));
      }
      if (snapshot && snapshot.path) body = setField(body, "Snapshot", snapshot.path);
      posting.newBody = body;

      await sleep(REQUEST_GAP_MS);
    }
  } finally {
    await deps.browserBox.close();
  }

  // Rebuild the file back-to-front so the earlier offsets stay valid.
  const edited = postings.filter((p) => p.newBody !== undefined).sort((a, b) => b.start - a.start);
  for (const p of edited) text = text.slice(0, p.start) + p.newBody + text.slice(p.end);

  if (!opts.dryRun && edited.length) {
    const after = await stat(JOBS_PATH);
    if (after.mtimeMs !== before.mtimeMs) {
      throw new Error("JOBS.md changed on disk while the check ran; re-run rather than clobbering it");
    }
    await writeFile(JOBS_PATH, text, "utf8");
  }

  const tally = results.reduce((acc, r) => ((acc[r.state] = (acc[r.state] || 0) + 1), acc), {});
  for (const r of results) {
    const snap = r.snapshot && r.snapshot.wrote ? ` [snapshot ${r.snapshot.chars} chars]` : "";
    console.log(`${r.state.padEnd(11)} ${r.title}\n            ${r.detail}${snap}`);
  }
  console.log(`\n${results.length} postings checked: ` + Object.entries(tally).map(([k, v]) => `${v} ${k}`).join(", "));
  return results;
}

export { DEAD_SIGNATURES };

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  run(process.argv.slice(2)).catch((err) => {
    console.error(err.message);
    process.exit(1);
  });
}
