# phase-7/review-7-4.md

Recheck of unit 7 (TASK-701, TASK-702), base `2489cca` -> staged `git diff --cached 2489cca`.

Date: 2026-11-20

## Review: unit 7 fix round 3 (TASK-701, TASK-702) (2489cca -> staged)

Findings: P0 0 · P1 1 · P2 0 · P3 0    Partitions reviewed: 6

### Index
1. [P1][Med] F01: three `spawnSync` CLI runs skip the network spy, so a CLI that reaches for the network still stalls the suite instead of failing, and the Differences log's "every CLI run now preloads the network spy" is false

### F01: three `spawnSync` CLI runs skip the network spy, so a CLI that reaches for the network still stalls the suite instead of failing, and the Differences log's "every CLI run now preloads the network spy" is false
- Severity / confidence: P1 / High
- Location: `test/greet.test.js:666`, `test/greet.test.js:835`, `test/greet.test.js:844` (the three `spawnSync(process.execPath, [bin, ...])` calls that do not pass `--require netSpy()`). Also affects: `plans/greet-options/feature-greet-options-tasks.md:269` (the TASK-702 Differences entry that claims every CLI run preloads the spy), `test/greet.test.js:233` and `test/greet.test.js:237` (the `run` and `runIn` helpers, which do preload it).
- Lens: tests | spec
- Failure: the fix round added the network spy to the `run` and `runIn` helpers and to the unknown-key CLI test, but left the three `spawnSync` call sites that start the CLI directly unguarded:
  - `test/greet.test.js:666` in `cli with no arguments prints Hello, world, writes nothing to stderr and exits 0`
  - `test/greet.test.js:835` in `cli echoes a name holding shell metacharacters as given and exits 0`
  - `test/greet.test.js:844` in `cli never hands the name to a shell`
  A `loadConfig` (or any other CLI code path) that reaches for the network runs unguarded in those three tests. The connection attempt is not blocked, so it stalls on the connect and then the test still passes: the network use is invisible, and the suite pays the full connect timeout.
- Evidence: two mutations, each run in its own scratch copy with `npm test`:
  - `loadConfig` calls `globalThis.fetch('http://10.255.255.1:81/').catch(() => {})` (a black-hole address, so the connect stalls) -> the three unguarded tests **pass** but each takes **~10.7 s** (`duration_ms` 10722 / 10684 / 10738), and the whole suite's wall time goes from **~7 s to ~48 s** (4.6 s on the pristine tree, 47.7 s with the mutation). The suite is not red, so the stall is invisible to CI.
  - The same mutation with the three `spawnSync` sites changed to `['--require', netSpy(), bin, ...]` -> the suite drops from 47.7 s to **15.7 s**, and the three previously-green tests now turn **red** (9 failures instead of 6), because the blocked `fetch` throws inside the child instead of stalling on the connect. This confirms the preload is the missing piece and that these three sites are the only remaining unguarded CLI runs.
  A targeted run of just the three tests with the black-hole mutation gives `# pass 3 / # fail 0` with a `# duration_ms 32360`, which is the stall in isolation.
  The three sites are the only remaining direct CLI launches: `grep -n "execFileSync\|spawnSync\|process.execPath" test/greet.test.js` lists `execFileSync` at lines 234 and 238 (both preloaded), `spawnSync` at lines 666, 835, 844 (none preloaded), 862 (preloaded) and 885 (preloaded).
- Why this is P1 and not P2: the Differences entry at `plans/greet-options/feature-greet-options-tasks.md:269` states the reason for the global preload explicitly, "a CLI that reached for the network in an unguarded run stalled the suite on a connection attempt instead of failing it", and states the coverage as "every CLI run now preloads the network spy". Both are false at these three sites, and the consequence the entry was written to prevent is exactly what still happens. This is the same defect class as the previous round's F01 (a guard that does not cover the surface its log claims it covers), and it sits in the lines this fix round touched: the fix widened the spy and added the preload but did not finish the job. It is also a plain gate-integrity issue: a test file can stall for 48 s and still report success, which is the failure mode a build pipeline cannot see.
- Fix: pass the spy at the three remaining sites, the same way `run` and `runIn` do:
  ```js
  spawnSync(process.execPath, ['--require', netSpy(), bin], { encoding: 'utf8' })
  spawnSync(process.execPath, ['--require', netSpy(), bin, '--name', 'Bob; rm -rf /'], { encoding: 'utf8' })
  spawnSync(process.execPath, ['--require', netSpy(), bin, '--name', 'Bob & echo INJECTED'], { encoding: 'utf8' })
  ```
  Then correct the Differences entry at `plans/greet-options/feature-greet-options-tasks.md:269` so it matches what the file does, and add a mutation that reaches the network through one of the three unguarded paths to the list of eight already claimed, so the claim stays checked.

### Guards
- mutation: `loadConfig` calls `globalThis.fetch('http://127.0.0.1:9/')` -> `npm test` **red** (`not ok 93`, `networkAttempts` equal to `['fetch']`); this was the previous round's green case, now closed
- mutation: `loadConfig` calls `require('node:dns').lookup('example.com')` -> `npm test` **red** (`not ok 93`); this was the previous round's green case, now closed
- mutation: `loadConfig` calls `require('node:child_process').spawn('curl', ['http://example.com'])` -> `npm test` **red** (`not ok 93`); this was the previous round's green case, now closed
- mutation: `loadConfig` calls `require('node:dns/promises').lookup('example.com')` -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` calls `require('node:child_process').execSync('curl http://example.com')` -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` calls `new globalThis.WebSocket('ws://example.com')` -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` calls `require('node:http').get('http://example.com')` -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` calls `globalThis.fetch('http://10.255.255.1:81/')` (black-hole address) -> `npm test` **green but 48 s**, and the three unguarded `spawnSync` tests each take ~10.7 s (see F01)
- mutation: `loadConfig` reads `<home>/.greet-secret` with `fs.promises.readFile(...).catch(() => {})` -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` writes `<home>/.greet-written` with `fs.writeFileSync` -> `npm test` **red** (`not ok 93`, the `writtenPaths` assertion)
- mutation: `loadConfig` reads the unknown key's value as a file path and merges what it read -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` copies a file with `fs.cpSync` outside the working directory -> `npm test` **red** (`not ok 93`)
- mutation: `loadConfig` copies a file with `fs.promises.cp` outside the working directory -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `loadConfig` truncates `<home>/.greet-secret` with `fs.truncateSync` -> `npm test` **red** (`not ok 92`, `not ok 93`)
- mutation: `buildGreeting` trims the name (`String(options.name).trim()`) -> `npm test` **red** (`not ok 88 - cli uses a name with surrounding spaces exactly as given, with no trimming`)
- mutation: `buildGreeting` lower-cases the name (`String(options.name).toLowerCase()`) -> `npm test` **red** (8+ failures, including `not ok 24`, `not ok 34`, `not ok 88`)
- mutation: `bin/greet.js` runs the name through an unquoted shell (`execSync(\`printf '%s' ${options.name}\`)`) -> `npm test` **red** (15+ failures, including `not ok 89`, `not ok 90`)

Scope: clean. The staged files are `test/greet.test.js`, the two new fixtures `test/fixtures/unknown-key-path/greet.config.json` and `test/fixtures/unknown-key-path/decoy.json`, the plan bookkeeping `plans/greet-options/feature-greet-options-tasks.md` and `plans/greet-options/decisions.tsv`, and the three review reports under `plans/greet-options/reports/phase-7/`. The two new fixture paths are named in TASK-702's Files column, which this diff widens to list them, and that widening is logged as a difference at `plans/greet-options/feature-greet-options-tasks.md:263`. `src/greet.js` and `bin/greet.js` are in TASK-702's Files column but needed no change, which the Differences entry explains, and `git diff --cached 2489cca -- src/ bin/` is empty: no shipped behaviour changed. No behaviour beyond the tasks was added. The only defect is the incomplete preload at the three `spawnSync` sites (F01), which is a gap in the unit's own guard, not drift.

### Checked and fine
- The previous round's F01 is fixed on all three of its green cases. The net spy now blocks `net`, `http`, `https`, `http2`, `dgram`, `tls`, `dns`, `dns/promises` and `child_process` (`test/greet.test.js:159`), and replaces the global `fetch` and `WebSocket` (`test/greet.test.js:191`). All three previously-green mutations (`globalThis.fetch`, `require('node:dns').lookup`, `require('node:child_process').spawn`) now turn `not ok 93` red, and the SEC-001 test fails on the `networkAttempts` assertion with the recorded name (`['fetch']`), so the guard is load-bearing rather than failing for an unrelated reason.
- The eight network mutations the Differences entry at `plans/greet-options/feature-greet-options-tasks.md:268` claims were run were each run here and each turns `not ok 93` red. The log's mutation list is accurate.
- A direct probe of the shipped spy confirms the coverage is real, not vacuous: under the spy, `globalThis.fetch` and `new globalThis.WebSocket` throw and record `FSNET fetch` / `FSNET WebSocket`; `node:dns/promises .lookup`, `node:net .connect`, `node:net .createConnection`, `node:http .get`, `node:child_process .execSync`, `node:child_process .spawn`, `node:dns .resolve`, `node:tls .connect` and `node:dgram .createSocket` all throw and record their module name. `require('undici')` fails outright (not a public module), and `require('node:internal/net')` and `require('node:internal/deps/undici/undici')` are not loadable, so there is no internal route around the loader hook.
- A Worker thread inherits the preload, so it is covered too: a `worker_threads` Worker that calls `require('node:net').connect(80, 'example.com')` under the spy throws, and the `FSNET node:net` line reaches the parent's stderr, where the SEC-001 assertion sees it.
- The spy is silent on normal operation. A probe of the CLI under the spy with `--name Ada`, `--help` and no arguments shows `stderr` empty for the successful runs and exactly `usage: greet [options] unknown flag: --help\n` for the usage error, so the exact-stderr assertions of the other tests are not weakened by the preload.
- The `networkAttempts` assertion is not vacuous: a child that preloads the shipped spy and calls `globalThis.fetch` writes an `FSNET` line and the child exits 1, so the assertion in the SEC-001 test has something real to catch.
- The file-system spy is unchanged by this round and still guards SEC-001's read and write halves: the secret read, the secret write, the unknown-key-as-a-path read, `fs.cpSync` and `fs.promises.cp` all turn the spy-backed tests red.
- The name-fidelity tests (TASK-701, REQ-012, SEC-003, TEST-019) are load-bearing: the trim mutation turns `not ok 88` red and the lower-case mutation turns `not ok 88` and the config tests red.
- The metacharacter tests (TASK-702, SEC-002, SEC-003, TEST-021) are load-bearing: the unquoted-shell mutation turns `not ok 89` and `not ok 90` red.
- The suite is stable: three consecutive `npm test` runs on the pristine tree gave 93/93 each, with a wall time of ~4.6 s.
- `check-plan.sh plans/greet-options` prints `OK` and `tick-unit.sh plans/greet-options 7 2489cca` exits 0, so the widened Files column and the new ticks are well formed and no foreign task was ticked.

### Set aside
- `fs.symlinkSync` is not in the spy's write list, so a `loadConfig` that symlinks the secret out of the home directory leaves the SEC-001 test green (mutation verified green). The fs spy is unchanged by this round and a symlink copies no secret content, so it is outside SEC-001's "reads no secrets". Not filed.
- `fs.cpSync`, `fs.promises.cp`, `fs.truncateSync`, `fs.linkSync` and `fs.symlinkSync` are not in the spy's method lists, but the first three are caught anyway by the read-side and write-side assertions (a copy reads the source, a truncate opens the target for writing). Verified red.
- The `blocked()` proxy records on the first property access, not on the `require` itself, so `require('node:net')` with no use is not recorded. That is the safe direction and no connection is opened, so it does not weaken the guard. Not filed.
- `require('node:child_process')` is now blocked wholesale rather than method by method, so a legitimate CLI that spawned a helper process would fail under the spy. The shipped CLI spawns nothing, and blocking the module whole is what closes the "a subprocess opens a connection in a process the spy never sees" hole. Not filed.
- The unit widens TASK-702's Files column to list the two new fixture files, which the writing-tasks skill does not list among the edits permitted during implementation. It is logged as a difference with the reason and the fixture files are named in the task's Files note. Carried forward from the previous two rounds, not filed again.
- `fs.watch` on a path outside the working directory is still not patched by the spy, so it is not recorded, and a watcher keeps the child's event loop alive. The shipped code watches nothing. Carried forward from the previous round, not filed.

### Open questions
Q01: Is SEC-001 meant to be guarded exhaustively (every `fs` and every network entry point) or only for the APIs the code uses today? The `fs` half now answers "exhaustively"; the network half answers "every network module plus the global `fetch` and `WebSocket`, and no subprocess". F01 is the last gap in the network half. Blocking: no.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
scope: clean
mutations: 16 run, 1 still green
top:
- F01 [P1] test/greet.test.js:666 three spawnSync CLI runs skip the network spy, so a CLI that reaches for the network still stalls the suite (48 s) instead of failing, and the "every CLI run preloads the network spy" claim at plans/greet-options/feature-greet-options-tasks.md:269 is false
report: plans/greet-options/reports/phase-7/review-7-4.md
