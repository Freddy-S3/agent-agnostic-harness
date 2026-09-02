# Task: Add asynchronous investigation reports to Agent-Agnostic Harness
## Decisions Made
- Use a concise report as the default output, with stable evidence references and trace drill-down.
- Keep wiki output draft-first for an explicitly selected page; operator approval is required before publication.
- Q18 remains open on whether investigation tickets should also create companion wiki drafts.

## Status
- [x] Phase 1-2: Plan
- [x] Phase 3: Workflow, fixtures, and focused validator
- [x] Phase 4: Verification and queue persistence
- [ ] Phase 5: Faruk review of PR #86

## Files Changed So Far
- skills/investigation/SKILL.md (done)
- skills/investigation/fixtures/*.md (done)
- tools/test-investigation-report.ps1 (done)

## Next Step
Review PR #86, then decide whether to merge it and resolve Q18 separately.
