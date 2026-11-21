# phase-7/review-7.md

Review of unit 7 (TASK-701, TASK-702), base `2489cca` → staged `git diff --cached 2489cca`.

Date: 2026-11-20

## Review: unit 7 (TASK-701, TASK-702) (2489cca → staged)

Findings: P0 0 · P1 2 · P2 1 · P3 0    Partitions reviewed: 6

### Index
1. [P1][Med] F01: the new CLI-level unknown-key test cannot fail, so it does not guard the behaviour its task row claims `test/greet.test.js:629`
2. [P1][Med] F02: the new "writes no file and reads no file other than the config" test does not guard the read half of its own name `test/greet.test.js:633`
3. [P2][Low] F03: the Differences log overstates what the unknown-key CLI test proved `plans/greet-options/feature-greet-options-tasks.md:262`

### F01: the new CLI-level unknown-key test cannot fail, so it does not guard the behaviour its task row claims
- Severity / confidence: P1 / High
- Location: `test/greet.test.js:629` (`cli ignores an unknown config key and applies the known keys only`). Also affects: `plans/greet-options/feature-greet-options-tasks.md:189` (TASK-702 row), `test/fixtures/unknown-key/greet.config.json:1`.
- Lens: tests | spec
- Failure: the test asserts only `runIn(fixture('unknown-key')) === 'Hello, Ada\n'`. The fixture's unknown key is `unknownKey: 1`, a number that has no effect on the greeting, so the output is byte-identical whether the key is ignored, merged into the options, read as a file path, or evaluated. TASK-702's row says this test proves "an unknown key is ignored rather than read as a path or evaluated", and the Differences entry for TASK-702 cites exactly that mutation as the proof. The test cannot detect any of it.
- Evidence: mutation `loadConfig` changed to `config[key] = value` for unknown keys (the mutation the Differences log names) → the new CLI test stays **green**; only the pre-existing unit test `loadConfig ignores an unknown key` (`test/greet.test.js:298`) turns red. A second mutation that reads an unknown key's string value as a file path (`fs.readFileSync(value, 'utf8')`) → **all 92 tests green**, including the new CLI test. Changing the fixture's unknown key to a path-shaped string (`"C:/Windows/win.ini"`) did not make the CLI test red either, because the misuse has no observable effect on stdout.
  The unit-level assertion `loadConfig(fixture('unknown-key'))` deep-equals `{ name: 'Ada' }`, so it does pin REQ-061 ("a key that is not one of these five is ignored"). REQ-061 is therefore not untested overall, but the new CLI test adds no guard for it and the cited proof is not reproducible against it.
- Fix: either drop the redundant CLI test, or make it observable. The smallest change that makes it load-bearing is to assert on the resolved options rather than only stdout, e.g. `assert.deepStrictEqual(greetModule.loadConfig(fixture('unknown-key')), { name: 'Ada' })` at the CLI level is already covered, so the CLI test needs a different observable: a fixture whose unknown key carries a value that would change the output if it were read (for example `{"name": "Ada", "lang": "es"}` is not unknown, so use a key like `"greeting": "Bonjour"`), or assert on a side-effect channel (for example that no file named after the unknown key appears in the working directory).

### F02: the new "writes no file and reads no file other than the config" test does not guard the read half of its own name
- Severity / confidence: P1 / High
- Location: `test/greet.test.js:633` (`cli writes no file and reads no file other than the config in the working directory`). Also affects: `plans/greet-options/feature-greet-options-tasks.md:264` (Differences entry for TASK-702 / SEC-001, REQ-064).
- Lens: tests | spec
- Failure: the test's name promises two things. It only checks one: `fs.readdirSync(cwd)` is `[]` after the run, which is the write half and it does guard that (mutation: `loadConfig` writes `greet.log` into the cwd → red). The read half is not guarded: the test never observes which files were opened. A mutation that additionally reads a secret outside the working directory (`fs.readFileSync(path.join(process.env.HOME || process.env.USERPROFILE, '.greet-secret'))`) leaves the test **green**. SEC-001 says "the CLI reads no secrets, opens no network connection and writes no file"; only the write half is pinned here, and the test's name overstates what it checks.
- Evidence: mutation `loadConfig` also reads `<home>/.greet-secret` → **all 92 tests green**. Mutation `loadConfig` writes `greet.log` into the cwd → test 92 red (`not ok 92 - cli writes no file and reads no file other than the config in the working directory`). The source has no `child_process`, `http` or `net` usage today, so no defect exists in the shipped code; the gap is the guard.
- Fix: rename the test to what it checks (`cli writes no file into the working directory`), or make the read half observable. The cheapest observable read guard is to point the CLI at a working directory that contains a decoy file and assert the CLI's output does not depend on it, or to run the child with `NODE_DEBUG=fs` and assert no path outside `<cwd>/greet.config.json` appears in stderr. A network guard would need a different mechanism (for example running the child with a stubbed `net`/`http` module).

### F03: the Differences log overstates what the unknown-key CLI test proved
- Severity / confidence: P2 / High
- Location: `plans/greet-options/feature-greet-options-tasks.md:262` (TASK-702 Differences entry), also `:261`.
- Lens: spec | tests
- Failure: the TASK-702 entry states the new tests "were checked to be load-bearing by mutating `loadConfig` to read the unknown key (the unknown-key test fails)". The mutation does not fail the new CLI test; it fails the pre-existing unit test `loadConfig ignores an unknown key` from TASK-301. The entry also states "TASK-301 already ignored an unknown config key, so the Green step had nothing left to build", which is consistent with the fact that the new CLI test adds no coverage. The log therefore records a proof that does not hold against the test it names.
- Evidence: running only the two unknown-key tests under the mutation gives `not ok 1 - loadConfig ignores an unknown key` and `not ok 2 - loadConfig ignores an unknown key that names an Object.prototype member`; the new CLI test `cli ignores an unknown config key and applies the known keys only` is not in the failing list. See F01.
- Fix: name the test that actually failed (`loadConfig ignores an unknown key`, from TASK-301), or fix the test per F01 and then the entry becomes true.

### Tests
Behaviour changed without a test: none. The unit adds only tests; `src/greet.js` and `bin/greet.js` are unchanged, so no shipped behaviour was altered.
Tests a wrong implementation would still pass:
- `test/greet.test.js:629` (new CLI unknown-key test): an implementation that merges unknown keys, or reads them as a path, still passes. See F01.
- `test/greet.test.js:633` (new no-file test): an implementation that reads a secret outside the working directory still passes. See F02.
- `test/greet.test.js:611` (new `Bob; rm -rf /` test): on this platform (`cmd.exe`) `;` is not a command separator, so the test fails under a shell-injection mutation only because `cmd.exe` collapses the spaces in an unquoted argument, not because `;` separates commands. The added `& echo INJECTED` test at `test/greet.test.js:618` is the one that shows real injection on this platform (mutation produced `Hello, BobINJECTED`). The author documents this in the Differences log, so the test set as a whole is load-bearing; the `;` test alone is weak on Windows and strong on POSIX.

### Guards
- mutation: `buildGreeting` trims the name (`options.name.trim()`) -> `npm test` **red** (`not ok 88 - cli uses a name with surrounding spaces exactly as given, with no trimming`)
- mutation: `buildGreeting` lower-cases the name (`options.name.toLowerCase()`) -> `npm test` **red** (`not ok 87`, `not ok 88`, `not ok 89`, `not ok 90`, `not ok 91`, `not ok 92`)
- mutation: `bin/greet.js` runs the name through an unquoted shell (`execSync(\`printf '%s' ${options.name}\`)`) -> `npm test` **red** (`not ok 89 - cli echoes a name holding shell metacharacters as given and exits 0`, `not ok 90 - cli never hands the name to a shell`; actual stdout `Hello, BobINJECTED`)
- mutation: `loadConfig` reads the unknown key into the config (`config[key] = value`) -> `npm test` **green** for the new CLI test; **red** only for the pre-existing `loadConfig ignores an unknown key` (see F01)
- mutation: `loadConfig` reads an unknown key's string value as a file path -> `npm test` **green** (see F01)
- mutation: `loadConfig` also reads `<home>/.greet-secret` -> `npm test` **green** (see F02)
- mutation: `loadConfig` writes `greet.log` into the working directory -> `npm test` **red** (`not ok 92`)

Scope: clean. Only `plans/greet-options/feature-greet-options-tasks.md` (status ticks and Differences) and `test/greet.test.js` are changed. Both are in the unit's Files column (`src/greet.js` is listed but needed no change, which the Differences log explains). `test/fixtures/unknown-key/greet.config.json` is listed in TASK-702's Files column but was created in unit 3 and is unchanged here, which is consistent with its Files note.

### Open questions
Q01: Is the CLI-level unknown-key test meant to be the guard for REQ-061, or is the pre-existing unit test `loadConfig ignores an unknown key` accepted as the guard with the CLI test only as an end-to-end smoke check? If the former, F01 needs a fix. Blocking: no.

### Set aside
- SEC-001's "opens no network connection" half has no test. `src/greet.js` and `bin/greet.js` contain no `net`, `http` or `dns` usage, so there is no defect to fix today; only a coverage gap, and F02 already covers the missing read/no-file guard.
- Title-casing the name is not caught by the new TASK-701 tests, because the spec pins the inputs `Ada Lovelace` and `  Ada  `, both of which are already title-cased. The spec's TEST-019 wording is followed faithfully. The behaviour is caught incidentally by the new metacharacter tests and by the pre-existing `buildGreeting uses the name exactly as given` unit test. Not a defect of this unit; the input choice belongs to the spec.
- `Bob; rm -rf /` would be destructive if a future regression made the CLI shell out on a POSIX host. The shipped CLI never spawns a child process (`grep` for `child_process` in `src/` and `bin/` finds nothing), so the name is inert today. The risk only materialises with the very regression the test exists to catch, and it is inherent to the spec's own TEST-021 wording. Noted, not filed.

### Checked and fine
- `test/greet.test.js:603` (`cli uses a name with a space exactly as given`): catches trimming and lower-casing (red under both mutations). Exact byte comparison against `'Hello, Ada Lovelace\n'` pins REQ-012.
- `test/greet.test.js:607` (surrounding spaces): red under the trim mutation; pins `'Hello,   Ada  \n'` with the spaces kept.
- `test/greet.test.js:611` and `:618` (metacharacters): both red under the unquoted-shell mutation; `status === 0`, `stdout` exact, `stderr === ''` all asserted. The `&` case is the load-bearing one on `cmd.exe`, as the Differences log states.
- The temp-directory test (`test/greet.test.js:633`) cleans up in a `finally` block, runs outside the project tree, and does not depend on test ordering.
- `require('node:os')` is a new import at `test/greet.test.js:5`, used only by the new temp-dir test; the `os` name does not collide with anything else in the file.
- `spawnSync` was already imported at `test/greet.test.js:3` before this unit, so the new tests add no dependency.
- The existing `run` / `runIn` helpers are reused correctly; the `runIn(cwd, ...args)` signature already supported the new calls.
- `src/greet.js` and `bin/greet.js` are untouched by this unit and still satisfy REQ-012, REQ-061, REQ-064, SEC-001, SEC-002, SEC-003, SEC-006.
- The base tree passes all 92 tests; the staged tree passes all 92 tests.

SUMMARY
verdict: fail
p0: 0
p1: 2
p2: 1
scope: clean
mutations: 7 run, 3 still green
top:
- F01 [P1] test/greet.test.js:629 new CLI unknown-key test cannot fail; the cited proof does not reproduce
- F02 [P1] test/greet.test.js:633 new no-file test does not guard the read half of its own name
- F03 [P2] plans/greet-options/feature-greet-options-tasks.md:262 Differences log overstates the unknown-key proof
report: plans/greet-options/reports/phase-7/review-7.md
