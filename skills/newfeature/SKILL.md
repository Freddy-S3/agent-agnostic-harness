---
name: newfeature
description: "New feature implementation workflow. Use when building a new endpoint, service, or UI feature."
---

# New Feature Skill

## 1. Clarify Scope
- Identify which component(s) the change lands in, and name them explicitly before touching code.
- For new API endpoints: confirm HTTP method, authentication/authorization attribute, and sync vs async (does it need a polling pattern?).
- Find the closest existing similar feature and model after it before designing from scratch. Name that reference sibling in the plan.
- Read the reference sibling's controller/service/component before writing the new one, so conventions carry over instead of being reinvented.

## 2. Design First
- Define request/response shapes and the service interface before the implementation.
- For an asynchronous feature, use a `POST` returning a transaction id plus a status-polling endpoint, not a blocking request thread.
- Before implementation, agree on one observable test seam and expected outcome, such as an endpoint response, service behavior, or component state.
- Use `/tdd` at that seam where practical by establishing the focused test before the implementation.

## 3. Implementation Order (backend / service layer)
Run the narrowest available type/build check and focused test after each observable implementation slice before continuing.

1. **DTOs** - request/response models; document all public properties
2. **Interface** - the service abstraction, in the project's interfaces location
3. **Service** - the implementation, alongside its siblings
4. **Controller / handler** - log the exception and return an explicit server error for an unexpected failure; never return success with empty data
5. **Dependency registration** - register with the correct lifetime (scoped for per-request services, singleton for thread-safe clients)
6. **Config** - add any new keys to *every* per-environment config file, not just the one you are testing against

## 4. Implementation Order (frontend / UI layer)
Run the narrowest available type/build check and focused component or service test after each observable implementation slice before continuing.

1. **Service module** - an exported object of functions rather than a class, in the services location
2. **Shared store** - add state to the appropriate store only when it is genuinely shared across components
3. **Component** - keep the owning feature tree's existing component library; do not introduce a second design system without an explicit migration request
4. **Unmount guard** - for any async polling loop, set a boolean flag in the unmount hook and check it before and after each `await`
5. **Result cache** - cache expensive computed or generated results at module scope, keyed by their input id, with a small bounded size (LRU)

## 5. Pre-Done Checklist
- [ ] Dependency registration present with correct lifetime
- [ ] Doc comments on all new public DTOs and interfaces
- [ ] All new config keys added to every per-environment config file
- [ ] Happy path + at least one error path unit test
- [ ] No `NotImplementedException`, `TODO`, or stub methods left behind
- [ ] Unused imports pruned from every modified file
- [ ] Run `/codereview` before declaring done
