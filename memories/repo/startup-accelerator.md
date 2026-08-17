# Engineering Workflow Accelerator

## Product model
- Jira is the intake signal for an asynchronous first implementation.
- The Faruk skill is a restricted first-pass variant of Freddy: it reads a ready Jira ticket and produces an initial draft PR without broad engineering, merge, deployment, or production permissions.
- Engineers review and test that first draft themselves.
- If the first draft needs changes, engineers run Freddy for a permissioned second implementation pass and continue through the normal review workflow.
- A weekly skill can turn completed Jira tickets into automated documentation and publish or update pages in the customer's Confluence or other documentation system through the relevant MCP server.

## Positioning
- The service accelerates teams toward an engineer workflow centered on reviewing, testing, and directing AI-produced changes rather than starting every implementation from an empty branch.
- The first release should measure time from ticket readiness to draft PR, usable first-draft rate, engineer rework, review cycles, documentation coverage, and model cost per ticket.
