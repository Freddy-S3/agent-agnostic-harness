---
name: research
description: "Investigate a question against high-trust primary sources and capture the findings as a Markdown file. Use when the user wants a topic researched, docs or API facts gathered, or claims verified before being relied on."
---

# Research Skill

## Workflow

### 1. Go to Primary Sources
- Investigate against **primary sources** — official docs, source code, specs, first-party APIs — not a secondary write-up of them.
- Use an available webpage or document-retrieval tool for official documentation and specs, an available repository-search tool for source-of-truth external code, and `semantic_search`/`grep_search`/`read_file` for facts that live in this workspace.
- If the needed external retrieval or repository-search tool is unavailable, report that limitation and request a source or access path instead of substituting an unsupported tool.
- Follow every claim back to the source that owns it. If a secondary source (blog post, forum answer, Stack Overflow) is the only thing available, say so explicitly and try to corroborate it against the primary source before trusting it.
- Prefer the smallest number of authoritative sources over many shallow ones.

### 2. Cite Every Claim
- Each finding must carry a citation: a link/path and line number for in-repo files, or the exact doc/spec title and section for external sources.
- Never state a fact without a source attached to it. If you can't find a source, mark the claim as unverified rather than dropping the caveat.
- Quote sparingly and precisely; paraphrase the rest, but keep the citation pointing at the exact section that supports the paraphrase.

### 3. Keep an Evidence Ledger
- While researching, track each claim as a row: **claim → source → confidence (confirmed / inferred / unverified)**.
- Confirmed: directly stated in a primary source you read.
- Inferred: derived by combining multiple confirmed facts or by reading code behavior rather than an explicit statement.
- Unverified: could not be traced to a primary source in the time available.
- Carry this ledger into the final Markdown output as a "Sources" or "Evidence" section so the reader can audit it.

### 4. Surface Uncertainty
- Do not smooth over conflicting sources — report the conflict and which source you weighted higher, and why.
- Flag anything time-sensitive (version-specific behavior, pricing, API limits) with the date you checked it.
- If a question can't be answered with available tools (paywalled docs, private APIs, no network access to a required host), say so plainly instead of guessing.

### 5. Capture Findings in Markdown
- Write the findings to a single Markdown file with a clear title, a short summary/answer up top, then supporting detail with citations, then the evidence ledger.
- Save it where the repo already keeps such notes; match the existing convention. If there is none, put it somewhere sensible under `docs/` (or the most relevant project folder) and say where you put it.
- Do not create a new Markdown file for research the user only wants as a chat answer — only write one when the user wants it captured for later reference or the investigation is substantial enough to be worth preserving.
