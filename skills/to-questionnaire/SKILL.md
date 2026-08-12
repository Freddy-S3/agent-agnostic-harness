---
name: to-questionnaire
description: Create an asynchronous discovery questionnaire for a knowledgeable recipient. Use when the missing context is held by someone other than Faruk and has to be gathered by sending them questions rather than by reading code.
user-invocable: true
---

Create a **discovery questionnaire** for a recipient who holds facts or context the user needs.

**Grill the send, not the subject.** Ask the user only what they can supply about the recipient and the outcome they need; write questions that target the gap between that and what the recipient knows.

1. Ask one concise exchange for only:
   - The recipient's name or role, relationship to the user, and relevant expertise.
   - The decisions or facts the user needs from the recipient, and how the answers will be used.
   - The target artifact location.
   Do not infer missing recipient facts.

2. Write the questionnaire to the confirmed location.
   State recipient facts only when the user supplied them.
   Turn every needed decision or fact into a question.
   Replace any request for passwords, tokens, API keys, credentials, or other secrets with a request for the responsible owner, system, and approved secret-management process.

3. Use this structure:

```md
# <Topic> Discovery Questionnaire

**Purpose:** <decision or outcome this discovery supports>

**To:** <recipient name or role>

**How your answers will be used:** <decision, plan, or artifact they inform>

## Context

<Brief, supplied context that helps the recipient answer.>

## Instructions

Answer asynchronously at your convenience.
<Optional: Please respond by <deadline>; this should take about <effort>.>
Short, partial answers and "I don't know" are useful.

## <Theme>

### <One single-concept question>

<Optional: _Why this matters: <why a substantive answer is needed.>_>

> [Answer]

## Anything else?

What else should we know to make this decision well?

> [Answer]
```

Group questions under concise themes and order each theme's questions by importance.
Keep each question to one concept, with an answer stub directly below it. Add a one-line "Why this matters" only when a question could be misread or invite a shallow answer.
Report the written artifact location when complete.