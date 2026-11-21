# Phase 7 report: Name fidelity and the security boundary

Feature: greet-options
Phase: 7 (unit 7)
Previous tag: greet-options-phase-6

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 7 | TASK-701, TASK-702 | 3f54a14 | plans/greet-options/reports/phase-7/review-7-5.md | pass (p0: 0, p1: 0, p2: 1, scope: clean, mutations: 8 run, 0 still green) |

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-7/review-7.md | fail | 0 | 2 | 1 | F01: the new CLI unknown-key test asserted only stdout with a numeric unknown key, so it could not fail. F02: the no-file test checked only the write half |
| plans/greet-options/reports/phase-7/review-7-2.md | fail | 0 | 1 | 1 | F01: the fs spy observed only eleven synchronous methods, so SEC-001's read and write halves escaped |
| plans/greet-options/reports/phase-7/review-7-3.md | fail | 0 | 1 | 0 | F01: the network spy blocked six `node:` modules, so `fetch`, `node:dns` and a spawned `curl` connected while the test stayed green |
| plans/greet-options/reports/phase-7/review-7-4.md | fail | 0 | 1 | 0 | F01: three `spawnSync` CLI launches skipped the spy preload, so the suite stalled instead of failing |
| plans/greet-options/reports/phase-7/review-7-5.md | pass | 0 | 0 | 1 | recheck after the user's guidance round; F01 (P2): the `greet-spy-*` temp dir is never removed |

## Fix rounds

4 rounds on unit 7. The first three closed P1 gaps in the test harness, the fourth was
run after the user chose "Give guidance" at the MAX_LOOPS gate. The shipped code never
changed: `git diff --stat 2489cca..3f54a14 -- src/ bin/ package.json` is empty, and
`src/greet.js` and `bin/greet.js` import only `fs` and `path`.

1. The CLI unknown-key test was replaced with one that can fail: the fixture
   `test/fixtures/unknown-key-path/greet.config.json` names `decoy.json`, so a
   `loadConfig` that reads the unknown key as a path prints `Hola, Injected` and the test
   goes red. The no-file test was rewritten around a file-system spy that records every
   file the child opens and writes.
2. The fs spy was widened to the synchronous, callback and promise entry points for
   reads and writes.
3. The network spy was widened to block `dns`, `dns/promises` and `child_process`, and to
   replace the global `fetch` and `WebSocket`.
4. The three direct `spawnSync` CLI launches were given the same preload as every other
   launch, so a CLI that reaches for the network fails the test instead of stalling on
   the connect. Measured with a black-hole `fetch` mutation in `loadConfig`: before the
   fix the suite was green at those three tests and took 47.7 s; after the fix the same
   three tests are red and the suite takes 15.8 s.

## Added units

None.

## Differences from the spec (phase 7 tasks)

The full list is in the tasks file. In summary:

- TASK-701 and TASK-702: the Red cases pass as soon as they are written, so the
  end-to-end layer only needed the tests. TASK-201 already inserted the name verbatim,
  TASK-401 already wrote the line with `process.stdout.write`, and TASK-301 already
  ignored an unknown config key.
- TASK-702 (REQ-061, SEC-002): the first version of the CLI-level unknown-key test could
  not fail, so it was replaced by one that can.
- TASK-702 (SEC-001, REQ-064): the unit adds a test that the CLI writes no file, opens
  no network connection and reads no file other than the config in the working
  directory. The task's Red list does not name it, but SEC-001 is traced here and no
  other test covers any of its three halves.
- TASK-702 (SEC-002, SEC-003): the metacharacter tests use two names. The task names
  `Bob; rm -rf /`; the unit adds `Bob & echo INJECTED` because `;` is not a command
  separator in `cmd.exe`, so on Windows the task's name alone cannot fail a
  shell-injection bug.
- TASK-702 (SEC-001, REQ-064): the spy widening rounds, each with the mutation list
  that proves it.

## Conformance

Report: plans/greet-options/reports/phase-7/conformance.md
Verdict: pass (p0: 0, p1: 0, p2: 1)

All 9 phase-7 ids (REQ-012, REQ-061, REQ-064, SEC-001, SEC-002, SEC-003, SEC-006,
TEST-019, TEST-021) are Met on Tested and Verified evidence. The matcher ran the real
CLI against the committed fixtures and ran five of its own mutations to prove the new
tests are load-bearing.

The matcher's top findings:

- REQ-012: the name is echoed verbatim; the surrounding-spaces test is red under a trim
  mutation
- SEC-001: only `<cwd>/greet.config.json` is read; the test is red under secret-read,
  write and home-lookup mutations
- REQ-064: the parent and home/user-config clauses are both guarded. This closes the
  phase-6 Warning
- SEC-002: the name never reaches a shell; both metacharacter tests are red under an
  `execSync` mutation
- The fs-spy temp-dir leak (P2, no spec id)

Left open: the `greet-spy-*` leak; spec §8's sentence "every other directory holds its
`greet.config.json`" is now stale because `test/fixtures/unknown-key-path/` holds two
files (logged as a Difference); the fs spy still does not cover `fs.symlinkSync`,
`fs.linkSync`, `fs.watch` or `fs.cp` (the shipped code uses none of them).

## Test run

Command: `npm test`
Result: 93 tests, 93 pass, 0 fail, 0 skipped.

## Diffstat

```
 plans/greet-options/decisions.tsv                  |  10 +
 plans/greet-options/feature-greet-options-tasks.md |  14 +-
 plans/greet-options/reports/phase-7/guidance-7.md  |  37 +++
 plans/greet-options/reports/phase-7/review-7-2.md  |  92 ++++++
 plans/greet-options/reports/phase-7/review-7-3.md  |  93 ++++++
 plans/greet-options/reports/phase-7/review-7-4.md  |  91 ++++++
 plans/greet-options/reports/phase-7/review-7-5.md  |  80 ++++++
 plans/greet-options/reports/phase-7/review-7.md    |  89 +++++++
 test/fixtures/unknown-key-path/decoy.json          |   4 +
 test/fixtures/unknown-key-path/greet.config.json   |   4 +
 test/greet.test.js                                 | 327 ++++++++++++++++++++-
 11 files changed, 833 insertions(+), 8 deletions(-)
```
