---
goal: Demo tasks
spec: plans/demo/feature-demo-spec.md
---

# Introduction

Fixture for pipeline tests.

## Phase 1: Scaffold

- **GOAL-001**: Tests run.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-010 | Scaffold the CLI and test runner. | CON-001 | package.json, src/cli.ts | [x] | 2026-11-14 |
| TASK-011 | Print a greeting. | REQ-001 | src/cli.ts, test/cli.test.ts | [x] | 2026-11-14 |

**Done when:** `npm test` passes.

## Phase 2a: Flags

depends: 1

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-020 | Add `--json`. | REQ-002 | src/json.ts, test/json.test.ts | [x] | 2026-11-14 |
| TASK-021 | Escape names in JSON (a \| b stays one cell). | SEC-001 | src/json.ts | [ ] | |

## Phase 2b: Name

depends: 1

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-022 | Add `--name`. | REQ-003 | src/name.ts, test/name.test.ts | ✅ | |
| TASK-023 | Document flags. | REQ-002, REQ-003 | README.md | [ ] | |

## Phase 3: Ship

depends: 2

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-030 | Add `--upper`. | CON-001 | src/upper.ts, test/upper.test.ts | [ ] | |

## Requirement traceability

| Requirement | Tasks |
|---|---|
| REQ-001 | TASK-011 |

## Differences from the spec

None yet.
