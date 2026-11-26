---
name: ship-rubber-duck
description: Challenge a Ship plan before implementation or a Ship diff and its evidence before the review verdict.
user-invocable: true
---

# Ship rubber duck

Run once per settled plan and once per settled review.
Run inline from this file on any host.
When native skill loading is unavailable, open this file from the harness repository or its installed skills directory and follow it directly.
Use the full skill name to avoid ambiguity with built-in host commands.

## Planning

Read the request, verified premise, proposed scope, acceptance criteria, and validation plan.
Identify a credible way the plan could solve the wrong problem or satisfy its proposed checks while missing the requested outcome.
Trace that concern to a premise, requirement, scope boundary, or likely failure mode.
Check whether the plan includes an observable acceptance criterion and a discriminating check for that concern.
When the premise evidence supports only a narrower conclusion, verify it at the source and correct the plan.

## Review

Read the approved criteria, settled diff, and actual verification results, including their tested scope and revision.
Trace the highest-risk criterion through its entry point to the changed behavior and its proof.
Look for an omitted path, regression, or test gap that would let the current evidence pass while the behavior fails.
Run the smallest safe check that can resolve a material uncertainty when available.

## Result

Return a compact result with:

- **Phase and input** - planning or review, with the plan revision or the reviewed head and any uncommitted diff.
- **Challenge and evidence** - the failure scenario examined and the requirement, file, or check result that supports the finding.
- **Disposition** - `clear`, `revise` with a concrete correction, or `blocked` with the missing evidence or decision and the next action.

A `clear` result still requires a concrete challenge and the evidence that resolves it.
Reconcile material findings in the calling phase and rerun the affected check when its inputs change.
Ship owns the gates, and `/codereview` owns finding labels and the review verdict.
