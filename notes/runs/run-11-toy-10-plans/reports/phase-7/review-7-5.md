# phase-7/review-7-5.md

Recheck of unit 7 (TASK-701, TASK-702), base `2489cca` -> staged `git diff --cached 2489cca`.

Date: 2026-11-20

## Review: unit 7 fix round 4 (TASK-701, TASK-702) (2489cca -> staged)

Findings: P0 0 · P1 0 · P2 1 · P3 0    Partitions reviewed: 6

### Index
1. [P2][Low] F01: the fs spy helper leaks a `greet-spy-*` temp directory on every test run, and nothing removes it

### F01: the fs spy helper leaks a `greet-spy-*` temp directory on every test run, and nothing removes it
- Severity / confidence: P2 / High
- Location: `test/greet.test.js:213-223` (`fsSpy()`). Also affects: `test/greet.test.js:226-229` (`netSpy()`), which calls `fsSpy()`.
- Lens: design | performance
- Failure: `fsSpy()` creates a fresh temp directory with `fs.mkdtempSync(path.join(os.tmpdir(), 'greet-spy-'))` and writes the two spy source files into it, but no code path ever removes it. The two other temp directories the unit creates, the `greet-sec-` working directory and the `greet-home-` secret directory in the SEC-001 test, are both removed in a `finally` block (`test/greet.test.js:911-914`); the spy directory has no such cleanup. Every `npm test` run therefore leaves one more ~4 KB directory in the OS temp directory, and a CI agent that runs the suite repeatedly accumulates them without bound.
- Evidence: measured in a scratch copy of the staged tree, `ls -d /tmp/greet-spy-* | wc -l` went from 32 to 33 across one `npm test` run (the count grew by exactly one). The base commit `2489cca` contains no `mkdtempSync` at all in `test/greet.test.js` (`git show 2489cca:test/greet.test.js | grep -c mkdtempSync` returns 0), so the leak is introduced by this diff. Each leaked directory holds exactly two files, `fs-spy.cjs` (2568 bytes) and `net-spy.cjs` (1461 bytes). After 32 runs the accumulated clutter was 33 directories.
- The leak is harmless to correctness. A stale spy directory from a prior run cannot pollute a later run: each run loads only its own spy file, so the stale directory's path never appears in the child's recorded opens. Verified with a probe that created a stale `greet-spy-STALE` directory alongside the current one and confirmed that the current run's `openedPaths` contained no path under the stale directory.
- Fix: remove the spy directory when the suite finishes. The smallest change is to register the cleanup with `process.on('exit', ...)` next to the `fsSpy()` helper:
  ```js
  const fsSpy = () => {
    if (fsSpyPath === null) {
      fsSpyDir = fs.mkdtempSync(path.join(os.tmpdir(), 'greet-spy-'));
      fsSpyPath = path.join(fsSpyDir, 'fs-spy.cjs');
      netSpyPath = path.join(fsSpyDir, 'net-spy.cjs');
      fs.writeFileSync(fsSpyPath, FS_SPY_SOURCE);
      fs.writeFileSync(netSpyPath, NET_SPY_SOURCE);
      process.on('exit', () => fs.rmSync(fsSpyDir, { recursive: true, force: true }));
    }
    return fsSpyPath;
  };
  ```
  A `test.after` hook or an `after()` from `node:test` would also work. The cleanup must run after the last CLI launch, so an `exit` handler or an `after` hook is the right shape, not a removal at the end of `fsSpy()`.

### Guards
- mutation: `loadConfig` calls `globalThis.fetch('http://10.255.255.1:81/')` (a black-hole address, so the connect stalls) -> `npm test` **red** (`not ok 55`, `not ok 89`, `not ok 90`, `not ok 93`, 26 failures); the suite's wall time drops from 46.6 s to 14.6 s. This is the previous round's green case, now closed. The three previously-unguarded `spawnSync` sites are the ones that turn red.
- mutation: `loadConfig` calls `require('node:dns').lookup('example.com', ...)` -> `npm test` **red** (`not ok 55`, `not ok 89`, `not ok 90`, `not ok 93`), wall time 5.0 s, no stall
- mutation: `loadConfig` calls `require('node:child_process').spawn('curl', ['http://example.com'])` -> `npm test` **red** (`not ok 55`, `not ok 89`, `not ok 90`, `not ok 93`), wall time 5.9 s, no stall
- mutation: `loadConfig` reads `<home>/.greet-secret` with `fs.readFileSync` -> `npm test` **red** (`not ok 92`, `not ok 93`), so SEC-001's read half is load-bearing
- mutation: `loadConfig` writes `<home>/.greet-written` with `fs.writeFileSync` -> `npm test` **red** (`not ok 93`), so SEC-001's write half is load-bearing
- mutation: `loadConfig` reads the unknown key's value as a file path and merges what it read -> `npm test` **red** (`not ok 92`), so TASK-702's unknown-key-as-path guard is load-bearing
- mutation: `buildGreeting` trims the name (`String(options.name).trim()`) -> `npm test` **red** (`not ok 88`), so TASK-701's no-trimming guard is load-bearing
- mutation: `bin/greet.js` runs the name through an unquoted shell (`execSync(\`printf '%s' ${options.name}\`)`) -> `npm test` **red** (`not ok 87`, `not ok 88`, `not ok 89`, `not ok 90`, `not ok 92`, `not ok 93`; 21 failures), so TASK-702's shell-injection guard is load-bearing on both metacharacter names

Scope: clean. The staged files are `test/greet.test.js`, the two new fixtures `test/fixtures/unknown-key-path/greet.config.json` and `test/fixtures/unknown-key-path/decoy.json`, the plan bookkeeping `plans/greet-options/feature-greet-options-tasks.md` and `plans/greet-options/decisions.tsv`, and the four review documents under `plans/greet-options/reports/phase-7/` (`guidance-7.md`, `review-7.md`, `review-7-2.md`, `review-7-3.md`, `review-7-4.md`). The two new fixture paths are named in TASK-702's Files column, which this diff widens to list them, and that widening is logged as a difference at `plans/greet-options/feature-greet-options-tasks.md:263`. `src/greet.js` and `bin/greet.js` are in TASK-702's Files column but needed no change, which the Differences entry explains, and `git diff --cached 2489cca -- src/ bin/ package.json` is empty: no shipped behaviour changed. No behaviour beyond the tasks was added. The only defect found is the temp-directory leak (F01), which is a gap in the unit's own test harness, not drift.

### Checked and fine
- The previous round's F01 is fixed. All seven CLI launch sites in `test/greet.test.js` now preload the network spy: `run` at line 234, `runIn` at line 238, and the five `spawnSync` sites at lines 666, 835, 846, 864 and 887. `grep -n "execFileSync\|spawnSync\|process.execPath" test/greet.test.js` lists every launch and each one passes `--require netSpy()` (the two fs-backed sites pass `--require fsSpy()` as well). There are no `worker_threads`, `vm` or `fork` launch sites, so the defect class is closed: no CLI run can reach the network unguarded.
- The net spy is genuinely load-bearing at the three previously-unguarded sites, not merely present. A direct probe of the child under the spy shows the record line `FSNET\tfetch` on stderr and the child exiting 1 with `Error: network access is blocked in this test`, with the stack pointing at `loadConfig`. The three tests fail on `result.status` (`1 !== 0`), so the failure is the network block and not an unrelated error.
- The "before" and "after" numbers in the new Differences entry (`plans/greet-options/feature-greet-options-tasks.md:270`) are accurate. Reverting only the three `spawnSync` sites to their unguarded form and re-running the black-hole `fetch` mutation gives a 46.6 s suite in which tests 55, 89 and 90 are **green**; restoring the fix gives a 14.6 s suite in which the same three are **red**. The entry's "47.7 s" and "15.8 s" are within measurement noise of the 46.6 s and 14.6 s measured here.
- The net spy writes nothing to stderr on a normal run, so the exact-stderr assertions are not weakened. A probe of the CLI under the net spy shows `stderr` empty for the no-arguments run and for `--name Ada`, and exactly `usage: greet [options] unknown flag: --help\n` for the usage error. `run` and `runIn` preload only the net spy (not the fs spy), so the strict `err.stderr` assertions at `test/greet.test.js:30`, `:47` and `:662` still see the CLI's own stderr untouched.
- The fs spy's escaping is correct and the record format is what the parsers expect. The spy source carries `\\t` and `\\n` inside a template literal, so the file written to disk holds `'\\t'`, which the child evaluates to a real tab and a real newline. Verified at the byte level: the child's stderr begins `F S O P E N TAB r e a l p a t h S y n c TAB`, so `openedPaths`/`writtenPaths`/`networkAttempts` split on a genuine tab. (An earlier reading that suggested a literal backslash-t was an artifact of the probe extracting the template text with a regex instead of evaluating it; the shipped code is right.)
- The parsers see real records. A probe inside the test file's own helper scope shows `openedOutsideProject` returning exactly `[<cwd>/greet.config.json]`, `writtenPaths` `[]`, `networkAttempts` `[]` and `cliStderr` `""`. The spy directory is correctly excluded by the `fsSpyDir` prefix filter, and the project's own `bin/greet.js` and `src/greet.js` by exact equality.
- The guard is precise, not just loud: the SEC-001 test's `openedOutsideProject` assertion names the one expected file, so a `loadConfig` that opened any other path would be caught. The secret-read and file-write mutations confirm both halves.
- The name-fidelity tests (TASK-701, REQ-012, SEC-003, TEST-019) and the metacharacter tests (TASK-702, SEC-002, SEC-003, TEST-021) are load-bearing, as the mutation list shows.
- The suite is stable: three consecutive `npm test` runs on the pristine tree gave 93/93 each, with a wall time of ~4.7 s.
- `check-plan.sh plans/greet-options` prints `OK` and `tick-unit.sh plans/greet-options 7 2489cca` exits 0, so the widened Files column and the new ticks are well formed and no foreign task was ticked.
- The guidance file `plans/greet-options/reports/phase-7/guidance-7.md` asks for exactly three things: preload the spy at the three `spawnSync` sites, correct the Differences entry, and prove the fix with a before/after timing. All three are done and the timings check out.

### Set aside
- `cliStderr` strips any line that starts with `FSOPEN\t`, `FSWRITE\t` or `FSNET\t`, so a CLI stderr line beginning with one of those prefixes followed by a tab would be swallowed. The shipped CLI's only stderr output is the `usage: greet [options] ...` line, which never has that prefix, so this is a theoretical masking risk and not a live defect. Not filed.
- `fs.symlinkSync`, `fs.watch` and `fs.linkSync` are not in the spy's method lists, and the net spy records an `FSNET` line merely on loading `node:http`. All three were noted and set aside by the previous rounds, the guidance explicitly says not to chase them, and the shipped code uses none of them. Carried forward, not filed again.
- `child_process` is blocked wholesale rather than method by method, so a legitimate CLI that spawned a helper process would fail under the spy. The shipped CLI spawns nothing, and blocking the module whole is what closes the "a subprocess opens a connection in a process the spy never sees" hole. Not filed.
- The unit widens TASK-702's Files column to list the two new fixture files, which the writing-tasks skill does not list among the edits permitted during implementation. It is logged as a difference with the reason and the fixture files are named in the task's Files note. Carried forward from the previous rounds, not filed again.

### Open questions
Q01: Is SEC-001 meant to be guarded exhaustively (every `fs` and every network entry point) or only for the APIs the code uses today? The `fs` half answers "exhaustively" and the network half answers "every network module plus the global `fetch` and `WebSocket`, and no subprocess". With the three `spawnSync` sites now preloaded, the network half has no known remaining gap. Blocking: no.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
scope: clean
mutations: 8 run, 0 still green
top:
- F01 [P2] test/greet.test.js:213 fsSpy() creates a greet-spy-* temp directory that no code removes, so every npm test run leaks one
report: plans/greet-options/reports/phase-7/review-7-5.md