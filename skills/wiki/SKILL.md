---
name: wiki
description: "Create or edit Confluence pages in valid storage-format HTML using Freddy's concise wiki templates and formatting rules."
user-invocable: true
---

# Wiki Writing Skill

Use this guide when creating or editing Confluence wiki pages for Freddy.

All output should be valid Confluence storage format (HTML).
When editing an existing wiki, output the full document - not just the modified section.

## Source of Truth

When Atlassian MCP tools are available, fetch and read the current Confluence page before editing.
Treat the fetched page as authoritative over memory or assumptions.

If Atlassian MCP tools are not available, ask the user to attach the current page content or a link export before drafting edits.

---

## Visual Assets

- Treat a user-supplied chart as the visual authority. Use its original file or a source-native export; never substitute a browser page or viewport screenshot.
- For a public source chart, capture or export only the full chart bounds at its intended aspect ratio. If the visual result cannot be validated, ask for the source image instead of uploading an approximation.
- Upload, replace, and remove Confluence attachments through MCP. After updating the full page body, read it back to verify the exact attachment filename before deleting stale assets.

---

## Writing Style

**Be concise. Do not info dump.**

Every section should contain only what the reader needs to act or decide. If it doesn't help them, cut it.

### Length targets

| Section | Target length |
|---|---|
| Context | 2–4 sentences. State what, why, and what options are being compared — nothing else. |
| Table cells | 1–3 sentences or a short bullet list. No multi-paragraph essays in cells. |
| Challenges | One sentence per bullet. Bold the key term, state the risk, done. |
| Questions | One sentence per bullet. No preamble. |
| Recommendation | 2–4 sentences. Lead with the decision, follow with the single strongest reason. |
| Conclusion | 2–3 sentences. State the decision plainly. Do not restate what the Summary table already said. |

### Anti-patterns to avoid

- **Restating the heading** — Don't open a section by repeating what the heading already says. (Bad: "This section compares the two options." The heading already says "Comparison".)
- **Duplicating across sections** — If Pros/Cons covers it, don't repeat it in Recommendation or Conclusion.
- **Padding table cells** — If a cell only needs one sentence, write one sentence. Don't fill space.
- **Over-explaining obvious tradeoffs** — "We own all maintenance" is enough. Don't expand into a paragraph about what S3 lifecycle policies are.
- **Hedging conclusions** — If a decision has been made, state it cleanly. Remove "awaiting" or "TBD" language once resolved.
- **Listing every possible option when only 2–3 matter** — Trim options tables to what's actually under consideration.

### What good looks like (from real examples)

- Context: *"We want to add AI-powered audio generation to our platform — letting us convert articles into audio. This investigation compares two approaches: [A] and [B]."*
- Recommendation: *"We recommend Option A, with the expectation we will switch to ElevenLabs upon gaining traction. While building Option A, we will keep the code interchangeable with different voice vendors."*
- Conclusion: *"We will go with a Custom Build. We will be going with Amazon Polly + the in-house audio service."*
- Bullet: *"Character limits — ElevenLabs v3 caps at 5K chars/request. Long articles need chunking, which can introduce tone shifts."*

---

## Choosing the Right Template

| If the wiki is about... | Use template |
|---|---|
| Researching something new, evaluating options, or presenting findings to stakeholders | **Research Wiki** |
| Documenting how something already works, a pipeline, a workflow, or an implemented feature | **Documentation Wiki** |

---

## Template 1: Research Wiki

Use for: investigating a new technology, evaluating providers/vendors, spike tickets, answering stakeholder questions.

Sections:
- **Related Tickets** - Jira macro link
- **Table of Contents** - TOC macro (H2 only, outline style)
- **Context** - 2–4 sentences: what is being investigated, why, and what two or three options are being compared. No history or background padding.
- **Cross-Comparison** (optional) - Tables grouped by theme (e.g. Speed, Security, Cost). Each cell: 1–3 sentences or bullet points. No prose paragraphs in cells.
- **Architecture Overview** (optional) - One short paragraph per option describing the data flow. Include a diagram macro if one exists.
- **Cost** (optional) - Numbers in a table. Short prose only if a cost tradeoff needs explaining.
- **Questions** - Bullet list of specific open questions. One sentence each.
- **Challenges** - Bullet list. Bold key term, one sentence of explanation. No sub-bullets.
- **Handling Procedures** (optional) - If there are specific cases to document with decisions/recommendations, use a wrapped table with columns: Component | Details | Recommendation.
- **Decisions Needed from Stakeholders** (optional) - Numbered table of open questions with options listed as `a) / b) / c)`.
- **Summary: Pros & Cons** - One Pros/Cons table per option. Use short bullet points, not sentences.
- **Recommendation** - 2–4 sentences. Lead with the recommendation, follow with the single strongest justification.
- **Conclusion** - 2–3 sentences. State the final decision. Do not restate what Summary or Recommendation already covered. Include "To be updated with the decisions from stakeholders" only when decisions are genuinely still pending.
- **Notes & Comments** - Links to test articles, staging URLs, or relevant references.
- **Viewtracker macro** at the bottom.

```html
<p>Related Tickets: [JIRA MACRO]</p>

<h2><u>Table of contents</u></h2>
<p>
  <ac:structured-macro ac:name="toc">
    <ac:parameter ac:name="maxLevel">2</ac:parameter>
    <ac:parameter ac:name="minLevel">2</ac:parameter>
    <ac:parameter ac:name="outline">true</ac:parameter>
    <ac:parameter ac:name="exclude">^(Table of contents$).*</ac:parameter>
    <ac:parameter ac:name="style">none</ac:parameter>
  </ac:structured-macro>
</p>

<h2><u>Context</u></h2>
<p>WIP</p>

<h2><u>Questions</u></h2>
<p></p>

<h2><u>Challenges</u></h2>
<p>WIP</p>

<h2><u>Summary: Pros &amp; Cons</u></h2>
<p>WIP</p>

<p><u>
  <ac:structured-macro ac:name="viewtracker"/>
</u></p>
```

---

## Template 2: Documentation Wiki

Use for: documenting an implemented feature, a pipeline, a workflow, non-standard case handling, or a how-to guide.

Sections:
- **Related Tickets** - Jira macro link
- **Table of Contents** - TOC macro
- **Context** - 2–4 sentences: what this documents, why it exists, and what the key constraint or approach is. No history padding.
- **Handling Procedures** - The core content. Use wrapped tables organized by category. Each table has columns: Component | Details | Recommendation/Options. Keep cells tight — 1–3 sentences or a short list. Numbered `<ol>` for multiple options within a cell.
- **Example Articles** (optional) - Table of real article URLs with "Relevant Cases" column. Useful when testing is involved.
- **Challenges** - Bullet list only if there are real blockers. Bold key term, one sentence. Skip if there's nothing substantive.
- **Decisions Needed from Stakeholders** (optional) - Only include if decisions are genuinely open. Remove once resolved.
- **Notes & Comments** - Links to test articles, staging URLs, or relevant references.
- **Viewtracker macro** at the bottom.

No Summary/Pros & Cons, no Recommendation sections unless options were genuinely compared.

```html
<p>Related Tickets: [JIRA MACRO]</p>

<h2><u>Table of contents</u></h2>
<p>
  <ac:structured-macro ac:name="toc">
    <ac:parameter ac:name="maxLevel">2</ac:parameter>
    <ac:parameter ac:name="minLevel">2</ac:parameter>
    <ac:parameter ac:name="outline">true</ac:parameter>
    <ac:parameter ac:name="exclude">^(Table of contents$).*</ac:parameter>
    <ac:parameter ac:name="style">none</ac:parameter>
  </ac:structured-macro>
</p>

<h2><u>Context</u></h2>
<p></p>

<h2><u>Handling Procedures</u></h2>
<h3>[Category Name]</h3>
<table class="wrapped">
  <colgroup><col/><col/><col/></colgroup>
  <tbody>
    <tr>
      <th>Component</th>
      <th>Details</th>
      <th>Recommendation</th>
    </tr>
    <tr>
      <td><strong>Example</strong></td>
      <td>Description</td>
      <td>What to do</td>
    </tr>
  </tbody>
</table>

<h2><u>Notes &amp; Comments</u></h2>
<p></p>

<p><u>
  <ac:structured-macro ac:name="viewtracker"/>
</u></p>
```

---

## Shared Formatting Rules

- Use `<table class="wrapped">` for all tables.
- Use `<strong>` for component names in the first column of procedure tables.
- Use `<code>` for inline code references (class names, field names, constants).
- Use `<ol>` for numbered options within a table cell.
- Use `<u>` on all `<h2>` section headings.
- When a cell has multiple paragraphs, wrap each in `<p>` tags.
- Use `&amp;` for `&` in HTML content.
- Jira macro format:
```html
<ac:structured-macro ac:name="jira">
  <ac:parameter ac:name="server">&lt;configured Jira server name&gt;</ac:parameter>
  <ac:parameter ac:name="serverId">&lt;configured Jira serverId GUID&gt;</ac:parameter>
  <ac:parameter ac:name="key">&lt;PROJECT&gt;-XXXX</ac:parameter>
</ac:structured-macro>
```

---

## Architecture Diagram

After generating a **Documentation Wiki** for a pipeline, workflow, or implemented feature that has meaningful component interactions, also output an architecture diagram using the `ArchitectureDiagram` skill.

Rules:
- Output the diagram **after** the wiki HTML, separated by a visible heading so the user knows where to copy from.
- Do **not** embed the diagram inside the wiki HTML. It is for the user to copy separately.
- Only produce the diagram if the wiki documents a system with real data flow (not a purely procedural how-to guide).
- Use this exact separator so the user can clearly see the boundary:

```
---
## Architecture Diagram (copy separately - do not paste into Confluence)
```
