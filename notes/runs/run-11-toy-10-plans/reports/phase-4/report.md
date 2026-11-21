# Phase 4 report: The CLI entry point

Feature: greet-options
Phase: 4 (unit 4)
Previous tag: greet-options-phase-3

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 4 | TASK-401, TASK-402 | 53f32ec | plans/greet-options/reports/phase-4/review-4-2.md | pass (p0: 0, p1: 0, p2: 0, scope: clean, mutations: 13 run, 2 still green) |

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-4/review-4.md | fail | 0 | 1 | 0 | F01: the usage-error test asserted only the stderr prefix, the trailing newline and the line count, never the reason, so a `formatUsage` that discarded its reason broke REQ-071 with the suite green |
| plans/greet-options/reports/phase-4/review-4-2.md | pass | 0 | 0 | 0 | recheck after 1 fix round |

## Fix rounds

1 round on unit 4. The fix replaced the three weaker stderr assertions with the exact
string assertion the task row and the spec both prescribe, so the prefix, the reason,
the single trailing newline and the one-line rule are pinned at once. No production code
changed: `src/greet.js` and `bin/greet.js` already implemented the spec exactly.

## Added units

None.

## Differences from the spec (phase 4 tasks)

None. No phase-4 task introduced a divergence. The five entries in the tasks file's
Differences section belong to TASK-101, TASK-102 and TASK-301 in phases 1 and 3.

## Conformance

First check: plans/greet-options/reports/phase-4/conformance.md
Unfinished. The matcher stopped before writing a SUMMARY and used the standalone
verdict format ("conforms"), so `check-report.sh` rejected it.

Recheck: plans/greet-options/reports/phase-4/conformance-2.md
Verdict: pass (p0: 0, p1: 0, p2: 0)

0 Critical, 0 Major, 0 Warning. 14 ids Met, 10 ids Not started (owned by phases 5 to 7).
The matcher built its own mutation harness in a scratch copy and ran 24 mutants, all
red; the one green mutant it confirmed (`options.times` instead of `greeting.count`) is
equivalent, since `buildGreeting` sets `count: options.times`.

The matcher's top findings:

- REQ-070: a usage error gives one stderr line, an empty stdout and exit 2 (verified
  live and by mutation)
- REQ-071: the usage line prefix and reason are pinned by the exact-string test
- REQ-051: the JSON output is exactly `{"greeting":"..."}` plus one newline
- SEC-005: nothing reaches stdout on the usage-error path
- TEST-015: the usage-error contract holds at the process seam

The matcher also re-ran the real CLI against a scratch directory for all 23 flag
combinations: every exit code, stdout and stderr byte matched.

The two phase-3 Warnings (the unreadable-config branch and the stale fixture inventory)
are carried forward at the same severity. The user accepted both at the phase-3 gate.

Left open, not findings and not owned by any phase-4 id: the non-`UsageError` re-throw
branch at `bin/greet.js:18` has no test, and `formatUsage` has no unit-seam test (the
CLI coverage is sufficient). Both are noted for the phase-5 owner.

## Test run

Command: `npm test`
Result: 59 tests, 59 pass, 0 fail, 0 skipped.

## Diffstat

```
 bin/greet.js                                       |  23 +-
 plans/greet-options/decisions.tsv                  |   4 +
 plans/greet-options/feature-greet-options-tasks.md |   4 +-
 plans/greet-options/reports/phase-4/review-4-2.md  | 218 +++++++++++++++++
 plans/greet-options/reports/phase-4/review-4.md    | 262 +++++++++++++++++++++
 src/greet.js                                       |   5 +
 test/greet.test.js                                 |  65 ++++-
 7 files changed, 573 insertions(+), 8 deletions(-)
```
