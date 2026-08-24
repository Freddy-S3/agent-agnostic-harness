# Ticket-Backed and Review Work

Read this when a task is backed by a Jira ticket or Confluence page, or when reviewing a pull request.

- For a request to complete a ticket, authenticate using MCP to the configured Jira instance (`JIRA_URL`) and Confluence instance (`CONFLUENCE_URL`) before planning or implementation; if either authentication fails, stop immediately and do not proceed. When neither is configured, treat the work as ticketless and stay local rather than blocking.
- When retrieving any Jira ticket, request and read all comments as part of the requirements before planning or implementing.
- Treat ticket comments as acceptance criteria, and surface conflicts between a comment and the ticket description before proceeding.
- For every pull request review, retrieve and read all available comments and activity before forming findings; treat them as review context and acceptance criteria.
