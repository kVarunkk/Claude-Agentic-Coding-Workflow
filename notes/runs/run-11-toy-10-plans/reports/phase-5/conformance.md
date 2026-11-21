---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: d76d786
tests: npm test: 78/78 (log: ${TMPDIR:-/tmp}/greet-phase5/tests.log)
mode: phase 5
---

# Conformance: greet-options (phase 5)

**Summary:** 10 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms

verdict: pass

Phase 5 covers TASK-501 and TASK-502: the usage-error contract end to end at the process seam.
Every id in the two rows' Spec columns is graded below on the behaviour those rows ask for
(their Tests and Green steps), and on that evidence alone. The half of an id that a later
phase's task owns is marked ➖ Not started with the owning task named.

## Critical

None.

## Major

None.

## Warnings

None new in phase 5.

The two P2 Warnings from phase 3 (`reports/phase-3/conformance-3.md`) are still open and are
carried to the final report at the same severity: the unreadable-config branch at
`src/greet.js:146-151` has no test, and the three fixture directories
`test/fixtures/top-level-string/`, `top-level-number/` and `top-level-boolean/` sit outside the
spec §8 inventory and outside the plan's Differences section. Phase 5's diff touches neither
(`git diff e41cada..HEAD --stat`: only `src/greet.js`, `test/greet.test.js`, the tasks file, the
decisions trail and the two review reports), so neither is closed or worsened here. The user
accepted both at the phase-3 gate (`decisions.tsv` row `2026-11-20T11:58:02Z`).

## Real run

`npm test` (`node --test`): **78 tests, 78 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo.**
Log: `${TMPDIR:-/tmp}/greet-phase5/tests.log`. Node v22.20.0, `package.json` unchanged
(`npm test` is still `node --test`; no new dependency, no lint or type script named by the spec).

The spec names a runnable entry point (`node bin/greet.js ...`, spec §9 process seam). I re-ran
the real CLI in a scratch directory outside the repo and captured stdout, stderr and the exit code
as bytes, so every phase-5 claim below is Verified as well as Tested.

Every one of the 17 flag-side rows of the spec's §4.3 table, byte-compared against the table:

```
--nmae x        -> exit=2 stdout=0B stderr=b'usage: greet [options] unknown flag: --nmae\n'        OK
--help          -> exit=2 stdout=0B stderr=b'usage: greet [options] unknown flag: --help\n'        OK
--version       -> exit=2 stdout=0B stderr=b'usage: greet [options] unknown flag: --version\n'     OK
Ada             -> exit=2 stdout=0B stderr=b'usage: greet [options] unexpected argument: Ada\n'    OK
--name          -> exit=2 stdout=0B stderr=b'usage: greet [options] missing value for --name\n'    OK
--name -x       -> exit=2 stdout=0B stderr=b'usage: greet [options] missing value for --name\n'    OK
--name ""       -> exit=2 stdout=0B stderr=b'usage: greet [options] empty value for --name\n'      OK
--name=Ada      -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid flag syntax: --name=Ada\n' OK
--              -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid argument: --\n'       OK
--times 0       -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid value for --times: 0\n'  OK
--times abc     -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid value for --times: abc\n' OK
--times 03      -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid value for --times: 03\n'  OK
--times +2      -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid value for --times: +2\n'  OK
--lang de       -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid value for --lang: de\n'   OK
--format xml    -> exit=2 stdout=0B stderr=b'usage: greet [options] invalid value for --format: xml\n' OK
```

Every stderr byte count above holds exactly one `\n` (44, 44, 47, 48, 48, 46, 52, 52, 55, 44, 48,
49, 48, 50, 53, 54, 55 bytes) and stdout is 0 bytes in every case.

Beyond the table, the remaining REQ-074/REQ-032/REQ-040 inputs, probed live:

```
--times 6      -> exit=2 stderr='usage: greet [options] invalid value for --times: 6\n'
--times 1.5    -> exit=2 stderr='usage: greet [options] invalid value for --times: 1.5\n'
--lang ES      -> exit=2 stderr='usage: greet [options] invalid value for --lang: ES\n'
--lang ""      -> exit=2 stderr='usage: greet [options] invalid value for --lang: \n'
--format ""    -> exit=2 stderr='usage: greet [options] invalid value for --format: \n'
--times ""     -> exit=2 stderr='usage: greet [options] invalid value for --times: \n'
--name --shout -> exit=2 stderr='usage: greet [options] missing value for --name\n'
--times -1     -> exit=2 stderr='usage: greet [options] missing value for --times\n'
--times 007    -> exit=2 stderr='usage: greet [options] invalid value for --times: 007\n'
--times 1      -> exit=0 stdout='Hello, world\n'
--times 4      -> exit=0 stdout=4 lines
--times 5      -> exit=0 stdout=5 lines
--lang en|es|fr -> exit=0 stdout='Hello, world\n' / 'Hola, world\n' / 'Bonjour, world\n'
```

The one-line rule under a newline-bearing value, live:

```
--lang 'de\nX'  -> stderr=b'usage: greet [options] invalid value for --lang: de X\n'   (1 newline)
--lang 'de\rX'  -> stderr=b'usage: greet [options] invalid value for --lang: de X\n'   (1 newline)
--name=A\nB     -> stderr=b'usage: greet [options] invalid flag syntax: --name=A B\n'   (1 newline)
Ada\nBob        -> stderr=b'usage: greet [options] unexpected argument: Ada Bob\n'     (1 newline)
config {"lang":"de\nX"} -> stderr=b'usage: greet [options] invalid value for lang: de X\n' (1 newline)
```

### Mutation pass (mine, in a scratch copy outside the repo)

Baseline in `/tmp/greet-phase5/mut`: 78 pass, 0 fail. Every phase-5 behaviour turns the suite
red on a targeted mutation, so the tests pin the claim and not just the file names.

```
M1  formatUsage drops the reason            -> 58/20  (red)
M2  formatUsage drops the trailing newline  -> 58/20  (red)
M3  formatUsage prefix becomes 'usage: greet [opts] ' -> 58/20 (red)
M4  oneLine removed (newline kept in reason)-> 76/2   (red)
M5  'unknown flag: ${arg}' -> 'unknown flag' -> 73/5   (red)
M6  'missing value for ${arg}' -> 'missing value' -> 71/7 (red)
M7  'invalid value for ${arg}: ${value}' drops the value -> 73/5 (red)
M8  'invalid flag syntax: ${arg}' reworded  -> 75/3   (red)
M9  'invalid argument: --' reworded         -> 76/2   (red)
M10 'empty value for --name' reworded       -> 76/2   (red)
M11 --times digit rule allows '03'          -> 75/3   (red)
M12 --times range cap removed               -> 77/1   (red)
M13 a value starting with '-' is consumed   -> 76/2   (red)
M14 an unknown flag becomes positional      -> 70/8   (red)
M15 the usage path also writes to stdout    -> 59/19  (red)
M16 the usage path exits 1 instead of 2      -> 59/19  (red)
M17 the usage path writes nothing to stderr -> 59/19  (red)
```

One mutant stayed green: `oneLine`'s `+` quantifier dropped (`[\r\n]+` → `[\r\n]`), 78/0. I
confirmed it independently. It is equivalent on every output a cited id constrains: it changes
the rendering only for a value holding *consecutive* line breaks (`de\n\nX` renders `de X`
under `+` and `de  X` without it), and no id in phase 5's slice pins the reason for such a
value. Both forms still remove every `\r` and `\n`, so the one-line guarantee, the fixed prefix,
the exit code and all 21 §4.3 reason strings are unchanged. Not a finding.

## Attention

- `decisions.tsv` row `2026-11-20T13:07:05Z` (unit-5 gate-reason, the `formatUsage` entry): the
  unit changed `formatUsage` so it no longer returns the reason verbatim as spec §4.1 line 283
  states; a line break inside the reason is collapsed to a space first. The decision row itself
  says "the spec owner may want to confirm the choice", so this was decided by the
  implementer, not by the user. I checked the cause: REQ-070 and REQ-072 are absolute ("writes
  exactly one line", "stderr never holds more than one line"), the spec is silent on what a
  newline-bearing value should look like, and every reason string pinned in §4.3 stays byte for
  byte the same (verified above). The choice is sound, but the spec text at §4.1 line 283 now
  reads "Returns `usage: greet [options] ${reason}`" while the code returns
  `` `usage: greet [options] ${oneLine(reason)}\n` ``. The user should either confirm the
  behaviour or update that sentence through `writing-specs`.
- `decisions.tsv` row `2026-11-20T13:06:59Z` (unit-5 gate-reason, TEST-023 deferral): the
  config half of TEST-023, the `usage: greet [options] invalid greet.config.json\n` line for a
  config whose top level is not an object, is not tested in phase 5. It needs the `runIn(cwd, ...)`
  helper, which belongs to TASK-601. The deferral is logged under Differences and the requirement
  it carries (REQ-066) is traced to TASK-301, TASK-303 and TASK-602, so it is a planned
  deferral, not a loss. I confirmed the gap is real: `test/greet.test.js` has no `runIn` helper
  and no `cwd`-based test.
- `decisions.tsv` rows `2026-11-20T13:06:58Z` and `2026-11-20T13:07:05Z` (unit-5 gate-reason):
  the 17 Red cases of TASK-501 and TASK-502 passed as soon as they were written, because the
  reasons were already pinned by TASK-102 at the unit seam and the prefix and exit code by
  TASK-402. The unit logged this under Differences as the writing-tasks skill prescribes. I
  re-verified the load-bearing claim myself: each of the 17 route tests pins its own exact
  reason string, and every reason mutation (M5 to M10) turns exactly the tests that pin that
  reason red. The fix round for this unit did change production code (`src/greet.js:186-190`,
  the `oneLine` helper), and that change is what closes the phase-5 review's P1 (F01).
- `decisions.tsv` row `2026-11-20T11:58:02Z` (phase-3 gate-reason): the user accepted phase 3
  with two P2 Warnings open. They are carried forward, not new here.
- The seven spec-gate answers Q-1 to Q-7 (`decisions.tsv`, 2026-11-19) are binding and were
  applied by the implementer, not re-decided here. Q-1 (`--times` accepts only a plain digit
  string) and Q-2 (a value starting with `-` is never consumed) are directly exercised by this
  phase's slice: `--times 03`, `--times +2`, `--name -x` and `--times -1` all give their pinned
  usage lines, live.

## Not in the spec

None for phase 5. The unit's production change is one private helper, `oneLine`, in
`src/greet.js:186`, used only inside `formatUsage`. It is not exported, so it adds no public
surface (CON-004 holds: exactly five options, no `--help`, no `--version`, no environment
variable). `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting` and `renderOutput` are
byte-identical to the phase-4 base (`git diff e41cada..HEAD -- src/greet.js` shows 6 changed
lines, all inside `formatUsage`). No fixture directory was created, changed or deleted.

## Contracts (data model, API, config)

- **Usage-error contract (REQ-070, REQ-071, REQ-072, SEC-005):** `src/greet.js:188-190` builds
  the line as `` `usage: greet [options] ${oneLine(reason)}\n` ``; `bin/greet.js:13-19` writes it
  to stderr, sets `process.exitCode = 2` and writes nothing to stdout. Live: stdout is 0 bytes
  and stderr is exactly one line for all 17 flag cases. `bin/greet.js:15` is the only
  `process.stderr.write` in the codebase, so the one-line rule holds on the config path too
  (`formatUsage` is the single writer, GUD-004); the config path was probed live and gives
  `invalid value for lang: de X` on one line.
- **Pinned reason strings (REQ-011, REQ-032, REQ-040, REQ-077, REQ-078):** the §4.3 table has 15
  flag-side rows; all 15 are byte-exact live, and the two extra values the table does not name
  (`--times 6`, `--times 1.5`, `--lang ES`) produce the same reason shape with the offending
  value appended, which is what §4.3's closing paragraph requires.
- **CLI surface (CON-004, REQ-001):** `--help` and `--version` are usage errors with exit code 2,
  live, as Q-3 and CON-004 pin. No sixth option was added.
- **`--times` range (REQ-032):** 1, 4 and 5 accepted live with the right number of lines; 0, 6,
  `abc`, `1.5`, `03`, `+2`, `007` and `-1` are usage errors with exit code 2.

## Tasks file

- Ticked: TASK-501 and TASK-502 (`tasks:161-162`), both dated 2026-11-20. Every id in their Spec
  columns is Met in this report.
- Untick-worthy: none. No ticked task in the file has an id that is not Met.
- Unticked and correctly so: TASK-601, TASK-602 (phase 6), TASK-701, TASK-702 (phase 7) are all
  `[ ]`. The config CLI behaviour itself already works (probed live: a config
  `{"name":"Ada","lang":"es"}` gives `Hola, Ada\n` and `--name Bob` gives `Hola, Bob\n`), but the
  `runIn(cwd, ...)` helper and the CLI-level config tests are genuinely absent
  (`grep -c runIn test/greet.test.js` is 0), and the name-fidelity and security-boundary cases
  are untested at the process seam. The behaviour being present without the coverage is exactly
  what the unticked tasks own, so the ticks are honest.
- **Differences from the spec:** four new entries were added by this unit (`tasks:254-257`),
  covering the Red-cases-pass-immediately fact for TASK-501 and TASK-502, the TEST-023 config
  deferral, and the `formatUsage` `oneLine` change. I checked each against the code and the
  spec: all four are accurate. The `oneLine` entry is a real deviation from one descriptive
  sentence in §4.1 and is logged with its reason, as the writing-tasks skill requires.
- `check-plan.sh plans/greet-options` passes: "50 REQ/SEC ids, 19 tasks. OK".

## All ids

Met: REQ-011, REQ-032, REQ-040, REQ-070, REQ-071, REQ-072, REQ-074, SEC-005, TEST-015, TEST-023

| Id | Status | Tier | Test |
|---|---|---|---|
| (all above) | ✅ Met | Tested + Verified | `test/greet.test.js` › the 17 route tests and the live CLI probes above |

Grade notes for the ids phase 5 owns only in part:

- REQ-011: Met for the flag path (the reason `empty value for --name`, the one stderr line, the
  empty stdout and the exit code 2), which is the whole of REQ-011. The config `name` rule is
  REQ-079, owned by TASK-602 (phase 6).
- REQ-032: Met. The full invalid set (0, 6, `abc`, `1.5`, `03`, `+2`) is asserted at the unit
  seam (`test/greet.test.js:125-132`) and 0, `03` and `abc` are asserted at the route seam with
  the exact stderr string; all six are probed live.
- REQ-040: Met for the flag path. `--lang de` and `--lang ES` are usage errors with exit code 2
  (the route test pins `de`, the unit test pins `ES`, both probed live); the empty value is a
  usage error too. The config `lang` rule is REQ-062/REQ-068 (phase 3 unit, phase 6 CLI).
- REQ-070, SEC-005: Met for the flag path, which is phase 5's slice. The config-path usage error
  is TASK-602 (phase 6).
- REQ-071: Met. The fixed prefix and the reason shape are pinned by exact-string assertions;
  M3 (prefix) and M1 (reason) are red.
- REQ-072: Met. Every stderr capture holds exactly one `\n`; the `oneLine` collapse keeps that
  true for a value holding a newline, which M4 proves is load-bearing.
- REQ-074: Met. Every listed case (unknown flag `--nmae`, `--help`, `--version`, a stray
  positional, `--name` and `--times` with no value, `--name -x`, a value for an unknown flag, an
  unsupported `--lang`, an unsupported `--format`, an empty `--name`, and a bad `--times`) is a
  usage error with exit code 2, empty stdout and one stderr line.
- TEST-015: Met. The six inputs it names are all asserted at the route seam with the exact
  stderr string, the empty stdout and the exit code 2.
- TEST-023: Met for the phase-5 slice, which is the five flag-side exact strings. The sixth
  string it names, `usage: greet [options] invalid greet.config.json\n` for a config whose top
  level is not an object, is the config half, owned by TASK-602 (phase 6); the deferral is
  logged under Differences and the behaviour is probed correct (a non-object config gives
  `invalid greet.config.json` with exit code 2 and an empty stdout).

Not started in this phase, owned by a later task (not a gap, and not graded here): REQ-060 to
REQ-069, REQ-079, SEC-001, SEC-002, SEC-003, SEC-004, SEC-006, REQ-073, CON-001 to CON-006,
GUD-001 to GUD-005, PAT-001, TEST-005 to TEST-014, TEST-016 to TEST-022, TEST-024, RISK-001 to
RISK-005, ASSUMPTION-001 to ASSUMPTION-004.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
top:
- REQ-070 Met one stderr line, empty stdout, exit code 2 on every usage error
- REQ-071 Met the fixed prefix and the reason are pinned by exact-string assertions
- REQ-074 Met every bad input the spec lists is a usage error with exit code 2
- REQ-072 Met stderr holds exactly one line, including for a newline-bearing value
- SEC-005 Met stdout is 0 bytes on every usage error
report: plans/greet-options/reports/phase-5/conformance.md
