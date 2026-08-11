# Dev Tools Setup

## Jira + Confluence MCP routing
- A self-hosted/Data Center Jira needs the Jira Data Center MCP server; the Atlassian MCP server is for Confluence and for real Atlassian Cloud sites. Do not assume one server covers both.
- Set the instance URLs through `JIRA_URL` and `CONFLUENCE_URL`; credentials stay in Windows User or Process environment variables and never in files.
- Agent CLI config at `~/.copilot/mcp-config.json` (and Claude's `.mcp.json`) requires a top-level `mcpServers` key; VS Code user/workspace `mcp.json` uses top-level `servers`. Mixing these up is the most common silent misconfiguration.
- When an MCP server is registered read-only (`--read-only`), use a separately configured write-enabled server only when explicitly available.
- Until a required tracker MCP is configured, remind the user once per workstream without blocking unrelated local work.
- A direct probe (`mcp-atlassian --transport stdio`) confirms package transport only — not chat-host tool registration or a successful issue lookup. Verify the actual lookup before declaring it working.
- Never use GitKraken MCP tools for Jira or git operations.
- `.venv/` is gitignored - each developer must install independently.

## E2E Browser Testing (Playwright)
- Point Playwright at an already-installed Chrome rather than downloading a browser, which avoids corporate TLS interception blocking `cdn.playwright.dev`:
  `C:\Program Files\Google\Chrome\Application\chrome.exe`
- Override the path via env var: `CHROME_PATH=C:\path\to\chrome.exe`
- For SSO-protected targets, save an authenticated session to a gitignored `.auth/` file via a one-time interactive login task, then reuse it for headless runs. Expect to re-authenticate roughly every 8-24h.
- Build the application before running E2E against a built artifact.

## AWS CloudWatch
- `aws logs filter-log-events --log-group-name /aws/lambda/<function> --start-time $(date -d '1 hour ago' +%s000)`
- Credentials come from the existing refresh helper; no additional setup needed.

## Stash MCP
- Read-only adapter: `tools/msstash-mcp/server.mjs`; workspace registration in a gitignored local `.vscode/mcp.json`.
- Requires Node 20+; set `MSSTASH_TOKEN` in the launch environment, with optional `MSSTASH_USERNAME` and `MSSTASH_AUTH_MODE=basic` for Basic auth.
