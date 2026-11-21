# Review: unit 4 (TASK-401, TASK-402), recheck — 9983638 → staged

Date: 2026-11-20
Unit: `## Phase 4: The CLI entry point` (depends: 1, 2, 3)
Tasks: TASK-401 (REQ-010, REQ-030, REQ-031, REQ-033, REQ-073, TEST-010, TEST-011, TEST-012, TEST-014, TEST-018), TASK-402 (REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-056, REQ-070, REQ-071, REQ-072, SEC-005, TEST-013, TEST-014, TEST-015)
Base: 9983638f878faf8cb0b3cea4df914c57e6ea4ca4
Recheck of: `plans/greet-options/reports/phase-4/review-4.md`

Findings: P0 0 · P1 0 · P2 0 · P3 0    Partitions reviewed: 6

## Recheck of F01: fixed

- Status: **fixed**.
- Evidence: `test/greet.test.js:408` now reads
  `assert.strictEqual(err.stderr, 'usage: greet [options] unknown flag: --nmae\n');`
  The three weaker assertions (prefix `startsWith`, `endsWith('\n')`, `split('\n').length === 2`)
  were replaced by that one exact-string assertion, which is what TASK-402's Red text and
  spec §4.3 (`plans/greet-options/feature-greet-options-spec.md:399`) ask for.
- Mutation rerun in a scratch copy (`bash .dostuff/scripts/scratch-copy.sh "${TMPDIR:-/tmp}/mut-unit4-2"`),
  with `npm test` (`TEST_CMD` from `.dostuff/pipeline.conf`):

  ```
  mutation: formatUsage ignores its reason argument
    src/greet.js:185  return `usage: greet [options] some other reason\n`;
    -> npm test: 59 tests, 58 pass, 1 fail  RED
       not ok 54 - cli writes one usage line to stderr, nothing to stdout, and exits 2 on a usage error
  ```

  The same mutation was green in the previous review (59/59). It is red now.

- The prefix is guarded too, not only the reason. Two further mutants on `formatUsage` were
  added and both are red:

  ```
  mutation: formatUsage changes the fixed prefix (`[options]` -> `<options>`) -> RED (58 pass, 1 fail)
  mutation: formatUsage puts the reason before the prefix -> RED (58 pass, 1 fail)
  ```

- The new tests are load-bearing against the base tree. With the base tree
  (`scratch-copy.sh <dir> --base 9983638`) and only the new `test/greet.test.js` copied in,
  `npm test` gives 59 tests, 52 pass, **7 fail**: "cli upper-cases the whole greeting with
  --shout", "cli greets in the language of --lang", "cli prints one line per --times count",
  "cli writes one usage line to stderr, nothing to stdout, and exits 2 on a usage error",
  "cli prints the compact JSON object", "cli JSON output follows the name and shout rules of
  the text format", "cli JSON output joins the repeated lines inside the value".

- No new P0 or P1 problem was found in the lines the fix touched. The fix is a single
  `assert.strictEqual` that constrains the stderr to exactly the string the spec §4.3 and
  TASK-501 pin (`usage: greet [options] unknown flag: --nmae\n`), so it over-constrains
  nothing that the plan wants to keep.

## Partitions reviewed

1. The usage-error path: status, stdout, stderr content, exit code, one-line rule, prefix.
2. The success path: stdout bytes, empty stderr, exit code 0, no `process.exit`.
3. The JSON output shape: one key, compact form, joined value, trailing newline.
4. The flag pipeline end to end: `--name`, `--shout`, `--lang`, `--times`, `--format`.
5. The config path: the CLI reads `<cwd>/greet.config.json` before the merge, a broken config
   is a usage error even when a flag overrides the offending key.
6. Gate integrity and scope: no test deleted, skipped or relaxed; every changed file is in the
   unit's Files column or is pipeline bookkeeping.

## Tests

No test was deleted, skipped or relaxed. The diff to `test/greet.test.js` is 65 added lines
and 1 changed line (the `require` line, which gains `spawnSync`). There is no `.skip`, `xit`,
`todo` or `skip` marker anywhere in the file, and the three pre-existing tests named by
TEST-018 (`greet formats the name`, `cli defaults to world`, `cli takes --name`) are unchanged
and still pass.

`npm test` on the staged tree: 59 tests, 59 pass, 0 fail, 0 skipped, 0 todo.
Baseline in the scratch copy: the same 59/59.

The `runExpectingFailure` helper (`test/greet.test.js:14-21`) is sound. Probed live in the
scratch copy: on a usage error it returns the `execFileSync` error with `err.status === 2`,
`err.stdout` a **string** (not a Buffer, because `run` sets `encoding: 'utf8'`) equal to `''`,
and `err.stderr` equal to `"usage: greet [options] unknown flag: --nmae\n"`. On a successful
run it throws with the message `expected greet --name Ada to exit non-zero`, so it cannot pass
on a CLI that exits 0. A missing or broken binary yields `err.status` other than 2, which the
`status === 2` assertion rejects.

The `spawnSync` test (`test/greet.test.js:411-416`) is needed because `execFileSync` returns
only stdout on success (no `status`, no `stderr`), so REQ-073 cannot be asserted through the
`run` helper. Probed: `execFileSync(...)` returns a string whose `.status` and `.stderr` are
`undefined` on success.

Every spec id in the two task rows' Spec columns now has a test that turns red when the
behaviour is broken. REQ-051/052/053/054/055/056, REQ-030/031/033, REQ-010, REQ-070/071/072,
REQ-073 and SEC-005 are each pinned by at least one of the mutations in the Guards section.

## Guards

All mutations were run in a scratch copy (`bash .dostuff/scripts/scratch-copy.sh
"${TMPDIR:-/tmp}/mut-unit4-2"`), with `npm test` (`TEST_CMD` from `.dostuff/pipeline.conf`).
The copy was deleted afterwards. Baseline in the scratch copy: 59 tests, 59 pass, 0 fail.

- `mutation: formatUsage ignores its reason argument (src/greet.js:185) -> red (58 pass, 1 fail)`
- `mutation: formatUsage drops the trailing newline (src/greet.js:185) -> red (58 pass, 1 fail)`
- `mutation: formatUsage emits two lines instead of one (src/greet.js:185) -> red (58 pass, 1 fail)`
- `mutation: formatUsage changes the fixed prefix (src/greet.js:185) -> red (58 pass, 1 fail)`
- `mutation: formatUsage puts the reason before the prefix (src/greet.js:185) -> red (58 pass, 1 fail)`
- `mutation: the usage-error path exits 1 instead of 2 (bin/greet.js:16) -> red (58 pass, 1 fail)`
- `mutation: the usage-error path writes the usage line to stdout instead of stderr (bin/greet.js:15) -> red (58 pass, 1 fail)`
- `mutation: renderOutput drops the repeat count in the text format (src/greet.js:57) -> red (56 pass, 3 fail)`
- `mutation: buildGreeting never upper-cases the line (src/greet.js:44) -> red (55 pass, 4 fail)`
- `mutation: the JSON object gains a second key (src/greet.js:54) -> red (48 pass, 11 fail)`
- `mutation: the JSON value gets a trailing newline inside the string (src/greet.js:53) -> red (49 pass, 10 fail)`

Two further mutants stay green. Both were already set aside in the previous review, and both
still belong there:

- `mutation: the catch block turns every error into a usage line instead of re-throwing a
  non-UsageError (bin/greet.js:17) -> green (59 pass, 0 fail)`. The re-throw is a Green-step
  requirement of TASK-402 ("re-throws any other error so an unexpected failure shows a stack
  trace instead of a usage line") with no Red test. It is not raised as a finding: no REQ or
  SEC id in TASK-402's Spec column states it, and the branch is unreachable in practice,
  because `loadConfig` converts every config problem into a `UsageError`
  (`src/greet.js:150,157,163,176`). Verified live: the CLI in every broken-config fixture
  directory prints a usage line and exits 2, never a stack trace. The re-throw is present in
  the source (`/throw err;/` matches, verified).
- `mutation: the CLI calls process.exit(0) right after the stdout write instead of setting
  process.exitCode = 0 and falling off the end (bin/greet.js:11-12) -> green (59 pass, 0 fail)`.
  On this platform (Windows, Node v22) Node's stdout to a pipe is synchronous, so the
  truncation the spec §4.2 warns about does not reproduce. The implementation follows the
  spec exactly (`/process\.exit\(/` does not match `bin/greet.js`, verified).

### Scope: clean

Every changed file is in the unit's Files column, or is pipeline bookkeeping that the pipeline
itself owns:

- `bin/greet.js` — in TASK-401's and TASK-402's Files columns
- `src/greet.js` — in TASK-402's Files column
- `test/greet.test.js` — in TASK-401's and TASK-402's Files columns
- `plans/greet-options/feature-greet-options-tasks.md` — the plan file, always owned by the unit
  (TASK-401 and TASK-402 ticked `[x]` with the date 2026-11-20)
- `plans/greet-options/decisions.tsv` — one pipeline bookkeeping row recording the fix round
  (`2026-11-20T12:12:21Z unit-4 fix-round ... plans/greet-options/reports/phase-4/review-4.md`),
  in the same format as the phase-3 rows above it
- `plans/greet-options/reports/phase-4/review-4.md` — the previous review report, added by the
  pipeline's own stage step

No behaviour beyond the two tasks was added: `src/greet.js` gained exactly one function
(`formatUsage`) and one export line, and `bin/greet.js` gained the pipeline and the
usage-error path and nothing else. No `## Differences from the spec` entry was added and
none is needed: no file outside the Files columns was touched and no spec behaviour deviated.

The implementation in `bin/greet.js` is byte-for-byte the code the spec's §4.2 shows
(`plans/greet-options/feature-greet-options-spec.md:290-311`).

The unit's "Done when" line is met, verified live in the scratch copy: `npm test` passes,
`node bin/greet.js` prints `Hello, world` and exits 0, and `node bin/greet.js --nmae x` writes
one usage line to stderr, nothing to stdout, and exits 2.

## Checked and fine

- All six TEST-015 inputs (`--times 0`, `--lang de`, `--nmae x`, `--help`, `--name`,
  `--name ""`) produce an empty stdout, exactly one usage line on stderr starting with
  `usage: greet [options] `, and exit code 2, verified live. Only `--nmae x` is asserted by
  a test in this unit; the other five are enumerated by TASK-501 (`[ ]`, phase 5), which names
  each exact stderr line. The behaviour is correct today and the coverage is claimed by a
  task that owns it, so this is not raised as a finding.
- The stdout flush behaviour (spec §4.2, "the process ends by falling off the end of the
  script, not by calling `process.exit`") is implemented as specified: `process.exitCode = 0`
  then fall off the end.
- Nothing is written to stdout on the usage-error path. The pipeline order is parse → load →
  merge → build → write, and both `parseOptions` and `loadConfig` throw before the only
  `process.stdout.write`. Verified live: every broken-config fixture printed an empty stdout.
- A broken config is a usage error even when a flag supplies a valid value for the same key:
  `greet --times 2` in `test/fixtures/times-six/` prints an empty stdout, writes
  `usage: greet [options] invalid value for times: 6` to stderr and exits 2. Verified live.
- The `UsageError` check uses `instanceof` against the class exported by the same module
  instance `bin/greet.js` requires, so there is no dual-module hazard.
- No config content leaks into a usage line (GUD-005): the reasons observed live are
  `invalid value for format: xml`, `invalid value for lang: de`, `invalid greet.config.json`,
  `empty value for name`, `invalid value for name: 123`, `invalid value for times: 6`. None
  contains the file contents.
- The CLI reads exactly one file, `<cwd>/greet.config.json`, and the merge does not re-read it
  (`src/greet.js:140-182`, plus the existing "loadConfig reads the config file exactly once"
  test at `test/greet.test.js:378`).
- The JSON branch keeps exactly one key and the compact `JSON.stringify` form with no space
  after the colon (REQ-054, REQ-055); both are guarded by mutation.
- The repo root holds no `greet.config.json`, so the CLI tests are not affected by a stray
  config in the working directory.
- `formatUsage` is placed between `loadConfig` and `mergeOptions` in `src/greet.js`; function
  hoisting makes the order irrelevant, so this is cosmetic only.

## Open questions

None. The previous review's Q01 ("should the exact-stderr assertion wait for TASK-501?") is
answered by the fix: the assertion is in this unit's own task row, and it is now there.

## Set aside

- The re-throw of a non-`UsageError` (spec §4.2, "an unexpected failure shows a stack trace
  and exits non-zero") has no Red test; a mutant that turns every error into a usage line
  stays green. Not raised: no REQ or SEC id in this unit's Spec column states it, and the
  branch is unreachable in practice because `loadConfig` converts every config problem into a
  `UsageError`. Worth one line in TASK-501 if the owner wants the branch pinned.
- The pipe-truncation risk that TASK-401's Green step names ("the stdout stream flushes
  before the process ends and a piped run is never truncated") is not reproduced on this
  platform (Windows, Node v22): Node's stdout to a pipe is synchronous here, so a
  `process.exit(0)`-instead-of-`process.exitCode = 0` mutant produces identical bytes. The
  implementation follows the spec exactly; adding a test would not have caught anything on
  this platform.
- The five TEST-015 inputs other than `--nmae x` have no test in this unit. The behaviour is
  correct (verified live) and TASK-501 enumerates each exact stderr line, so the coverage is
  claimed by a task that owns it rather than missing.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
scope: clean
mutations: 13 run, 2 still green
top:
report: plans/greet-options/reports/phase-4/review-4-2.md