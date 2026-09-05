# Eval sets and the LLM judge

Every other check in this harness is binary and mechanical.
`check-rule-triggers.ps1` asks whether a path resolves.
`check-skill-caches.ps1` asks whether two files differ.
`check_resume.py` asks whether the PDF is one page.
`converge.ps1` asks whether a command exited zero.

None of them can answer the questions that actually decide whether the work is any good:

- Is this resume bullet honest?
- Can this queue item be acted on from a phone by someone who was not in the session that wrote it?
- Would this commit message read badly to a recruiter who finds it out of context?

Those have all routed through Faruk, one artifact at a time.
That is why he has personally been the QA step, and it is the gap this directory closes.

## The format

An eval set is a `*.eval.json` file in this directory:

```json
{
  "name": "resume-bullet-truthfulness",
  "aim": "What the artifact is being judged for, in prose.",
  "rubric": ["FAIL if ...", "PASS only if ...", "Do not fail merely for ..."],
  "cases": [
    {
      "id": "harness-80pct-deployment",
      "expect": "fail",
      "origin": "Portfolio-Website 78679a8, 2026-08-11. This bullet reached rendered PDFs.",
      "input": { "bullet": "...", "evidence": "..." }
    }
  ]
}
```

Four things about this shape are load-bearing.

**`expect` scores the judge, not only the artifact.**
A run reports where the judge disagreed with the expected verdict.
So a judge that rubber-stamps everything fails the run loudly, which is the entire point: a judge only ever observed passing is worthless.

**`origin` names the real incident.**
Every case in this directory is seeded from something that actually happened - a reverted commit, a queue item Faruk could not act on, a rule in `AGENTS.md` written after an incident.
A case nobody can trace to a real event is a case nobody can argue with when it later disagrees with them.
`tools/tests/judge.tests.ps1` rejects a case with no `origin`.

**`rubric` carries the counter-cases too.**
Each set has lines that say what must *not* fail, because a judge that fails everything is exactly as broken as one that passes everything, and only a mixed set detects it.
The register set, for example, must pass a blunt public description of a real crash and must pass candid private incident notes, because the register rule explicitly requires private records to stay candid.

**`input` is free-form.**
It is serialised to JSON and handed to the judge whole. A truthfulness case carries a bullet and its evidence; a queue case carries a description and options; a register case carries the text and the surface it appears on.

## The sets

| Set | Judges | Seeded from |
|---|---|---|
| `resume-bullet-truthfulness` | A bullet against its evidence: invented metrics, unconfirmed scale, activated commented drafts | Portfolio-Website `78679a8` / `c55e22c`, 2026-08-11 - the 80% deployment-time bullet that reached rendered PDFs |
| `queue-item-self-containedness` | Whether a blocked item can be acted on cold, on a phone | The QUEUE-PC resume page-count item, whose description was the log entry referring to "the four fixes" without naming them |
| `public-language-register` | Public text for loaded words and character attribution | The register rule in `AGENTS.md`, which names `fabricated` as the canonical loaded word |

## Running it

```powershell
tools\judge.ps1 -EvalSet evals\resume-bullet-truthfulness.eval.json
tools\judge.ps1 -All
tools\judge.ps1 -EvalSet evals\public-language-register.eval.json -DryRun
tools\judge.ps1 -EvalSet evals\queue-item-self-containedness.eval.json -CaseId four-fixes-unnamed
```

`-DryRun` renders the prompts and invokes nothing, so you can read what would be sent before paying for it.
`-JudgeCommand` swaps the judge; the default is `claude -p` and the prompt arrives on stdin.

## Where it runs, and what it costs

**Deliberately not in `install.ps1`, and not in a git hook.**
It makes one network call per case and costs real money.
A gate that bills on every commit is a gate that gets disabled, and a disabled gate is worse than no gate because people believe it is running.

Run it at these four moments:

| When | Which set |
|---|---|
| Before publishing or exporting resume content | `resume-bullet-truthfulness` |
| In `/closing`, when the session wrote queue items | `queue-item-self-containedness` |
| Before a commit message or PR body goes to a public repository | `public-language-register` |
| After editing any rubric | `-All` |

That last row matters most and is the least obvious.
Editing a rubric is editing the test.
Ng's point: you have to evaluate the tests to ensure they correspond to your aims, and you will evolve them if not.
The expected verdicts are the mechanism by which this harness notices that a rubric has stopped corresponding to its aim - and it has already earned that.
The first run of `resume-bullet-truthfulness` reported a miss on `harness-iac-no-metric`: the judge failed a bullet the case expected to pass, on the grounds that the evidence described the text as sitting in a commented draft block.
The judge was right and the case was mislabelled.
The case was fixed; the rubric was not touched.

**Cost.** One invocation per case. The 15 cases here render prompts of roughly 2,000 characters, so on the order of 600-900 input tokens and under 200 output tokens each.
On Sonnet that is a fraction of a cent per case and a few cents for `-All`; on Opus, a few times that.
Cost scales linearly with case count, so a single set is the normal invocation and `-All` is the rubric-change invocation.

## Testing the harness itself

```powershell
tools\tests\judge.tests.ps1
```

45 assertions, no network calls, nothing billed.
The tests stub the judge and drive `judge.ps1` into every state where it must report a problem: a judge that passes everything, one that fails everything, one that answers in prose, one that returns nothing, one that does not exist, a set with an empty rubric, a case with no expected verdict, a case with no origin.
There is also an honest control - a stub that answers both fixture cases correctly - because without it every one of those assertions would be satisfied by a harness that simply never passes anything.
