# Per-repository entry points

The harness rules live in this repository, at `instructions/AGENTS.md`.
Every other repository under the workspace root is a place agents write, and until now none
of them said so.

A session working in `Portfolio-Website` or `hoshi-candle-co` read that repository's own
working agreement - scope, source of truth, workflow - and nothing in it mentioned tree
claims, queue compare-and-swap, the write-ahead ledger, or worktree isolation. Those are
exactly the rules that matter in the repositories where two sessions collide.

## What each tool actually reads

Confirmed against the installed binaries and the working setup on 2026-08-23, not assumed.

| Tool | Reads | Precedence | Include directive |
| --- | --- | --- | --- |
| Claude Code | `~/.claude/CLAUDE.md`, then `CLAUDE.md` from the repository root down to the working directory | deeper wins | **yes** - `@path` imports a file live |
| Codex | `~/.codex/AGENTS.md`, then `AGENTS.override.md` / `AGENTS.md` / configured fallbacks, from the working directory up to the repository root | more-deeply-nested wins | **no** |

Evidence for the Codex row, read out of `codex.exe` 0.148.0-alpha.9:

- `"Use the root and scoped project instruction files applicable to changed files,
  respecting normal project-document precedence (AGENTS.override.md, AGENTS.md, then
  configured fallback filenames)"`
- `"The scope of an AGENTS.md file is the entire directory tree rooted at the folder that
  contains it"`, and `"More-deeply-nested AGENTS.md files take precedence in the case of
  conflicting instructions"`
- `"Failed to read global AGENTS.md instructions from ..."` - so `~/.codex/AGENTS.md` is
  merged in as well
- config keys `project_doc_max_bytes`, `project_doc_fallback_filenames`,
  `project_root_markers`
- no import, include, or `@file` handling anywhere in the binary

Evidence for the Claude Code row: `~/.claude/CLAUDE.md` is a one-line stub whose only
content is `@~/Repo/agent-agnostic-harness/instructions/AGENTS.md`, and it resolves - the
rules arrive in context without being copied. `tewaza-market/CLAUDE.md` was already using
the same mechanism relatively, as `@AGENTS.md`.

### What could not be confirmed

- **Codex's default `project_doc_max_bytes`.** The config key exists; its default value is
  not recoverable from the binary's strings. This matters because `instructions/AGENTS.md`
  is around 46 KB and the installed copy at `~/.codex/AGENTS.md` is around 43 KB. If the cap
  is below that, Codex has been reading a truncated file and the tail of the rules - which
  is where the queue-format rules and the rename checklist live - has never reached it. Set
  the key explicitly in `~/.codex/config.toml` rather than relying on a default nobody has
  measured.
- **Whether `~/.codex/AGENTS.md` is truncated in practice.** Same question, observable from
  inside a Codex session by asking it to quote the last rule in the file.

## The convention

Every repository under the workspace root carries a root `AGENTS.md` that opens with a
**Harness rules - read this first** section pointing at
`$HOME/Repo/agent-agnostic-harness/instructions/AGENTS.md`, and a root `CLAUDE.md`
containing `@AGENTS.md`.

It is a pointer, not a copy. The harness already records what copies do: a skill that
snapshotted resume state went stale and advice was given from the snapshot for work that had
been finished days earlier. A duplicated rulebook in ten repositories is that failure ten
times over, and each copy looks authoritative while it drifts.

The cost of a pointer is that the agent has to open the file. That is a real cost and it is
the right one to pay: an open instruction is auditable, and a stale copy is not.

## Known drift, not fixed here

`install.ps1` copies `instructions/AGENTS.md` to `~/.codex/AGENTS.md`. On 2026-08-23 the
copy was seven days old and about 3 KB shorter than the source. Codex has therefore been
running against a stale rulebook - not a missing one, which is the more comfortable reading,
but a confidently wrong one.

This is a real defect and it is not in scope for this change, because fixing it means
changing what the installer writes rather than what the repositories contain. It is recorded
as an open decision in the queue.
