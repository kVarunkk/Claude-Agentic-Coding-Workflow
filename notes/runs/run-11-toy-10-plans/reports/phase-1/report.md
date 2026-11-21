# Phase 1 report: Option parsing core

Feature: greet-options
Phase: 1 (unit 1)
Previous tag: greet-options-tasks

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 1 | TASK-101, TASK-102 | 6d426a5 | plans/greet-options/reports/phase-1/review-1-2.md | pass (p0: 0, p1: 0, p2: 0, scope: clean, mutations: 8 run, 0 still green) |

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-1/review-1.md | fail | 0 | 1 | 2 | F01: `times` stayed a string and no task in the plan converted it |
| plans/greet-options/reports/phase-1/review-1-2.md | pass | 0 | 0 | 0 | recheck after 1 fix round |

## Fix rounds

1 round (unit 1). The fix converted the count at the parse boundary (`parseTimes`), added a
test pinning the number type, and replaced the stale Differences entry.

## Differences from the spec (phase 1 tasks)

- TASK-102 (REQ-032, Q-1): the `--times` digit-string rule is implemented as
  `/^[1-9][0-9]*$/`, not the `/^[0-9]+$/` the Decisions row named. `/^[0-9]+$/` matches
  `03`, so it cannot reject `03`, which TASK-102's Red list, the spec (REQ-032, Q-1) and
  the Decisions row's own wording all require. The Decisions row was corrected in this
  unit so it agrees with the code.
- TASK-101 (REQ-002): `parseOptions` returns the count as the number the user typed, so
  `--times 3` yields `times: 3`, not the string `'3'`. The spec's resolved option record
  (spec §3) holds `times` as an integer and REQ-068 requires a JSON number from the
  config path, so the flag path converts at the parse boundary to keep one type per key
  in the merged record.

## Conformance

Report: plans/greet-options/reports/phase-1/conformance.md
Verdict: pass (p0: 0, p1: 0, p2: 0)

All 13 phase-1 ids grade Met (Tested). The matcher's top findings:

- REQ-001: `parseOptions` recognises exactly the five flags, every other argument is a
  usage error
- REQ-032: `--times` accepts a plain digit string 1-5, rejecting 0, 6, abc, 1.5, 03, +2
- REQ-074: every bad input in the spec's list throws a `UsageError` at the parse boundary
- REQ-075: last occurrence wins, `--shout` set twice stays true
- REQ-002: `DEFAULT_OPTIONS` is the spec's five-key record with `times` as a number

The matcher noted that `bin/greet.js` still holds the old ad-hoc `--name` lookup, so the
CLI does not yet honour the new parser. That is correct for phase 1: TASK-401 and
TASK-402 own the CLI rewrite in phase 4.

## Test run

Command: `npm test`
Result: 17 tests, 17 pass, 0 fail, 0 skipped.

## Diffstat

```
 plans/greet-options/decisions.tsv                  |   5 +
 plans/greet-options/feature-greet-options-tasks.md |  36 +++----
 plans/greet-options/reports/phase-1/review-1-2.md  |  82 ++++++++++++++++
 plans/greet-options/reports/phase-1/review-1.md    | 106 +++++++++++++++++++++
 plans/greet-options/reports/tasks/fix-scope.md     |  30 ++++++
 src/greet.js                                       |  89 ++++++++++++++++-
 test/greet.test.js                                 |  86 ++++++++++++++++-
 7 files changed, 415 insertions(+), 19 deletions(-)
```
