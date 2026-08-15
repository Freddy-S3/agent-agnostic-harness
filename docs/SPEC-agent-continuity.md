# Agent Continuity: Claims, Write-Ahead Journals, and Findings

Status: draft specification. No implementation in this document.

## Problem

The harness already has a continuity mechanism: the live task ledger described in
`skills/ship/SKILL.md`, written at gates by `/ship`, read at Phase 0 by `/plan`, and
maintained at session end by `/closing`.
It is the right idea in the wrong shape, and six concrete failures in a single day trace
back to the same four gaps in it.

The ledger is global, not per-repo.
It lives under the shared memories tree, keyed by task, so a peer session working in the
same repository has nothing to look at and no reason to look.

The ledger is a summary, not a journal.
It is updated at phase boundaries and gates - that is, after work completes.
A session that dies mid-operation never writes the entry that would have described the
operation, so the record is silent about exactly the case it is needed for.

The ledger is single-writer by assumption.
Nothing in it records who holds which files, so two sessions can both believe they own a
working tree.

The ledger is deleted on completion.
Findings that were true but out of scope have nowhere to live, and a finding a subagent
returns in a message evaporates when the orchestrator's turn ends.

The six observed failures:

1. Two sessions wrote one working tree concurrently, neither warned; found only as
   unexplained working-tree entries. One was rewriting content another was building
   artifacts from.
2. Sessions died on usage limits mid-edit, leaving half-applied changes. A killed session
   is currently indistinguishable from one that chose to stop, and never reaches its
   end-of-run capture step - so the handoff that matters most is the one never written.
3. Findings reported to an orchestrator evaporated at end of turn; the decision dashboard
   showed no blockers while a dozen decisions were outstanding.
4. An agent's "repo-wide" purge missed instances a later agent found.
5. A verification run passed vacuously against invented identifiers, until it was re-run
   with real ones and failed.
6. An agent made a content judgement about the user's own claimed experience that it had
   no basis to make, and the result reached published artifacts.

## Desired Outcome

One continuity record per repository, per session, that a successor or a peer can act
from without reading the conversation that produced it.
It is written *ahead* of risk rather than after success, it is cheap to check, and it
makes unfinished work visible by its own structure rather than by narration.

This extends the existing ledger. It does not introduce a competing one.

## Scope

### In scope

- A per-repo `.agent/` directory holding claim records and run journals.
- A write-ahead INTENT/OUTCOME protocol for risky operations.
- A claim record enabling collision detection before work starts.
- A findings sink that survives an orchestrator turn ending.
- Read ordering rules so none of the above costs a full-document read.
- Acceptance rules that cannot pass vacuously.
- An explicit stop list of judgements an agent may not make.
- Amendments to `ship`, `plan`, `closing`, `faruk`, `sleep`, `queue`, `status-report`,
  and the shared instructions so they read and write this record instead of the current
  global-only ledger.

### Out of scope

- Any locking primitive, daemon, or background process. The claim is advisory and
  cooperative; enforcement is a check an agent runs, not a mutex.
- Replacing `/wayfinder` (long-horizon decision maps), `/learn` (retrospective mining),
  or `/queue` (the backlog and the human decision channel). This record feeds them.
- Cross-machine synchronisation of the record itself. See the decision below.

## Implementation Decisions

### D1. Location and tracking: per-repo `.agent/`, gitignored

Each repository gains:

```
.agent/
  claims/<session-id>.md     one per active session
  runs/<session-id>.md       the write-ahead journal for that session
  findings/<slug>.md         durable findings outliving their session
```

`.agent/` is added to each repo's `.gitignore` and is never committed.

Justification. Committing would buy cross-machine continuity at the price of publishing
raw operational detail - file paths, half-finished reasoning, verbatim failure text, and
whatever a session happened to be handling - into repositories that are public, in an
ecosystem with a live history of internal detail reaching published artifacts. The
journal's value comes from being written fast and unedited; a file that must be
sanitised before every write will not be written before every risky operation, which
destroys the one property the design depends on.

Cross-machine continuity is served instead by the channels that already exist and are
already private: the queue files for anything needing a decision, and the tracker for
durable outcome. Both are outside any public repository. The rule that follows is: the
journal is local and candid; anything that must travel is promoted to the queue or the
tracker in the sanitised register the shared instructions already define.

**Relocation is deferred, deliberately.** The INTENT/OUTCOME protocol and the live-ledger
posture are already merged into `skills/ship` and `skills/freddy` at the existing shared
path (`/memories/repo/tasks/`), because they work at either location and delaying them
costs the recovery property on every run in the meantime. Moving that record into per-repo
`.agent/` is the part awaiting the decision above. Until it is answered there is one
mechanism at one path, which is the point; implementing both at once would create the
duplication this spec exists to remove.

### D2. Every file opens with a fixed header block

Progressive disclosure is a property of the file format, not of a convention someone
remembers. Every file above opens with a fenced block of no more than eight `key: value`
lines, then a blank line, then free-form body.

Claim header:

```text
session: <session-id>
status: active | paused | dead | released
repo: <repo name>
worktree: <absolute path>
branch: <branch>
owns: <glob or path list, comma separated>
started: <ISO timestamp>
heartbeat: <ISO timestamp>
```

Run-journal header carries `session`, `status`, `objective` (one sentence),
`acceptance` (one observable condition), `open-intents` (count), `blocker`,
`next` (single action), `updated`.

A peer reads headers only. A resuming session reads its own header, then the tail of its
own journal, and reads the body of anything else only when the header says it must.

### D3. The claim, and how a collision is detected

Before the first write in a repository, a session writes `claims/<session-id>.md`, then
lists sibling claims and reads their headers.

A collision is: another claim with `status: active`, the same `worktree`, and an `owns`
pattern intersecting this session's. On collision the session does not proceed. It
either takes its own worktree - which the shared instructions already require for
concurrent work and which so far has had no mechanism behind it - or reports the
collision and stops.

A claim with a `heartbeat` older than the staleness window and `status: active` is
presumed dead, not active. A presumed-dead claim may be taken over, but only by a
session that first reads the dead session's journal and records in its own what it found
half-applied. Taking over without reading is the failure this exists to prevent.

The heartbeat is refreshed on each journal write. It costs nothing extra because it is
the same write.

### D4. Write-ahead: INTENT before, OUTCOME after

This is the core of the design and the part that has no equivalent today.

Before any risky operation - any file write, any command that mutates state, any
publish, any git operation beyond reading - the session appends to its journal:

```text
## INTENT <n> <ISO timestamp>
op: <what is about to be attempted, one line>
partial: <the half-completed state this could leave>
discriminator: <the exact command or check a successor runs to tell which happened>
```

After the operation completes, it appends:

```text
## OUTCOME <n> <ISO timestamp>
result: done | failed | abandoned
note: <one line, only if result is not "done">
```

The invariants this creates:

- An INTENT with no matching OUTCOME is unfinished work. A successor finds it by
  reading the tail of the journal; it does not have to infer anything.
- A session that *chose* to stop writes `status: paused` in its header with every INTENT
  closed. A session that *died* leaves at least one INTENT open, or `status: active`
  with a stale heartbeat. The two cases are now distinguishable, which they are not
  today.
- The `discriminator` field is mandatory and must be a command, not a description.
  "Check whether the file was written" is not a discriminator; a command whose output
  differs between the two states is. This is what makes recovery mechanical rather than
  archaeological.

Batching rule, so this does not become unaffordable: a run of same-kind, independently
reversible operations - editing several files in one planned pass - may share one INTENT
whose `partial` describes the whole pass and whose `discriminator` distinguishes any
point within it. Anything irreversible, anything outward-facing, and anything crossing a
repository boundary gets its own INTENT.

### D5. Findings survive the turn that produced them

A finding recorded only in a message returned to an orchestrator is not recorded.

Any agent - including a subagent in a wave - that produces a finding worth a human's
attention writes it to `.agent/findings/<slug>.md` itself, before returning. The
orchestrator's job is then to promote, not to remember: it copies anything that blocks
into the queue as an entry with a `Blocked` reason and an `Options:` list, per the
existing queue contract, so `/status-report` and the dashboard see it.

`/status-report` gains one additional source: unpromoted findings across repos, so a
blocker that was written but never promoted still surfaces rather than sitting silent.

### D6. Ported: the ledger becomes a live intermediate document

The transferred patch's contribution is a posture, not a file format: the handoff is a
*live* document maintained continuously through the run and treated as the compact
recovery source of truth, with the conversation as supplementary - not a summary written
at the end. Subagents receive only their sub-task, the document, and a reference path;
never conversation history.

That posture is adopted here in full and is what the INTENT/OUTCOME protocol implements.
The run journal *is* the intermediate document; `.agent/runs/<session-id>.md` supersedes
the global per-task ledger as the primary record, and the existing ledger fields
(`objective`, `acceptance`, `decisions`, `changed`, `evidence`, `blocker`, `next`) move
into its header and body rather than being duplicated.

### D7. Ported with reservations: sticky routing

The patch also carries a director/owner ledger so a router does not re-route on ordinary
follow-up turns, released only by an explicit terminal reply, with realignment commands
that re-read the record.

Assessment: the *state* belongs here; the *ceremony* mostly does not. The current
routers already keep a route within a conversation without a stored record, and the
observed failures were about persistence across sessions, not about re-routing within
one. Adopt the two fields - `director` and `owner` - into the run-journal header, so a
resuming session knows which workflow was driving and does not re-decide. Adopt a single
re-read command rather than one per skill: re-reading the header is one action and does
not need two names for it. Do not adopt route release semantics as a separate lifecycle;
the journal's `status` already covers it.

The transferred router and orchestrator documents are not applied. The current versions
are ahead of them and carry the personal/delivery mode split the incoming ones lack.
Concepts are ported; files are not.

### D8. Read order, stated explicitly

A resuming session reads, in this order, stopping as soon as it can act:

1. Its own claim header and its own journal header. Eight lines each. This answers "is
   this mine, is it stale, what was I doing, what is next".
2. The tail of its own journal: the last INTENT/OUTCOME pair, and any open INTENT.
   This answers "what might be half-applied, and how do I tell".
3. Only if an INTENT is open: run its `discriminator` and act on the result.
4. Only if the objective is unclear or the work spans sessions: the journal body,
   then the linked spec or plan.

A peer session checking for collisions reads step 1 of every sibling claim and nothing
else - a directory listing plus one small read each.

Nothing in this design requires reading a large document to start work. Skills reference
the record by path and by header field, never by quoting its content into their own
instructions.

## Test Strategy

This is a documentation and protocol change; its verification is behavioural, exercised
against constructed failures rather than asserted in prose. Each check below constructs
the failure it is meant to catch, per the harness rule that a predicate is verified by
constructing the failure and not by re-reading the line.

- **Collision detection.** Create two claim files in one repo with intersecting `owns`
  and the same worktree. A session running the check must refuse to proceed. Then vary
  `owns` to be disjoint and confirm it proceeds - a check that refuses in both cases is
  not detecting anything.
- **Death versus choice.** Construct a journal with an open INTENT and a stale
  heartbeat, and a second with all INTENTs closed and `status: paused`. A resuming
  session must classify them differently and must name the open operation in the first.
- **Discriminator is real.** For a sampled INTENT, run its `discriminator` against both
  the completed and the half-applied state and confirm the outputs differ. A
  discriminator whose output is identical in both states is void.
- **Findings survive.** Run a subagent wave that produces a blocker, end the
  orchestrator's turn, and confirm the blocker is readable from the repo and appears in
  a status check.
- **Read cost.** Confirm the peer-collision check and the resume path each complete
  within the reads listed in D8.

## Acceptance Criteria

An implementation is accepted when all of the following hold, each stated as something
observable rather than something claimed:

1. Every repo the harness works in has `.agent/` present and gitignored, and no
   `.agent/` path appears in any commit.
2. A session writes its claim before its first repository write, and a peer can detect
   the collision by reading headers alone.
3. Every risky operation in a sampled run has a preceding INTENT with all three fields
   populated, and a discriminator that is a runnable command.
4. A journal from a killed session is correctly classified as killed, and the open
   operation is named, by a session that never saw the original conversation.
5. A blocker produced by a subagent appears in the queue with a `Blocked` reason and an
   `Options:` list without the orchestrator having been asked to remember it.
6. Each amended skill references the record by path and header field, and none of them
   grew a full copy of this document.

### Guard against vacuous verification

The invented-identifier failure is prevented by a rule applied to every check above and
to any acceptance check written under this design:

- **Enumerate before asserting.** Every identifier a check depends on - a test name, a
  file path, a ticket key, a record id - must first be listed from the real system, and
  the listing output recorded, before any assertion references it. A check that names an
  identifier not present in a recorded listing is void, not failing.
- **Negative control.** Every check must be run once against a deliberately wrong
  identifier and must fail. A check that passes with a wrong identifier proves only that
  it is not looking at anything, and its passing result carries no information.
- **Zero results are a failure, not a pass.** A check whose scope resolves to nothing -
  no matching tests, no matching files - reports blocked, never green.

### Guard against overclaimed exhaustiveness

Any claim that a change is repository-wide must record the exact search command used and
its result count, and must re-run that same command at the end and record zero. The claim
is then scoped to what that command covers, and stated that way - "no matches for
`<command>`" rather than "repo-wide". An exhaustiveness claim with no recorded command is
not accepted.

## Human-Judgement Boundaries

An agent stops and records a queue blocker with `Options:` rather than deciding, in each
of these classes. This list is normative and belongs in the shared instructions.

- **Money.** Any spend, subscription, paid tier, or commitment with a recurring cost.
- **Legal and licensing.** Licence choice or change, terms acceptance, attribution and
  third-party code provenance, anything with contractual effect.
- **Brand and voice.** Public-facing copy published under the user's name, and any
  change to how he is described.
- **Irreversible operations.** Force-push, history rewrite, branch or repository
  deletion, publishing, merging, and anything sending content to an external service.
- **Claims about the user's own experience.** Any statement about what he did, built,
  achieved, or measured. This includes activating, promoting, or deleting draft or
  commented-out content in career materials: commented content is unverified, not
  disabled truth, and neither activating nor deleting it is an agent's call. This class
  produced failure 6 and is the one an agent is most likely to talk itself past, because
  the content is sitting right there and looks merely disabled.

The boundary is about *authority*, not difficulty. An agent capable of making the change
correctly still may not decide that it should be made.

## Assumptions and Open Questions

- Assumed: `.agent/` is acceptable as a per-repo directory name and does not collide with
  existing tooling in the repos the harness touches. Not yet checked against every repo.
- Assumed: the staleness window for a heartbeat is on the order of tens of minutes -
  long enough to survive a slow operation, short enough that a killed session does not
  block a peer for a whole session. The exact value is an open decision.
- Assumed: the global per-task ledger is superseded rather than kept in parallel. Keeping
  both would recreate the drift this spec exists to remove, but the migration of any
  in-flight ledger is unspecified.
- Open: whether the claim check should be enforced by a hook rather than left to skill
  instructions. The harness's own rule is that a convention living only in prose is one
  that tooling will quietly violate, which argues for a hook; the counter-argument is
  that a session's first write is not a single interceptable event.
- Open: whether findings should be promoted to the queue automatically or only on
  explicit orchestrator action.
