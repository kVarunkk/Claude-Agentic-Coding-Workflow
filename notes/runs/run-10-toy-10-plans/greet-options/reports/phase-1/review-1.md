# Review: phase 1, unit 1 (TASK-010, TASK-011)

Date: 2026-11-19
Base: `35e17652a7dac280612a4685b9b5d2c56ab57cb6` → staged working tree

Verdict: approve-with-notes
Findings: P0 0 · P1 1 · P2 1 · P3 0    Partitions reviewed: 6

## Index

1. [P1][Med] F01: the "catch only `UsageError`" rule is implemented but no test guards it — a parser bug silently becomes a usage error with exit 2 and no stack trace `bin/greet.js:9-16`
2. [P2][Low] F02: the parsed object can hold a present-but-`undefined` value, which breaks the "absent means absent" convention the plan states and `bin/greet.js` relies on `src/options.js:47-52`

### F01: the "catch only `UsageError`" rule is implemented but no test guards it

- Severity / confidence: P1 / High
- Location: `bin/greet.js:9-16` (`main`). Also affects: `src/options.js:44` (the only place a `UsageError` is raised today).
- Lens: tests (gate integrity / test gap), spec
- Failure: the shipped code has the right shape (`if (!(err instanceof UsageError)) throw err;`), but **no test exercises it**. If that guard is ever removed or weakened, every exception thrown inside `parseArgs` is converted into a usage error: stdout empty, one usage line on stderr, exit 2. A genuine programming error in the parser is then reported to the user as "you typed the wrong flag", with no stack trace and no diagnostic. The developer debugging it is sent down the wrong path; the bug ships because the whole suite is green.
- Evidence:
  - Mutation (scratch copy, `npm test`): replaced `if (!(err instanceof UsageError)) {` with `if (false) {` in `bin/greet.js`. **Result: 13 pass, 0 fail — still green.** The guard is unguarded.
  - Same scratch copy, with `parseArgs` raising a plain `TypeError` instead of `UsageError`: the CLI printed `status=2 stdout="" stderr="Usage: greet [--name NAME] ...\n"`. A parser bug is indistinguishable from a user typo.
  - With the shipped code (guard intact) and the same `TypeError`, the CLI correctly exits 1 with the stack trace. So the shipped behaviour is right; only the **test coverage** is missing.
  - Spec: REQ-042 ("the exit code is 2 and no stack trace, no usage text beyond that one line") and GUD-003 ("`bin/greet.js` catches that type **and nothing else**, one place prints the usage line and sets exit code 2"). Spec §4.3: "`UsageError` is the only type caught here, so an unexpected error is not swallowed and never prints a usage line in place of a stack trace."
  - Plan: TASK-011 Green step, verbatim: "`bin/greet.js` wraps the parse in a `try`/`catch` that **re-throws anything that is not a `UsageError`**". The plan makes the re-throw a required deliverable of this unit, and no test in this unit asserts it.
- Fix: add one test to `test/cli.test.js` that pins the re-throw. The cheapest form is a unit-level assertion on the exported behaviour rather than a process test, but the process contract is what the spec states, so a process test is the faithful one: run the binary with an argument that makes `parseArgs` throw a non-`UsageError` and assert the exit code is not 2 and stderr does not contain the usage line. Because `parseArgs` is a pure function of `argv`, the seam can be tested directly by requiring `bin/greet.js` is not possible (it calls `main()` on load), so the practical options are (a) export `main` from `bin/greet.js` and call it with an injected `parseArgs`, or (b) factor the catch into a small exported helper in `src/options.js`, e.g. `handleUsageError(err, { stderr, exit })`, and unit-test that it re-throws a non-`UsageError` and returns 2 for a `UsageError`. Option (b) keeps the "one place prints the usage line" property GUD-003 asks for and makes the rule testable without spawning a process. A process-level test is also possible: add a hidden env-var escape hatch, but that adds a production affordance for testing, which is worse.
  - Minimum viable: in `test/options.test.js`, assert that `parseArgs` raises a `UsageError` whose `name` is `'UsageError'` **and** that a `UsageError` is not `instanceof` the base `TypeError` — this at least pins the type identity, but it does **not** cover the re-throw rule, which is the actual gap. A real fix must cover the re-throw.

### F02: the parsed object can hold a present-but-`undefined` value

- Severity / confidence: P2 / High (behaviour confirmed, but the state is transient by plan design)
- Location: `src/options.js:47-52` (`parseArgs`), consumed at `bin/greet.js:18`.
- Lens: data-shape
- Failure: `parseArgs(['--name'])` returns `{ name: undefined }` — the key is **present** with an `undefined` value, not absent. `bin/greet.js:18` uses `'name' in flags ? flags.name : DEFAULTS.name`, so the presence test is true and the CLI prints `Hello, undefined` and exits 0. Probe output: `run('--name')` → `status=0 stdout="Hello, undefined\n" stderr=""`.
- Evidence: probe against the scratch copy, `parseArgs(['--name'])` → `{ name: undefined }`, `Object.prototype.hasOwnProperty.call(r,'name') === true`, `r.name === undefined`. CLI probe as above.
- Why P2 and not P1: the plan assigns this exact case to a later phase. TASK-020 (Phase 2) says "`parseArgs(['--name'])` … all throw `UsageError`" and the CLI case "the binary with `--name` as the last argument … has empty stdout, one usage line on stderr and exit code 2". TASK-021 owns `--shout=true` and stray arguments. So the current behaviour is a planned intermediate state, not a defect of this unit, and REQ-005/REQ-007 are not claimed by TASK-010/TASK-011.
- The plan's stated convention is nonetheless violated right now. The tasks file decisions row "What an absent flag looks like in the parsed object" says: "`parseArgs` returns an object holding **only the keys whose flags were present**. A flag that was not given means the key is **absent** from the object, **not present with an `undefined` value**, so `mergeSettings` can test for the key with `Object.prototype.hasOwnProperty`." TASK-010's Green step repeats "returns an object holding only the keys whose flags were present". `parseArgs(['--name'])` produces a present key with an `undefined` value, which is exactly the shape the convention forbids.
- Fix: none needed in this unit. Confirm that TASK-020's Green step removes the state by making the missing value a `UsageError` (which it does), and that no later task reintroduces a present-`undefined` key. The general lesson worth carrying forward: `parseArgs` should never store `undefined` as a value; it should either store a string or raise. If TASK-020 is ever re-scoped, add the `hasOwnProperty` assertion to `test/options.test.js` at that time.

### Guards

Mutations run in a scratch copy (`${TMPDIR:-/tmp}/mut-u1`), one per guard task, `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`. The scratch copy was deleted afterwards.

| Task | Mutation | Result |
|---|---|---|
| TASK-010 (REQ-003, last occurrence wins) | `src/options.js`: `flags[name] = value` → `if (!(name in flags)) flags[name] = value` (first occurrence wins) | **red** — `not ok 11 - parseArgs keeps the last occurrence of a repeated --name` |
| TASK-010 (REQ-002, space form) | covered by the last-occurrence mutant above; the space form is asserted directly by `parseArgs(['--name','Ada'])` | red under the mutant above |
| TASK-010 (REQ-015, `--shout` is a no-value flag) | `src/options.js`: `flags[name] = true` → `flags[name] = 'true'` | **red** — `not ok 12 - parseArgs reads --shout as a flag that takes no value` |
| TASK-010 (REQ-001, default greeting) | `bin/greet.js`: `DEFAULTS.name` → `'nobody'` | **red** — `not ok 1`, `not ok 6` |
| TASK-011 (REQ-004, unknown flag is a usage error) | `src/options.js`: `throw new UsageError(...)` → `return flags` | **red** — `not ok 4`, `not ok 13` |
| TASK-011 (REQ-040/041/042, exit code 2) | `bin/greet.js`: `process.exitCode = 2` → `= 1` | **red** — `not ok 4` |
| TASK-011 (REQ-041, the exact usage line) | `src/options.js`: reworded `USAGE` | **red** — `not ok 4` (the test hardcodes the spec string, so a wrong usage line is caught) |
| **TASK-011 (GUD-003, "catches that type and nothing else")** | `bin/greet.js`: `if (!(err instanceof UsageError))` → `if (false)` (catch swallows every error type) | **GREEN — 13 pass, 0 fail.** See F01. |

5 of 6 guard behaviours are red under their mutation; **1 stayed green** (the `UsageError`-only catch), which is the P1 test gap in F01.

### Scope: clean

Files changed in the staged diff: `bin/greet.js`, `src/options.js`, `test/options.test.js`, `test/cli.test.js`, plus `plans/greet-options/feature-greet-options-tasks.md`.

The four code files are exactly the `Files` column of TASK-010 and TASK-011 (`src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js`). The tasks-file change is the expected status flip (`Planned` → `In progress`), the two task ticks (`[x]`, done 2026-11-19) and the Differences entries. No unrequested behaviour was added: `src/options.js` exports only the constants and `parseArgs`/`UsageError` that TASK-010/TASK-011 own; `mergeSettings`, `resolveGreeting` and `render` are correctly left to their later tasks.

The three Differences entries are accurate and do not weaken a spec test:
- "TASK-010: the Red step needed `src/options.js` to exist before `test/options.test.js` could fail on an assertion instead of an import error" — a factual account of the Red step; it adds no behaviour.
- "TASK-010: a flag value may itself hold an `=` … `--name A=B` and `--name=A=B`" — confirmed correct by probe (both give `{ name: 'A=B' }`), matches the plan's intent that only a leading `--` argument is split on `=`. No spec id forbids it.
- "TASK-011: the usage error for an unknown flag names the offending flag with its dashes" — the plan leaves the message text free and `bin/greet.js` prints only `USAGE`, so this is inside the plan's latitude.

The tasks file's own note about `test/zz-seeded.test.js` is unchanged and the seeded file is absent from this tree, so the suite is 13/13 green as the unit's "Done when" requires.

### Tests

- **Behaviour changed without a test**: the re-throw of a non-`UsageError` (F01). This is the one gap in the unit.
- **Tests a wrong implementation would still pass**: `test/cli.test.js` hardcodes its own copy of the `USAGE` string instead of importing it from `src/options.js`. This is *not* a weakness — the hardcoded copy is what makes the usage line pinned to the spec text rather than to the implementation — but the two copies can drift. Low cost to leave as is; noting it so a future edit does not "fix" it by importing `USAGE` into the test, which would make REQ-041 untestable.
- `test/options.test.js` asserts the `UsageError` type with `err instanceof UsageError && err.name === 'UsageError'`, which is the right assertion shape (both the class identity and the `name` property).

### Open questions

Q01: Should the re-throw rule (F01) be guarded by a process-level test or by a unit test of an extracted helper? The unit-test route requires a small refactor of `bin/greet.js` or `src/options.js` that the plan does not authorise for this unit, so the author may prefer to log it as a Difference and add the guard in a later phase. Blocking: no — the shipped code is correct today; this is a coverage gap, not a live defect.

### Set aside

- `parseArgs(['--name'])` → `{ name: undefined }`, `parseArgs(['--name','--lang','es'])` → `{ name: '--lang' }`, `parseArgs(['Ada'])` → `{}`, `parseArgs(['--shout=true'])` → `{ shout: true }`: all belong to TASK-020 and TASK-021 by the plan's explicit assignment. Not findings of this unit.
- `greet --name` printing `Hello, undefined`: same deferral, but the underlying data-shape convention breach is recorded as F02 at P2.
- `test/greet.test.js` uses `execFileSync`, which throws on a non-zero exit: it will need `spawnSync` once TASK-021 makes stray arguments exit 2. TASK-021's Files column does not list `test/greet.test.js`, so that will be a scope question for Phase 2, not here.
- The `USAGE` string duplicated between `src/options.js` and `test/cli.test.js`: intentional, see Tests above.

### Checked and fine

- `parseArgs` never reads `process.argv`; the slicing happens in `bin/greet.js:8` as spec §4.3 requires. Confirmed by grep.
- `parseArgs` returns only the keys whose flags were present, for every case the unit covers (`[]` → `{}`).
- Last occurrence wins for a repeated `--name` (REQ-003), confirmed by mutation.
- `--name=Ada` and `--name Ada` give the same parsed value (REQ-002, TEST-001).
- `--shout` is recognised as a no-value flag and sets the boolean `true` (REQ-015's parsing half).
- The usage error path: stdout empty, exactly one usage line on stderr, exit 2, no stack trace, no second stderr line (REQ-004, REQ-040, REQ-041, REQ-042).
- `process.exitCode = 2` plus `return` rather than `process.exit(2)`, so a pending stdout write is never truncated, as the plan's decisions row requires.
- `instanceof` on a non-object `err` (`null`, a string) returns `false` rather than throwing, so the re-throw path cannot itself crash.
- `UsageError` identity is stable: `require('./src/options')` and `require('./src/options.js')` yield the same class object in this CommonJS single-entry setup.
- The `USAGE` line matches the spec text exactly, character for character.
- `DEFAULTS`, `LANGS`, `FORMATS`, `TIMES_MIN` and `TIMES_MAX` match the spec §4.1 declarations exactly.
- `test/greet.test.js` still passes unchanged, and the whole suite is 13/13 green.
- No network, no file-system writes, no shell invocation: the CLI writes only to stdout and stderr.

### Not checked

- The behaviour of `mergeSettings`, `resolveGreeting`, `render` and `readConfig`: not in this unit's scope and not implemented yet.
- The `--times`, `--lang` and `--format` value validation (TASK-030, TASK-031): the values are read as raw strings here, as TASK-010's plan text explicitly intends.
- Windows-specific line-ending handling of the usage line: the tests assert `\n` and pass on this machine, so the spawn path does not translate the newline on Windows.
- The seeded `test/zz-seeded.test.js` was absent from this tree, so the "seeded test still fails" expectation was not observed.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 1
scope: clean
mutations: 7, 1 still green
top:
- F01 [P1] bin/greet.js:9 the "catch only UsageError" rule has no test; removing it keeps the suite green and turns a parser bug into a usage error with exit 2
- F02 [P2] src/options.js:47 a present-but-undefined value breaks the plan's "absent means absent" convention; transient until TASK-020
report: plans/greet-options/reports/phase-1/review-1.md
