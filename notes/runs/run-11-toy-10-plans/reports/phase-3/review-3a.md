# Review: unit 3a (TASK-303, TASK-304) — ee8c9c8 → staged

Date: 2026-11-20
Unit: `## Phase 3a: Auto-fix REQ-066 and REQ-065 config coverage` (depends: 3)
Tasks: TASK-303 (REQ-066, TEST-006), TASK-304 (REQ-065)
Base: ee8c9c8c8cf3c5517f1e5197e7308eca422e5d8c

Findings: P0 0 · P1 0 · P2 1 · P3 0    Partitions reviewed: 6

### Index
1. [P2][Low] F01: the TEST-006 fixture-list widening is documented inside the task row, not under `## Differences from the spec`; the Decisions-row fixture list stays stale `plans/greet-options/feature-greet-options-tasks.md:135`

## What the unit does

Two guard units that close the two gaps the phase-3 conformance report
(`plans/greet-options/reports/phase-3/conformance.md`) recorded as **Partial**:

- REQ-066 was Partial: only the array and `null` top levels had a test, and the mutation
  "narrowed to array+null only" stayed green.
- REQ-065 was Partial: no test asserted the read count, and the mutation "config file read
  twice" stayed green.

The staged change adds three fixtures (`test/fixtures/top-level-{string,number,boolean}/greet.config.json`),
one test for the three non-object top levels, one read-count test, and ticks TASK-303/TASK-304.
`src/greet.js` is not touched, which is correct: both rows are `**Guard:**` tasks and the code
already behaved as required.

### F01: the fixture-list widening is documented in the task row, not under Differences
- Severity / confidence: P2 / High
- Location: `plans/greet-options/feature-greet-options-tasks.md:135` (TASK-303 row, the
  `**TEST-006 fixture list widened:**` note). Also affects the `## Differences from the spec`
  section (`:247`) and the `Decisions taken` row "Where the config fixture directories live"
  (`:43`).
- Lens: spec / design
- Failure: no wrong behaviour and no broken contract. The gap is bookkeeping. The note states
  that the three new fixture directories "sit outside the fixture list of spec §8 (spec:388) and
  outside the Decisions row's list of fixture case names", but neither list is updated, and no
  `## Differences from the spec` entry is added. Consequences, both non-blocking:
  1. The `checking-spec-conformance` skill reads "**Differences from the spec**" as the record of
     accepted deviations and flags "divergences missing from Differences"
     (`.dostuff/skills/checking-spec-conformance/SKILL.md:19,83`). The phase-3 conformance check
     may report the three new fixture directories as an unlogged divergence, because the note
     lives in the task row, which that skill does not read.
  2. `unit-gate.sh` treats a changed `## Differences from the spec` section as the signal to stop
     for the user (`.dostuff/scripts/unit-gate.sh:57-63`). With no entry there, this unit will
     not gate on the widening.
- Evidence: the note's factual claim was verified and is correct in substance but the placement
  does not match the plan's own conventions:
  - The spec's binding text requires exactly the shapes the new fixtures cover: REQ-066 §4.1
    (spec:254) names "An array, a JSON string, a JSON number, a JSON boolean and `null`", the
    §4.3 table row (spec:342) lists `` `[1,2]`, `"x"`, `null`, `3`, `true` ``, and the binding
    gate answer Q-5 (spec:464) says the five shapes are "Applied in REQ-066, §4.1, §4.3 and
    TEST-006". So the code moves **toward** the spec; only the spec's non-exhaustive
    enumerations (§8 fixture inventory, TEST-006's prose, the Decisions row) lag.
  - The spec's §8 (spec:388) and the Decisions row (`:43`) list 18 fixture case names and omit
    the three new ones, exactly as the note says. The Decisions row was **already** stale before
    this unit for `unknown-key-inherited` and `unknown-key-proto` (both added by TASK-301), so
    this unit inherited the staleness rather than creating it.
  - The repo's precedent: TASK-301 added its two out-of-column fixtures under
    `## Differences from the spec` (`:249,251`). TASK-303 did not. But TASK-303's fixtures are
    **inside** its own Files column and no behaviour changed, and the writing-tasks rule only
    requires a Differences entry for "Touching a file outside the task's Files column" or a
    behaviour deviation (`.dostuff/skills/writing-tasks/SKILL.md`, "During implementation").
    So no entry was strictly required; the note in the task row is a reasonable substitute.
- Fix: smallest change is to add one bullet under `## Differences from the spec` and update the
  Decisions row's fixture list, so the note's claim and the two lists agree:
  `- TASK-303 (REQ-066, TEST-006): the TEST-006 fixture list is widened with three top-level
  shapes (a JSON string, a JSON number, a JSON boolean) that REQ-066 §4.1, the §4.3 table and
  Q-5 name but the TEST id and the spec §8 fixture inventory did not enumerate. The three new
  fixture directories follow the test/fixtures/<case>/greet.config.json convention.`
  Alternatively, leave the note where it is and accept that the phase-3 conformance check may
  flag the fixtures as unlogged. Nothing here needs a code change.

### Guards

All mutations were run in a scratch copy (`bash .dostuff/scripts/scratch-copy.sh
"${TMPDIR:-/tmp}/mut-3a"`), with `npm test` (`TEST_CMD` from `.dostuff/pipeline.conf`), and the
copy was deleted afterwards. Baseline in the scratch copy: 49 tests, 49 pass.

- `mutation: drop the `typeof parsed !== 'object'` half of the top-level check in `loadConfig`
  (src/greet.js:162), so a string, number or boolean top level is accepted -> test 39 "loadConfig
  rejects a top level that is a string, a number or a boolean" red (48 pass, 1 fail)`
- `mutation: read the config file twice in `loadConfig` (src/greet.js:145), breaking REQ-065's
  "read once per process run" -> test 49 "loadConfig reads the config file exactly once and the
  merge does not read it again" red (48 pass, 1 fail)`
- `mutation: make `mergeOptions` (src/greet.js:184) re-read `greet.config.json` from
  `process.cwd()`, breaking REQ-065's "not re-read when a flag overrides one of its keys" ->
  test 49 red (48 pass, 1 fail)`

These are exactly the two mutations the phase-3 conformance report recorded as still green
("narrowed to array+null only -> green", "config file read twice -> green"). Both are now red,
so the two Partial grades should become Met.

Two further mutations were run as probes of the counter's design, not as guard mutations:
- `mutation: an extra read of a different, existing file (test/fixtures/good-format/other.json)
  during `loadConfig` -> test 49 stays green`, which confirms the counter ignores reads that are
  not of the config file, as the task row requires ("a read of any other file does not raise the
  counter"). Not counted as a guard mutation: it breaks no behaviour a cited REQ or SEC states.
- `mutation: `loadConfig` reads a different directory's `greet.config.json` -> red in 12 tests
  (the other `loadConfig` tests), while test 49 itself stays green. The suffix-based counter
  cannot distinguish two files with the same name, but the `assert.deepStrictEqual(config, {
  format: 'json' })` assertion plus the sibling fixture tests cover that. Not a defect.

### Scope: clean

Every changed file is in the unit's Files column (verified with the repo's own parser,
`.dostuff/scripts/lib.sh:parse_tasks`):

- `test/greet.test.js` — in both TASK-303 and TASK-304 Files columns
- `test/fixtures/top-level-string/greet.config.json`, `.../top-level-number/...`,
  `.../top-level-boolean/...` — in TASK-303's Files column
- `plans/greet-options/feature-greet-options-tasks.md` — under the plan dir, always owned

No `src/greet.js` change, so no unrequested behaviour was added. Both rows are `**Guard:**`
tasks whose Green step says `src/greet.js` changes only if a case fails, with the reason logged
under Differences; no case failed, so no source change and no Differences entry are required for
the code. The traceability table was updated correctly (`REQ-065 | TASK-301, TASK-304, TASK-601`,
`REQ-066 | TASK-301, TASK-303, TASK-502, TASK-602` at `:225-226`). The unit's "Done when" line
is satisfied: the array, `null`, string, number and boolean top levels are each rejected with
reason `invalid greet.config.json`, one `loadConfig` call reads the config once, and a merge with
an overriding flag does not read it again.

### Tests

No behaviour was added and no existing test was changed, deleted, skipped or relaxed: the diff
to `test/greet.test.js` is 36 added lines and zero removed lines, and there are no `.skip`,
`xit` or `todo` markers in the file. The `node:test` top-level `test()` calls run sequentially, so
the global `fs.readFileSync` stub installed by the TASK-304 test cannot interleave with another
test; the stub is restored in a `finally` block either way.

Strength of the two new tests was probed by mutation (see Guards): each fails when the
behaviour it names is broken. The read-count test ties the count of 1 to the config file itself
rather than to any read, through `assert.deepStrictEqual(config, { format: 'json' })` and the
suffix filter on the counted path.

### Checked and fine
- The stub reaches `src/greet.js`: `src/greet.js:1` does `require('fs')` while the test does
  `require('node:fs')`, and Node returns the **same module object** for both
  (`require('fs') === require('node:fs')` is `true`), so the stub intercepts the real call.
  Verified by mutation 2 and 3 turning red.
- If `src/greet.js` ever stopped using `fs.readFileSync`, the counter would be 0 and the test
  would fail loudly rather than silently pass.
- The stub calls `original(...args)` unbound; `fs.readFileSync` does not rely on `this` in Node
  22 (verified).
- The three new fixtures are valid JSON of the intended type (`"hello"` → string, `42` → number,
  `true` → boolean), one file per directory, trailing newline, no BOM, matching the existing
  `top-level-array` / `top-level-null` convention and the spec §8 rule that every fixture
  directory holds at least one file so git keeps it.
- `assert.throws` with a validator function reports the custom message
  (`expected <name> to be rejected`) when the validator returns false, so a future regression
  points at the fixture that broke.
- The phase-3 conformance report's third green mutation (a read error other than ENOENT treated
  as "file absent", `src/greet.js:146-151`) is **out of scope** for this unit: the unit's title
  is "Auto-fix REQ-066 and REQ-065 config coverage", neither task row asks for that case, and the
  conformance report itself recorded it as a Warning, not a Major. Not a finding.
- The "read once per process run" clause at the CLI level is owned by TASK-601 in phase 6, as the
  conformance report and the traceability table both state. `bin/greet.js` is still the old
  pre-feature script and is not touched here, which is correct for this phase.

### Open questions
Q01: Should the phase-3 conformance check treat the three new fixture directories as an
"accepted deviation" only if a `## Differences from the spec` entry exists, per
`checking-spec-conformance/SKILL.md:19`? If yes, F01 becomes a P1 for the conformance run.
Blocking: no (the substance is right and the note is discoverable in the task row).

### Set aside
- The Decisions-row fixture list (`:43`) was already stale for `unknown-key-inherited` and
  `unknown-key-proto` before this unit (TASK-301 did not update it either). Pre-existing, and
  this unit did not make it worse. Folded into F01 rather than raised separately.
- The unreadable-config branch (`src/greet.js:146-151`, a file that exists and cannot be read)
  has no test. Out of scope for this unit, and the behaviour is correct.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
scope: clean
mutations: 3 run, 0 still green
top:
- F01 [P2] plans/greet-options/feature-greet-options-tasks.md:135 the TEST-006 fixture-list widening is documented in the task row, not under `## Differences from the spec`; the Decisions-row fixture list stays stale
report: plans/greet-options/reports/phase-3/review-3a.md
