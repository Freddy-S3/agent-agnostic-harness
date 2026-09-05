# Premise interrogation

Read this before starting substantial delivery-mode work, and any time a task arrives carrying a stated fact you did not verify yourself.

The plan is not the first thing to check. The premise is.

A plan can be flawless and still produce a wasted day, because planning takes the task's framing as given and optimises inside it. Every failure below passed planning cleanly. None of them would have survived one question about the premise.

## What this catches, from the record

**A company reported dead that was hiring.** A job posting was marked gone and the employer written off. The company had 42 open roles at the time. The premise was "the posting 404s, therefore the company is not hiring"; the question is *does the evidence support the conclusion drawn from it, or only a narrower one?*

**A resume investigated on a checkout 29 commits behind.** Several tool calls of analysis ran against a working tree missing the file under discussion, and concluded the file did not exist. The premise was "the working tree reflects the repository"; the question is *am I looking at current state, and how would I know if I were not?*

**Discovery reporting zero matches from a hardcoded list of five boards.** "No matching roles" was reported as a fact about the market. It was a fact about five URLs in a config file. The premise was "the search covered the space"; the question is *what is the actual denominator here?*

The shape is the same in all three: a narrow, true observation was promoted to a broad conclusion, and nothing in the plan-review step was looking at the promotion.

## The required step

Before Gate 1 in delivery mode, and before starting any substantial piece of personal-mode work, state the interrogation explicitly. It is four questions, and it is short - a few lines, not a session.

1. **What must be true for this task to be worth doing?** Name the premise in one sentence. If the task arrived with a stated fact - this is broken, this is missing, this is gone, nobody is hiring - that is the premise.
2. **How was that established, and by whom?** A thing you verified this session is different from a thing a previous session reported, which is different from a thing inferred from an absence. An absence of evidence is the weakest of the three and the one that reads most like fact.
3. **What is the cheapest check that would falsify it?** Usually one command. `git fetch && git status`, one URL, one grep for the denominator. If falsifying the premise costs less than the first hour of the work, run it before the work rather than after.
4. **What is being taken as scope that could be dropped?** The overengineering question. Which part of this is here because it was asked for, and which because it seemed to follow?

Then answer the security question if the change touches auth, credentials, permissions, published output, or anything that leaves the machine: **what does this let someone do that they could not do before?**

## Where it is written down

In delivery mode, the answers go in the Gate 1 output under `Premise`, so Faruk sees what the work is standing on before he replies `proceed`. A premise that turned out to be false and changed the task goes in the ledger, because that is a finding, not a detour.

In personal mode, state it in a line or two and keep going - no gate, no ceremony. It still gets stated, because the cost of the question is seconds and the failures above each cost hours.

## When to escalate to a full grilling

The four questions are the floor. Run `/grilling` - which routes to `/grill-me`, or `/grill-with-docs` when decisions worth recording are likely to crystallise - when any of these hold:

- The premise cannot be checked cheaply, so the work has to proceed on an assumption.
- The task's framing has been stable across several sessions and nobody has re-derived it.
- The work is large enough that being wrong about the premise costs more than a day.
- Two premises conflict and the task assumes one without saying so.

All three grill skills are model-invocable, so this routing works without the user typing a slash command. That was verified rather than assumed: none of `skills/grilling`, `skills/grill-me` or `skills/grill-with-docs` carries `disable-model-invocation`, so nothing blocks a router from reaching them. If a future edit adds that key to any of them, this routing silently stops working and this paragraph becomes wrong - `tools/check-router-contract.ps1` is where that would be caught.

## The thing this rule is not

It is not a licence to relitigate a decision Faruk has already made. Interrogating a premise means checking whether the facts the task rests on are true, not whether the task is a good idea. When the premise holds, say so in one line and get on with the work; when it does not, say what is actually true and what that changes, then keep going under the corrected premise rather than stopping to ask.
