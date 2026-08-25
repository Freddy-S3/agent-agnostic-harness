# job-liveness

Two safeguards against a job posting disappearing out from under the pipeline.

1. **Liveness.** Checks whether each posting in `$QUEUE_DIR/JOBS.md` is still up, and writes
   the verdict back as fields the dashboard renders. Gone postings are marked, never deleted.
2. **Snapshot.** Captures the posting's content the first time it is seen live, so the
   qualifications survive the takedown. This is the half that pays for itself: a tailored
   resume written against a posting nobody can read any more is written against boilerplate.

```bash
node tools/job-liveness/check.mjs          # skips postings checked in the last 12 hours
node tools/job-liveness/check.mjs --force  # re-check everything
node tools/job-liveness/check.mjs --dry-run --force
node tools/job-liveness/check.mjs --only cerebras
```

Snapshots land in `$QUEUE_DIR/job-snapshots/`, next to `JOBS.md` and outside every
repository, because they are archived copies of third-party postings.

## dead vs unreachable

The two are never merged, and this is the whole design.

- **dead** - the site positively told us the posting is gone: absent from the Ashby board
  feed, a Greenhouse 404, Workday's requisition-not-found error, an HTTP 404/410, or a
  takedown sentence in the rendered page.
- **unreachable** - our check failed. DNS, a timeout, a 500, a bot wall, a consent screen we
  could not get past, no renderer installed. It says nothing about the posting, and the card
  says so: "could not check this posting - it may well still be open."

A network error can never produce a "dead" verdict. Every unreachable result is retried once,
spaced, before it is recorded.

The rendered path also refuses to call a page live merely because it lacks a takedown
notice - it requires positive evidence, namely that most of the posting's own title words
appear in the rendered text. No bad news is not the same as good news.

## Why the checks are shaped this way

**A status code is not an answer.** Google Careers returns HTTP 200 for a requisition that
has been pulled, with "Job not found. This job may have been taken down" in the body. Any
check that reads only the response code passes a dead posting as live.

**A raw fetch is not an answer either.** Verified 2026-08-24: fetching a live Google
requisition and a nonexistent one returned 1,255,206 and 1,255,173 bytes of identical
client-side app shell. Neither the status nor any body-text signature separates them.

**Headless rendering is not an answer for every site.** Verified 2026-08-24: headless
Chromium on Google Careers renders 3,270 characters of page chrome with the job pane never
painted, identically for a live and a pulled requisition. The same navigation in a real
browser window renders the takedown sentence. So the renderer runs headful by default.
`JOB_CHECK_HEADLESS=1` forces headless on a machine with no display, at the cost of Google
postings coming back undetermined rather than answered.

The order of preference follows from that. Where an ATS publishes a feed its own site reads -
Ashby, Greenhouse, Workday - that feed is used: it is authoritative, cheap, needs no browser,
and returns the full posting text for the snapshot in the same request. Rendering is the
fallback for everything else.

## Politeness

Sequential, one posting at a time, three seconds between requests, and postings checked
within the last twelve hours are skipped entirely. Read-only requests to URLs already on the
board. Nothing crawls, enumerates, or submits anything. Where a cookie consent wall blocks
the page, the checker clicks only a decline control - never an accept.

## Snapshots never regress

A snapshot exists to outlive the posting, so the one thing it must not do is overwrite good
content with the husk of a pulled page. Snapshots are written only on a `live` verdict, and a
rewrite that would lose more than half the stored text is refused.

## Renderer

`npm install` in this directory installs Playwright. Failing that, the checker falls back to
the Playwright already installed under `~/Repo/job-applications/node_modules`. If neither
resolves, non-ATS postings come back `unreachable`, never `dead`.

## Tests

```bash
node --test tools/job-liveness
```

Fifteen tests, no network. `probe-rendered.mjs` is a manual network probe, deliberately
outside the suite.
