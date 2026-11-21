# phase-7/review-7-3.md

Review of unit 7 fix round 2 (TASK-701, TASK-702), base `2489cca` -> staged `git diff --cached 2489cca`.

Date: 2026-11-20

## Review: unit 7 fix round 2 (TASK-701, TASK-702) (2489cca -> staged)

Findings: P0 0 · P1 1 · P2 0 · P3 0    Partitions reviewed: 8

### Index
1. [P1][Med] F01: the network spy blocks six `node:` modules and nothing else, so `fetch`, `node:dns` and a spawned `curl` all open a network connection while the SEC-001 test stays green

### F01: the network spy blocks six `node:` modules and nothing else, so `fetch`, `node:dns` and a spawned `curl` all open a network connection while the SEC-001 test stays green
- Severity / confidence: P1 / High
- Location: `test/greet.test.js:143` (`NET_SPY_SOURCE`, the `BLOCKED` set). Also affects: `test/greet.test.js:855` (the test `cli writes no file, opens no network connection and reads no file other than the config in the working directory`), `test/greet.test.js:872` (the `networkAttempts` assertion), `plans/greet-options/feature-greet-options-tasks.md:266` (the TASK-702 Differences entry that describes the network spy).
- Lens: tests | spec
- Failure: the net spy intercepts `Module._load` and returns a throwing proxy for exactly six module names: `net`, `http`, `https`, `http2`, `dgram`, `tls`. Every other way to open a network connection goes past it.
  - `globalThis.fetch` is a global, not a module, so it never reaches `Module._load`. A `loadConfig` that calls `globalThis.fetch('http://example.com')` opens an HTTP connection and the test stays green.
  - `node:dns` is not in the `BLOCKED` set, so `require('node:dns').lookup('example.com')` performs a DNS query, which is a network connection, and the test stays green.
  - `node:child_process` is not blocked, so `require('node:child_process').spawn('curl', ['http://example.com'])` opens a connection in a child process and the test stays green.
  The test's name (`opens no network connection`) and SEC-001's wording (`opens no network connection`) both promise the whole half; the guard covers three spellings of one mechanism.
- Evidence: three mutations, each run in its own scratch copy with `npm test`:
  - `loadConfig` calls `globalThis.fetch('http://127.0.0.1:9/').catch(() => {})` -> **green** (93/93 pass).
  - `loadConfig` calls `require('node:dns').lookup('example.com', () => {})` -> **green** (93/93 pass).
  - `loadConfig` calls `require('node:child_process').spawn('curl', ['http://example.com'], { stdio: 'ignore' })` -> **green** (93/93 pass).
  A direct probe of the spy confirms the mechanism: a child that preloads the shipped `net-spy.cjs` and then calls `globalThis.fetch('http://example.com/')` and `require('node:dns').lookup('example.com')` writes **no `FSNET` line at all** and neither call throws. The same probe shows `require('node:child_process').spawn` still returns a working child process under the spy.
  For contrast, the blocked spellings are caught: `require('node:net').connect(80, 'example.com')` -> `not ok 93`, with `networkAttempts` equal to `['node:net']`.
- Why this is P1 and not P2: TASK-702's Spec column cites SEC-001, and SEC-001 reads "The CLI reads no secrets, opens no network connection and writes no file." This unit added the test that is its answer to that requirement, and the Differences entry at `plans/greet-options/feature-greet-options-tasks.md:266` states that the network spy "records the attempt and throws at once, so a CLI that opened a connection fails the test instead of hanging on it". The three mutations above break SEC-001 while the test that claims to cover it reports success. There is no live defect in the shipped code (`src/greet.js` and `bin/greet.js` load no network module and call no global network API), so this is a test gap rather than a behaviour defect, but it is the same defect class the previous round raised for the `fs` surface, which this reviewer rated P1 and which the fix round closed by widening the spy.
- Fix: widen the guard, or narrow the claim.
  1. Block the global `fetch` in the child as well: in the preload, replace `globalThis.fetch` with a function that records `FSNET\tfetch` and throws. `undici` is internal to Node, so it never reaches `Module._load`.
  2. Add `dns` and `dns/promises` to the `BLOCKED` set.
  3. Add `child_process` to the `BLOCKED` set, or record a `spawn`/`exec`/`fork` attempt so a subprocess cannot open a connection either.
  4. If the exhaustive guard is not wanted, narrow the test's name and the Differences entry to the six modules the spy blocks, so the log does not overstate what is checked.

### Guards
- mutation: `buildGreeting` trims the name (`String(options.name).trim()`) -> `npm test` **red** (`not ok 88 - cli uses a name with surrounding spaces exactly as given, with no trimming`)
- mutation: `buildGreeting` lower-cases the name (`String(options.name).toLowerCase()`) -> `npm test` **red** (8+ failures, including `not ok 24`, `not ok 34`)
- mutation: `bin/greet.js` runs the name through an unquoted shell (`execSync(\`printf '%s' ${options.name}\`)`) -> `npm test` **red** (15+ failures)
- mutation: `loadConfig` reads an unknown key's value as a file path -> `npm test` **red** (`not ok 38`, `not ok 91`, `not ok 92 - cli ignores an unknown config key: it is not read as a path and not evaluated`)
- mutation: `loadConfig` reads `<home>/.greet-secret` with `fs.promises.readFile(...).catch(() => {})` -> `npm test` **red** (`not ok 92`, `not ok 93`); this is the F01a case the fix round closed
- mutation: `loadConfig` reads `<home>/.greet-secret` with `fs.readFileSync` hidden inside a `fs.writeFileSync` call -> `npm test` **red** (`not ok 92`, `not ok 93`); the read half is not hidden by the spy's `writeDepth` suppression, because the write itself is still recorded
- mutation: `loadConfig` writes `<home>/.greet-written` with `fs.writeFileSync` -> `npm test` **red** (`not ok 93`, failing at `test/greet.test.js:869`, the `writtenPaths` assertion)
- mutation: `loadConfig` writes with `fs.promises.writeFile` outside the working directory -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` writes with `fs.writeFile` (callback) outside the working directory -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` writes with `fs.createWriteStream` outside the working directory -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` writes with `fs.mkdirSync` in the home directory -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` copies a file with `fs.cpSync` outside the working directory -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` copies a file with `fs.promises.cp` outside the working directory -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` writes with `fs.writeSync` through a descriptor from `fs.openSync(path, 'w')` -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` writes with `fs.truncateSync` outside the working directory -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` writes with `fs.promises.open(path, 'w')` then `handle.writeFile(...)` -> `npm test` **red** (`not ok 92`, `not ok 93`); the write is not tagged `FSWRITE`, but the `open` path is recorded, so the read-side assertion still catches it
- mutation: `loadConfig` opens a connection with `require('node:net').connect(80, 'example.com')` -> `npm test` **red** (`not ok 93`, `networkAttempts` equal to `['node:net']`)
- mutation: `loadConfig` opens a connection with `globalThis.fetch('http://127.0.0.1:9/')` -> `npm test` **green** (see F01)
- mutation: `loadConfig` opens a connection with `require('node:dns').lookup('example.com')` -> `npm test` **green** (see F01)
- mutation: `loadConfig` opens a connection with `require('node:child_process').spawn('curl', ['http://example.com'])` -> `npm test` **green** (see F01)
- mutation: `loadConfig` opens the config with a descriptor and calls `fs.fstatSync(fd)` -> `npm test` **red** (`not ok 53 - loadConfig reads the config file exactly once and the merge does not read it again`, the SEC-004 guard, and no longer `not ok 92`/`not ok 93`); this is the F02 case the fix round closed, the spy no longer records a descriptor as a path

Scope: clean. The staged files are `test/greet.test.js`, the two new fixtures `test/fixtures/unknown-key-path/greet.config.json` and `test/fixtures/unknown-key-path/decoy.json`, the plan bookkeeping `plans/greet-options/feature-greet-options-tasks.md` and `plans/greet-options/decisions.tsv`, and the two review reports under `plans/greet-options/reports/phase-7/`. The two new fixture paths are named in TASK-702's Files column, which this diff widens to list them, and that widening is logged as a difference at `plans/greet-options/feature-greet-options-tasks.md:263`. `src/greet.js` and `bin/greet.js` are in TASK-702's Files column but needed no change, which the Differences entry explains. No behaviour beyond the tasks was added to the shipped code: `src/greet.js` and `bin/greet.js` are byte-identical to the base.

### Checked and fine
- The previous round's F01 (the file-system spy observed only part of the `fs` surface) is fixed on the read and the write halves. The spy now covers the synchronous, callback and promise entry points for both reads and writes. A direct probe of the shipped spy shows it records `statSync`, `lstatSync`, `existsSync`, `accessSync`, `realpathSync`, `readdirSync`, `opendirSync`, `createReadStream`, `globSync`, `openSync`, `readFileSync`, `fstatSync`, the callback `readFile`/`open`/`read`/`stat`/`lstat`/`access`/`realpath`/`opendir`/`glob`/`globSync`, the promise `readFile`/`open`/`stat`/`lstat`/`readdir`/`opendir`/`access`/`realpath`/`glob`, and the write methods `writeFileSync`, `appendFileSync`, `createWriteStream`, `mkdirSync`, `rmSync`, `renameSync`, `copyFileSync`, `unlinkSync` plus their callback and promise variants. `require('node:fs/promises')` is covered too, because it hands back the same patched `fs.promises` object.
- The previous round's F02 (the spy turned a file descriptor into a bogus path) is fixed. A read whose target is a number is now left out of the recorded paths, and the descriptor-producing call already records the path. The `fstatSync` mutation now fails only on SEC-004's own guard (`not ok 53`), not on the two spy-backed tests.
- The previous round's F03 (the Differences log overstated the unknown-key proof) is fixed and still holds. The entry at `plans/greet-options/feature-greet-options-tasks.md:263` names the fixture, the two mutations and the test that turns red.
- The write half of SEC-001 is now guarded by an assertion, not by a directory listing. The `writtenPaths(result)` assertion at `test/greet.test.js:869` is load-bearing: the `fs.writeFileSync` mutation fails there and not on the read assertion.
- The `readdirSync(cwd)` check at `test/greet.test.js:866` is kept as a cheap second signal and still holds.
- The net spy works as advertised for the six modules it blocks: `require('node:net')` under the spy returns a proxy whose `connect` throws, and the attempt is recorded as `FSNET\tnode:net`.
- The spy modules live in their own temp directory and are filtered out of `openedOutsideProject`, so they never count as files the CLI read. A raw dump of the child's stderr shows the only recorded paths are the two spy modules, `bin/greet.js`, `src/greet.js` and `greet.config.json`. Node reads `package.json` through the internal binding, so it is not recorded and does not break the assertion.
- `cliStderr` strips the spy's own `FSOPEN`/`FSWRITE`/`FSNET` lines before asserting stderr is otherwise empty, so the spy does not weaken the "nothing on stderr" contract (REQ-073).
- Both spy-backed tests clean up their temp directories in a `finally` block and do not depend on test ordering. Each passes when run alone with `--test-name-pattern`, and three consecutive `npm test` runs gave 93/93 each.
- The name-fidelity tests (TASK-701, REQ-012, SEC-003, TEST-019) are load-bearing: the trim mutation turns `not ok 88` red and the lower-case mutation turns `not ok 24` and `not ok 34` red.
- The metacharacter tests (TASK-702, SEC-002, SEC-003, TEST-021) are load-bearing: the unquoted-shell mutation turns the CLI tests red.
- The unknown-key test (TASK-702, REQ-061) is load-bearing: reading the unknown key's value as a path turns `not ok 92` red, and the `unknown-key-path` fixture's `decoy.json` names `{"name": "Injected", "lang": "es"}`, so a merged read prints `Hola, Injected` instead of `Hello, Ada`.
- `check-plan.sh plans/greet-options` prints `OK` and `tick-unit.sh plans/greet-options 7 2489cca` exits 0, so the widened Files column and the new ticks are well formed and no foreign task was ticked.

### Set aside
- `fs.watch` on a path outside the working directory is not patched by the spy, so it is not recorded. A mutation that watches `<home>/.greet-secret` hangs the test run instead of failing it, because the watcher keeps the child's event loop alive. Watching a file is not "reading a secret" in the sense SEC-001 means, and the shipped code does not watch anything. Not filed.
- The net spy records a `FSNET` line when the CLI merely *loads* `node:http` without connecting, so a legitimate implementation that imports but does not use a network module would fail the test. The guard is conservative in the safe direction and the shipped code loads none. Not filed.
- The unit widens TASK-702's Files column to list the two new fixture files. No earlier unit in this plan edited its own Files column, and the writing-tasks skill lists only the Status, the Done date and a Differences entry as the permitted edits during implementation. The change is a scope widening, but it is logged as a difference with the reason and the fixture files are named in the task's Files note, so it is visible to a reader. Carried forward from the previous round, not filed again.

### Open questions
Q01: Is SEC-001 meant to be guarded exhaustively (every `fs` and every network entry point) or only for the APIs the code uses today? The `fs` half now answers "exhaustively"; the network half still answers "only the six `node:` modules". Blocking: no.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
scope: clean
mutations: 21 run, 3 still green
top:
- F01 [P1] test/greet.test.js:143 the network spy blocks six node: modules, so fetch, node:dns and a spawned curl open a connection while the SEC-001 test stays green
report: plans/greet-options/reports/phase-7/review-7-3.md
