# Review: unit 2c (TASK-205, TASK-206) (6a95fde → staged)

Date: 2026-11-20
Unit: 2c (Phase 2c: Auto-fix REQ-056 JSON name and language coverage)
Tasks: TASK-205, TASK-206
Base: 6a95fde6814c8271deace63db19391be78c740c0
Reviewed: `git diff --cached 6a95fde` (2 files, 40 insertions, 2 deletions)

Findings: P0 0 · P1 0 · P2 0 · P3 0    Partitions reviewed: 5

### Index

No findings. The unit is a test-only change that closes the REQ-056 gap the phase-2
conformance report recorded (`plans/greet-options/reports/phase-2/conformance.md`, "Major"):
the name and language rules of the JSON `greeting` value were Inspected-only because every
pre-existing JSON test passed a hand-written `line` literal into `renderOutput`.

### Partitions reviewed

1. **JSON value over the `buildGreeting` → `renderOutput` seam** (REQ-056): name, language,
   shout, count all composed through one `options` object. Confirmed by 5 red mutations.
2. **Name fidelity in the JSON value** (REQ-012): surrounding spaces kept, no trimming.
   Confirmed by a red trim mutant.
3. **Whole-line upper-casing with a name** (REQ-020, REQ-021): confirmed by a red
   upper-case-the-word-only mutant (the spec's rejected ALT-001).
4. **Count over the seam** (REQ-053, REQ-056): confirmed by a red `count: 1` mutant in
   `buildGreeting` and a red `length: 1` mutant in the JSON branch.
5. **Gate integrity and scope**: pure additions to the test file, no deletions, no
   `.skip`/`.only`, no source change, plan ticks and traceability rows consistent.

### Guards

Every mutation was run in a scratch copy (`scratch-copy.sh` into `${TMPDIR}/mut-2c`), with
`TEST_CMD="npm test"` from `.dostuff/pipeline.conf`. The scratch copy was deleted afterwards;
the repo was never edited.

- mutation: `buildGreeting` always uses the `en` greeting word (language rule broken) -> `npm test` red
  (`not ok 29 - the JSON value carries a named, non-English greeting built by buildGreeting`)
- mutation: `buildGreeting` trims the name (name fidelity broken) -> `npm test` red
  (`not ok 30 - the JSON value carries the name exactly as given`)
- mutation: `buildGreeting` upper-cases only the greeting word, not the whole line -> `npm test` red
  (`not ok 31 - the JSON value upper-cases the whole line when shout and a name are combined`)
- mutation: the JSON branch appends a trailing `\n` inside the string -> `npm test` red
  (`not ok 32 - the JSON value joins the repeated lines inside the value`)
- mutation: the JSON branch rebuilds the line from `options` and applies shout to the word only
  (the seam break the task row warns about) -> `npm test` red
  (`not ok 31 - the JSON value upper-cases the whole line when shout and a name are combined`)
- mutation: `buildGreeting` returns `count: 1` instead of `options.times` -> `npm test` red
  (`not ok 32 - the JSON value joins the repeated lines inside the value`)
- mutation: the JSON branch renders `"Hello, world"` regardless of name and language -> `npm test` red
  (all four new tests red)
- mutation: the JSON branch drops the name (value is the greeting word only) -> `npm test` red
  (all four new tests red)
- mutation: the JSON branch ignores the count (`length: 1`) -> `npm test` red
  (`not ok 32 - the JSON value joins the repeated lines inside the value`)
- mutation: the JSON output gains a space after the colon (REQ-055) -> `npm test` red
  (all four new tests red)

**Value added over the base suite, proven:** with the *base* test file (28 tests) the
"JSON value drops the name and language" mutant is caught only by the old shout test, which
passes a literal `line`. With the *new* test file (32 tests) the same mutant is caught by all
four new tests. The new tests guard the seam the base suite left open.

**Equivalent mutant (green, not a finding):** reading the count from `options.times` instead of
`greeting.count` in the JSON branch stays green. This is the same mutant recorded in the 2b
gate-reason row (`plans/greet-options/decisions.tsv`, `2026-11-20T10:20:36Z`): `buildGreeting`
sets `count: options.times` and the spec calls `buildGreeting(options)` and
`renderOutput(options, greeting)` with the same options object, so `greeting.count ===
options.times` on every production path. It cannot change any output.

Scope: clean

### Tests

The four new tests are composed through a single `options` object and never a hand-written
`line` literal, exactly as TASK-206 requires. Each new test is falsifiable: the mutants above
show a wrong implementation of the name, language, shout or count rule fails it. The count test
is not redundant with the pre-existing `renderOutput joins the repeated lines inside the JSON
value` test, because that one passes `count: 2` literally and therefore cannot see a
`buildGreeting` that drops the count.

### Checked and fine

- Gate integrity: the diff is 39 added lines and zero removed lines in `test/greet.test.js`.
  No test was deleted, skipped (`.skip`, `xit`) or narrowed; no `.only`; no lint, type or CI
  config touched; no coverage or timeout threshold lowered. No assertion was relaxed.
- Scope: only `test/greet.test.js` (in both task rows' Files column) and the tasks file
  (tick and traceability rows, under the plan dir) are staged. `src/greet.js` and `bin/greet.js`
  are untouched, matching the `**Guard:**` labelling. `check-plan.sh plans/greet-options`
  reports OK (50 ids, 17 tasks).
- The five items from `plans/greet-options/reports/phase-2/fix-scope-2c.md` are all closed:
  F01 both rows relabelled `**Guard:**`; F02 `src/greet.js` removed from TASK-206's Files
  column; F03 both rows cite TEST-013, not TEST-009; F04 a composed `times: 2` case added and
  GOAL-009 widened to name, language, shout and count; F05 the traceability rows now list
  TASK-206 under REQ-012 (line 191), REQ-020 (line 192), REQ-021 (line 193) and REQ-056 (line 206).
- Task ticks: both rows carry Status `[x]` and Done `2026-11-20`, the required ISO date, and
  only the unit's own tasks were ticked.
- The "Done when" line for unit 2c is satisfied: `npm test` passes (32 tests, 32 pass, 0 fail,
  0 skipped) and the JSON format is proven for a named, non-English greeting built by
  `buildGreeting` and rendered by `renderOutput`, with the name kept exactly as given, the
  shout rule applied to the whole line and the repeated lines joined inside the value.
- JSON escaping: a name containing a quote, a backslash or a newline round-trips exactly
  (`JSON.parse(out).greeting === greeting.line`), which is the behaviour REQ-055's
  `JSON.stringify` mandate gives. No REQ id in this unit's Spec column asks for an escaping
  test, so its absence is not a gap in this unit.
- `renderOutput` has no caller in `bin/greet.js` yet; the CLI is owned by TASK-401/402 in
  phase 4, so the composed seam is exercised by these unit tests alone. That is what the
  unit is for.

### Open questions

None.

### Set aside

- The `options.times` instead of `greeting.count` mutant staying green: equivalent on every
  production path, already recorded in the 2b gate-reason row. No action.
- A JSON-escaping unit test (name with a quote or newline): not required by any REQ in this
  unit's Spec column, and the current behaviour is correct. Noted for phase 4's route tests
  if the user wants it.

```
SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
scope: clean
mutations: 10 run, 0 still green
top:
- no findings; 10 mutations run in a scratch copy, all red; 1 green mutant judged equivalent (options.times vs greeting.count, already recorded in the 2b gate-reason row)
report: plans/greet-options/reports/phase-2/review-2c.md
```
