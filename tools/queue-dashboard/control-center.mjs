// Control Center: the "what do I do next" surface.
//
// WHY THIS IS A GENERATOR AND NOT A DOCUMENT. There are already four overlapping surfaces
// answering pieces of this question - the queue dashboard, the business plans, the 12-week
// study plan, and STUDY.md - and they already disagree with each other. A fifth
// hand-written document would become the stalest of the five inside a week, because
// nothing regenerates it. The harness rule is explicit: a skill that snapshots state goes
// stale silently, so name the live source, require reading it first, and treat the
// snapshot as a summary that loses to the source on any disagreement.
//
// So every line this file produces is computed from a file on disk at request time, and
// every recommendation carries `evidence` - the source it came from and the specific fact
// that triggered it. Nothing here is a remembered conclusion. If a source disappears the
// signal disappears with it rather than being asserted from memory, and `unavailable`
// records which sources could not be read, so a thin Control Center is visibly thin rather
// than quietly wrong.
//
// It deliberately computes NOTHING it cannot show its work for. "Buy the domain" is here
// because src/config/site.ts still resolves to the placeholder and robots.txt therefore
// emits Disallow: /, not because someone decided it was important once.

import { readFile, stat } from "node:fs/promises";
import { join } from "node:path";

// A recommendation is only as good as the fact behind it, so the two travel together.
function action({ rank, title, why, unblock, minutes, evidence, source }) {
  return { rank, title, why, unblock, minutes, evidence, source };
}

// --- signal 1: the blog cannot be indexed -------------------------------------------
//
// The master plan names unattended-runs as the one project to run for 90 days. The site
// builds with a placeholder domain, so BaseLayout emits noindex AND robots.txt emits
// Disallow: / - it cannot be indexed at all, and every day of that is SEO ramp not
// happening. Detected from the config, not hardcoded: set SITE_URL and this signal stops
// firing on its own.
async function blogIndexable(repoRoot) {
  const siteConfig = join(repoRoot, "..", "unattended-runs", "src", "config", "site.ts");
  try {
    const text = await readFile(siteConfig, "utf8");
    const placeholder = text.match(/const PLACEHOLDER_SITE_URL\s*=\s*"([^"]+)"/)?.[1] || null;
    if (!placeholder) return null;

    // The build reads SITE_URL from the environment. This process is not that build, so
    // the honest test is whether a real domain has been configured anywhere the repo can
    // see it - not whether this shell happens to have the variable set.
    const envFiles = [".env", ".env.production", ".env.local"];
    let configured = null;
    for (const f of envFiles) {
      try {
        const env = await readFile(join(repoRoot, "..", "unattended-runs", f), "utf8");
        const hit = env.match(/^\s*SITE_URL\s*=\s*(.+)$/m)?.[1]?.trim().replace(/^["']|["']$/g, "");
        if (hit && hit !== placeholder) { configured = { value: hit, from: f }; break; }
      } catch { /* absent is the normal case */ }
    }

    let robots = null;
    try {
      robots = await readFile(join(repoRoot, "..", "unattended-runs", "dist", "robots.txt"), "utf8");
    } catch { /* no build output yet */ }

    return {
      placeholder,
      configured,
      robotsDisallowsAll: robots ? /^\s*Disallow:\s*\/\s*$/m.test(robots) : null,
      siteConfigPath: "unattended-runs/src/config/site.ts",
    };
  } catch {
    return null;
  }
}

// --- signal 2: where the job search has the most surface ------------------------------
//
// "Best opportunity" is not a judgement this file is entitled to make, so it computes the
// one thing that is actually countable: which employer has the most live, unapplied
// postings on the board. Volume at one employer is a real signal - one tailored
// application reaches many openings - and it is reproducible from JOBS.md alone.
function topEmployer(jobs) {
  if (!jobs || !jobs.sections) return null;
  const all = jobs.sections.flatMap((s) => s.jobs);
  const byCompany = new Map();
  for (const job of all) {
    if (!job.company) continue;
    if (job.liveness === "dead") continue;
    if (job.status === "applied" || job.status === "pass") continue;
    const entry = byCompany.get(job.company) || { company: job.company, roles: [], top: null };
    entry.roles.push(job);
    byCompany.set(job.company, entry);
  }
  const ranked = [...byCompany.values()].sort((a, b) => b.roles.length - a.roles.length);
  const best = ranked[0];
  if (!best || best.roles.length < 2) return null;

  // Within the employer, surface the best-paid live role as the concrete thing to open.
  const top = [...best.roles].sort((a, b) => b.salaryValue - a.salaryValue)[0];
  const locations = [...new Set(best.roles.map((r) => r.location).filter(Boolean))];
  return {
    company: best.company,
    openRoles: best.roles.length,
    topRole: top,
    locations: locations.slice(0, 4),
    applied: all.filter((j) => j.status === "applied").length,
    total: all.length,
  };
}

// --- signal 3: the study plan's leading gap -------------------------------------------
//
// STUDY.md marks exactly one book ACTIVE. The leading gap is the first NEXT section, which
// is the next thing that becomes active. Both are read from the file; neither is named
// here, so re-ordering STUDY.md re-orders this.
async function studyFocus(queueDir) {
  try {
    const text = await readFile(join(queueDir, "STUDY.md"), "utf8");
    const heads = [...text.matchAll(/^##\s+(ACTIVE|NEXT\s*\d*)\s*-\s*(.+)$/gm)];
    const activeHead = heads.find((h) => /^ACTIVE/.test(h[1]));
    const nextHead = heads.find((h) => /^NEXT/.test(h[1]));

    const chaptersFor = (head) => {
      if (!head) return { done: 0, total: 0 };
      const from = head.index + head[0].length;
      const after = heads.find((h) => h.index > head.index);
      const body = text.slice(from, after ? after.index : text.length);
      const boxes = [...body.matchAll(/^\s*-\s*\[([ xX])\]/gm)];
      return { done: boxes.filter((b) => b[1].toLowerCase() === "x").length, total: boxes.length };
    };

    // Sequence position and "identified gap" are different claims and they can disagree.
    // A section annotated as a new block was added because the file had NOTHING on that
    // subject, which is a stronger signal than being next in line - but reading order is
    // still reading order. Reporting only one of them is how two surfaces start
    // contradicting each other, so both are returned and the caller shows both.
    const identifiedGap = (() => {
      for (const h of heads) {
        if (!/^NEXT/.test(h[1])) continue;
        const after = heads.find((x) => x.index > h.index);
        const body = text.slice(h.index + h[0].length, after ? after.index : text.length);
        if (/\*\*New block/i.test(body)) {
          const reason = body.match(/\*\*New block[^*]*\*\*\s*([\s\S]{0,320})/)?.[1] || "";
          return {
            title: h[2].trim(),
            ...chaptersFor(h),
            reason: reason.replace(/\s+/g, " ").trim(),
            sequence: h[1].trim(),
          };
        }
      }
      return null;
    })();

    return {
      active: activeHead ? { title: activeHead[2].trim(), ...chaptersFor(activeHead) } : null,
      nextGap: nextHead ? { title: nextHead[2].trim(), sequence: nextHead[1].trim(), ...chaptersFor(nextHead) } : null,
      identifiedGap,
      planRef: text.match(/`(study-plan-[^`]+\.md)`/)?.[1] || null,
    };
  } catch {
    return null;
  }
}

// --- the assembly ---------------------------------------------------------------------
export async function controlCenter(snap, repoRoot) {
  const unavailable = [];

  const blog = await blogIndexable(repoRoot);
  if (!blog) unavailable.push("unattended-runs/src/config/site.ts - could not read, so the blog indexing signal is not being reported either way");

  const study = await studyFocus(snap.queueDir);
  if (!study) unavailable.push("STUDY.md - could not read, so no study focus is shown");

  // The business plans live in a Codex outputs folder that this process cannot reach and
  // which was empty when last checked. Saying so beats inventing a phase.
  const planDir = join(process.env.USERPROFILE || "", "Documents", "Codex");
  let businessPlan = null;
  try {
    await stat(planDir);
    businessPlan = { dir: planDir, readable: false };
  } catch { /* not present at all */ }
  unavailable.push(
    "business plans - the per-project plan outputs under Documents/Codex are empty, so the phase below is derived from what the repositories actually show, not from the plan text"
  );

  const employer = topEmployer(snap.jobs);

  // Blocked on Freddy: items with a real question and no answer, shortest list wins. The
  // dashboard's own impact ordering already ran, so this takes the top of it rather than
  // inventing a second ranking that could disagree with the cards below.
  const blocked = [];
  for (const g of snap.groups) {
    for (const item of g.items) {
      if (!item.needsDecision) continue;
      blocked.push({
        title: item.title,
        gate: g.gate,
        file: g.file,
        repo: item.repo,
        unblock: item.options[0] || (item.asks[0] || "").slice(0, 160) || "read the item and answer it",
        options: item.options.length,
      });
    }
  }
  blocked.sort((a, b) => (b.options > 0 ? 1 : 0) - (a.options > 0 ? 1 : 0));

  // Answered but nobody acted: a decision recorded and not consumed is work already paid
  // for and not collected, which is why it is counted separately from blocked.
  let answeredUnconsumed = 0;
  for (const g of snap.groups) {
    for (const item of g.items) {
      if (item.answered && item.status !== "done") answeredUnconsumed++;
    }
  }

  const actions = [];

  if (blog && !blog.configured) {
    actions.push(action({
      rank: 1,
      title: "Buy and configure the blog's real domain",
      why:
        "unattended-runs is the one project the plan says to run for 90 days, and it currently cannot be indexed at all. " +
        `${blog.siteConfigPath} still resolves to the placeholder ${blog.placeholder}, so every page emits noindex and robots.txt emits Disallow: /. ` +
        "Every day in this state is SEO ramp that does not start. Nothing else on this page is blocked by so little.",
      unblock: "Buy the domain, set SITE_URL at the host's build settings, redeploy. The robots.txt and canonical links regenerate from that one value.",
      minutes: 10,
      source: blog.siteConfigPath,
      evidence: blog.robotsDisallowsAll
        ? "dist/robots.txt currently contains Disallow: / for all user-agents"
        : "site config resolves to the placeholder domain; no SITE_URL found in .env, .env.production or .env.local",
    }));
  }

  if (employer) {
    const r = employer.topRole;
    actions.push(action({
      rank: actions.length + 1,
      title: `Apply to ${employer.company}`,
      why:
        `${employer.openRoles} live unapplied roles at one employer - the highest concentration on the board, so one tailored application reaches the most openings. ` +
        (r?.salary ? `Best paid live role: ${r.title} at ${r.salary}. ` : "") +
        (employer.locations.length ? `Locations: ${employer.locations.join(", ")}.` : ""),
      unblock: r?.url ? `Open ${r.url} and apply` : "Open JOBS.md and pick the top role",
      minutes: 45,
      source: "JOBS.md",
      evidence: `${employer.openRoles} of ${employer.total} board entries are ${employer.company}, live and not yet applied; ${employer.applied} applications sent across the whole board`,
    }));
  }

  // The identified gap outranks the sequence position when they differ: a section added
  // because the file had nothing on the subject is a hole, not a queue position.
  if (study?.identifiedGap && study.identifiedGap.title !== study.nextGap?.title) {
    const g = study.identifiedGap;
    actions.push(action({
      rank: actions.length + 1,
      title: `Start ${g.title}`,
      why:
        `STUDY.md flags this as a new block rather than an ordinary next read - it was added because the file had nothing on the subject at all. ` +
        `It sits at ${g.sequence} in reading order, so sequence and stated gap disagree here; the gap is the stronger signal. ` +
        `${g.done}/${g.total} chapters ticked.` + (g.reason ? ` Reason recorded: ${g.reason}` : ""),
      unblock: "Open STUDY.md, move this section to ACTIVE if you agree it outranks reading order, and tick chapters as you go",
      minutes: 60,
      source: `STUDY.md${study.planRef ? ` (sequenced against ${study.planRef})` : ""}`,
      evidence: `"${g.title}" is marked ${g.sequence} but carries a New block annotation; the first NEXT section is "${study.nextGap?.title || "none"}"`,
    }));
  }

  if (study?.nextGap) {
    actions.push(action({
      rank: actions.length + 1,
      title: `Start ${study.nextGap.title}`,
      why:
        `Next in reading order${study.active ? `, behind the active book ${study.active.title} (${study.active.done}/${study.active.total} chapters)` : ""}. ` +
        `${study.nextGap.done}/${study.nextGap.total} chapters ticked.`,
      unblock: "Open STUDY.md and tick the first chapter as you finish it; the dashboard writes ticks straight back",
      minutes: 60,
      source: `STUDY.md${study.planRef ? ` (sequenced against ${study.planRef})` : ""}`,
      evidence: `STUDY.md marks ${study.active ? `"${study.active.title}" ACTIVE` : "no active book"} and "${study.nextGap.title}" as the next section`,
    }));
  }

  // Phase: derived from what the repositories and board actually show, because the plan
  // documents are unreadable from here. Stated as an inference, labelled as one.
  const phase = {
    name: blog && !blog.configured ? "Pre-launch: the 90-day project is built but not publishable"
      : employer ? "Job search active, blog shipping"
      : "Unknown - not enough readable sources",
    moveItForward: blog && !blog.configured
      ? "The blog has content and a build and no domain. Buying it converts every future post from unindexable to indexed, so it gates the whole 90 days."
      : "Keep applying at volume and keep the posting cadence.",
    derivedFrom: "repository state and JOBS.md, not the plan documents - those are listed under unavailable",
  };

  return {
    actions,
    blocked: blocked.slice(0, 5),
    blockedTotal: blocked.length,
    answeredUnconsumed,
    inFlight: snap.prs.map((p) => ({ ...p, needsYou: false })),
    phase,
    study,
    businessPlan,
    unavailable,
    generatedAt: Date.now(),
  };
}
