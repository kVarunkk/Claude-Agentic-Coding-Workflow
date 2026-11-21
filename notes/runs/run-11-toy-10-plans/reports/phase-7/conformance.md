---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 3f54a14
tests: npm test: 93/93 (log: ${TMPDIR:-/tmp}/phase7-test.log)
mode: phase 7
---

# Conformance: greet-options (phase 7)

**Summary:** 9 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms

verdict: pass

Phase 7 covers TASK-701 and TASK-702 (GOAL-008): name fidelity and the security boundary.
Every id in the two rows' Spec columns is graded below on the behaviour those rows ask for
(their Tests and Green steps), and on that evidence alone.

The phase-7 diff (`2489cca..3f54a14`) changed **no production code**: `git diff --stat
2489cca..3f54a14 -- src/ bin/ package.json` is empty. The unit is test-only, which the
Differences entries for TASK-701 and TASK-702 both explain. That is consistent with the plan:
TASK-201, TASK-301 and TASK-401 had already put the name in the line verbatim, ignored the
unknown config key and written the line with `process.stdout.write`.

## Critical

None.

## Major

None.

## Warnings

- **Test-harness temp-directory leak** (P2, carried from `plans/greet-options/reports/phase-7/review-7-5.md` F01): the spy helper creates a `greet-spy-*` directory with
  `fs.mkdtempSync` at `test/greet.test.js:216` and no code ever removes it. The two other
  temp directories the unit creates (`greet-sec-`, `greet-home-`) are removed in the `finally`
  block at `test/greet.test.js:912-913`; the spy directory has no such cleanup. Measured here:
  `ls -d /tmp/greet-spy-* | wc -l` returned 9 after the runs I made today, and the count grows
  by exactly one per `npm test`. The leak is harmless to correctness (a stale spy directory
  cannot pollute a later run) but it accumulates without bound on a CI agent. It is a gap in
  this unit's own harness, not in the shipped CLI, and it touches no spec id.

## Real run

`npm test` (`node --test`): **93 tests, 93 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo.**
Log: `${TMPDIR:-/tmp}/phase7-test.log`. Node v22.20.0. `package.json` unchanged (`npm test` is
still `node --test`; the spec names no lint or type-check script). No test was skipped, edited
or deleted to get green: `git diff 6ec27a3..3f54a14 -- test/greet.test.js` shows only helper
replacements (the `run`/`runIn`/`spawnSync` helpers gained the spy preload), and
`grep -rn "skip\|todo\|\.only" test/greet.test.js` returns nothing.

The spec names a runnable entry point (`node bin/greet.js ...`, spec §9 process seam), so I
re-ran the real CLI against the committed fixtures and captured stdout, stderr and the exit
code. Every phase-7 claim below is Verified as well as Tested.

```
node bin/greet.js --name "Ada Lovelace"    -> stdout='Hello, Ada Lovelace\n'         exit=0  OK (REQ-012, TEST-019)
node bin/greet.js --name "  Ada  "         -> stdout='Hello,   Ada  \n' (cat -A)    exit=0  OK (REQ-012, SEC-003, TEST-019)
node bin/greet.js --name "Bob; rm -rf /"   -> stdout='Hello, Bob; rm -rf /\n'       exit=0  OK (SEC-002, SEC-003, TEST-021)
                                                 stderr = 0 bytes
node bin/greet.js --name 'Bob & echo INJECTED'
                                              -> stdout='Hello, Bob & echo INJECTED\n' exit=0 OK (SEC-002)
                                                 stderr = 0 bytes
cd test/fixtures/unknown-key-path && node .../bin/greet.js
                                              -> stdout='Hello, Ada\n'             exit=0  OK (REQ-061)
cd test/fixtures/parent-has-config/child && node .../bin/greet.js
                                              -> stdout='Hello, world\n'           exit=0  OK (REQ-064, SEC-006)
HOME=<tmp holding greet.config.json {"name":"HOMEBOSS","lang":"fr"} USERPROFILE=<same> XDG_CONFIG_HOME=<same>
                                              -> stdout='Hello, world\n'           exit=0  OK (REQ-064)
```

A spy probe over `fs.readFileSync` in a fresh directory holding only `decoy.json` recorded
exactly three opens: the CLI's own `bin/greet.js`, the project's `src/greet.js`, and
`<cwd>/greet.config.json` (the attempt, which returns ENOENT). Nothing else was opened, so
SEC-001's "the config file is the only file it reads" holds on the real run, and the decoy
file in the working directory was not read.

## Attention

- `2026-11-20T17:07:32Z` (unit-7): 4 fix rounds ran on unit 7, each closing a real P1 in the
  **test harness** (the unknown-key CLI test could not fail; the no-file test did not guard the
  read half; the fs spy observed only part of the fs surface; the network spy missed `fetch`,
  `node:dns` and a spawned `curl`; three `spawnSync` CLI launches skipped the spy preload). The
  shipped code never changed: `src/` and `bin/` import only `fs` and `path` and contain no
  `exec`, `spawn`, `http`, `net`, `fetch` or `eval` call (grep over `src/` and `bin/`).
- `2026-11-20T17:07:32Z` (unit-7): the P2 temp-directory leak (`greet-spy-*`) is open and
  carried above. It is a harness defect, not a behaviour defect, and it touches no spec id.
- `2026-11-20T13:29:09Z` (unit-6): REQ-064's home-directory clause was untested at the phase-6
  gate. **Phase 7 closes it.** The phase-7 SEC-001 test runs the CLI with `HOME` and
  `USERPROFILE` pointed at a temp directory and asserts that the only file opened is
  `<cwd>/greet.config.json`; a `loadConfig` that also reads `<home>/greet.config.json` turns
  that test red (verified by mutation, see below). The phase-6 Warning is therefore closed,
  not carried.
- Phase 3's two P2 Warnings are still open and carried to the final report at the same severity
  (accepted by the user at the phase-3 gate, `decisions.tsv` `2026-11-20T11:58:02Z`): the
  unreadable-config branch at `src/greet.js:146-151` has no test, and the fixture directories
  `test/fixtures/top-level-string/`, `top-level-number/` and `top-level-boolean/` sit outside
  the spec §8 inventory and outside the plan's Differences section. Phase 7's diff touches
  neither.
- Phase 7 added a fixture directory `test/fixtures/unknown-key-path/` that holds **two** files
  (`greet.config.json` and `decoy.json`). Spec §8 says "every other directory holds its
  `greet.config.json`", so the new directory breaks that convention. This is logged as a
  Difference at `plans/greet-options/feature-greet-options-tasks.md:263` and is required by
  TASK-702's Red list, so it is an accepted deviation, but the spec's §8 sentence is now
  stale.

## Not in the spec

None. The phase-7 diff adds only the two fixture files TASK-702's Files column names
(`test/fixtures/unknown-key-path/greet.config.json`, `test/fixtures/unknown-key-path/decoy.json`),
the tests TASK-701 and TASK-702 ask for, and plan bookkeeping. No new route, export, flag,
env var or file-writing behaviour entered the CLI: `src/` and `bin/` are byte-identical to
phase 6.

## Contracts (data model, API, config)

- **Security contract (spec §1 Security, REQ-012, SEC-001 to SEC-003, SEC-006).** The name is
  interpolated into a template literal at `src/greet.js:42` and written with
  `process.stdout.write` at `bin/greet.js:11`, so it is never shell-escaped and never reaches a
  shell. `loadConfig` reads exactly one path, `path.join(cwd, 'greet.config.json')`
  (`src/greet.js:141`), with no glob, no walk and no home or user-config lookup. The only
  `require` calls in the shipped code are `fs` and `path` (`src/greet.js:1-2`) plus
  `require('../src/greet')` (`bin/greet.js:4`).
- **Unknown-key rule (REQ-061).** `src/greet.js:170` uses
  `Object.hasOwn(CONFIG_VALIDATORS, key)`, so an unknown key is skipped before any read. The
  phase-7 test proves it end to end with a fixture whose unknown key names a file in the
  working directory.
- **Usage-error contract (REQ-070 to REQ-072).** Unchanged by this phase; `formatUsage`
  (`src/greet.js:188-190`) still emits exactly one line and `bin/greet.js:14-16` still exits 2
  with an empty stdout.
- **No API contracts.** The CLI is the only public surface (spec §4.4); phase 7 adds no export.

## Tasks file

- TASK-701 `[x]` 2026-11-20: its Spec column is REQ-012, SEC-003, TEST-019. All three are Met
  on this phase's own evidence. Its Green step ("insert the name into the greeting line
  verbatim ... and write the line to stdout with `process.stdout.write` rather than through a
  shell") holds at `src/greet.js:42` and `bin/greet.js:11`.
- TASK-702 `[x]` 2026-11-20: its Spec column is REQ-012, REQ-061, REQ-064, SEC-001, SEC-002,
  SEC-003, SEC-006, TEST-021. All eight are Met on this phase's own evidence. Its Green step
  ("keep the option values as plain strings and numbers used only to pick a greeting word ...
  the CLI must read no file other than `<cwd>/greet.config.json`") holds in the shipped code.
- No ticked task in phases 1 to 6 regressed: `git diff --stat 6ec27a3..3f54a14 -- src/ bin/`
  is empty, so every phase-1 to phase-6 code and test file is unchanged, and the whole 93-test
  suite is green.
- The phase-7 ticks are not contradicted by the evidence: all seven new tests exist, assert
  exact bytes, exit codes or observed file paths, and pass today. The tick's Red-list wording
  ("the CLI must read no file other than `<cwd>/greet.config.json`: it must not open a network
  connection, read a secret or write a file") is beyond the spec's own TEST list, so the unit
  added three guards the spec does not name. That is a strengthening, not a divergence, and it
  is logged in the Differences entries.

### Load-bearing check (mutations I ran myself, in a copy of the tree under `${TMPDIR:-/tmp}`)

| Mutation | Result |
|---|---|
| `buildGreeting` trims the name (`String(options.name).trim()`) | red: tests 24, 34, **88** |
| `bin/greet.js` runs the name through an unquoted shell (`execSync`) | red: 21 tests incl. **89, 90** |
| `loadConfig` reads the unknown key's value as a file path and merges it | red: **test 92** |
| `loadConfig` reads `<home>/.greet-secret` and writes `<home>/.greet-written` | red: **tests 92, 93** |
| `loadConfig` also reads `<home>/greet.config.json` | red: tests 53, 92, **93** |

Every phase-7 test named above turns red under the mutation it guards, so the new tests are
load-bearing rather than decorative.

## All ids

Met: REQ-012, REQ-061, REQ-064, SEC-001, SEC-002, SEC-003, SEC-006, TEST-019, TEST-021

| Id | Status | Tier | Test |
|---|---|---|---|
| REQ-012 | ✅ Met | Tested + Verified | `test/greet.test.js` › `cli uses a name with a space exactly as given`, `cli uses a name with surrounding spaces exactly as given, with no trimming` |
| REQ-061 | ✅ Met | Tested + Verified | `test/greet.test.js` › `cli ignores an unknown config key and applies the known keys only`, `cli ignores an unknown config key: it is not read as a path and not evaluated` |
| REQ-064 | ✅ Met | Tested + Verified | `cli does not look for the config file in a parent directory`; the home/user-config clause is guarded by `cli writes no file, opens no network connection and reads no file other than the config in the working directory` |
| SEC-001 | ✅ Met | Tested + Verified | `cli writes no file, opens no network connection and reads no file other than the config in the working directory` |
| SEC-002 | ✅ Met | Tested + Verified | `cli echoes a name holding shell metacharacters as given and exits 0`, `cli never hands the name to a shell`, `cli ignores an unknown config key: it is not read as a path and not evaluated` |
| SEC-003 | ✅ Met | Tested + Verified | `cli uses a name with surrounding spaces exactly as given, with no trimming`, `cli echoes a name holding shell metacharacters as given and exits 0` |
| SEC-006 | ✅ Met | Tested + Verified | `cli does not look for the config file in a parent directory`, `cli writes no file, opens no network connection and reads no file other than the config in the working directory` |
| TEST-019 | ✅ Met | Tested + Verified | `cli uses a name with a space exactly as given`, `cli uses a name with surrounding spaces exactly as given, with no trimming` |
| TEST-021 | ✅ Met | Tested + Verified | `cli echoes a name holding shell metacharacters as given and exits 0` |
