# Review: unit 5 (TASK-501, TASK-502) — greet CLI usage-error contract

Date: 2026-11-20
Base: `e41cadae3c6b475b7138d38f2f3eb80167409df4`
Unit: 5 — TASK-501, TASK-502
Spec: `plans/greet-options/feature-greet-options-spec.md` v0.4

Findings: P0 0 · P1 1 · P2 0 · P3 0    Partitions reviewed: 5

## Index

1. [P1][Med] F01: a value containing a newline makes stderr hold more than one line, contradicting REQ-070 and REQ-072, and no test in this unit covers it — `src/greet.js:77` (`parseOptions`), `src/greet.js:185` (`formatUsage`), `test/greet.test.js:26` (`assertUsageError`)

## What the unit did

Staged diff (`git diff --cached e41cadae3c6b475b7138d38f2f3eb80167409df4`) touches two files:

- `test/greet.test.js` — adds the `assertUsageError(args, expectedStderr)` helper (lines 26-33) and 17 new CLI route tests (lines 448-514).
- `plans/greet-options/feature-greet-options-tasks.md` — ticks TASK-501 and TASK-502, adds three Differences entries.

No production code changed (`src/greet.js` and `bin/greet.js` are byte-identical to the base). The staged diff has **0 deleted lines** in the test file and no `.skip` / `only` / `.todo`, so no gate was loosened.

The 17 new cases map one-to-one onto the two task rows' Red lists (7 for TASK-501, 10 for TASK-502) with the exact reason strings each row names. `npm test` in a scratch copy: 76 tests, 76 pass, 0 fail.

Both rows are labelled **Red**, but every new case passes against the base tree's production code. Verified directly: copying the new `test/greet.test.js` onto a `--base e41cada` scratch tree gives 76 pass / 0 fail. The behaviour was already pinned at the unit seam by TASK-102 and the prefix/exit code were already wired by TASK-402, so these are effectively **Guard** rows. Per `.dostuff/skills/writing-tasks/SKILL.md:73` ("a `**Red:**` test that passes before its code is written: log it with the reason"), the agent logged both under Differences with the reason. That is the prescribed remedy, so this is compliant, not a defect.

## F01: a newline in an offending value breaks the one-line stderr contract

- Severity / confidence: P1 / High
- Location: `src/greet.js:77` (`parseOptions`, `unexpected argument: ${arg}`), `src/greet.js:99` (`invalid value for ${arg}: ${value}`), `src/greet.js:80` (`invalid flag syntax: ${arg}`), `src/greet.js:185` (`formatUsage`). Test gap at `test/greet.test.js:26` (`assertUsageError`).
- Lens: correctness, spec, tests
- Failure: a value that contains a newline reaches a usage error, so the reason string carries the newline and `formatUsage` returns a **two-line** string. REQ-072 says "Exactly one line is written, so stderr never holds more than one line"; REQ-070 says "On any usage error the CLI writes exactly one line to stderr". Both are violated.

  Concretely (reproduced on the base tree, production code unmodified by this diff):

  ```
  greet $'--lang de\nX'
    stderr = "usage: greet [options] invalid value for --lang: de\nX\n"   (2 lines)
  greet $'--times 03\nX'
    stderr = "usage: greet [options] invalid value for --times: 03\nX\n"  (2 lines)
  greet $'--name=A\nB'
    stderr = "usage: greet [options] invalid flag syntax: --name=A\nB\n"  (2 lines)
  greet $'Ada\nBob'
    stderr = "usage: greet [options] unexpected argument: Ada\nBob\n"    (2 lines)
  ```

  The config path has the same defect: a `greet.config.json` holding `{"lang": "de\nX"}` writes
  `"usage: greet [options] invalid value for lang: de\nX\n"` to stderr, two lines.

- Evidence:
  - Direct probe of the CLI at base (output above), reproduced on `src/greet.js` as committed.
  - `src/greet.js:94` consumes the next argv entry verbatim; `src/greet.js:185` interpolates the reason into `usage: greet [options] ${reason}\n` with no newline handling.
  - Spec `plans/greet-options/feature-greet-options-spec.md:91-93`: REQ-070 "On **any** usage error the CLI writes exactly one line to stderr, writes nothing to stdout, and exits with code 2"; REQ-072 "The usage line ends with a single `\n`. Exactly one line is written, so stderr never holds more than one line."
  - The spec is aware that user values can carry newlines: SEC-003 (spec:113) says "A name containing shell metacharacters, quotes or **newlines** is echoed as given and changes nothing about how the process runs". That carve-out is for the **stdout** name path (REQ-012). No equivalent carve-out exists for the stderr reason path, so a newline-bearing offending value is in scope for REQ-070/REQ-072.
  - No test in the whole suite passes a newline inside an argv value or a config value (`grep` over `test/greet.test.js` finds no such input), so nothing catches it. The new `assertUsageError` helper would catch it (`err.stderr.split('\n').length === 2`) — the gap is the missing input, not a weak assertion.

- Why this is in this unit's report even though `src/greet.js` is untouched: this unit is the one that adds the route-level proofs for REQ-070, REQ-071 and REQ-072 (both rows cite them), and its helper is documented as "The usage-error contract end to end: one exact line on stderr". Signing off this unit would mark REQ-070/REQ-072 as route-proven when the contract holds only for the 17 whitelisted inputs in the two Red lists.

- Fix: the smallest change is in `src/greet.js`, and it needs a spec decision first, because §4.3 pins the reason as "the exact string in the table" and says the reason is built from user data "beyond the offending value itself":
  - Option A (reject): treat a value containing `\n` or `\r` as a usage error with a fixed reason that does not echo the value (e.g. `invalid value for --lang`), so stderr stays one line. This keeps the "never holds more than one line" guarantee absolute.
  - Option B (sanitise): collapse any newline in the offending value to a space before it reaches `formatUsage`, so the value is still named (GUD-005) but the line stays one line.
  Either way, add a route-level test that passes a newline-bearing value and asserts one line on stderr, e.g. `assertUsageError(['--lang', 'de\nX'], 'usage: greet [options] ...')`. The `assertUsageError` helper already exists and already enforces the one-line rule.

## Tests

- The 17 new route tests are load-bearing and each pins its own reason string: a prefix mutation, an exit-code mutation, a trailing-newline removal and a stdout-leak injection each turn 18 tests red (17 new + the pre-existing `cli writes one usage line to stderr, nothing to stdout, and exits 2 on a usage error`), and per-reason mutations turn exactly the tests that pin that reason red. See the Guards section.
- Behaviour changed without a test: none introduced by this diff (no production change).
- The unit's route-level REQ-070/REQ-072 proof covers a fixed whitelist of 17 inputs. The general claim "exactly one line on stderr" is not proven for a value containing a newline: see F01.
- Redundancy (not a defect): the new `--nmae x` case duplicates the pre-existing test at `test/greet.test.js:413-419`, which asserts the same line for the same input.

## Scope

`Scope: clean` — every changed file is in the unit's Files column (`test/greet.test.js`) or is the tasks file that carries the tick and the Differences log. No behaviour beyond the two task rows was added; the only production-code-adjacent content is the shared test helper, which sits inside `test/greet.test.js`. No fixture directory was created or changed. The deferred half of TEST-023 (the route-level `invalid greet.config.json` line) is covered by TASK-602's Red list ("with a top-level array it writes `usage: greet [options] invalid greet.config.json\n` and exits 2"), and the `runIn(cwd, ...args)` helper it needs is introduced by TASK-601, so the deferral in Differences is accurate and in-scope.

### Differences entries checked

- TASK-501 / TASK-502 "the Red cases pass as soon as they are written, so no production code changed in this unit" — **accurate**. Verified against the base tree (76 pass / 0 fail) and against the staged diff (no production files changed).
- TASK-501 "the prefix mutation fails 18 tests, the exit code mutation fails 18 tests, and each reason mutation fails the tests that pin that reason" — **accurate**. Reproduced: 18 / 18 / 2.
- TASK-502 (TEST-023) deferral of the config half to TASK-602 — **accurate** (TASK-602's Red list names the `top-level-array` route case; `runIn` belongs to TASK-601).

## Guards

All mutations were run in a scratch copy at `${TMPDIR:-/tmp}/mut-5` (`bash .dostuff/scripts/scratch-copy.sh`), never in the repo, with `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`. The scratch copy and the base-copy scratch were deleted afterwards; no process was left running.

- mutation: usage prefix `usage: greet [options] ` -> `usage: greet [opts] ` in `formatUsage` -> test red (18 failed)
- mutation: exit code `process.exitCode = 2` -> `= 1` in `bin/greet.js` -> test red (18 failed)
- mutation: usage line trailing `\n` removed in `formatUsage` -> test red (18 failed)
- mutation: reason `invalid flag syntax: ${arg}` -> `bad flag syntax: ${arg}` -> test red (2 failed: the new CLI test and the pre-existing unit test)
- mutation: reason `invalid argument: --` -> `invalid arg: --` -> test red (2 failed: the new CLI test and the pre-existing unit test)
- mutation: usage path also writes `LEAK` to stdout in `bin/greet.js` -> test red (18 failed)

mutations: 6 run, 0 still green

Baseline before any mutation: 76 tests, 76 pass, 0 fail.

## Open questions

Q01: Does the spec want a value containing a newline to be rejected with a fixed reason (Option A) or to have its newline collapsed (Option B)? §4.3 pins the reason as "the exact string in the table" and says the reason names the offending value, so both readings are defensible and the choice changes the pinned string. Blocking: no for the tests, yes for the exact expected stderr of the new F01 test. Non-blocking: no.

Q02: Should the two rows be relabelled from **Red** to **Guard** in the tasks file, given that every case passes against the base tree? Per the tasks file's own convention (line 22) a Guard test is not logged as a Difference, so relabelling would make the three Differences entries unnecessary. Non-blocking: no, the current logging follows the writing-tasks skill.

## Set aside

- The `assertUsageError` helper's `err.stderr.split('\n').length === 2` assertion is redundant with the exact-string comparison on the line above. Redundant, not wrong. P3-level nit, not reported.
- `assertUsageError` inherits `runExpectingFailure`'s broad `catch (err)`, so a spawn failure (ENOENT) would be reported as a stderr mismatch rather than a clearer message. Pre-existing helper, unchanged by this diff, and the assertions still fail loudly. Set aside.
- The new `--nmae x` case duplicates the pre-existing test at `test/greet.test.js:413-419`. Set aside as harmless redundancy.
- No test passes a newline inside an argv value **on the stdout name path**. That path is spec-intended (SEC-003, REQ-012: the name is echoed verbatim) and TASK-701 owns the route-level name fidelity tests. Set aside; only the stderr path is at issue.

## Checked and fine

- Gate integrity: 0 deleted lines in the test diff; no `.skip` / `only` / `.todo` / `xit`; no relaxed assertion; no lint, type or CI config touched; no coverage or timeout threshold lowered.
- Task-row fidelity: all 17 required cases present with the exact reason strings each row names, checked one by one against `TASK-501` (7 cases) and `TASK-502` (10 cases).
- `assertUsageError` is not vacuous: `err.stdout` and `err.stderr` are real strings (verified by probe), and `strictEqual(undefined, '')` would fail, so an uncaptured stream cannot make it pass.
- A crash in `bin/greet.js` (a non-`UsageError` re-thrown) would surface as exit code 1 plus a stack trace on stderr, and would fail both the `err.status === 2` and the exact-stderr assertions. The new tests would catch an unhandled error path.
- The `assert.fail` in `runExpectingFailure` sits after the `try` block, so a CLI that exits 0 on a usage error fails the test rather than passing silently.
- `check-plan.sh plans/greet-options` passes: "50 REQ/SEC ids, 19 tasks. OK".
- Tick format matches the file's convention (`[x]` plus the ISO date 2026-11-20); TASK-601 and TASK-602 remain `[ ]`.
- No fixture directory was created, changed or deleted; `test/fixtures/` is untouched.
- The repository working tree was not modified by this review: only `plans/greet-options/reports/phase-5/review-5.md` was written.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
scope: clean
mutations: 6 run, 0 still green
top:
- F01 [P1] src/greet.js:77,185 a value containing a newline makes stderr hold two lines, contradicting REQ-070 and REQ-072, and this unit's route-level tests cover only a whitelist of inputs
report: plans/greet-options/reports/phase-5/review-5.md
