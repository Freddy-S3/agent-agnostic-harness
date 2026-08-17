# Chat Continuity Guide

These templates are optional convenience context for host chats.
The repository, queue, tracker, and pull requests remain the source of truth across Codex, Claude Code, ChatGPT, and other hosts.

Use `AGENTS.md` for repository rules, `docs/PROJECT-CONTEXT.md` for stable project facts and setup, and `docs/CHAT-HANDOFF.md` for the latest generated continuation state.

## Global control-center chat

Paste this once into `00 Control Center`:

```text
Use this chat only for global routing, priorities, blockers, and decisions that affect more than one project.

When I ask what to do next, inspect the queue, tracker, active pull requests, and project coordination records before recommending work.
Route each request to exactly one owning project and repository unless it genuinely crosses project boundaries.
Keep responses concise and give me one recommended next action.
For an unanswered decision, ask one focused question or provide two or three complete options, then persist the decision to the dashboard queue.
Do not use this chat as the implementation transcript.

Continuity rules:
- Keep this chat open as the durable global index.
- Start a new outcome chat when a topic becomes a substantial implementation, investigation, or business-planning effort.
- Do not reset or archive this chat unless its context becomes confusing or the host becomes slow.
- If resetting it, paste this template into the new chat and ask it to read the repository, queue, tracker, and project map before continuing.
- Archive completed outcome chats after their result has been summarized in the owning project's coordination chat and durable files.
```

## Project coordination chat

Paste this once into each project's `00 Main - Coordination` chat, replacing the placeholders:

```text
This chat is the durable coordination index for [PROJECT NAME].

Owning repository:
[REPOSITORY PATH]

Keep this chat short and current. Track the project's goals, active outcome chats, settled decisions, open blockers, relevant files and pull requests, and the next recommended action.

Start a new chat for each distinct outcome. When an outcome finishes, summarize its result here and record the durable decision, artifact, issue, or pull request in the repository or tracker.

Continuity rules:
- Keep this coordination chat open while the project is active.
- Do not use it for a long implementation transcript.
- Reset it only when the index becomes stale or confusing; before resetting, ask the current chat for a concise current-state summary and paste that summary into the replacement chat.
- Archive completed outcome chats only after their result is recorded here.
- Keep repository files, queue entries, trackers, and pull requests authoritative over chat memory.
```

## Outcome chats

Name each chat for one result, such as `Outcome - Improve checkout` or `Outcome - Refresh resume`.
At the start, identify the owning repository and definition of done.
At the end, ask for a concise handoff containing what changed, verification, remaining risk, and the next action.
Then copy the result into the project's `00 Main - Coordination` chat if it changes the project map.

## Reset and archive policy

- Keep `00 Control Center` and each `00 Main - Coordination` chat as long-lived indexes.
- Start a replacement only when the index is stale, too long, or contaminated by unrelated work.
- Archive outcome chats after their durable result is recorded.
- Never rely on an archived or active chat as the only copy of a decision.

## Automated handoff

When a coordination chat is reset, run this from the harness repository:

```powershell
.\tools\chat-handoff.ps1 -Repository C:\Users\Faruk\Repo\<repository-name> -Purpose "Continue project coordination"
```

The script reads the repository name, branch, recent commits, working-tree status, and `AGENTS.md`, then writes a concise handoff to the repository at `docs/CHAT-HANDOFF.md`.
The next Codex or Claude Code chat can be told to read that file directly.
ChatGPT Project chats cannot automatically read a local repository file, so a ChatGPT replacement chat still requires either uploading the file or pasting its contents.
