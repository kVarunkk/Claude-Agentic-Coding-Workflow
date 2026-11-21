# Phase 3 report: Config loading and merging

Feature: greet-options
Phase: 3 (units 3, 3a)
Previous tag: greet-options-phase-2

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 3 | TASK-301, TASK-302 | 7623912 | plans/greet-options/reports/phase-3/review-3-2.md | pass (p0: 0, p1: 0, p2: 1, scope: clean, mutations: 18 run, 1 still green) |
| 3a | TASK-303, TASK-304 | 2c26a4f | plans/greet-options/reports/phase-3/review-3a.md | pass (p0: 0, p1: 0, p2: 1, scope: clean, mutations: 3 run, 0 still green) |

Plan commits in this phase: ee8c9c8 (add unit 3a).

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-3/review-3.md | fail | 0 | 1 | 2 | F01: `CONFIG_VALIDATORS[key]` hit `Object.prototype` members, so an unknown key crashed with a `TypeError`. F02: the config `times` upper bound had no test |
| plans/greet-options/reports/phase-3/review-3-2.md | pass | 0 | 0 | 1 | recheck; F03 (unreadable config) stays open at P2 |
| plans/greet-options/reports/phase-3/review-3a.md | pass | 0 | 0 | 1 | recheck of the added unit; F01 (fixture list widening) stays open at P2 |

## Fix rounds

1 round on unit 3. The fix made the known-key lookup own-property only, added the
`times-six` fixture and its assertion, and added two fixtures for the inherited-member
case. The stray-file finding (`test/fixtures/unknown-key-proto/greet.config.json` outside
the Files column) was resolved in the same round by naming the fixture paths in full in
the Differences entry.

## Added units

One unit was added: 3a (TASK-303, TASK-304), created by the automatic fix unit after the
first phase-3 conformance check graded REQ-066 and REQ-065 as Partial. The unit's task
ids were renamed from `TASK-3a1`/`TASK-3a2` to `TASK-303`/`TASK-304` in a writer round,
because the plan grammar requires `TASK-[0-9]+`.

## Differences from the spec (phase 3 tasks)

- TASK-301 (REQ-061, REQ-062, REQ-070, SEC-004): the known-key lookup is now own-property
  only (`Object.hasOwn(CONFIG_VALIDATORS, key)`), so an unknown key whose name is an
  `Object.prototype` member (`toString`, `constructor`, `valueOf`, `hasOwnProperty`,
  `__proto__`) is ignored instead of crashing with an uncaught `TypeError` or a garbage
  usage reason. The unit test and the fixture `test/fixtures/unknown-key-inherited/greet.config.json`
  are added here because TASK-301 owns the config key rule.
- TASK-301 (REQ-068): the fixture `test/fixtures/times-six/greet.config.json` is added in
  this unit, although the task file lists it under TASK-602's Files column, because the
  config `times` range check (1 to 5) belongs to TASK-301's validator and REQ-068 is
  cited there. TASK-602 reuses the same fixture.
- TASK-301 (REQ-061): two fixture files outside the task's Files column are added,
  `test/fixtures/unknown-key-inherited/greet.config.json` and
  `test/fixtures/unknown-key-proto/greet.config.json`, following the
  `test/fixtures/<case>/greet.config.json` convention of the Decisions row. The first
  holds a valid `name` beside a `toString` key, the second a lone `__proto__` key, which
  was the worst crash of the inherited-member bug.

## Conformance

First check: plans/greet-options/reports/phase-3/conformance.md
Verdict: fail (p0: 0, p1: 1, p2: 2). REQ-066 was graded Partial: only the array and
`null` top levels were tested, so a string, number or boolean top level would pass
unnoticed. REQ-065 was graded Partial: the read-once rule had no assertion, so a
double-read mutation stayed green.

Rechecks: plans/greet-options/reports/phase-3/conformance-2.md and
plans/greet-options/reports/phase-3/conformance-3.md
Verdict: fail (p0: 0, p1: 0, p2: 2)

Both rechecks grade all 16 phase-3 ids Met, with 0 untested, 0 partial, 0 missing, 0
diverge, and state "conforms with gaps". The two Warnings they carry are:

1. The unreadable-config branch (`src/greet.js:146-151`) has no test. The behaviour is
   correct (probed: a `greet.config.json` directory gives `UsageError` with reason
   `invalid greet.config.json`, matching spec §4.3). No task row and no TEST id asks for
   the case, so it is a coverage gap, not a spec violation.
2. The spec's §8 fixture inventory and the plan's Decisions-row fixture list are stale
   relative to the three new fixture directories (`top-level-string`, `top-level-number`,
   `top-level-boolean`). No behaviour diverges: REQ-066, spec §4.1, the §4.3 table and
   gate answer Q-5 already require exactly this.

The matcher's top findings:

- REQ-065: the read-once rule now has a test, the double-read and merge-re-read
  mutations are red
- REQ-066: string, number and boolean top levels now have tests, the narrowed-check
  mutations are red
- REQ-069: the whole config is validated inside `loadConfig`, before the merge
- REQ-076: a flag can only turn `shout` on, never off
- REQ-063: a flag overwrites only its own key

## Open findings accepted by the user

The two Warnings above. The user accepted phase 3 with both open, and they carry to the
final report.

## Test run

Command: `npm test`
Result: 49 tests, 49 pass, 0 fail, 0 skipped.

## Diffstat

```
 plans/greet-options/decisions.tsv                  |  10 ++
 plans/greet-options/feature-greet-options-tasks.md |  24 ++-
 plans/greet-options/reports/phase-3/conformance.md | 149 +++++++++++++++++
 .../greet-options/reports/phase-3/fix-scope-3a.md |  27 +++
 .../reports/phase-3/fix-unit-check-2.md            |   1 +
 .../reports/phase-3/fix-unit-check.md              |   5 +
 .../reports/phase-3/fix-unit-review.md             | 102 ++++++++++++++++
 plans/greet-options/reports/phase-3/review-3-2.md  | 107 ++++++++++++++++++++
 plans/greet-options/reports/phase-3/review-3.md    | 142 +++++++++++++++++++++
 plans/greet-options/reports/phase-3/review-3a.md   | 182 +++++++++++++++++++++
 src/greet.js                                       |  88 ++++++++++
 test/fixtures/bad-format/greet.config.json         |   3 +
 test/fixtures/bad-lang/greet.config.json           |   3 +
 test/fixtures/bad-shout/greet.config.json          |   3 +
 test/fixtures/empty-config/greet.config.json       |   1 +
 test/fixtures/good-format/greet.config.json        |   3 +
 test/fixtures/invalid-json/greet.config.json       |   1 +
 test/fixtures/name-empty/greet.config.json         |   3 +
 test/fixtures/name-number/greet.config.json        |   3 +
 test/fixtures/no-config/.gitkeep                   |   0
 test/fixtures/times-fraction/greet.config.json     |   3 +
 test/fixtures/times-six/greet.config.json          |   3 +
 test/fixtures/times-string/greet.config.json       |   3 +
 test/fixtures/times-zero/greet.config.json         |   3 +
 test/fixtures/top-level-array/greet.config.json    |   1 +
 test/fixtures/top-level-boolean/greet.config.json  |   1 +
 test/fixtures/top-level-null/greet.config.json     |   1 +
 test/fixtures/top-level-number/greet.config.json   |   1 +
 test/fixtures/top-level-string/greet.config.json   |   1 +
 test/fixtures/unknown-key-inherited/greet.config.json |   4 +
 test/fixtures/unknown-key-proto/greet.config.json |   3 +
 test/fixtures/unknown-key/greet.config.json        |   4 +
 test/greet.test.js                                 | 144 ++++++++++++++++
 33 files changed, 1025 insertions(+), 4 deletions(-)
```
