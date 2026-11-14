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
2. **Green:** write the minimum code that makes it pass. Repeat 1–2 for each listed test.
3. **Refactor:** with the tests green, clean up, then run the lint and type checks.

Rules:
- <test isolation: e.g. tests never call the network or a real model; which test utils to use>
- Tests drive the seams agreed in spec §9. Mock only at system boundaries.
- Tasks marked **Manual** need real keys or a human. Record what was observed in the task and, where it changes the plan, under Differences.
- Tick the task (✅) and fill in the date when it's done. Tasks run in order within a phase unless marked *(parallel)*.
- The **Spec** column maps each task to the spec's ids.

## Decisions taken for these tasks

Settled up front so work can start. Revisit in the last task if any turns out wrong.

| Decision | Taken |
|---|---|
| <a question a developer would otherwise stop on> | <the answer, with the reason if it isn't obvious> |

## Review focus

The inputs and failure modes most likely to hurt a real user that no requirement spells out, most likely first. Each one has a test in the named task.

1. <input or condition> → <the behaviour a reasonable user expects>. Test in TASK-<id>.

---

## Phase 0: Scaffold and test infrastructure

- **GOAL-000**: <a clean clone installs, runs and tests>

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-000 | <scaffold, scripts, env example> | CON-…, SEC-… | | |
| TASK-001 | <test runner config, test utils, a smoke test> | CON-… | | |

**Done when:** <checkable outcome>

---

## Phase 1: <name>

- **GOAL-001**: <outcome a user or developer can see working>

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-010 | **Red → Green:** `<module>` `<exact signature>`. **Tests:** <cases with the spec's exact values>. | REQ-…, TEST-… | | |
| TASK-011 | *(parallel)* **Red → Green:** `<module>`. Uses `<name from TASK-010>`. **Tests:** <cases>. | REQ-… | | |
| TASK-012 | **Manual:** <what to run and what to record>. | RISK-…, Q-… | | |

**Done when:** <checkable outcome>

---

## Phase N: Ship

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-N0 | README / docs. | CON-… | | |
| TASK-N1 | **Verify:** lint, typecheck, full test suite, a run from a clean clone, then `checking-spec-conformance`. | CON-… | | |
| TASK-N2 | Review the decisions table and fill in Differences. Update the spec's status and the answers to open questions. | — | | |

## Requirement traceability

| Requirement | Tasks |
|---|---|
| REQ-001 | TASK-… |
| SEC-001 | TASK-… |

## Differences from the spec

None yet. Record each deviation here as it happens, with the spec id and the reason.
