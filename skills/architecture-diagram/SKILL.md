---
name: architecture-diagram
description: "Produce a Mermaid architecture diagram when the user asks to visualize a real system or codebase."
user-invocable: true
---

# Architecture Diagram Skill

Use this skill when asked to produce an architecture diagram.
Output a single Mermaid `flowchart LR` code block that the user can copy directly into Confluence, Notion, or any Mermaid renderer.
Do NOT output plain-text component lists, Gliffy references, draw.io XML, or any other format.

---

## Output Format

Output exactly this structure:

````
**[Diagram Title]**

```mermaid
flowchart LR
  %% classDef declarations first
  %% subgraphs / swim lanes
  %% connections
  %% class assignments last
```
````

---

## Orientation and Layout

- Always use `flowchart LR` (left-to-right). This is the default and preferred orientation.
- Only switch to `flowchart TD` if the user explicitly asks for top-down.
- Break the diagram into **named swim lanes** using `subgraph` when the system has distinct phases or tracks (e.g. "Generate Preview" and "Save to ARC").
- Each swim lane should read left-to-right on its own — avoid back-arrows within a lane.
- Keep the diagram at **one level of abstraction**. Do not mix internal implementation details with high-level system components in the same diagram.

---

## Numbered Steps

Number the primary action nodes sequentially so the reader can follow the flow.
Put the step number at the start of the node label:

```
G1["1. Content API\nfetch article draft"]
G2{{"2. LLM service\ngenerate SSML"}}
```

Number across the entire diagram in flow order, not per swim lane.

---

## Node Shape Vocabulary

| Type | Mermaid syntax | Use for |
|---|---|---|
| Rectangle | `ID["label"]` | Internal service, API, module |
| Rounded rectangle | `ID("label")` | User-facing UI, browser client, START/END |
| Stadium / pill | `ID(["label"])` | External SaaS or third-party API |
| Cylinder | `ID[("label")]` | Database or data store |
| Parallelogram | `ID[/"label"/]` | File, config, or artifact |
| Hexagon | `ID{{"label"}}` | AI / ML service |

---

## Subgraphs

Group related nodes using `subgraph` to create swim lanes or logical boundaries.
Always give subgraphs a short, readable title.
Use `direction LR` inside a subgraph to enforce left-to-right layout within it.

```
subgraph GENERATE["GENERATE PREVIEW"]
  direction LR
  G1["1. Content API\nfetch draft"] --> G2{{"2. LLM service\nSSML"}} --> G3{{"3. TTS service\nMP3"}}
end
```

---

## Arrow Vocabulary

| Flow type | Mermaid syntax |
|---|---|
| Synchronous call | `A -->|label| B` |
| Request + response (combined) | `A <-->|label| B` |
| Async / event-driven | `A -.->|label| B` |
| Data / artifact write | `A ==>|label| B` |

- Use `<-->` for request-response pairs where showing both directions would clutter the diagram.
- Use `-.->` for async flows (polling, callbacks, events).
- Keep arrow labels to 3-6 words.

---

## START and END Points

Always include explicit START and END nodes using rounded rectangles:

```
START(["START\nBrowser Extension"])
END(["END\nArticle Draft (ANS)"])
```

Label START/END clearly so the reader knows where the flow begins and terminates.

---

## Colors (classDef)

Declare all `classDef` blocks at the **top** of the diagram (before subgraphs), and apply them with `class NodeId ClassName` at the **bottom**:

```
classDef internal fill:#4A90D9,stroke:#2C6FAC,color:#fff
classDef external fill:#E8943A,stroke:#C4722A,color:#fff
classDef ai      fill:#9B59B6,stroke:#7D3C98,color:#fff
classDef store   fill:#27AE60,stroke:#1E8449,color:#fff
classDef ui      fill:#ECF0F1,stroke:#95A5A6,color:#333
```

Color intent:
- `internal` - internal service or API (blue)
- `external` - external cloud service or third-party API (orange)
- `ai` - AI / ML service (purple)
- `store` - data store or persistence (green)
- `ui` - user-facing UI or browser client (light gray)

---

## Rules

- Every node must appear in at least one connection.
- Every connection must reference nodes defined in the diagram.
- Do not invent nodes or connections that are not real in the codebase/system.
- Do not add a legend unless the user asks for one.
- Number the primary action steps sequentially across the whole diagram.
- Use swim lanes when the system has two or more distinct sequential phases.
- Always include explicit START and END nodes.
