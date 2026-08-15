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
7. **Collision with fixed overlays.** Any element pinned with `position: fixed` - a rail, a sticky header, a floating action button - reserves a band of the viewport at every scroll position. Compute that band and assert no in-flow element enters it. This is the check that did not exist on 2026-08-14, when the landing router console ran underneath the portfolio's control rail above 1900px and again below 970px, and Faruk had to report it.
8. **Icon glyphs present.** `getComputedStyle(el, '::before').content` on every icon element. An icon name from a newer version of the icon font than the page loads renders as a blank box: it is correct in the markup, invisible in a diff, and obviously broken on screen. Three such names shipped in that same page (`fa-diagram-project`, `fa-circle-info` - Font Awesome 6 names on a 5.15.4 stylesheet).
9. **Sibling controls share a height and a baseline.** Buttons in a row, cards in a grid, form fields in a group. A missing glyph or a one-off padding leaves one item a few pixels short, which reads as sloppy long before anyone can say why.

Reference implementation of 7-9: `Portfolio-Website/tools/visual_check.py`, which sweeps eleven widths and exits non-zero on any defect.

### Sweep real widths, not two

A single desktop width proves almost nothing. Sweep, at minimum: 1280, 1440, 1920, 2560, every breakpoint the stylesheet itself declares, and 390.

Defects cluster at two places a spot check never lands on: **above** the widest declared breakpoint, where a fixed value stops keeping pace with a proportional one, and **just below** each breakpoint, where an override lands earlier than the layout it was written for. Both failures on 2026-08-14 were of exactly this shape - a `6rem` gutter against a rail positioned at `3vw`, and a media query that dropped the gutter at 970px while the rail stayed pinned right until 600px.

Derive a reserve from the thing it must clear, as shared tokens, rather than restating it as a magic number. Two constants that must agree and are written in two places will drift; the check above catches the drift, and shared tokens prevent it.

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

## Taste

The checks above catch what is broken. They do not catch what is merely mediocre, and an agent left to its own defaults produces mediocre reliably - the statistical median of every front end in its training data.

Two failure modes, and they need opposite responses.

**Sloppiness** is measurable, so measure it. Every item here is a runnable assertion, and belongs in the script rather than in a paragraph of advice:

- **Spacing comes from a scale.** Pick one step (4px or 8px) and assert every margin, padding, and gap is a multiple of it. Arbitrary values are the single clearest tell of generated layout.
- **Optical alignment holds.** Elements a person reads as a column share a left edge to the pixel. Sibling controls share a height.
- **Contrast passes in both themes.** 4.5:1 for body text, 3:1 for large text and meaningful icons, asserted per theme rather than assumed from the dark one.
- **Nothing touches the viewport edge**, and nothing slides under a fixed overlay.
- **The four omitted states exist** wherever anything loads or can be empty: loading, empty, error, and a visible active/pressed state. Agents ship the happy path and stop.
- **Focus is visible** on every interactive element, and the tab order follows the visual order.
- **Motion animates `transform` and `opacity` only.** Animating `width`, `height`, `top`, or `left` forces layout on every frame.

**Genericness** is a judgment, not an assertion, so look at the screenshot and ask it directly. The current defaults to distrust: Inter set at one weight throughout, a purple-to-blue gradient, a centered hero over three equal cards, uniform border radius everywhere, emoji standing in for icons. None is wrong in isolation; all of them together mean no decision was made. Prefer one accent colour under 80% saturation, a real type scale with contrast between heading and body weight, and asymmetry where the content earns it.

The published "taste skill" collections are worth reading for the specifics, and their own reviewers name the gap this section exists to close: there is no way to verify the agent followed a taste rule short of reading the output. So keep the split - anything that can be asserted becomes a line in the check script, and only genuine judgment stays as prose to be applied against a screenshot.

Sources: [taste-skill review](https://andrew.ooo/posts/taste-skill-anti-slop-ai-frontend-review/), [Awesome DESIGN.md](https://weihaoqu.github.io/learnAIDoc/wiki/awesome-design-md/), [design skills for AI agents](https://guayoyo.tech/blog/design-skills-agentes-ia-en/).

## Reporting

Report the ratio of checks passed and name every failure.
Never describe a front-end change as verified when only the markup was inspected; say plainly that it has not been rendered.
