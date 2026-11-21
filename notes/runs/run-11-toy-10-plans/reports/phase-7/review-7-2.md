# phase-7/review-7-2.md

Review of unit 7 fix round (TASK-701, TASK-702), base `2489cca` → staged `git diff --cached 2489cca`.

Date: 2026-11-20

## Review: unit 7 fix round (TASK-701, TASK-702) (2489cca → staged)

Findings: P0 0 · P1 1 · P2 1 · P3 0    Partitions reviewed: 6

### Index
1. [P1][Med] F01: the file-system spy observes only part of the `fs` surface, so SEC-001's "reads no secrets" and "writes no file" halves both escape `test/greet.test.js:61`
2. [P2][Low] F02: the spy turns a file descriptor into a bogus path, so a legitimate `fstatSync` breaks the two spy-backed tests `test/greet.test.js:61`

### F01: the file-system spy observes only part of the `fs` surface, so SEC-001's "reads no secrets" and "writes no file" halves both escape
- Severity / confidence: P1 / High
- Location: `test/greet.test.js:61` (`FS_SPY_SOURCE`, the `METHODS` list). Also affects: `test/greet.test.js:684` (`cli ignores an unknown config key: it is not read as a path and not evaluated`), `test/greet.test.js:706` (`cli writes no file and reads no file other than the config in the working directory`), `plans/greet-options/feature-greet-options-tasks.md:264` (the TASK-702 Differences entry for SEC-001).
- Lens: tests | spec
- Failure: the spy is the mechanism that makes SEC-001 observable, and it instruments a fixed list of eleven **synchronous** `fs` methods. Two holes follow.
  (a) **Reads.** Node exposes the same operations as promises (`fs.promises.readFile`, `fs.promises.open`, `fs.promises.stat`) and as callback APIs (`fs.readFile`, `fs.open`, `fs.read`, `fs.opendir`, `fs.glob`, `fs.globSync`). None are instrumented, so a `loadConfig` that reads `<home>/.greet-secret` through `fs.promises.readFile(...).catch(() => {})` is invisible to the spy, and SEC-001 ("The CLI reads no secrets") is broken while both new tests stay green. This also breaks SEC-004 ("The config file is read with `fs.readFileSync`"), which has no test of its own: the only `readFileSync` test in the file (`test/greet.test.js:462`) counts calls rather than pinning the API.
  (b) **Writes.** The spy records no writes at all. `fs.writeFileSync` does not route through the JS-visible `fs.openSync` (verified: patching `fs.openSync` records nothing for a `writeFileSync` call; node uses the internal binding), and `writeFileSync`, `appendFileSync`, `createWriteStream` and `mkdirSync` are not in `METHODS`. The only write check is `assert.deepStrictEqual(fs.readdirSync(cwd).sort(), ['decoy.json'])` at `test/greet.test.js:722`, which inspects the **working directory only**. A `loadConfig` that writes `<home>/.greet-written` or `<tmpdir>/greet-side-effect.txt` leaves the working directory untouched, so SEC-001 ("writes no file") is broken while every test stays green. The test's own name, `cli writes no file and reads no file other than the config in the working directory`, promises the write half it does not check, which is the same defect class the previous round raised for the read half.
- Evidence: three mutations, all run in a scratch copy with `npm test`:
  - `loadConfig` reads `<home>/.greet-secret` with `fs.readFileSync` -> **red** (`not ok 92`, `not ok 93`). This is the case the fix round closed.
  - `loadConfig` reads `<home>/.greet-secret` with `require('fs').promises.readFile(...).catch(() => {})` -> **green** (93/93 pass).
  - `loadConfig` writes `<home>/.greet-written` with `fs.writeFileSync` -> **green** (93/93 pass).
  - `loadConfig` writes `<tmpdir>/greet-side-effect.txt` with `fs.writeFileSync` -> **green** (93/93 pass).
  The Differences entry at `plans/greet-options/feature-greet-options-tasks.md:264` states "The spy records every file the child opens". That is true of the synchronous read API the shipped code happens to use, and not true of the promise API, the callback API, or any write.
- Why this is P1 and not P2: TASK-702's Spec column cites SEC-001, and TASK-702's own Green step says "The CLI must read no file other than `<cwd>/greet.config.json`: it must not open a network connection, read a secret or write a file." The unit added a test to trace that requirement, and the test is the unit's answer to it. The green mutations above break that requirement while the test that claims to cover it reports success. There is no live defect in the shipped code (`src/greet.js` and `bin/greet.js` use only `fs.readFileSync` and write nothing), so the finding is a test gap, not a behaviour defect.
- Fix: widen the spy and assert on the widened set.
  1. Instrument the promise and callback entry points as well: patch `fs.promises.readFile`, `fs.promises.open`, `fs.promises.stat`, `fs.promises.readdir`, `fs.promises.lstat`, `fs.promises.access`, `fs.promises.realpath`, and `fs.readFile`, `fs.open`, `fs.read`, `fs.stat`, `fs.lstat`, `fs.access`, `fs.realpath`, `fs.opendir`, `fs.glob`, `fs.globSync`, recording `path.resolve(String(target))` the same way.
  2. Instrument the write methods (`writeFileSync`, `appendFileSync`, `createWriteStream`, `mkdirSync`, `rmSync`, `unlinkSync`, `renameSync`, `copyFileSync`) and record them with a `FSWRITE` tag, then assert that the child recorded **no** write at all, anywhere. That replaces the `readdirSync(cwd)` check as the primary write guard (the directory listing can stay as a cheap second signal).
  3. A stub module that blocks `node:net`, `node:http` and `node:https` in the child, recording any attempt, would close SEC-001's remaining "opens no network connection" half, which no test currently covers.

### F02: the spy turns a file descriptor into a bogus path, so a legitimate `fstatSync` breaks the two spy-backed tests
- Severity / confidence: P2 / High
- Location: `test/greet.test.js:73` (`path.resolve(String(target))` inside the spy). Also affects: `test/greet.test.js:684`, `test/greet.test.js:706`.
- Lens: tests
- Failure: `fstatSync` takes a file descriptor, not a path. `String(target)` turns the descriptor into its decimal number, and `path.resolve` then resolves that number as a relative path against the child's working directory, so the spy records a path that does not exist, for example `C:\...\greet-sec-abc123\3`. Both spy-backed tests assert the exact list of opened paths, so a `loadConfig` that opens the config with a descriptor and sizes the buffer with `fs.fstatSync(fd)` fails both tests even though it read no file other than the config. The guard cries wolf on a legitimate implementation, which is how guards get switched off.
- Evidence: mutation `loadConfig` opens the config with `fs.openSync(file, 'r')`, calls `fs.fstatSync(fd)` and closes it -> `npm test` **red** (`not ok 92`, `not ok 93`). The recorded spy output for that run is:
  `FSOPEN openSync <cwd>\greet.config.json` / `FSOPEN fstatSync <cwd>\3` / `FSOPEN readFileSync <cwd>\greet.config.json`
  The only real file touched is `greet.config.json`; the `<cwd>\3` line is the descriptor number resolved as a path.
- Fix: record the raw argument instead of a resolved path when it is a number, or drop `fstatSync` from `METHODS` and record `openSync` only. `openSync` already carries the path, so the information is not lost.

### Guards
- mutation: `buildGreeting` trims the name (`String(options.name).trim()`) -> `npm test` **red** (`not ok 88 - cli uses a name with surrounding spaces exactly as given, with no trimming`)
- mutation: `buildGreeting` lower-cases the name (`String(options.name).toLowerCase()`) -> `npm test` **red** (15 failures, including `not ok 87`, `not ok 88`, `not ok 89`, `not ok 90`)
- mutation: `bin/greet.js` runs the name through an unquoted shell (`execSync(\`printf '%s' ${options.name}\`)`) -> `npm test` **red**
- mutation: `loadConfig` reads an unknown key's string value as a file path and merges it -> `npm test` **red** (`not ok 92 - cli ignores an unknown config key: it is not read as a path and not evaluated`)
- mutation: `loadConfig` evaluates an unknown key's value and puts the result in `config.name` -> `npm test` **red** (`not ok 92`)
- mutation: `loadConfig` additionally reads `<home>/.greet-secret` with `fs.readFileSync` -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` reads `<cwd>/decoy.json` -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` writes `greet.log` into the working directory -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` additionally reads `<home>/.greet-secret` with `fs.promises.readFile(...).catch(() => {})` -> `npm test` **green** (see F01a)
- mutation: `loadConfig` writes `<home>/.greet-written` -> `npm test` **green** (see F01b)
- mutation: `loadConfig` writes `<tmpdir>/greet-side-effect.txt` -> `npm test` **green** (see F01b)
- mutation: `loadConfig` opens the config with a descriptor and calls `fs.fstatSync(fd)` -> `npm test` **red** (see F02)

Scope: clean. The changed files are `plans/greet-options/feature-greet-options-tasks.md` (status ticks and Differences), `plans/greet-options/decisions.tsv` (two unit-7 rows), `test/greet.test.js`, and the two new fixtures `test/fixtures/unknown-key-path/greet.config.json` and `test/fixtures/unknown-key-path/decoy.json`. The two new fixture paths are named in TASK-702's Files column, which this diff also widens to list them; that widening is logged as a difference at `plans/greet-options/feature-greet-options-tasks.md:263`, so the scope change is visible. `src/greet.js` and `bin/greet.js` are listed in TASK-702's Files column but needed no change, which the Differences entry explains. No behaviour beyond the tasks was added to the shipped code.

### Checked and fine
- The previous round's F01 (the CLI-level unknown-key test could not fail) is fixed. The new test at `test/greet.test.js:684` uses the `unknown-key-path` fixture, whose unknown key names `decoy.json` in the working directory, so a `loadConfig` that reads or merges it prints `Hola, Injected` instead of `Hello, Ada` and the test fails. Confirmed red.
- The previous round's F02 (the no-file test did not guard the read half of its name) is fixed for the synchronous read API: the spy makes the read half observable, and the secret-read and decoy-read mutations turn `not ok 93` red. See F01 for the remaining holes.
- The previous round's F03 (the Differences log overstated the unknown-key proof) is fixed. The entry at `plans/greet-options/feature-greet-options-tasks.md:263` now names the test that actually fails and describes the new fixture and the two mutations that turn the new test red.
- The old, unfalsifiable CLI test `cli ignores an unknown config key and applies the known keys only` (`test/greet.test.js:679`) is kept. It is a harmless smoke check now that the load-bearing test sits next to it, but it still cannot fail on its own.
- The spy writes to the child's stderr, and both spy-backed tests strip the `FSOPEN` lines before asserting stderr is otherwise empty, so the spy does not weaken the "nothing on stderr" contract (REQ-073).
- `openedOutsideProject` filters the two module paths the loader reads (`bin/greet.js`, `src/greet.js`). Node reads `package.json` through the internal binding, so it is not recorded and does not break the assertion. Verified against the raw spy output.
- The spy module is written to its own temp directory, so it is never counted among the files the CLI read from its working directory.
- The spy's stderr lines and the `path.resolve` of the target both round-trip correctly: the parent's `cwd` string equals the child's `process.cwd()`, so `path.join(cwd, 'greet.config.json')` matches the recorded path exactly on this platform (verified against the raw spy output).
- Both spy-backed tests clean up their temp directories in a `finally` block and do not depend on test ordering. Three consecutive `npm test` runs gave 93/93 each, so the new tests are not flaky here.
- The "not evaluated" half of the new unknown-key test is guarded through the output assertion: an `eval` mutation that puts the evaluated value into `config.name` turns `not ok 92` red.
- The `Bob; rm -rf /` test is weak on `cmd.exe` (where `;` is not a command separator) but the added `Bob & echo INJECTED` test is the load-bearing one on this platform, and the Differences entry says so. The test set as a whole catches the unquoted-shell mutation.
- `src/greet.js` and `bin/greet.js` are untouched by this unit, so no shipped behaviour changed.
- `check-plan.sh plans/greet-options` prints `OK` and `tick-unit.sh plans/greet-options 7 2489cca` exits 0, so the widened Files column and the new ticks are well formed and no foreign task was ticked.

### Set aside
- SEC-001's "opens no network connection" half has no test. A mutation that calls `https.get` hangs the test run rather than failing it, so a network guard needs a different mechanism (a stubbed `node:https` module in the preload). The shipped code contains no `net`, `http` or `https` usage, so there is no defect to fix today. Noted inside F01's fix, not filed separately.
- The unit widens TASK-702's Files column to list the two new fixture files. No earlier unit in this plan edited its own Files column, and the writing-tasks skill lists only the Status, the Done date and a Differences entry as the permitted edits during implementation. The change is a scope widening, but it is logged as a difference with the reason and the fixture files are named in the task's Files note, so it is visible to a reader. P3, not filed.

### Open questions
Q01: Is SEC-001 meant to be guarded exhaustively (every `fs` entry point, plus writes and network) or only for the API the code uses today? If the former, F01 needs the full fix; if the latter, the Differences entry's claim "the spy records every file the child opens" and the test's name "writes no file" should be narrowed to what is actually checked. Blocking: no.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 1
scope: clean
mutations: 12 run, 3 still green
top:
- F01 [P1] test/greet.test.js:61 the fs spy observes only part of the fs surface, so SEC-001's read and write halves escape
- F02 [P2] test/greet.test.js:73 the spy resolves a file descriptor as a path, so a legitimate fstatSync fails both spy-backed tests
report: plans/greet-options/reports/phase-7/review-7-2.md
