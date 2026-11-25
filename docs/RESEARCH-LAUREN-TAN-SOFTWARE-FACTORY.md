# Research: Lauren Tan's software-factory talk

## Summary

The talk's central lesson is to earn agent autonomy by improving the environment around the agent.
The recommended order is deterministic code and architecture constraints, executable verification, then prose rules for the judgment that remains.
The most applicable harness changes are a compact feature map for runtime verification and a standing rule to promote recurring corrections into checks.

## Findings applied here

- `/ship` now carries a verification map for UI or workflow-visible tasks and requires runtime browser evidence when those paths change.
- `/browsertest` now defines the map as feature, entry point, user action, expected state, and proof artifact.
- `/closing` now directs mechanically checkable corrections toward tests, lint rules, validators, or API constraints.
- `docs/PROJECT-CONTEXT-TEMPLATE.md` now has a durable place for the map when a repository needs one.

## Findings not adopted yet

- The talk describes very strict comment reduction, but a universal comment ban would be too blunt for this harness; comments that explain durable constraints still have value.
- Formal verification and automatic release-triggered repair are valuable factory directions, but they need a concrete project invariant and an isolated execution boundary before they should become default harness behavior.
- The talk's production volume and revert-rate figures are practitioner-reported context, not independent evidence of quality.

## Evidence ledger

| Claim | Source | Confidence |
|---|---|---|
| The talk presents an inverse trust pyramid that puts code and deterministic checks below runtime or formal verification and a smaller prose layer. | [Official talk page](https://ai.engineer/talks/O_zcc6Xl12g-all-code-is-slop-except-mine) and [official transcript](https://ai.engineer/api/data/transcript?format=json&slug=youtube-87dd31e7fa6155e8455b) | Confirmed |
| A feature map gives the agent a user-facing feature vocabulary and connects actions to runtime proof. | [Official talk page](https://ai.engineer/talks/O_zcc6Xl12g-all-code-is-slop-except-mine) | Confirmed |
| Recurring review corrections can move into architecture or lint constraints so they stop consuming repeated manual review. | [Official talk page](https://ai.engineer/talks/O_zcc6Xl12g-all-code-is-slop-except-mine) | Confirmed |
| The speaker reports high production throughput and a low revert rate after investing in the environment. | [Official talk page](https://ai.engineer/talks/O_zcc6Xl12g-all-code-is-slop-except-mine) and [YouTube recording](https://youtu.be/O_zcc6Xl12g?si=wXBzC5G-WhuEgkDY) | Confirmed as a speaker-reported claim; not independently verified |

## Source note

The supplied recording is the primary source for the talk.
The official AI Engineer page supplied the accessible transcript endpoint used for this analysis.
The proposed harness changes are our application of the talk's mechanisms, not claims that the speaker endorsed this repository.
