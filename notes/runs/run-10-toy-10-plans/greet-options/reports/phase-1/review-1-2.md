# Review: phase 1, unit 1 (TASK-010, TASK-011) — RECHECK

Date: 2026-11-19
Base: `35e17652a7dac280612a4685b9b5d2c56ab57cb6` → staged working tree
Previous review: `plans/greet-options/reports/phase-1/review-1.md` (verdict: fail, P1 1, P2 1)

Verdict: approve
Findings: P0 0 · P1 0 · P2 0 · P3 0    Partitions reviewed: 5

## Index

1. [P1][Med] F01: **fixed** — the "catch only `UsageError`" rule is now guarded by a process-level test `test/cli.test.js:43-65`
2. [P2][Low] F02: **open, unchanged, still deferred** — a present-but-`undefined` value in the parsed object `src/options.js:47-52`

No new P0 or P1 findings in the lines the fix touched.

### F01: the "catch only `UsageError`" rule is implemented but no test guards it — FIXED

- Severity / confidence: P1 / High → **fixed**, verified by mutation
- Location: `bin/greet.js:9-16` (`main`); the guard now lives in `test/cli.test.js:43-65`.
- Lens: tests (gate integrity / test gap), spec
- Previous failure: the shipped code had the right shape (`if (!(err instanceof UsageError)) throw err;`) but no test exercised it. The mutation `if (!(err instanceof UsageError)) {` → `if (false) {` kept the whole suite green (13 pass, 0 fail).
- Fix applied: `test/cli.test.js` gained `cli re-throws an error that is not a UsageError`. It writes a `--require` preload module into a fresh temp directory at test time, replaces `parseArgs` on the loaded `src/options.js` module with one that throws a plain `TypeError`, runs the binary as a child process with that preload, and asserts: stdout empty, exit status **not** 2, stderr does **not** contain the usage line, stderr **does** contain `TypeError: parser bug`.
- Evidence (recheck, scratch copy `${TMPDIR:-/tmp}/mut-u1-recheck`, `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`):
  - Baseline: **14 pass, 0 fail** (the previous 13 plus the new guard test).
  - Mutation `bin/greet.js`: `if (!(err instanceof UsageError)) {` → `if (false) {` → **red**: `not ok 5 - cli re-throws an error that is not a UsageError` (13 pass, 1 fail). This is the exact mutation that was green in the previous review; it is now caught.
  - Mutation `bin/greet.js`: delete the whole `if (!(err instanceof UsageError)) { throw err; }` block, so every error becomes a usage error → **red**: `not ok 5` (13 pass, 1 fail).
  - Direct probe of the shipped code with the preload: `status=1`, `stdout=""`, stderr holds the full `TypeError: parser bug` stack trace and no usage line. The re-throw reaches the top of the process and is not swallowed.
  - Module identity verified: `require('<root>/src/options.js')` and `require('<root>/src/options')` return the **same module object** (`a === b` is `true`), so the preload's mutation of `module.exports.parseArgs` is seen by `bin/greet.js`'s destructuring. The preload runs before `bin/greet.js` is loaded, so the replacement is in place before `const { parseArgs } = require(...)` runs. The seam works as intended, not by accident.
- The test is faithful to the spec, which states the rule in three places: GUD-003 ("`bin/greet.js` catches that type **and nothing else**"), spec §4.3 ("`UsageError` is the only type caught here, so an unexpected error is not swallowed and never prints a usage line in place of a stack trace") and REQ-042. The spec does **not** pin an exit code for a non-usage error, so asserting `status !== 2` rather than `status === 1` is the right strength: it pins "not the usage-error path" without inventing a contract the spec does not state.
- The new test does not weaken any existing gate: the assertions it adds are all new (`stdout === ''`, `status !== 2`, no usage line, stack trace present), and no existing assertion was removed or relaxed. The temp directory is created with `fs.mkdtempSync` and removed in a `finally` block, so it is cleaned up even when an assertion fails.
- The approach adds **no production affordance**: `src/options.js` still exports exactly the list the spec pins in §4.1, and `bin/greet.js` still exports nothing. The Differences entry at `plans/greet-options/feature-greet-options-tasks.md:227` records this choice and its reason accurately.

### F02: the parsed object can hold a present-but-`undefined` value — OPEN, unchanged, still deferred

- Severity / confidence: P2 / High (behaviour confirmed, transient by plan design)
- Location: `src/options.js:47-52` (`parseArgs`), consumed at `bin/greet.js:18`.
- Lens: data-shape
- Status: **unchanged by this fix round**, and the fix round did not touch the data-shape path. The state is still `parseArgs(['--name'])` → `{ name: undefined }`, and the CLI still prints `Hello, undefined` and exits 0.
- Why it stays P2: the plan assigns this case to a later phase. TASK-020 (Phase 2) says "`parseArgs(['--name'])` … all throw `UsageError`" and that the binary with `--name` as the last argument has empty stdout, one usage line on stderr and exit code 2. TASK-021 owns `--shout=true` and stray arguments. REQ-005 and REQ-007 are not claimed by TASK-010/TASK-011.
- The convention breach is real, though: the tasks file's decisions row "What an absent flag looks like in the parsed object" says the key must be **absent**, "not present with an `undefined` value", and TASK-010's Green step repeats "returns an object holding only the keys whose flags were present". `parseArgs(['--name'])` produces exactly the shape the convention forbids.
- Fix: none in this unit. Carry the same note forward: when TASK-020 lands, `parseArgs` should either store a string or raise, never `undefined`. If TASK-020 is ever re-scoped, add the `hasOwnProperty` assertion to `test/options.test.js` at that time.

## Guards

Recheck mode: the previous review's P1 mutation was rerun, plus the other guard behaviours of this unit, all in a scratch copy (`${TMPDIR:-/tmp}/mut-u1-recheck`, `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`). The scratch copy was deleted afterwards; no probe files were written into the repo.

| Task / behaviour | Mutation | Result |
|---|---|---|
| **TASK-011 / GUD-003, "catches that type and nothing else"** (the previous review's green mutant) | `bin/greet.js`: `if (!(err instanceof UsageError)) {` → `if (false) {` | **red** — `not ok 5 - cli re-throws an error that is not a UsageError` (13 pass, 1 fail). **Now red, was green.** |
| TASK-011 / GUD-003, variant | `bin/greet.js`: delete the whole `if (!(err instanceof UsageError)) { throw err; }` block | **red** — `not ok 5` (13 pass, 1 fail) |
| TASK-010 / REQ-003, last occurrence wins | `src/options.js`: `flags[name] = value` → `if (!(name in flags)) flags[name] = value` | **red** (13 pass, 1 fail) |
| TASK-010 / REQ-015, `--shout` is a no-value flag | `src/options.js`: `flags[name] = true` → `flags[name] = 'true'` | **red** (13 pass, 1 fail) |
| TASK-010 / REQ-001, default greeting | `src/options.js`: `name: 'world'` → `name: 'nobody'` | **red** (12 pass, 2 fail) |
| TASK-011 / REQ-004, unknown flag is a usage error | `src/options.js`: `throw new UsageError(...)` → `return flags` | **red** (12 pass, 2 fail) |
| TASK-011 / REQ-040 to REQ-042, exit code 2 | `bin/greet.js`: `process.exitCode = 2` → `= 1` | **red** (13 pass, 1 fail) |
| TASK-011 / REQ-041, the exact usage line | `src/options.js`: reworded `USAGE` | **red** (13 pass, 1 fail) |
| TASK-011 / REQ-042, no partial greeting on the error path | `bin/greet.js`: added `console.log('partial greeting')` before the usage write | **red** — `not ok 4` (13 pass, 1 fail) |
| TASK-011 / GUD-003, the `UsageError` type identity | `src/options.js`: `class UsageError extends Error {` → `class UsageError {` | **red** (1 pass, 8 fail) |
| baseline | none | 14 pass, 0 fail |

**9 of 9 guard behaviours are red under their mutation; 0 stayed green.** The one mutant that was green in the previous review (the `UsageError`-only catch) is now red.

One mutant was examined and judged **equivalent**, not a defect: rewriting the catch as `if (err && err.name === 'UsageError') { } else { throw err; }` stayed green. It cannot change any output, because `UsageError` sets `this.name = 'UsageError'` in its constructor and no other error type produced by `parseArgs` carries that name, so the `name`-based check selects exactly the same set of errors as the `instanceof` check. The shipped code uses `instanceof`, which is the stricter form the spec names ("the dedicated `UsageError` type").

### Scope: clean

Files in the staged diff against `35e17652a7dac280612a4685b9b5d2c56ab57cb6`:

- `src/options.js`, `bin/greet.js`, `test/options.test.js`, `test/cli.test.js` — exactly the `Files` column of TASK-010 and TASK-011.
- `plans/greet-options/feature-greet-options-tasks.md` — the status flip (`Planned` → `In progress`), the two task ticks (`[x]`, done 2026-11-19), the new `**Guard (fix round):**` paragraph on the TASK-011 row, and the Differences entries.
- `plans/greet-options/decisions.tsv` — one new `unit-1 / fix-round` row pointing at the previous review.
- `plans/greet-options/reports/phase-1/review-1.md` — the previous review's report, staged by the pipeline as the unit's report artifact.

The fix round added no production behaviour: `src/options.js` still exports only the constants and `parseArgs`/`UsageError` that TASK-010/TASK-011 own (`mergeSettings`, `resolveGreeting` and `render` remain correctly left to their later tasks), and `bin/greet.js` still exports nothing. The only code change in the fix round is in `test/cli.test.js`.

The new Differences entry (`feature-greet-options-tasks.md:227`) is accurate and does not weaken a spec test: it records the mechanism (a `--require` preload), the reason (the spec pins the export list of `src/options.js` in §4.1, and the preload adds no production affordance) and the four asserted properties. The three pre-existing Differences entries were re-checked in the previous review and are unchanged.

### Tests

- **The one gap of the previous review is closed**: the re-throw of a non-`UsageError` now has a guard, and the guard is proven by mutation.
- **No test was deleted, skipped or relaxed** in the fix round. The suite grew from 13 to 14 tests; the baseline is 14 pass, 0 fail.
- **No new P2 reported**: the previous review's F02 stands unchanged, and the fix round did not touch the data-shape path.
- `test/cli.test.js` still hardcodes its own copy of the `USAGE` string rather than importing it from `src/options.js`. That is deliberate and must stay: the hardcoded copy is what pins REQ-041 to the spec text rather than to the implementation (confirmed by the `USAGE` mutation above, which is red).
- The new test asserts `status !== 2` rather than an exact code. This is the right strength: the spec pins no exit code for a non-usage error, only that the error is "not swallowed" and never replaced by a usage line.

### Open questions

Q01 (carried, non-blocking): the "absent means absent" convention (F02) still has no `hasOwnProperty` assertion in `test/options.test.js`. It belongs to TASK-020, which owns the missing-value case. Blocking: no.

### Set aside

- `parseArgs(['--name'])` → `{ name: undefined }`, `parseArgs(['--name','--lang','es'])` → `{ name: '--lang' }`, `parseArgs(['Ada'])` → `{}`, `parseArgs(['--shout=true'])` → `{ shout: true }`: all belong to TASK-020 and TASK-021 by the plan's explicit assignment. Not findings of this unit.
- `greet --name` printing `Hello, undefined`: same deferral, recorded as F02 at P2.
- `test/greet.test.js` uses `execFileSync`, which throws on a non-zero exit: it will need `spawnSync` once TASK-021 makes stray arguments exit 2. TASK-021's Files column does not list `test/greet.test.js`, so that is a scope question for Phase 2, not here.
- The `USAGE` string duplicated between `src/options.js` and `test/cli.test.js`: intentional, see Tests above.

### Checked and fine

- The re-throw path in the shipped code: `status=1`, empty stdout, the full `TypeError` stack trace on stderr, no usage line. Verified by direct probe, not only by the test.
- The preload seam resolves the same module instance as `bin/greet.js` (`require('src/options.js') === require('src/options')` is `true`), so the replacement of `parseArgs` is the one the CLI calls.
- The preload runs before `bin/greet.js` loads, so the mutated `parseArgs` is in place before the destructuring in `bin/greet.js:2`.
- The temp directory is created with `fs.mkdtempSync` and removed in a `finally`, so it survives a failed assertion only long enough to be cleaned up.
- The test spawns the binary with `process.execPath` and a `--require` preload; no shell is involved and no value from argv is passed to a shell (PAT-003).
- The whole suite is 14/14 green, and `test/greet.test.js` still passes unchanged, as the unit's "Done when" requires.
- `process.exitCode = 2` plus `return` rather than `process.exit(2)`, so a pending stdout write is never truncated.
- `instanceof` on a non-object `err` (`null`, a string) returns `false` rather than throwing, so the re-throw path cannot itself crash.
- The `USAGE` line matches the spec text exactly, character for character.
- `DEFAULTS`, `LANGS`, `FORMATS`, `TIMES_MIN` and `TIMES_MAX` match the spec §4.1 declarations exactly.

### Not checked

- The behaviour of `mergeSettings`, `resolveGreeting`, `render` and `readConfig`: not in this unit's scope and not implemented yet.
- The `--times`, `--lang` and `--format` value validation (TASK-030, TASK-031): the values are read as raw strings here, as TASK-010's plan text explicitly intends.
- Non-Windows line-ending handling of the usage line and the stack trace: the tests assert `\n` and pass on this machine.
- The seeded `test/zz-seeded.test.js` was absent from this tree, so the "seeded test still fails" expectation was not observed.
- Whether `--require` preload modules behave identically on other Node versions and platforms: only Node v22.20.0 on Windows 11 was exercised here.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
scope: clean
mutations: 10, 0 still green
top:
- F02 [P2] src/options.js:47 a present-but-undefined value still breaks the plan's "absent means absent" convention; deferred to TASK-020, unchanged by this fix round
report: plans/greet-options/reports/phase-1/review-1-2.md