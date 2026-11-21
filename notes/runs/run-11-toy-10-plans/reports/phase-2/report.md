# Phase 2 report: Greeting building and rendering

Feature: greet-options
Phase: 2 (units 2a, 2b, 2c)
Previous tag: greet-options-phase-1

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 2a | TASK-201, TASK-202 | d70d306 | plans/greet-options/reports/phase-2/review-2a.md | pass (p0: 0, p1: 0, p2: 0, scope: clean, mutations: 8 run, 0 still green) |
| 2b | TASK-204 | feb393b | plans/greet-options/reports/phase-2/review-2b.md | pass (p0: 0, p1: 0, p2: 0, scope: clean, mutations: 9 run, 1 still green) |
| 2c | TASK-205, TASK-206 | 0cfb3b7 | plans/greet-options/reports/phase-2/review-2c.md | pass (p0: 0, p1: 0, p2: 0, scope: clean, mutations: 10 run, 0 still green) |

Plan commits in this phase: 6a95fde (add unit 2c).

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-2/review-2a.md | pass | 0 | 0 | 0 | no findings |
| plans/greet-options/reports/phase-2/review-2b.md | pass | 0 | 0 | 0 | no findings; one green mutation judged equivalent |
| plans/greet-options/reports/phase-2/review-2c.md | pass | 0 | 0 | 0 | no findings, 10 mutations all red |

No fix rounds were needed in this phase.

## Added units

One unit was added: 2c (TASK-205, TASK-206), created by the automatic fix unit after the
first phase-2 conformance check found REQ-056 partially covered. The five P2 notes on the
new unit were closed in a writer round before it ran (see
plans/greet-options/reports/phase-2/fix-scope-2c.md and fix-unit-review.md).

## Differences from the spec (phase 2 tasks)

None. No phase-2 task introduced a divergence. The two entries in the tasks file's
Differences section belong to TASK-101 and TASK-102 in phase 1 and are unchanged.

## Conformance

First check: plans/greet-options/reports/phase-2/conformance.md
Verdict: fail (p0: 0, p1: 1, p2: 1). REQ-056 was graded Partial: the JSON value's shout
and count rules were tested, but the name and language rules had no phase-2 test because
all four JSON tests passed a hand-written `line` literal into `renderOutput`.

Recheck: plans/greet-options/reports/phase-2/conformance-2.md
Verdict: pass (p0: 0, p1: 0, p2: 0)

All 20 ids in phase 2's spec column are Met. The matcher's top findings:

- REQ-056: the JSON value's name, language, shout and count rules are now proven over
  the composed `buildGreeting` to `renderOutput` seam
- REQ-012: the name is inserted verbatim, proven in both the text and the JSON seam
- REQ-021: the upper-casing covers the word, the comma and the name with nothing added or
  removed
- REQ-031: the text branch prints exactly `count` lines, each ending with a single newline
- REQ-055: `JSON.stringify` on a one-key object gives the compact form with no space after
  the colon

The matcher left one forward-looking note for phase 3, not a phase-2 gap:
`buildGreeting` reads `GREETING_WORDS[options.lang]` with no fallback, so an invalid lang
would render `"undefined, world"`. That is unreachable today because the phase-1 parser
rejects it, but phase 3's `loadConfig` must reject an invalid config `lang`
(REQ-062, REQ-067) or that path becomes live.

The matcher also flagged that `bin/greet.js` is deliberately untouched by phase 2
(TASK-401 and TASK-402 own it in phase 4), so the CLI still prints `Hello, world` for
every argument.

## Test run

Command: `npm test`
Result: 32 tests, 32 pass, 0 fail, 0 skipped.

## Diffstat

```
 plans/greet-options/decisions.tsv                  |   6 +
 plans/greet-options/feature-greet-options-tasks.md |  31 +++--
 plans/greet-options/reports/phase-2/conformance.md | 119 ++++++++++++++++++
 .../greet-options/reports/phase-2/fix-scope-2c.md |  26 ++++
 .../reports/phase-2/fix-unit-review.md             |  78 ++++++++++++++++
 plans/greet-options/reports/phase-2/review-2a.md   | 133 ++++++++++++++++++++++
 plans/greet-options/reports/phase-2/review-2b.md   |  89 ++++++++++++++
 plans/greet-options/reports/phase-2/review-2c.md   | 133 ++++++++++++++++++++++
 src/greet.js                                       |  31 ++++-
 test/greet.test.js                                 | 127 +++++++++++++++++++-
 10 files changed, 762 insertions(+), 11 deletions(-)
```
