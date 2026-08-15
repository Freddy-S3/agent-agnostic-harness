---
name: polish
description: "Pre-ship quality gate for a web surface. Use before shipping or reviewing any page, or when a rendered defect reached a real visitor, to sweep the whole surface for controls that do nothing, elements that collide, links that go nowhere, and images that do not load."
user-invocable: true
---

# Polish

A page can pass every test in the suite and still be visibly broken to the person looking at it.
That is not a hypothetical: the portfolio's primary button did nothing when pressed, and two badges collided, while a real Playwright suite reported 37/37.
Both defects were found by Faruk on the live site during a job search.

This skill is the sweep that would have caught them.
It runs over a **whole surface**, not the diff, and it asserts **effect and geometry**, not presence and wiring.

`/browsertest` owns how to drive a browser: engine choice, setup, breakpoint sweeps, the debugging moves when an assertion fails.
This skill owns what to sweep for and what to do with what it finds.
Load `/browsertest` for the mechanics; do not restate them here.

## When this fires

- Before shipping any change to a page a real person will look at.
- When reviewing a front-end PR.
- Immediately after any rendered defect is reported by a human. One reported defect means the class is unguarded, so sweep the class, not the instance.

## The rule that makes it worth running

**Assert effect, not existence.**
Every defect class below shares one property: the element is present, styled, and correct in isolation.
Nothing that inspects markup, counts elements, or confirms a listener is attached can see any of them.

## The sweep

Run every item over the entire surface - each section, at desktop and at 375px, in both themes.
A collision that only appears at 375px, or only in light mode, is still one a visitor sees.

1. **Every control does something.** Click it and require the page to observably change. Fingerprint before and after: active section, body class, the text of result regions, field values, state classes, the hash.
2. **Every control is clicked from a state it is not already in.** A pre-selected chip or the current nav item correctly changes nothing. "Already in the target state" is not "does nothing", and a check that cannot tell them apart will cry wolf.
3. **The cold arrival state is tested.** The state a visitor lands in is the one most likely to be broken and least likely to be tested. Reload before asserting it - a control pressed after some earlier result is on screen can pass while the same press on arrival does nothing.
4. **Nothing collides.** Bounding-box intersection across sibling groups: badges, cards, chips, buttons, stats.
5. **No link goes nowhere.** No `href=""`, no `href="#"`. Every local href resolves to a real file on disk. Where markup is generated, fix the generator so a missing URL emits a non-link element rather than a placeholder `#`.
6. **Every inline `on*` handler resolves.** Run it and require the function it names to exist. A handler defined inside an IIFE is not reachable as a global and throws on every press, while appearing to work because a separate listener does the real job.
7. **No form posts into the void.** A form with no backend, or one relying on `mailto:`, silently swallows what people send it. Check where it actually posts before trusting it.
8. **The console is clean after every interaction.** Register a `pageerror` listener as well as a console one - an uncaught exception in a click handler never reaches `page.on("console")` and would leave the suite green.
9. **Images decode and carry meaningful alt.** `!complete || naturalWidth === 0` for decode; a null, empty, or two-character alt is not a description.

## Geometry needs two calibrations or it does not work

Both of these silently disabled the check when it was first written, and both were found by constructing the failure rather than by re-reading the assertion.

- **Strict intersection is not enough.** Two pills that touch at exactly 0px do not intersect, and read as one collided blob. That was the reported defect, and an intersection-only predicate scored it clean. Flag insufficient *clearance* on the axis the elements are stacked along, not just overlap.
- **Freeze transitions before measuring.** A box measured mid-transition reports a position it is on its way out of - 2px of clearance against a declared 8px gap. Inject a stylesheet disabling `transition` and `animation` before any geometry assertion.

One more, for the interaction checks: **exclude `document.activeElement` from the fingerprint.**
Clicking a button moves focus to it by definition, so including it makes every click look effective.
That single field let a dead button pass.

## Calibrate against false positives, deliberately

A check that reports defects that are not defects gets muted, and a muted check is worse than none.
Exclude, and say why in the code:

- Elements in a vertical list abut by design. Rows are not colliding pills.
- Absolutely positioned and fixed elements are meant to sit on top of things; the fixed-overlay check in `/browsertest` covers those separately.
- An ancestor always contains its descendant.

State each exclusion where the check lives, with the reason. An unexplained exclusion is indistinguishable from a bug next time someone reads it.

## Prove every guard before trusting it

**A guard that has only been observed passing has not been tested.**

For each new check, reintroduce the defect it was written for and confirm the suite goes red, then restore and confirm green.
Do this per guard, not once for the batch, and watch for a defect that is no longer a defect: if a second fix independently covers the same symptom, reverting only the first proves nothing.

Report the verification as a table of defect reintroduced against result.
A green suite is not evidence; a suite that went red on demand is.

## Fix, or report

Fix what is functional: a control that does nothing, a link to nowhere, a form with no backend, a missing alt, elements that collide.

Report rather than fix:

- Anything requiring an account, a paid service, or a credential. Never sign up for something on Faruk's behalf; list the options and let him choose.
- Anything that is a matter of taste rather than function, or that would restructure layout while a design pass is open. Put it in the report so it reaches whoever owns that work.
- Anything needing content only Faruk has - a real credential URL, the right copy.

Say plainly which findings are which. A defect list that mixes "fixed" with "needs you" leaves both unactioned.

## Reporting

Give the defect list with each item's location, then the fixed-versus-needs-you split, then the guard verification table.
Never describe a surface as polished when only the markup was read; if it was not rendered, say so.
