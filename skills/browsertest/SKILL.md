---
name: browsertest
description: "Verify a web UI by actually rendering it. Use whenever a change touches HTML, CSS, or client-side JS, before claiming the work is done."
user-invocable: true
---

# Browser Test Skill

Reading markup is not verification.
A page can parse cleanly, pass every link check, and still render as a broken column of overlapping text.
When the deliverable is something a person looks at, the check has to look at it.

Run this before reporting any front-end change as complete.

## Choosing the engine

| Situation | Use |
|---|---|
| Local page, static site, or dev server | Playwright with headless Chromium |
| Faruk's real logged-in session on a live site | Claude in Chrome, and only with him present |

Default to Playwright.
It needs no credentials, no permissions dialog, and runs unattended, which is the only option during `/sleep`.
Reach for Claude in Chrome only when the thing under test is behind a login that belongs to a real account.

## Setup

Once per machine:

```
py -m pip install playwright
py -m playwright install chromium
```

## The test

Write it as a script in the project, not as ad-hoc tool calls.
A committed `tools/test_site.py` is a regression net; a one-off browser session is a demo that evaporates.

Reference implementation: `Portfolio-Website/tools/test_site.py`.

Cover these, because each one has failed in real work:

1. **Content actually rendered.** Count the elements that should exist. Generated markup is where silent breakage hides.
2. **Images decoded.** Filter on `!img.complete || img.naturalWidth === 0`. A 200 response is not a rendered image.
3. **Interaction.** Click every nav control, tab, and toggle; assert the state that should follow.
4. **Both themes.** Compute the contrast ratio of new text against its background and assert 4.5 or better. A palette that works in dark mode routinely collapses in light mode, because the same token means different things in each.
5. **Horizontal overflow at every breakpoint.** `scrollWidth - clientWidth` on `documentElement`, at desktop, tablet, and mobile widths. This is the single highest-yield check; it catches responsive rules that silently do not match.
6. **Console errors and failed requests.** Collect via `page.on("console")` and `page.on("requestfailed")`. Ignore font CDNs when offline.

Write screenshots to a gitignored directory and read them.
Assertions confirm what was predicted; the screenshot shows what was not.

### Rendering a page behind a token gate

A local tool that requires an unlock token cannot always be reached the obvious way: the
Chrome extension's JS context could not set the dashboard's cookie on `127.0.0.1`, and
pasting the token into the unlock form is a password field, which is off limits.

Run a **test-only copy** of the server with the auth check stubbed to `true`, on a
different port and against a throwaway `QUEUE_DIR`, then render that.
Produce the copy with `sed` from the real file rather than hand-writing one, so the page
and client script under test are provably byte-identical to what ships.
Verify the auth paths separately with `curl` - a stubbed render proves the UI, not the gate.

Say in the report that the gate was stubbed and how the real one was checked.
A render that quietly bypassed authentication, reported as "rendered in a browser", is a
verification claim that is broader than the evidence behind it.

## When a check fails

Do not adjust the assertion to match the page.
Find the element that is actually wrong:

```js
[...document.querySelectorAll('*')]
    .map(e => ({t: e.tagName, c: e.className.toString(), r: e.getBoundingClientRect()}))
    .filter(o => o.r.right > document.documentElement.clientWidth + 1 && o.r.width > 0)
```

Then read the computed style rather than the source.
A rule can be present in the compiled CSS, match its media query, and still not apply because the selector assumes a DOM nesting that does not hold.
That exact failure shipped once already: a responsive override scoped to `.about-stats .skill-categories` never matched, because the generated block sat outside `.about-stats`.

`document.styleSheets[].cssRules` throws a security error on `file://` URLs, so inspect computed styles instead, or serve the page over `http.server`.

## Reporting

Report the ratio of checks passed and name every failure.
Never describe a front-end change as verified when only the markup was inspected; say plainly that it has not been rendered.
