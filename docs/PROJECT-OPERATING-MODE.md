# Portable Project Operating Model

This is the cross-host convention for keeping business work organized without making a
ChatGPT Project, Claude Code session, or Codex checkout the source of truth.

The goal is one lightweight control center, one host Project per durable business or
domain, one coordination chat in each Project, and one outcome per working chat.

## The hierarchy

| Layer | Use it for | Durable source of truth |
| --- | --- | --- |
| `00 Control Center` | Global priorities, queue status, routing, and calls that affect more than one project | The queue, dashboard, and tracker |
| Host Project | Stable instructions, reference sources, and the identity of one business or domain | The repository, project brief, queue, and pull requests |
| `00 Main - Coordination` | The current project map, open decisions, and links to active outcomes | A short summary written back to the project brief or tracker |
| Outcome chat | One distinct deliverable, decision, investigation, or review | The changed files, research note, issue, or PR |
| Repository and worktree | The actual implementation boundary | Git history and the checked-out files |

The control center should stay lightweight. It routes work and reports state; it is not a
second place to keep a long implementation transcript.

## Recommended host setup

Create these once in the host that provides Projects, then use the same names wherever a
different host offers an equivalent container:

- One standalone chat named `00 Control Center`.
- One Project for `Agent Harness & Queue`.
- One Project for `Career & Job Search`.
- One Project for `Portfolio Website`.
- One Project for each separate business or product domain.

The exact number of business Projects can change. A Project is a durable context boundary,
not a repository count. A business with several sibling repositories can keep one Project,
while each coding outcome still declares exactly one active repository root.

Inside every Project, create `00 Main - Coordination` first. Start a new chat for every
distinct outcome, for example `Outcome - Add job-tier dashboard` or
`Outcome - Review checkout reliability`. When an outcome finishes, put its decision and
links into the durable source of truth and let the outcome chat become historical context.

## Repository boundaries

Start a coding host in the exact repository root that owns the outcome. A repository with
several internal folders, such as `Portfolio-Website`, is one project boundary; its folders
are not separate Projects or conversations.

Separate sibling repositories get separate worktrees when their changes can proceed
independently. A swarm worktree is an execution copy, not a new business Project. Never
run two writing agents in the same worktree.

## Portability across hosts

The harness is portable because the durable instructions, project briefs, queue entries,
and PRs live in files and Git. The host Project itself is not portable account state:

- ChatGPT Projects and their chats are created and maintained in the ChatGPT account UI.
- Claude Code and Codex can reuse the same harness and repositories, but they do not
  automatically see ChatGPT Project chats.
- Project sources or uploads are convenience context. They must not replace a checked-in
  brief, a queue entry, or a PR when the information matters later.

Use the same Project name and `00 Main - Coordination` convention across hosts, then start
each coding session from the matching repository root. This gives every host the same
operating shape without pretending that one host can create or synchronize another host's
account-level Projects.

## Project instruction template

Paste and adapt this into each host Project's instructions:

```text
This Project is [PROJECT NAME].
Use it for [BUSINESS OR DOMAIN PURPOSE].

Coordination:
- Keep 00 Main - Coordination short and current.
- Start a new chat for each distinct outcome.
- End each outcome by recording the decision, artifact, or PR in the durable source of truth.

Source of truth:
- Repository roots: [ABSOLUTE OR HOST-APPROPRIATE PATHS]
- Project brief or context file: [PATH OR LINK]
- Queue/dashboard: [PATH OR LINK]
- Active PRs or tracker: [LINKS]

Execution:
- Work from the exact repository root that owns the outcome.
- Default to one agent and one active writing agent per worktree.
- Spawn agents only for independent, bounded work, or when explicitly requested.
- If parallel work is justified, use isolated worktrees and keep the total at three agents or fewer.
```

## Swarm policy

The current policy is deliberately conservative:

1. Do not spawn an agent for a small, serial, or easily verified task.
2. Use one task owner and one active writer per project/worktree by default.
3. Spawn only when the work is complex and independently bounded, or when Faruk asks for it.
4. Fan out read-only investigation when useful, but serialize writes to shared state.
5. If parallelism is justified, cap it at three agents until the policy is deliberately changed.

This is a harness policy, not an account-level switch. The host may expose its own swarm
setting, but installing this repository cannot change ChatGPT or another host's account
configuration automatically.

## Setup and reinstall checkpoint

After installing the harness on a new machine or a new host:

1. Install the harness and restart the host so its instructions are rediscovered.
2. Verify the host Project names and each `00 Main - Coordination` chat.
3. Verify that each coding session starts in the matching repository root.
4. Confirm the one-agent default and the three-agent maximum for exceptional parallel work.
5. Tell the control center that the Project map is verified.

The first setup still requires manual creation of the host Projects and chats. The harness
keeps this checkpoint visible and preserves the operating rules, but it cannot create
account-level UI objects or transfer their chat history between hosts.
