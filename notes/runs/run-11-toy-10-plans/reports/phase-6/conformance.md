---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 6ec27a3
tests: npm test: 86/86 (log: ${TMPDIR:-/tmp}/phase6-test.log)
mode: phase 6
---

# Conformance: greet-options (phase 6)

**Summary:** 15 met · 1 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms with gaps

verdict: pass

Phase 6 covers TASK-601 and TASK-602: the config file end to end at the process seam.
Every id in the two rows' Spec columns is graded below on the behaviour those rows ask for
(their Tests and Green steps), and on that evidence alone. The half of an id that a later
phase's task owns is marked ➖ Not started with the owning task named.

## Critical

None.

## Major

None.

## Warnings

- **REQ-064** 🧪 Untested (second clause only): REQ-064 (spec:81) says the CLI "does not look in
  parent directories, and it does not look at a home directory or a user config directory." The
  parent-directory clause is Tested and Verified (`test/greet.test.js` › `cli does not look for
  the config file in a parent directory`; probe printed `Hello, world` from
  `test/fixtures/parent-has-config/child`). The home-directory / user-config clause has no
  test: `grep -n "HOME\|homedir\|USERPROFILE\|XDG" test/greet.test.js` returns nothing. The code
  is clean today (`grep -rn "homedir\|HOME\|USERPROFILE\|XDG\|os\." src/ bin/` returns nothing) and
  a live probe with `HOME`/`USERPROFILE`/`XDG_CONFIG_HOME` pointed at a directory holding
  `{"name":"HOMEBOSS","lang":"fr"}` printed `Hello, world`, so this is a gap in the guard, not a
  live defect. Severity Warning (a REQ id with Inspected-only evidence on one of its clauses).
  Carried from `plans/greet-options/reports/phase-6/review-6.md` F01 (P2) and logged in the
  decision trail at `2026-11-20T13:29:09Z`.

## Real run

`npm test` (`node --test`): **86 tests, 86 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo.**
Log: `${TMPDIR:-/tmp}/phase6-test.log`. Node v22.20.0. `package.json` unchanged (`npm test` is
still `node --test`; the spec names no lint or type check script). No test was skipped, edited
or deleted: `git diff 21f692f..HEAD -- test/greet.test.js` shows additions only (no `-` lines
other than the file header), and `grep -rn "skip\|todo\|\.only" test/greet.test.js` returns
nothing.

The spec names a runnable entry point (`node bin/greet.js ...`, spec §9 process seam), so I
re-ran the real CLI against the committed fixtures and captured stdout, stderr and the exit code.
Every phase-6 claim below is Verified as well as Tested.

```
cd test/fixtures/name-ada-lang-es   -> stdout='Hola, Ada\n'            exit=0   OK (REQ-060, REQ-063)
cd test/fixtures/name-ada-lang-es --name Bob
                                    -> stdout='Hola, Bob\n'            exit=0   OK (REQ-063)
cd test/fixtures/parent-has-config/child
                                    -> stdout='Hello, world\n'        exit=0   OK (REQ-064, SEC-006)
cd test/fixtures/bad-lang           -> stdout='' stderr='usage: greet [options] invalid value for lang: de\n'
                                                                            exit=2   OK (REQ-062, REQ-066)
cd test/fixtures/name-empty         -> stdout='' stderr='usage: greet [options] empty value for name\n'
                                                                            exit=2   OK (REQ-079)
cd test/fixtures/name-number        -> stdout='' stderr='usage: greet [options] invalid value for name: 123\n'
                                                                            exit=2   OK (REQ-079, REQ-062)
cd test/fixtures/top-level-array    -> stdout='' stderr='usage: greet [options] invalid greet.config.json\n'
                                                                            exit=2   OK (REQ-066)
cd test/fixtures/times-six --times 2 -> stdout='' stderr='usage: greet [options] invalid value for times: 6\n'
                                                                            exit=2   OK (REQ-069)
```

Each stderr line above holds exactly one `\n` and stdout is 0 bytes in every error case, so
REQ-070's one-line / empty-stdout / exit-2 contract holds on the config path.

## Attention

- `2026-11-20T13:29:09Z` (unit-6): REQ-064's home-directory clause has no test. The production
  code is clean and a live probe confirms it, so the user is looking at a coverage gap, not a
  defect. The spec's own TEST-016 and TEST-020 do not name such a case, so closing it needs a
  plan change, not a code change.
- `2026-11-20T13:29:09Z` (unit-6): the fixture `test/fixtures/parent-has-config/greet.config.json`
  holds `{"name": "Config", "lang": "fr"}`. The spec pins only the shape of the case, so the
  values are the unit's choice, logged as a Difference.
- `2026-11-20T13:28:37Z` (unit-6): the config half of TEST-023 (the `invalid greet.config.json`
  line for a non-object top level) was deferred from unit 5 and is now covered by TASK-602 at
  `test/greet.test.js:586-591`. Closed.
- Phase 3's two P2 Warnings are still open and carried to the final report at the same severity
  (accepted by the user at the phase-3 gate, `decisions.tsv` `2026-11-20T11:58:02Z`): the
  unreadable-config branch at `src/greet.js:146-151` has no test, and the fixture directories
  `test/fixtures/top-level-string/`, `top-level-number/` and `top-level-boolean/` sit outside the
  spec §8 inventory and outside the plan's Differences section. Phase 6's diff touches neither.
- Phase 6 added no production code (`git diff --stat 21f692f..HEAD`: only `test/greet.test.js`,
  three fixture files, the tasks file, the decisions trail and the review report). All three
  Differences entries for TASK-601 and TASK-602 say the Red cases passed as soon as they were
  written. That is consistent with the plan: the pipeline was wired in TASK-401 and the
  validation in TASK-301, so phase 6 was a test-only unit. The unit-6 review ran six mutations
  (all red) plus two equivalent mutants, so the new tests are load-bearing.

## Not in the spec

None. The phase-6 diff adds only the fixture files the task rows list and the tests the task
rows ask for. `bin/greet.js` and `src/greet.js` are unchanged since phase 4, so no unplanned
public behaviour entered the CLI.

## Contracts (data model, API, config)

- **Config file contract (spec §3 table).** All five known keys are validated by
  `CONFIG_VALIDATORS` (`src/greet.js:117-138`) with the pinned types: `name` a non-empty string,
  `shout` a boolean, `times` a JSON integer 1 to 5, `lang` one of `en`/`es`/`fr`, `format` one of
  `text`/`json`. The unknown-key rule (REQ-061) holds via `Object.hasOwn` at `src/greet.js:170`.
- **Usage-error contract (spec §4.3, config rows).** The config-side rows of the table hold
  byte for byte: `invalid value for lang: de`, `empty value for name`,
  `invalid value for name: 123`, `invalid greet.config.json`, and `invalid value for times: 6`
  for the REQ-069 case. A config reason names the key without the `--` prefix, a flag reason
  names the flag with it, exactly as §4.3 requires.
- **No API contracts.** The CLI is the only public surface (spec §4.4); the phase-6 diff adds
  no export and no route.

## Tasks file

- TASK-601 `[x]` 2026-11-20 and TASK-602 `[x]` 2026-11-20: every id in their Spec columns is
  Met on this phase's own evidence, except the one REQ-064 clause above. Their Green steps ask
  for `loadConfig(process.cwd())` before rendering and `mergeOptions(config, flags)` in
  `bin/greet.js`; both are present at `bin/greet.js:9-10` (wired in TASK-401, unchanged by this
  unit), and the whole-file validation before the merge is at `src/greet.js:166-179`
  (`loadConfig` throws before `mergeOptions` is called at `bin/greet.js:10`).
- No ticked task in phases 1 to 5 regressed: the phase-5 Met list (REQ-011, REQ-032, REQ-040,
  REQ-070, REQ-071, REQ-072, REQ-074, SEC-005, TEST-015, TEST-023) and the phase-4 Met list
  still hold, and their files did not change in this diff.
- The phase-6 tick is not contradicted by the evidence: all eight new tests exist, assert exact
  bytes and exit codes, and pass today.

## All ids

Met: REQ-060, REQ-062, REQ-063, REQ-065, REQ-066, REQ-069, REQ-070, REQ-079, SEC-004, SEC-006,
TEST-016, TEST-017, TEST-020, TEST-022, TEST-024
| Id | Status | Tier | Test |
|---|---|---|---|
| REQ-064 | 🧪 Untested (home-directory clause) | Inspected | parent-directory clause Tested; home/user-config clause has no test |
