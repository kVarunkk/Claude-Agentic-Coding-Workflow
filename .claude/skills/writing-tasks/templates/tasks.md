---
goal: TDD task breakdown for <feature summary>
version: 0.1
date_created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
owner: <repo or team>
status: 'Planned'
spec: plans/<feature>/feature-<feature>-spec.md
tags: [feature, <area>, tasks, tdd]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

These tasks implement `plans/<feature>/feature-<feature>-spec.md` (v0.1) with test-driven development. Every task follows **Red → Green → Refactor**:

1. **Red:** write the next listed test and confirm it fails for the right reason: an assertion about behaviour, not an import error or a missing mock.
2. **Green:** write the minimum code that makes it pass. Repeat 1-2 for each listed test.
3. **Refactor:** with the tests green, clean up, then run the lint and type checks.

A test listed under **Guard:** is expected to pass as soon as it is written, because earlier code already gives the behaviour. It is not logged as a difference.

Rules:
- <test isolation: e.g. tests never call the network or a real model; which test utils to use>
- Tests drive the seams agreed in spec §9. Mock only at system boundaries.
- Tasks marked **Manual** need real keys or a human. Record what was observed in the task and, where it changes the plan, under Differences.
- Tick a task (`[x]` plus the ISO date in Done) when its tests pass. Tasks run in order within a unit.
- The **Spec** column maps each task to the spec's ids. The **Files** column lists every file the task touches.

## Decisions taken for these tasks

Settled up front so work can start. Revisit in the last task if any turns out wrong.

| Decision | Taken |
|---|---|
| <a question a developer would otherwise stop on> | <the answer, with the reason if it isn't obvious> |

## Review focus

The inputs and failure modes most likely to hurt a real user that no requirement spells out, most likely first. Each one has a test in the named task.

1. <input or condition> → <the behaviour a reasonable user expects>. Test in TASK-<id>.

---

<!-- Phase 0 only when the repo lacks a test runner or scaffold the tasks need; delete it otherwise. -->
## Phase 0: Scaffold and test infrastructure

- **GOAL-000**: <a clean clone installs, runs and tests>

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-000 | <scaffold, scripts, env example> | CON-… | package.json, .env.example | [ ] | |
| TASK-001 | <test runner config, test utils, a smoke test> | CON-… | <config file>, test/smoke.test.ts | [ ] | |

**Done when:** <checkable outcome>

---

## Phase 1a: <name>

depends: 0

- **GOAL-001**: <outcome a user or developer can see working>

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-010 | **Red → Green:** `<module>` `<exact signature>`. **Tests:** <cases with the spec's exact values>. | REQ-…, TEST-… | <src file>, <test file> | [ ] | |
| TASK-011 | **Red → Green:** `<module>`. Uses `<name from TASK-010>`. **Tests:** <cases>. | REQ-… | <src file>, <test file> | [ ] | |

**Done when:** <checkable outcome>

## Phase 1b: <name>

depends: 0

- **GOAL-002**: <outcome>

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-015 | **Red → Green:** `<module>`. **Tests:** <cases>. Document the flag in README. | REQ-… | <src file>, <test file>, README.md | [ ] | |
| TASK-016 | **Manual:** <what to run against TASK-015's code and what to record>. | RISK-…, Q-… | none | [ ] | |

**Done when:** <checkable outcome>

<!-- No Ship/Verify unit: the pipeline runs the full suite, a real run and the conformance check at the end. -->

## Requirement traceability

| Requirement | Tasks |
|---|---|
| REQ-001 | TASK-… |
| SEC-001 | TASK-… |

## Differences from the spec

None yet. Record each deviation here as it happens, one bullet per entry with the task id, the spec id and the reason.
