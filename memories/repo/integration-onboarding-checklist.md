# Integration Onboarding Checklist

Template for standing up a new workspace's integrations. Reset the statuses per environment.

## 1) Confluence MCP access
- Status: Pending
- Verify: `GET /wiki/rest/api/space?limit=3` returns spaces
- Remaining: expose Atlassian MCP tools in the chat host and test a wiki search/read tool call

## 2) Platform / content API credentials
- Status: Pending
- Need: DEV/Sandbox API base URL + credential mechanism + a test resource endpoint

## 3) Observability dashboards
- Status: Pending
- Need: APM dashboard URL, or CloudWatch dashboard/log group mappings per service

## 4) Slack/Teams notification webhook
- Status: Pending
- Need: incoming webhook URL and desired message format/channel
