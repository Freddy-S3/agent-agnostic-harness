# Claim enforcement

`tools/claim.ps1` has existed for a while and `instructions/AGENTS.md` has said to run it
for just as long.
Nothing ran it.
On 2026-08-23 the `agent-agnostic-harness` working tree was being written in by a live
Codex session that held no claim, while the registry's only entry was a four-day-old stale
claim on an unrelated Portfolio-Website worktree.

That is the failure the harness already names in its own rules: an instruction to check is
not a mechanism.
A claim that binds only the agents who choose to obey it does not bind a session that never
read the file, which is precisely the session most likely to be in the tree you are in.

`git-hooks/pre-commit` is the mechanism.

## Why a git hook

A git hook is the only enforcement point available that is vendor-neutral without a daemon.

- It runs identically for Claude Code, Codex, an IDE agent, and a shell script.
  None of them can opt out by not reading an instruction file, because all of them reach
  git the same way.
- `install.ps1` already points global `core.hooksPath` at `git-hooks/`, so there is nothing
  new to install and no per-repository setup that a new repository can be created without.
- The commit is the unit of collision. Two sessions editing one tree destroy each other's
  work at the moment one of them records it.
- A daemon would have to be running, would have to survive a reboot, and would be one more
  thing that fails silently. A hook has no lifecycle.

`pre-commit` rather than `pre-push`, because the damage is done before a push: the second
session's commit has already buried the first session's uncommitted edits.

## Why it rejects instead of rewriting

The sibling `commit-msg` hook deliberately rewrites rather than rejects, on the grounds that
a blocked commit teaches the author to reach for `--no-verify`.
That reasoning does not transfer here.
A wrong co-author trailer can be corrected mechanically.
A missing claim cannot be: acquiring the claim on the agent's behalf would hand it exactly
the exclusivity the claim is supposed to prove, and would hand it over in a tree a live peer
may be holding.

So this one refuses, and pays for that with an error message that states the tree, the
session, why the process was treated as an agent, what claim.ps1 actually said, and the two
commands that resolve it.

## It must never block Freddy

This is the hard constraint, not a nicety.
A hook that refuses a hand-typed commit, or that fires when no agent is running at all, is
worse than the problem it solves.

Three separate bounds keep it off Freddy's path:

1. **Agent detection.** The hook exits 0, silently, unless the committing process exports a
   recognised agent marker. Freddy's terminal exports none of them.
2. **Managed root.** It only applies to trees under `$HOME/Repo`, overridable with
   `HARNESS_TREE_ROOT`. A scratch clone or somebody else's checkout is not policed.
3. **Fail open.** If it cannot find `claim.ps1`, or cannot find a PowerShell to run it with,
   it exits 0. A guard that cannot run must not become an outage.

### How an agent is detected

| Variable | Set by | How it was confirmed |
| --- | --- | --- |
| `HARNESS_SESSION` | the harness contract | portable opt-in, preferred - it is the identity passed to `claim.ps1 acquire` |
| `HARNESS_AGENT` | any host | portable opt-in for a host that exports nothing else |
| `CLAUDECODE`, `AI_AGENT`, `CLAUDE_CODE_SESSION_ID` | Claude Code | read out of a running Claude Code shell's environment |
| `CODEX_SESSION_ID`, `CODEX_SANDBOX` | Codex | Codex's own variable names, read out of the `codex.exe` binary |
| `CURSOR_AGENT`, `AIDER_CHAT` | other agents | conventional names, not verified here |

**Not verified:** whether Codex exports `CODEX_SESSION_ID` or `CODEX_SANDBOX` into the shell
it spawns for a tool call. The names are certainly Codex's, but they were read from the
binary rather than from a live Codex shell, and a variable a program defines is not
necessarily a variable it exports. Run this inside a Codex session to settle it:

```sh
env | grep -E '^(CODEX_|AI_AGENT|HARNESS_)' | sed 's/=.*/=<set>/'
```

If it comes back empty, Codex sessions are invisible to the hook and must set
`HARNESS_SESSION` themselves. That is why the global instruction file tells every agent to
export `HARNESS_SESSION` regardless of host: the host-specific markers are a convenience,
and `HARNESS_SESSION` is the contract.

## Escape hatches

| Hatch | Effect |
| --- | --- |
| `HARNESS_CLAIM_BYPASS=1 git commit ...` | allows one unverified agent commit, prints to stderr that it did |
| `git commit --no-verify` | skips every hook, including `commit-msg`'s co-author strip |

Prefer the first. It is scoped to this hook, and it leaves a line in the output saying the
guard was waived rather than leaving no trace at all.

## Staleness

Sessions die unannounced on usage limits, so a claim expires after 30 minutes without a
heartbeat (`-StaleMinutes`). Two behaviours follow, and they are deliberately different:

- **Your own stale claim does not lock you out.** A commit is proof of life, so `verify`
  refreshes the heartbeat on a claim this session already owns, whatever its age. A long
  session cannot be shut out of its own tree by its own claim ageing.
- **A peer's stale claim still refuses the commit.** Staleness lets a successor *take over*
  after reading the dead session's journal for an `INTENT` with no `OUTCOME`; it is not a
  silent expiry. Taking over is `claim.ps1 acquire -Force`, an explicit act.

## Verification

Every case below was run against a throwaway repository with `core.hooksPath` pointed at
`git-hooks/`, on 2026-08-23. The predicate was checked by constructing the failure, not by
re-reading the line - the first draft of the managed-root bound compared
`C:/Users/faruk/Repo/x` against `/c/Users/faruk/Repo` as raw strings, never matched, and
exited 0 for every commit it existed to catch. It passed the Freddy case and silently passed
the agent case too.

| Case | Environment | Claim state | Expected | Result |
| --- | --- | --- | --- | --- |
| A | no agent markers | none | allow | allowed, exit 0, no output |
| B | `CLAUDECODE=1`, session `s1` | none | refuse | refused, exit 1, `UNCLAIMED` |
| C | `CLAUDECODE=1`, session `s1` | held by `s1` | allow | allowed, exit 0 |
| D | `CLAUDECODE=1`, session `s2` | held live by `s1` | refuse | refused, `NOTYOURS ... live claim` |
| E | session `s2`, `HARNESS_CLAIM_BYPASS=1` | held by `s1` | allow + warn | allowed, warning on stderr |
| F | `CLAUDECODE=1`, `HARNESS_TREE_ROOT=/nonexistent` | none | allow | allowed, out of managed root |
| G | session `s1`, own claim aged 3h | stale, owned by `s1` | allow + refresh | allowed, heartbeat refreshed |
| I | session `s2`, `s1` claim aged 3h | stale, owned by `s1` | refuse | refused, `NOTYOURS ... stale claim` |
