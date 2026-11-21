# Phase 6 report: The config file end to end

Feature: greet-options
Phase: 6 (unit 6)
Previous tag: greet-options-phase-5

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 6 | TASK-601, TASK-602 | 6ec27a3 | plans/greet-options/reports/phase-6/review-6.md | pass (p0: 0, p1: 0, p2: 1, scope: clean, mutations: 6 run, 0 still green) |

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-6/review-6.md | pass | 0 | 0 | 1 | no P0 or P1; F01 (P2): REQ-064's home-directory clause has no test |

No fix rounds were needed in this phase.

## Added units

None.

## Differences from the spec (phase 6 tasks)

- TASK-601 (REQ-060, REQ-063, REQ-064, REQ-065, SEC-006, TEST-016, TEST-020): the three
  Red cases pass as soon as they are written, so the end-to-end layer only needed the
  tests. TASK-401 had already wired the whole pipeline into `bin/greet.js`, including
  `loadConfig(process.cwd())` before the render and `mergeOptions(config, flags)`, and
  `loadConfig` already read only `<cwd>/greet.config.json` with no parent, home or
  user-config lookup, so the Green step had nothing left to build. The new tests were
  checked to be load-bearing by mutating `loadConfig` to walk up parent directories (the
  parent-directory test fails) and by dropping the config from the merge (the
  config-applies test and the flag-overrides-only-its-own-key test fail).
- TASK-602 (REQ-062, REQ-066, REQ-069, REQ-070, REQ-079, SEC-004, TEST-017, TEST-022,
  TEST-024): the five Red cases pass as soon as they are written, so the end-to-end layer
  only needed the tests. TASK-301 had already put the whole-file validation in
  `loadConfig`, which throws the `UsageError` before it returns, and TASK-402 had already
  put the catch block in `bin/greet.js`, so a broken config reached the same usage line
  as a bad flag. The new tests were checked to be load-bearing by mutating `loadConfig`
  to skip the per-key validation and by moving the validation to the merged options (only
  the `times-six` case with `--times 2` fails, which is the case REQ-069 names).
- TASK-601 (REQ-060): the content of `test/fixtures/parent-has-config/greet.config.json`
  is `{"name": "Config", "lang": "fr"}`. The spec pins only the shape of the case, so
  the values are this unit's choice; they are chosen so that a parent lookup would print
  `Bonjour, Config` and fail the assertion loudly.
- TASK-502 (TEST-023): the config half of TEST-023 was not tested in unit 5 because it
  needs a child process run with a `cwd` set to a fixture directory, and the `runIn`
  helper belongs to TASK-601 and the config CLI tests to TASK-602. TASK-602 has since
  added that test, so the config half of TEST-023 is now covered there.

## Conformance

Report: plans/greet-options/reports/phase-6/conformance.md
Verdict: pass (p0: 0, p1: 0, p2: 1)

15 ids Met, 1 Warning, no Critical and no Major. The matcher re-ran the real CLI against
the committed fixtures for all eight phase-6 cases, capturing stdout, stderr and exit
codes as Verified evidence. It confirmed phase 6 added no production code, consistent
with the logged Differences.

The matcher's top finding:

- REQ-064: the parent-directory clause is Tested and Verified; the home-directory and
  user-config clause is Untested. The code is clean and a live probe with `HOME` pointed
  at a config-holding directory printed `Hello, world`, so it is a coverage gap, not a
  defect.

The phase-3 Warnings (the unreadable-config branch and the stale fixture inventory) are
carried forward at the same severity. Phase 6's diff touches neither.

## Test run

Command: `npm test`
Result: 86 tests, 86 pass, 0 fail, 0 skipped.

## Diffstat

```
 plans/greet-options/decisions.tsv                  |   7 ++
 plans/greet-options/feature-greet-options-tasks.md |   9 ++-
 plans/greet-options/reports/phase-6/review-6.md    |  78 ++++++++++++++++++++++
 test/fixtures/name-ada-lang-es/greet.config.json   |   4 ++
 test/fixtures/parent-has-config/child/.gitkeep     |   0
 test/fixtures/parent-has-config/greet.config.json  |   4 ++
 test/greet.test.js                                 |  70 +++++++++++++++++++
 7 files changed, 169 insertions(+), 3 deletions(-)
```
