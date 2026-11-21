# Review: unit 2 (TASK-020, TASK-021) recheck (356b5f4 -> staged)

Date: 2026-11-19

Verdict: pass
Findings: P0 0 · P1 0 · P2 1 · P3 0    Partitions reviewed: 6

Recheck mode: previous report `plans/greet-options/reports/phase-1/review-2-2.md`.

Scope of the recheck: check each P0/P1 finding of the previous report (fixed or open, with
evidence), rerun its mutation, and look for new P0 or P1 problems in the lines the fix touched.
No new P2s are raised; the previous P2 is carried over with its status restated, since it was
never resolved and is still visible in the code.

## Index

1. [P1][Med] F01: **fixed** — the missing-value rule is now guarded for `--times`, `--lang` and `--format` — `src/options.js:55`, `test/options.test.js:39-46`, `test/cli.test.js:43-58`
2. [P2][Low] F02: **open** — an earlier invalid occurrence of a repeated flag errors even when the last occurrence is valid — `src/options.js:55-60`

### F01: the missing-value rule (REQ-005) was unguarded for `--times`, `--lang` and `--format` — FIXED

- Severity / confidence: P1 / High (was open)
- Location: `src/options.js:55` (`parseArgs`, the missing-value guard). Tests now:
  `test/options.test.js:39-46` (`parseArgs raises a UsageError when a flag value is missing`) and
  `test/cli.test.js:43-58` (`cli prints one usage line and exits 2 for a missing flag value`).
- Lens: tests
- The fix adds the three sibling flags to both tests:
  - `test/options.test.js:43-45` — `throwsUsageError(['--times'])`,
    `throwsUsageError(['--lang', '--shout'])`, `throwsUsageError(['--format'])`.
  - `test/cli.test.js:48-50` — `['--times']`, `['--lang']`, `['--format']` added to the loop that
    asserts empty stdout, exactly one usage line on stderr and exit code 2 for each case.
  The `['--lang', '--shout']` case pins the "the next flag is not swallowed as a value" rule for a
  flag other than `--name`, which was the part of F01 that had no process-level coverage before.
- Evidence (rerun in this recheck, scratch copy at `${TMPDIR:-/tmp}/mut-u2r3`, `TEST_CMD="npm test"`
  from `.dostuff/pipeline.conf`; baseline 25 pass, 0 fail):

  ```
  mutation: narrow the missing-value guard to --name only
    -> npm test red (23 pass, 2 fail: cli missing flag value, parseArgs missing value)
  ```

  The same mutation was **green (25 pass)** before the fix. The mutant is now caught by both the
  unit test and the process-level test.
- The unmutated staged code is correct for all four value flags, verified by probe:

  ```
  parseArgs(['--times'])          -> THROW UsageError missing value for --times
  parseArgs(['--lang'])           -> THROW UsageError missing value for --lang
  parseArgs(['--format'])         -> THROW UsageError missing value for --format
  parseArgs(['--lang','--shout']) -> THROW UsageError missing value for --lang
  parseArgs(['--times','--shout']) -> THROW UsageError missing value for --times
  parseArgs(['--format','--shout']) -> THROW UsageError missing value for --format
  ```

  And at the process level, `node bin/greet.js --times`, `--lang` and `--format` each print the
  single usage line on stderr, nothing on stdout and exit 2.
- No new P0/P1 problems in the lines the fix touched. The new assertions are additive to existing
  tests, no assertion was removed or relaxed, and the new `throwsUsageError` helper
  (`test/options.test.js:5-10`) is sound: it checks `err instanceof UsageError && err.name === 'UsageError'`,
  and a probe confirmed `assert.throws` rejects a plain `TypeError` under that predicate, so the
  helper cannot be satisfied by the wrong error type.

### F02: an earlier invalid occurrence of a repeated flag errors even when the last occurrence is valid — OPEN (previous P2, no new P2 raised)

- Severity / confidence: P2 / Medium
- Location: `src/options.js:55-60` (`parseArgs`, the value-validation guards).
- Lens: spec
- Failure: `parseArgs(['--name', '', '--name', 'Ada'])` raises `UsageError` ("empty value for
  --name"), and `parseArgs(['--lang', '--shout', '--lang', 'es'])` raises `UsageError` ("missing
  value for --lang"), even though the last occurrence of each flag is valid. REQ-003 says that when
  the same flag is given more than once "the last occurrence wins and no error is raised". The
  implementation validates each occurrence as it is read, so an earlier invalid occurrence also
  fails the run.
- Evidence: probe against the staged code (rerun in this recheck, unchanged result):

  ```
  parseArgs(['--name','','--name','Ada'])        -> THROW UsageError empty value for --name
  parseArgs(['--lang','--shout','--lang','es'])  -> THROW UsageError missing value for --lang
  parseArgs(['--name','Ada','--name','Bob'])     -> {"name":"Bob"}   (control: both valid)
  parseArgs(['--name','Ada','--name',''])        -> THROW UsageError empty value for --name
  ```
- Why P2 and not P1: the plan's decision table (`plans/greet-options/feature-greet-options-tasks.md:52`)
  says "A flag value is validated as it is read", which the implementation follows literally, and the
  plan's own Red step only pins the invalid-last-occurrence direction
  (`['--name','Ada','--name','']`). The reverse direction is not specified anywhere, so this is an
  under-specified corner rather than a proven contradiction. Note the same decision row is worded two
  ways in one sentence ("validated as it is read, so the value of the last occurrence is the one that
  is validated"), which is where the ambiguity comes from; the fix round did not touch that row.
- Fix: if validate-as-read is the intended reading, reword the decision row so the two clauses agree
  and add `parseArgs(['--name','','--name','Ada'])` to `test/options.test.js` to pin the chosen
  behaviour. If the last-occurrence reading is intended, defer the validation to the end of the loop
  in `parseArgs` instead.

## Tests

Behaviour changed in this unit, and what is not covered:

- Covered and guarded (each mutation below turns the suite red):
  - REQ-005 missing value for `--name` (space form, equals form, next-argument-is-a-flag, flag is last).
  - REQ-005 missing value for `--times`, `--lang` and `--format`, including the
    next-argument-is-a-flag case for `--lang` (this is what F01 asked for; now guarded).
  - REQ-005 a value that starts with a single `-` is an ordinary value (`--name -x` → `Hello, -x`, exit 0).
  - REQ-006 an empty `--name` value, in both the space form and the equals form.
  - REQ-003/REQ-006 the last occurrence of a repeated `--name` is the one validated.
  - REQ-007 a bare positional argument, a bare `--`, a stray argument after `--name Ada`, and a single-dash
    argument used as a flag (`-n`, `-x`).
  - REQ-004/D-10 `--shout=true` is an unknown flag, in the unit and at the process level.
  - The process contract for each of the above: empty stdout, exactly one usage line on stderr, exit 2.
- Not covered, and belonging to a later task: an empty value for a non-`--name` flag
  (`parseArgs(['--lang='])` currently returns `{ lang: '' }` rather than raising; likewise
  `--times=` and `--format=`). REQ-013/REQ-014/REQ-011 make those a usage error, but the value
  validation for those flags is TASK-030/TASK-031's work, so this is not a defect in this unit.

## Guards

Each mutation was applied to a scratch copy of the repo (never in the repo) and run with
`TEST_CMD="npm test"` from `.dostuff/pipeline.conf`. Baseline: 25 pass, 0 fail.

- `mutation: narrow the missing-value guard to --name only` -> `npm test` **red** (2 fail) — was green before the fix, so F01 is closed
- `mutation: narrow the missing-value guard to --name only and drop the empty-name guard` -> `npm test` **red** (5 fail)
- `mutation: drop the "--"-prefix half of the missing-value guard` -> `npm test` **red** (3 fail)
- `mutation: make the missing-value UsageError a non-UsageError for --times/--lang/--format` -> `npm test` **red** (2 fail)
- `mutation: make the missing-value UsageError a non-UsageError for every flag` -> `npm test` **red** (3 fail)
- `mutation: remove the empty-name guard` -> `npm test` **red** (3 fail)
- `mutation: make a stray/unknown argument continue instead of throw` -> `npm test` **red** (3 fail)
- `mutation: let --shout=true through as a boolean flag` -> `npm test` **red** (2 fail)
- `mutation: treat a value starting with a single "-" as a missing value` -> `npm test` **red** (2 fail)
- `mutation: drop the arg === '--' special case` -> `npm test` **green** (25 pass) — **equivalent**:
  the only difference is the message text (`unknown flag: --` instead of `unknown argument: --`);
  both are `UsageError`, both give empty stdout, one usage line on stderr and exit 2, and
  `bin/greet.js:13` prints only `USAGE`, never the error message. No output can change, so this
  mutant cannot break any cited requirement.

10 mutations run, 9 red, 1 still green (equivalent). The one still-green mutant is equivalent by
the reason above, not a test gap.

## Scope: clean

Every changed file is accounted for:
- `src/options.js` — in the Files column of both TASK-020 and TASK-021.
- `test/options.test.js` — in the Files column of both tasks.
- `test/cli.test.js` — in the Files column of both tasks.
- `plans/greet-options/feature-greet-options-tasks.md` — the plan file itself: the two task rows are ticked
  with the ISO date and four Differences entries are added (the message texts for the new usage
  errors, the `--` / `--shout=true` wording, and the TASK-020 fix-round entry describing the F01 fix).
  No source behaviour was added beyond what the two tasks ask for.
- `plans/greet-options/decisions.tsv` — the pipeline's own decision log: it records the two fix-round
  starts, the empty-report event from the first reviewer, and the two gate reasons for the fix round.
  The tab-separated columns and the `logged` / `committing` result values match the existing rows.
- `plans/greet-options/reports/phase-1/review-2.md` and `review-2-2.md` — the previous review
  reports for this unit, added as artefacts of the fix round.

The Differences entries are accurate and do not narrow or drop a spec test: they record only message
text, which `bin/greet.js` never prints (it prints only `USAGE`), the `--` / `--shout=true` wording,
which the plan itself fixes, and the F01 fix-round note, which describes exactly the assertions that
were added. No gate was loosened: no test was deleted, skipped or relaxed, and no lint, type or CI
config was touched. The task rows for TASK-020 and TASK-021 were ticked with the ISO date and no
other row was touched.

## Open questions

Q01: For a repeated flag, does an earlier invalid occurrence fail the run, or only the last occurrence?
    See F02. The plan's decision row at `feature-greet-options-tasks.md:52` is worded two ways in one
    sentence and should be made to agree with whichever behaviour is intended. Blocking: no.

## Set aside

- `parseArgs(['--lang='])` returns `{ lang: '' }` instead of raising. The value rules for `--lang`,
  `--format` and `--times` are TASK-030/TASK-031's, so this is not this unit's defect (see Tests).
- `test/cli.test.js` hardcodes the `USAGE` string instead of importing it from `src/options.js`. This is
  pre-existing from unit 1, not part of this diff, and hardcoding is defensible (it pins the literal text
  of the usage line). Left alone.
- The `--` argument is reported as `unknown argument: --` while `--shout=true` is reported as
  `unknown flag: --shout`. Both are `UsageError` and neither message is ever printed, so the wording
  difference has no observable effect (confirmed by the equivalent mutation above).
- `test/zz-seeded.test.js` does not exist in the tree, so the whole suite is green. The plan expects that
  file to exist and fail (spec §8); its absence is a repo-seed matter, not a defect in this unit.
- `parseArgs(['--name', '-'])` accepts `-` as a name. A value that starts with a single `-` is an
  ordinary value per REQ-005, so this is correct, not a gap.

## Checked and fine

- Index arithmetic in the parse loop: the space form consumes `argv[i+1]` and advances `i`, so a value is
  never re-read as an argument. Verified by mutation (red) and by probe over mixed forms.
- The `=` separator is only honoured inside an argument that starts with `--`, so `--name A=B` and
  `--name=A=B` both give the name `A=B` (logged as a unit-1 Difference; unchanged here).
- Every new error is a `UsageError`, so `bin/greet.js` keeps catching only that type and REQ-042's
  no-stack-trace rule still holds. Verified: the `--require` preload test still passes.
- `parseArgs` never touches `process.argv` (spec §4.3), and the new code adds no I/O, no file access and
  no shell use, so SEC-001/002/003 are unaffected.
- The process-level contract asserted for each new error path is exactly "empty stdout, one usage line on
  stderr, exit 2", asserted separately on stdout, stderr and the exit status. The empty-string argument
  in `run('--name', '')` really does reach the child process as an empty argv entry (probed), so that
  case is not a vacuous assertion.
- The equals form of every flag behaves consistently with the space form: `--name=--foo` and
  `--lang=--shout` raise the missing-value error, `--name=-x` gives the name `-x`, and `--shout=`,
  `--shout=false` are unknown flags.
- The new `throwsUsageError` helper cannot be satisfied by the wrong error type (probed with a plain
  `TypeError`), so the added assertions genuinely guard REQ-005 for the three sibling flags.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
scope: clean
mutations: 10 run, 1 still green
top:
- F02 [P2] src/options.js:55 an earlier invalid occurrence of a repeated flag errors even when the last occurrence is valid
report: plans/greet-options/reports/phase-1/review-2-3.md
