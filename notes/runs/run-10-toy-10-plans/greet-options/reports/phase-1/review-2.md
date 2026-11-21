# Review: unit 2 (TASK-020, TASK-021) (356b5f4 -> staged)

Date: 2026-11-19

Verdict: changes-requested
Findings: P0 0 · P1 1 · P2 1 · P3 0    Partitions reviewed: 6

Scope: the staged change `git diff --cached 356b5f4` for plan `plans/greet-options`, unit 2
(tasks TASK-020 and TASK-021), covering `src/options.js`, `test/options.test.js`,
`test/cli.test.js` and the plan file itself.

## Index

1. [P1][Med] F01: the missing-value rule is unguarded for `--times`, `--lang` and `--format` — `src/options.js:55`
2. [P2][Low] F02: an earlier invalid occurrence of a repeated flag errors even when the last occurrence is valid — `src/options.js:55`

### F01: the missing-value rule (REQ-005) is unguarded for `--times`, `--lang` and `--format`

- Severity / confidence: P1 / High
- Location: `src/options.js:55` (`parseArgs`, the missing-value guard). Tests: `test/options.test.js:38-41`
  (`parseArgs raises a UsageError when a flag value is missing`) and `test/cli.test.js:43-49`
  (`cli prints one usage line and exits 2 for a missing flag value`).
- Lens: tests
- Failure: the unit's Green step for TASK-020 says "a flag that takes a value raises `UsageError` when no
  next argument exists or when the next argument starts with `--`". That rule covers all four value flags
  (`name`, `times`, `lang`, `format`), but every test in this unit exercises it with `--name` only.
  `test/options.test.js` never passes `--times`, `--lang` or `--format` as a flag that takes a value; the
  single mention of `--lang` (line 41) is as the *next* argument in the `--name --lang es` case.
  A mutant that narrows the guard to `--name` alone leaves the whole suite green while breaking REQ-005
  for the other three flags:

  ```
  mutation: restrict the missing-value guard to --name (drop the generic check for --times/--lang/--format)
    -> npm test green (25 pass, 0 fail)
  ```

  Under that mutant the CLI stops failing loudly for three of the five flags:

  ```
  $ node bin/greet.js --times        # mutant: "Hello, world", exit 0
  $ node bin/greet.js --lang         # mutant: "Hello, world", exit 0
  $ node bin/greet.js --format       # mutant: "Hello, world", exit 0
  $ node bin/greet.js --lang --shout # mutant: "Hello, world", exit 0
  ```

  REQ-005 requires, for a flag that takes a value and is given none: nothing on stdout, exactly one usage
  line on stderr, exit code 2. The mutant prints a greeting and exits 0. The `--lang --shout` case is the
  nastier one: the mutant swallows `--shout` as the *language value* (`parseArgs(['--lang','--shout'])`
  returns `{ lang: '--shout' }`), so a user who means `--lang` with no value gets a silent wrong answer
  instead of the missing-value error. This is the exact "user types `--name --lang es` expecting the name
  to be `--lang`" failure from the plan's review focus (item 1), reproduced for the sibling flags.
- Evidence: the mutant above, run in a scratch copy of the repo (`${TMPDIR}/mut-unit2`) with
  `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`. The unmutated code is correct for all four flags
  (`parseArgs(['--times'])`, `parseArgs(['--lang'])`, `parseArgs(['--format'])` and
  `parseArgs(['--lang','--shout'])` all raise `UsageError`), so this is a test gap, not a wrong implementation.
- Fix: add the sibling flags to the existing unit and CLI tests, for example in `test/options.test.js`:

  ```js
  test('parseArgs raises a UsageError when a flag value is missing', () => {
    throwsUsageError(['--name']);
    throwsUsageError(['--name', '--lang', 'es']);
    throwsUsageError(['--name', '--shout']);
    throwsUsageError(['--times']);
    throwsUsageError(['--lang', '--shout']);
    throwsUsageError(['--format']);
  });
  ```

  and in `test/cli.test.js` add `['--times']`, `['--lang']` and `['--format']` to the loop in
  `cli prints one usage line and exits 2 for a missing flag value`. One assertion of
  `parseArgs(['--lang', '--shout'])` is enough to pin the "the next flag is not swallowed as a value" rule
  for a non-`--name` flag. (The same narrowing mutation applied to `--name`'s equals form is already caught
  by `parseArgs raises a UsageError for an empty name value`, so the equals form needs no new case.)

### F02: an earlier invalid occurrence of a repeated flag errors even when the last occurrence is valid

- Severity / confidence: P2 / Medium
- Location: `src/options.js:55-60` (`parseArgs`, the value-validation guards).
- Lens: spec
- Failure: `parseArgs(['--name', '', '--name', 'Ada'])` raises `UsageError` ("empty value for --name"), and
  `parseArgs(['--lang', '--shout', '--lang', 'es'])` raises `UsageError` ("missing value for --lang"),
  even though the last occurrence of each flag is valid. REQ-003 says that when the same flag is given more
  than once "the last occurrence wins and no error is raised", and the plan's decision row says "the value
  of the last occurrence is the one that is validated". The implementation validates each occurrence as it is
  read, so an earlier invalid occurrence also fails the run.
- Evidence: probe against the staged code:
  ```
  parseArgs(['--name','','--name','Ada'])      -> THROW UsageError empty value for --name
  parseArgs(['--lang','--shout','--lang','es']) -> THROW UsageError missing value for --lang
  ```
- Why P2 and not P1: the plan's decision table explicitly says "A flag value is validated as it is read",
  which the implementation follows literally, and the plan's own Red step only pins the
  invalid-last-occurrence direction (`['--name','Ada','--name','']`). The reverse direction is not specified
  anywhere, so this is an under-specified corner rather than a proven contradiction. It is also not covered
  by the cited requirement text unambiguously. Raising it so the plan author either confirms the
  validate-as-read reading or adds the reverse case to a task.
- Fix: if validate-as-read is the intended reading, say so explicitly in the plan's decision row (it is
  currently worded the other way: "the value of the last occurrence is the one that is validated") and add
  `parseArgs(['--name','','--name','Ada'])` to `test/options.test.js` to pin the chosen behaviour. If the
  last-occurrence reading is intended, defer the validation to the end of the loop in `parseArgs` instead.

## Tests

Behaviour changed in this unit, and what is not covered:

- Covered and guarded (each mutation below turns the suite red):
  - REQ-005 missing value for `--name` (space form, equals form, next-argument-is-a-flag, flag is last).
  - REQ-005 a value that starts with a single `-` is an ordinary value (`--name -x` → `Hello, -x`, exit 0).
  - REQ-006 an empty `--name` value, in both the space form and the equals form.
  - REQ-003/REQ-006 the last occurrence of a repeated `--name` is the one validated.
  - REQ-007 a bare positional argument, a bare `--`, a stray argument after `--name Ada`, and a single-dash
    argument used as a flag (`-n`, `-x`).
  - REQ-004/D-10 `--shout=true` is an unknown flag, in the unit and at the process level.
  - The process contract for each of the above: empty stdout, exactly one usage line on stderr, exit 2.
- Not covered (see F01): REQ-005 for `--times`, `--lang` and `--format`.
- Not covered, and belonging to a later task: an empty value for a non-`--name` flag
  (`parseArgs(['--lang='])` currently returns `{ lang: '' }` rather than raising). REQ-013/REQ-014 make an
  empty `--lang`/`--format` a usage error, but the value validation for those flags is TASK-030/TASK-031's
  work, so this is not a defect in this unit.

## Guards

Each mutation was applied to a scratch copy of the repo at `${TMPDIR}/mut-unit2` (never in the repo) and run
with `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`.

- `mutation: drop the "value starts with --" half of the missing-value guard` -> `npm test` **red**
  (3 fail: cli missing flag value, parseArgs missing value, parseArgs value starts with --)
- `mutation: remove the empty-name guard` -> `npm test` **red** (3 fail)
- `mutation: make a non-`--` argument skip instead of throw` -> `npm test` **red** (3 fail)
- `mutation: let `--shout=true` through as a boolean flag` -> `npm test` **red** (2 fail)
- `mutation: treat a value starting with a single "-" as a missing value` -> `npm test` **red** (2 fail)
- `mutation: validate only the first occurrence of a repeated flag` -> `npm test` **red** (1 fail)
- `mutation: restrict the missing-value guard to --name only` -> `npm test` **green** (25 pass) — **F01**
- `mutation: apply the empty-value guard to every value flag, not just --name` -> `npm test` **green** (25 pass)
  — equivalent for the current requirement set (an empty `--lang`/`--format`/`--times` is invalid under
  REQ-011/REQ-013/REQ-014 either way, and those flags' value rules land in TASK-030/031), so this is not
  reported as a finding.
- `mutation: validate the empty-name value only in the space form, not the equals form` -> `npm test` **red** (1 fail)
- `mutation: let one stray argument through` -> `npm test` **red** (1 fail)
- `mutation: apply the stray-argument guard only after a `--name` was seen` -> `npm test` **red** (3 fail)
- `mutation: do not consume the next argv entry as the flag value` -> `npm test` **red** (6 fail)
- `mutation: write the usage line to stdout instead of stderr` -> `npm test` **red** (3 fail)

13 mutations run, 12 red, 1 still green (F01).

## Scope: clean

Every changed file is accounted for:
- `src/options.js` — in the Files column of both TASK-020 and TASK-021.
- `test/options.test.js` — in the Files column of both tasks.
- `test/cli.test.js` — in the Files column of both tasks.
- `plans/greet-options/feature-greet-options-tasks.md` — the plan file itself: the two task rows are ticked
  with the ISO date and three Differences entries are added (message texts for the new usage errors, and
  the `--` / `--shout=true` wording). No source behaviour was added beyond what the two tasks ask for.

The three Differences entries are accurate and do not narrow or drop a spec test: they record only message
text, which `bin/greet.js` never prints (it prints only `USAGE`), and the `--` / `--shout=true` wording,
which the plan itself fixes. No gate was loosened: no test was deleted, skipped or relaxed, and no lint,
type or CI config was touched.

## Open questions

Q01: Is the missing-value rule for `--times`/`--lang`/`--format` (REQ-005) meant to land in this unit, or
    is it deferred to TASK-030/TASK-031? The TASK-020 Green step reads "a flag that takes a value", which
    is generic, and the rule is implemented generically in `src/options.js`; but the unit's tests only
    cover `--name`. Blocking: no (F01 is reportable either way as a test gap; if the answer is "deferred",
    it should be recorded as a Difference).

Q02: For a repeated flag, does an earlier invalid occurrence fail the run, or only the last occurrence?
    See F02. Blocking: no.

## Set aside

- `parseArgs(['--lang='])` returns `{ lang: '' }` instead of raising. The value rules for `--lang` and
  `--format` are TASK-031's, so this is not this unit's defect (see Tests).
- `test/cli.test.js` hardcodes the `USAGE` string instead of importing it from `src/options.js`. This is
  pre-existing from unit 1, not part of this diff, and hardcoding is defensible (it pins the literal text
  of the usage line). Left alone.
- The `--` argument is reported as `unknown argument: --` while `--shout=true` is reported as
  `unknown flag: --shout`. Both are `UsageError` and neither message is ever printed, so the wording
  difference has no observable effect.
- `test/zz-seeded.test.js` does not exist in the tree, so the whole suite is green. The plan expects that
  file to exist and fail (spec §8); its absence is a repo-seed matter, not a defect in this unit.

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
  stderr, exit 2", asserted separately on stdout, stderr and the exit status.
