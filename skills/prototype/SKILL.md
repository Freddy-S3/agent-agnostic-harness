---
name: prototype
description: Create a throwaway runnable prototype that answers one design question. Use when a design choice needs evidence from running code rather than reasoning, and the code is meant to be discarded afterwards.
user-invocable: true
---

# Prototype

Build throwaway code to answer one explicit question.

1. State the question at the top as `Answering: <question>`.
   Ask the user to clarify if it does not clearly concern either logic or UI.
2. Choose one branch.
   - **Logic:** Answer whether a state model or behavior feels right.
     Build the smallest interactive artifact that drives difficult cases, such as one standalone HTML file with controls and guided cases.
   - **UI:** Answer what an interface should look like.
     Build one isolated page with several meaningfully different variations and a visible switch between them.
3. Mark the artifact `PROTOTYPE - THROWAWAY` in a prominent visible place.
   Create it in the OS temporary directory by default.
   Use a project-local location only when the user explicitly requests a project-local prototype.
4. Make it runnable with one obvious action, such as opening the HTML file or running one documented local command.
   Keep state in memory unless persistence is the question being tested.
   After every logic action or UI variation change, render the full relevant state.
5. Use only synthetic, non-sensitive data.
   Keep the work local: never use secrets or production data.
6. After the prototype is validated, capture only the validated decision and the question it answered in the relevant existing work item or document.
   Preview and get explicit confirmation before modifying a tracker work item; for internal Jira, use the Jira Data Center MCP only.
   Do not create a branch or commit automatically.