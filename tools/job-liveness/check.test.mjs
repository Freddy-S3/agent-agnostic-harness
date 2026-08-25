import test from "node:test";
import assert from "node:assert/strict";
import {
  parsePostings,
  field,
  setField,
  checkAshby,
  checkGreenhouse,
  checkWorkday,
  isFresh,
  shouldReplaceSnapshot,
  slugify,
  titleEvidence,
} from "./check.mjs";

const SAMPLE = `# Job board

## Tier S - apply this week

### Senior Software Engineer, AI - Klue
Company: Klue
Location: Toronto
URL: https://jobs.ashbyhq.com/klue/2fdcccfe-6520-4536-a7f3-3acf79829784
Status: interested

### Senior AI Engineer, AI - Justworks
Company: Justworks
URL: https://job-boards.greenhouse.io/justworks/jobs/7797374?gh_jid=7797374
Status: new
`;

const ok = (body) => ({ ok: true, status: 200, json: async () => body });
const code = (status) => ({ ok: false, status, json: async () => ({}) });

test("parses postings and their URLs out of JOBS.md", () => {
  const postings = parsePostings(SAMPLE);
  assert.equal(postings.length, 2);
  assert.equal(postings[0].company, "Klue");
  assert.match(postings[1].url, /greenhouse\.io/);
});

test("setField replaces an existing field and appends a new one inside the field block", () => {
  const body = "Company: Klue\nStatus: new\n\nSome prose that is not a field.\n";
  const replaced = setField(body, "Status", "applied");
  assert.equal(field(replaced, "Status"), "applied");
  const added = setField(body, "Liveness", "live");
  assert.equal(field(added, "Liveness"), "live");
  // The new field must land inside the contiguous field block, not after the prose.
  assert.ok(added.indexOf("Liveness:") < added.indexOf("Some prose"));
});

test("ashby: a posting missing from the board feed is dead", async () => {
  const fetchImpl = async () => ok({ jobs: [{ id: "other-id", isListed: true }] });
  const v = await checkAshby(SAMPLE.match(/https:\/\/jobs\.ashbyhq\.com\/\S+/)[0], fetchImpl);
  assert.equal(v.state, "dead");
});

test("ashby: an unlisted posting is dead even though it is still in the feed", async () => {
  const id = "2fdcccfe-6520-4536-a7f3-3acf79829784";
  const fetchImpl = async () => ok({ jobs: [{ id, isListed: false, title: "Klue" }] });
  const v = await checkAshby(`https://jobs.ashbyhq.com/klue/${id}`, fetchImpl);
  assert.equal(v.state, "dead");
});

test("ashby: a listed posting is live and carries snapshot content", async () => {
  const id = "2fdcccfe-6520-4536-a7f3-3acf79829784";
  const fetchImpl = async () =>
    ok({ jobs: [{ id, isListed: true, title: "Senior AI", location: "Toronto", descriptionPlain: "Minimum qualifications..." }] });
  const v = await checkAshby(`https://jobs.ashbyhq.com/klue/${id}`, fetchImpl);
  assert.equal(v.state, "live");
  assert.equal(v.content.body, "Minimum qualifications...");
});

test("a transport failure is unreachable, never dead", async () => {
  const boom = async () => {
    throw new Error("getaddrinfo ENOTFOUND");
  };
  const ashby = await checkAshby("https://jobs.ashbyhq.com/klue/2fdcccfe-6520-4536-a7f3-3acf79829784", boom);
  assert.equal(ashby.state, "unreachable");
  const gh = await checkGreenhouse("https://job-boards.greenhouse.io/justworks/jobs/7797374", boom);
  assert.equal(gh.state, "unreachable");
});

test("a 500 from the ATS is unreachable, a 404 on the job is dead", async () => {
  assert.equal((await checkGreenhouse("https://job-boards.greenhouse.io/justworks/jobs/1", async () => code(500))).state, "unreachable");
  assert.equal((await checkGreenhouse("https://job-boards.greenhouse.io/justworks/jobs/1", async () => code(404))).state, "dead");
});

test("greenhouse: a returned posting is live with its content", async () => {
  const fetchImpl = async () => ok({ title: "Senior SWE", location: { name: "Remote" }, content: "&lt;p&gt;Preferred quals&lt;/p&gt;" });
  const v = await checkGreenhouse("https://job-boards.greenhouse.io/justworks/jobs/7797374?gh_jid=7797374", fetchImpl);
  assert.equal(v.state, "live");
  assert.match(v.content.body, /Preferred quals/);
});

test("non-ATS URLs fall through to the rendered check", async () => {
  const never = async () => {
    throw new Error("should not be called");
  };
  assert.equal(await checkAshby("https://www.triomind.ca/careers/senior-ai-engineer", never), null);
  assert.equal(await checkGreenhouse("https://www.triomind.ca/careers/senior-ai-engineer", never), null);
});

test("freshness window keeps us from hammering sites", () => {
  const now = Date.parse("2026-08-24T12:00:00Z");
  assert.equal(isFresh("2026-08-24T06:00:00Z", 12, now), true);
  assert.equal(isFresh("2026-08-23T06:00:00Z", 12, now), false);
  assert.equal(isFresh("", 12, now), false);
  assert.equal(isFresh("not a date", 12, now), false);
});

test("a snapshot is never replaced by a much shorter capture", () => {
  const good = "x".repeat(4000);
  assert.equal(shouldReplaceSnapshot("", good), true);
  assert.equal(shouldReplaceSnapshot(good, "x".repeat(4100)), true);
  assert.equal(shouldReplaceSnapshot(good, "Job not found"), false);
});

test("slugs are stable and distinguish two postings sharing a title", () => {
  const a = slugify("Senior AI Engineer", "https://a.example/1");
  const b = slugify("Senior AI Engineer", "https://a.example/2");
  assert.equal(a, slugify("Senior AI Engineer", "https://a.example/1"));
  assert.notEqual(a, b);
});

test("title evidence requires most of the identifying words, ignoring generic ones", () => {
  const title = "Senior AI Engineer - Triomind AI";
  assert.equal(titleEvidence(title, "We are hiring an AI Engineer at Triomind. Apply now.").ok, true);
  // Page chrome with no posting on it must not read as evidence.
  assert.equal(titleEvidence(title, "Careers Home Jobs Students How we work Sign in").ok, false);
  // "Senior" alone is a stopword and cannot carry a match on its own.
  assert.equal(titleEvidence(title, "Senior roles at many companies").ok, false);
});

test("a title of only stopwords yields no evidence rather than a free pass", () => {
  assert.equal(titleEvidence("Senior and the", "anything at all here").ok, false);
});

test("workday: only the specific requisition-missing error counts as dead", async () => {
  const url = "https://jdpa.wd501.myworkdayjobs.com/en-US/JDPower/job/Senior-AI-Engineer_R-100379";
  const s21 = async () => ({ ok: false, status: 404, json: async () => ({ errorCode: "S21", message: "not found: Job_Posting_Anchor_ID=x" }) });
  assert.equal((await checkWorkday(url, s21)).state, "dead");
  // A generic 404 more likely means our tenant-path guess was wrong, so fall through.
  const generic = async () => ({ ok: false, status: 404, json: async () => ({ errorCode: "HTTP_404" }) });
  assert.equal(await checkWorkday(url, generic), null);
  const live = async () => ({ ok: true, status: 200, json: async () => ({ jobPostingInfo: { title: "Senior AI Engineer", jobDescription: "<p>Quals</p>" } }) });
  const v = await checkWorkday(url, live);
  assert.equal(v.state, "live");
  assert.match(v.content.body, /Quals/);
});
