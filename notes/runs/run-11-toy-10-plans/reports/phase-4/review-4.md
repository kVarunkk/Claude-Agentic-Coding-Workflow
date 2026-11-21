# Review: unit 4 (TASK-401, TASK-402) — 9983638 → staged

Date: 2026-11-20
Unit: `## Phase 4: The CLI entry point` (depends: 1, 2, 3)
Tasks: TASK-401 (REQ-010, REQ-030, REQ-031, REQ-033, REQ-073, TEST-010, TEST-011, TEST-012, TEST-014, TEST-018), TASK-402 (REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-056, REQ-070, REQ-071, REQ-072, SEC-005, TEST-013, TEST-014, TEST-015)
Base: 9983638f878faf8cb0b3cea4df914c57e6ea4ca4

Findings: P0 0 · P1 1 · P2 0 · P3 0    Partitions reviewed: 7

### Index
1. [P1][Med] F01: the usage-error test never asserts the reason, so a `formatUsage` that discards the reason breaks REQ-071 with the whole suite green `test/greet.test.js:403`

## What the unit does

`bin/greet.js` stops being an ad-hoc `--name` lookup and becomes the parse / load / merge / build /
render pipeline the spec §4.2 pins. `src/greet.js` gains the `formatUsage(reason)` export. The CLI
grows a `try`/`catch` that turns a `UsageError` into one usage line on stderr with exit code 2 and
nothing on stdout, and re-throws anything else.

The staged diff touches four files:

- `bin/greet.js` — rewritten to the spec's §4.2 shape, byte-for-byte the same code the spec shows.
- `src/greet.js` — `formatUsage(reason)` added at `:184-186` and exported at `:212`.
- `test/greet.test.js` — the `runExpectingFailure` helper (`:14-21`), five CLI happy-path tests
  (`:47-62`), the usage-error test (`:403-410`), the no-args spawnSync test (`:412-417`) and four
  JSON CLI tests (`:419-437`).
- `plans/greet-options/feature-greet-options-tasks.md` — TASK-401 and TASK-402 ticked `[x]` with
  the date 2026-11-20.

`npm test` on the staged tree: 59 tests, 59 pass, 0 fail.

### F01: the usage-error test never asserts the reason
- Severity / confidence: P1 / High
- Location: `test/greet.test.js:403-410` (`cli writes one usage line to stderr, nothing to stdout, and exits 2 on a usage error`). Also affects `src/greet.js:184-186` (`formatUsage`) and `bin/greet.js:15`.
- Lens: tests / spec
- Failure: `formatUsage(reason)` is the only place the reason reaches stderr. A `formatUsage` that
  ignores its argument prints `usage: greet [options] some other reason` for every usage error.
  REQ-071 requires "the usage line starts with the fixed prefix `usage: greet [options]` and is
  followed by a space and a short reason, for example `usage: greet [options] unknown flag:
  --nmae`". The reason the CLI actually produces is never checked, so the wrong reason ships
  green: 59 tests, 59 pass, 0 fail.
- Evidence: the mutation was run in a scratch copy
  (`bash .dostuff/scripts/scratch-copy.sh "${TMPDIR:-/tmp}/mut-unit4"`), with `npm test`
  (`TEST_CMD` from `.dostuff/pipeline.conf`):

  ```
  mutation: formatUsage ignores its reason argument
    src/greet.js:184  return 'usage: greet [options] ' + 'some other reason' + String.fromCharCode(10);
    -> node bin/greet.js --nmae x prints "usage: greet [options] some other reason" (exit 2)
    -> npm test: 59 tests, 59 pass, 0 fail          GREEN
  ```

  The mutant's stderr is `usage: greet [options] some other reason`, where spec §4.3 and REQ-071
  pin `usage: greet [options] unknown flag: --nmae\n`. The delivered test asserts only
  `err.stderr.startsWith('usage: greet [options] ')`, `err.stderr.endsWith('\n')` and
  `err.stderr.split('\n').length === 2`, all of which the mutant satisfies.

  The same mutant shape was run twice more and stayed green both times:
  `return 'usage: greet [options] something went wrong' + ...` → 59/59 green, and
  `return 'usage: greet [options] totally bogus reason' + ...` → 59/59 green.

  This is also a deviation from the unit's own task row. TASK-402's Red text
  (`plans/greet-options/feature-greet-options-tasks.md:149`) asks for a helper that "asserts on
  `err.status === 2`, `err.stdout === ''` and **the exact `err.stderr` string**". The delivered
  test asserts the first two exactly and the third only by prefix and line count. The spec says
  the same at `plans/greet-options/feature-greet-options-spec.md:399`: "the helper catches that
  error and asserts on `err.status === 2`, `err.stdout === ''` and the exact `err.stderr`
  string for the usage-error cases".

  `formatUsage` has no unit-seam test either: `grep -n formatUsage test/greet.test.js` returns
  nothing, so the exported function is exercised only through the CLI, and the CLI test does not
  look at the reason.

- Fix: the smallest change is to assert the exact stderr string in the CLI test, which the task
  row already prescribes:

  ```js
  test('cli writes one usage line to stderr, nothing to stdout, and exits 2 on a usage error', () => {
    const err = runExpectingFailure('--nmae', 'x');
    assert.strictEqual(err.status, 2);
    assert.strictEqual(err.stdout, '');
    assert.strictEqual(err.stderr, 'usage: greet [options] unknown flag: --nmae\n');
  });
  ```

  That single `assert.strictEqual` covers the prefix, the reason, the single trailing `\n` and the
  one-line rule at once, so the three weaker assertions can go. The `endsWith('\n')` and
  `split('\n').length` checks are then redundant; keep them only if a second case is added that
  needs a different reason.

  A complementary unit-seam test (`assert.strictEqual(formatUsage('unknown flag: --nmae'),
  'usage: greet [options] unknown flag: --nmae\n')`) would pin the exported function on its own,
  but it is not required for the fix.

- Note on later coverage: TASK-501 (`plans/greet-options/feature-greet-options-tasks.md:161`,
  still `[ ]`) will assert the exact stderr line for each bad flag, so the gap closes in phase 5
  if that task is done as written. It is still open today, and it is the unit's own row that
  asked for the assertion, so it is reported here rather than deferred.

### Guards

All mutations were run in a scratch copy (`bash .dostuff/scripts/scratch-copy.sh
"${TMPDIR:-/tmp}/mut-unit4"`), with `npm test` (`TEST_CMD` from `.dostuff/pipeline.conf`). The
copy was deleted afterwards. Baseline in the scratch copy: 59 tests, 59 pass, 0 fail.

Guard mutations, one per behaviour this unit's tests are meant to guard:

- `mutation: renderOutput drops the repeat count in the text format (src/greet.js:57,
  `.repeat(greeting.count)` → no repeat) -> red (56 pass, 3 fail: "cli prints one line per --times
  count", "renderOutput repeats the greeting line once per count in the text format",
  "renderOutput repeats the line exactly count times with no blank line at the end")`
- `mutation: buildGreeting never upper-cases the line (src/greet.js:44, drop the
  `options.shout ?` branch) -> red (55 pass, 4 fail: "cli upper-cases the whole greeting with
  --shout", "buildGreeting upper-cases the whole line when shout is true", "the JSON value
  upper-cases the whole line when shout and a name are combined", "cli JSON output follows the
  name and shout rules of the text format")`
- `mutation: the usage-error path exits 1 instead of 2 (bin/greet.js:16,
  `process.exitCode = 2` → `= 1`) -> red (58 pass, 1 fail: "cli writes one usage line to stderr,
  nothing to stdout, and exits 2 on a usage error")`
- `mutation: formatUsage ignores its reason argument (src/greet.js:184) -> GREEN (59 pass, 0
  fail). This is F01.`
- `mutation: the usage-error path writes the usage line to stdout instead of stderr
  (bin/greet.js:15) -> red (58 pass, 1 fail: "cli writes one usage line to stderr, nothing to
  stdout, and exits 2 on a usage error")`
- `mutation: formatUsage emits two lines instead of one (src/greet.js:184) -> red (58 pass, 1
  fail: the same usage-error test, on the `split('\n').length === 2` assertion)`
- `mutation: formatUsage omits the trailing newline (src/greet.js:184) -> red (58 pass, 1 fail:
  the same usage-error test, on the `endsWith('\n')` assertion)`
- `mutation: the JSON object gains a second key (src/greet.js:54,
  `{ greeting: value }` → `{ greeting: value, count: greeting.count }`) -> red (48 pass, 11 fail:
  the four `renderOutput` JSON tests, the four unit-level JSON tests and the three JSON CLI
  tests)`
- `mutation: the JSON value gets a trailing newline inside the string (src/greet.js:52-53,
  join the lines with no separator and append `\n` to each) -> red (49 pass, 10 fail: the same
  JSON tests)`
- `mutation: the CLI calls `process.exit(0)` right after the stdout write instead of setting
  `process.exitCode = 0` and falling off the end (bin/greet.js:11-12) -> GREEN (59 pass, 0 fail).
  Probed rather than counted as a defect: on this platform (Windows, Node v22.20.0) Node's
  stdout to a pipe is synchronous, so the truncation the spec §4.2 warns about does not reproduce
  here. A 300 KB greeting through a pipe and through a file both came out at 300008 bytes with
  the mutant and with the original, so the mutant is equivalent on this platform and not
  equivalent in principle. The unit's "Done when" line is satisfied either way. See "Set aside".

Two further mutations were run as probes of the design, not as guard mutations:

- `mutation: the catch block turns every error into a usage line instead of re-throwing a
  non-`UsageError` (bin/greet.js:17) -> GREEN (59 pass, 0 fail)`. The re-throw is a Green-step
  requirement of TASK-402 ("re-throws any other error so an unexpected failure shows a stack
  trace instead of a usage line") with no Red test. It is **not** raised as a finding: no REQ or
  SEC id in TASK-402's Spec column states it (REQ-070/071/072 cover the usage-error path only),
  and the branch is unreachable in practice, because `loadConfig` converts every config problem
  into a `UsageError` (`src/greet.js:150,157,163,176`). Verified by running the CLI in each
  broken-config fixture directory: every one printed a usage line and exited 2, never a stack
  trace. See "Set aside".
- `mutation: `renderOutput` builds the JSON string with `JSON.stringify(value)` plus a
  `String.fromCharCode(10)` instead of the template literal -> GREEN`. Equivalent mutant: the
  emitted bytes are identical.

### Scope: clean

Every changed file is in the unit's Files column:

- `bin/greet.js` — in TASK-401's and TASK-402's Files columns
- `src/greet.js` — in TASK-402's Files column
- `test/greet.test.js` — in TASK-401's and TASK-402's Files columns
- `plans/greet-options/feature-greet-options-tasks.md` — the plan file, always owned by the unit

No behaviour beyond the two tasks was added: `src/greet.js` gained exactly one function
(`formatUsage`) and one export line; `bin/greet.js` gained the pipeline and the usage-error path
and nothing else. No `## Differences from the spec` entry was added, and none is needed: no file
outside the Files columns was touched and no spec behaviour deviated.

The implementation in `bin/greet.js` is byte-for-byte the code the spec's §4.2 shows
(`plans/greet-options/feature-greet-options-spec.md:290-311`), so there is no design drift to
report. The traceability table already maps REQ-010/030/031/033/073 to TASK-401 and
REQ-050..056/070/071/072 and SEC-005 to TASK-402; the unit's ticks are consistent with it.

The unit's "Done when" line is met: `npm test` passes, `node bin/greet.js` prints `Hello, world`
and exits 0, and a bad flag prints one usage line to stderr, nothing to stdout, and exits 2
(verified live: `node bin/greet.js --nmae x` → stderr `usage: greet [options] unknown flag:
--nmae`, stdout empty, exit 2).

### Tests

No existing test was deleted, skipped or relaxed: the diff to `test/greet.test.js` is 66 added
lines and 1 changed line (the `require` line, which gains `spawnSync`), and there are no `.skip`,
`xit`, `todo` or `skip` markers anywhere in the file. The three pre-existing tests named by
TEST-018 (`greet formats the name`, `cli defaults to world`, `cli takes --name`) are unchanged
and still pass.

The strength of the new tests was probed by mutation (see Guards). Six of the seven behaviours
they claim to guard are properly guarded: the repeat count, the upper-casing, the exit code, the
stdout/stderr split, the one-line rule, the trailing newline, the JSON shape, the JSON key set and
the joined JSON value each turn the suite red when broken. The one that is not guarded is the
reason inside the usage line (F01).

The `runExpectingFailure` helper (`:14-21`) is sound. It catches only the `execFileSync` raise,
returns the error, and calls `assert.fail` outside the `try`, so a CLI run that exits 0 produces
an `AssertionError` with the message `expected greet <args> to exit non-zero` rather than being
swallowed. Probed live: a successful `--name Ada` run yields exactly that message and an
`AssertionError`, not a confusing `undefined` property error. A spawn failure (the script missing)
yields `err.status === 1` and a stack trace on stderr, which the `status === 2` assertion rejects,
so the helper cannot pass on a broken binary.

The `spawnSync` test (`:412-417`) is needed because `execFileSync` returns only stdout on success
(no `status`, no `stderr`), so the REQ-073 "exits 0 and writes nothing to stderr" assertion
cannot be made through the existing `run` helper. Verified: `execFileSync(...)` returns a string
whose `.status` and `.stderr` are `undefined` on success.

### Checked and fine
- The stdout flush behaviour (spec §4.2, "the process ends by falling off the end of the script,
  not by calling `process.exit`") is implemented as specified: `process.exitCode = 0` then fall off
  the end, with no `process.exit` call anywhere in `bin/greet.js`.
- Nothing is written to stdout on the usage-error path. The pipeline order is parse → load →
  merge → build → write, and both `parseOptions` and `loadConfig` throw before the only
  `process.stdout.write`. Confirmed live: every broken-config fixture printed an empty stdout.
- The `UsageError` check uses `instanceof` against the class exported by the same module instance
  `bin/greet.js` requires, so there is no dual-module hazard.
- No config content leaks into a usage line (GUD-005): the reasons observed live are
  `invalid value for format: xml`, `invalid value for lang: de`, `invalid greet.config.json`,
  `empty value for name`, `invalid value for name: 123`, `invalid value for times: 6`. None
  contains the file contents.
- The CLI reads exactly one file, `<cwd>/greet.config.json`, and the merge does not re-read it
  (`src/greet.js:140-182`, plus the existing "loadConfig reads the config file exactly once" test
  at `test/greet.test.js:378`).
- The JSON branch keeps exactly one key and the compact `JSON.stringify` form with no space after
  the colon (REQ-054, REQ-055); both are guarded by mutation.
- The CLI now honours `--lang`, `--shout`, `--times` and `--format` end to end, and the five
  pre-existing CLI/unit tests for the old behaviour still pass unchanged (TEST-018).
- `process.exitCode = 0` on the success path is explicit and cannot mask a non-zero exit.
- The `run` helper still has the exact signature the spec pins (`:409`), and `runIn` is correctly
  left for TASK-601, which owns the fixture-directory runs.

### Open questions
Q01: Should the exact-stderr assertion in F01 wait for TASK-501, which will assert the exact
line for each bad flag? If the plan owner prefers to keep TASK-402 minimal, F01 could be
re-scoped to "closed by TASK-501" instead of a fix in this unit. Blocking: no (the fix is one
line and the behaviour is currently unguarded).

### Set aside
- The re-throw of a non-`UsageError` (spec §4.2, "an unexpected failure shows a stack trace and
  exits non-zero") has no Red test; a mutant that turns every error into a usage line stays
  green. Not raised: no REQ or SEC id in this unit's Spec column states it, and the branch is
  unreachable in practice because `loadConfig` converts every config problem into a `UsageError`.
  Worth one line in TASK-501 if the owner wants the branch pinned.
- The pipe-truncation risk that TASK-401's Green step names ("the stdout stream flushes before
  the process ends and a piped run is never truncated") is not reproduced on this platform
  (Windows, Node v22.20.0): Node's stdout to a pipe is synchronous here, so a
  `process.exit(0)`-instead-of-`process.exitCode = 0` mutant produces identical bytes through a
  pipe and through a file. The implementation follows the spec exactly; there is no test asserting
  the pipe behaviour, and adding one would not have caught anything on this platform.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
scope: clean
mutations: 9 run, 1 still green
top:
- F01 [P1] test/greet.test.js:403 the usage-error test never asserts the reason, so a formatUsage that discards the reason breaks REQ-071 with the whole suite green
report: plans/greet-options/reports/phase-4/review-4.md
