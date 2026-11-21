---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 9da58b2
tests: npm test: 93/93 (/tmp/gocheck/test.log)
mode: full
---

# Conformance: greet-options

**Summary:** 85 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms with gaps

verdict: pass

Every REQ, SEC, CON, GUD, PAT and TEST id in spec v0.4 is implemented exactly as written and is
proven by a test that ran green today, or (for the guideline and pattern ids) by the code review
the spec itself marks "Checked by code review". No behaviour diverges and no id is untested. Four
open P2 Warnings carry forward from the phase gates; none is a behaviour defect, so the verdict is
`pass` with p0=0 and p1=0.

The suite is green, no test was skipped, edited or deleted (`grep -rn "skip\|todo\|\.only"
test/greet.test.js` returns nothing), `package.json` is unchanged, and this report is the only
file I wrote.

## Critical

None.

## Major

None.

## Warnings

- **Unreadable-config branch is unproven (P2, carried from `reports/phase-3/conformance-3.md`).**
  `src/greet.js:144-151` has a `catch` around `fs.readFileSync` with two paths: `ENOENT` (returns
  `{}`) and every other read error (throws `UsageError` with reason
  `invalid greet.config.json`). Only the `ENOENT` path is guarded by a test. I re-ran the phase-3
  mutation in a copy of the tree: replacing the two-branch `catch` with a bare `return {}` leaves
  the suite **green at 93/93**. The behaviour is nevertheless correct: a `greet.config.json` that
  is a directory gives `usage: greet [options] invalid greet.config.json` and exit 2, which is
  what spec §4.1 (`spec:253`) and the §4.3 row "Unreadable or malformed config" (`spec:343`) pin.
  No TEST id and no task row asks for this case. Accepted open by the user at the phase-3 gate
  (`decisions.tsv` `2026-11-20T11:58:02Z`).
- **Spec §8 fixture inventory and the plan's Decisions-row fixture list are stale (P2, carried from
  `reports/phase-3/conformance-3.md`).** Spec §8 (`spec:388`) enumerates 18 fixture directories;
  24 exist. Six are outside that list. Three, `test/fixtures/top-level-string/`,
  `top-level-number/` and `top-level-boolean/`, were added by TASK-303 and are documented only in
  the TASK-303 task row (`tasks:135`), not under **Differences from the spec** and not in the
  Decisions-row fixture list (`tasks:43`). The other three, `unknown-key-inherited/`,
  `unknown-key-proto/` and `unknown-key-path/`, are logged under Differences (`tasks:251`, `253`,
  `263`). No behaviour diverges: REQ-066, spec §4.1 (`spec:254`) and gate answer Q-5 (`spec:464`)
  already require the string, number and boolean top levels to be usage errors, and the code
  rejects all five non-object shapes. A stale enumeration in two plan documents, not a code defect.
- **Test-harness temp-directory leak (P2, carried from `reports/phase-7/conformance.md`).**
  `test/greet.test.js:216` creates a `greet-spy-*` directory with `fs.mkdtempSync` and no code ever
  removes it. The other two temp directories the suite creates (`greet-sec-`, `greet-home-`) are
  removed in the `finally` block at `test/greet.test.js:912-913`; the spy directory has no such
  cleanup, so the count grows by exactly one per `npm test`. Harmless to correctness (a stale spy
  directory cannot pollute a later run) but it accumulates without bound on a CI agent. A defect in
  the test harness, not the shipped CLI; it touches no spec id.
- **Spec §8 sentence "every other directory holds its `greet.config.json`" is now false.** Two
  directories hold more than one file: `test/fixtures/parent-has-config/` holds `greet.config.json`
  and the `child/` directory (which the spec's own parenthetical asks for), and
  `test/fixtures/unknown-key-path/` holds `greet.config.json` **and** `decoy.json`. The second is
  required by TASK-702's Red list and is logged as a Difference (`tasks:263`), so it is an accepted
  deviation, but the spec's §8 wording is stale and should be updated.

## Real run

`npm test` (`node --test`), Node v22.20.0: **93 tests, 93 pass, 0 fail, 0 cancelled, 0 skipped,
0 todo.** Log: `/tmp/gocheck/test.log`. The spec names a runnable entry point (`node bin/greet.js
...`, spec §9), so I drove the real CLI against the committed fixtures and captured stdout, stderr
and the exit code. Every claim below is Verified as well as Tested.

```
node bin/greet.js                          -> 'Hello, world\n'   exit=0  stderr empty
node bin/greet.js --name Ada --shout       -> 'HELLO, ADA\n'     exit=0
node bin/greet.js --lang es --name Ada     -> 'Hola, Ada\n'      exit=0
node bin/greet.js --lang fr --name Ada     -> 'Bonjour, Ada\n'   exit=0
node bin/greet.js --times 3                -> 3 x 'Hello, world\n'  exit=0
node bin/greet.js --times 1                -> 'Hello, world\n'   exit=0
node bin/greet.js --format json            -> '{"greeting":"Hello, world"}\n'  exit=0
node bin/greet.js --format json --times 3  -> '{"greeting":"Hello, world\nHello, world\nHello, world"}\n'  exit=0
node bin/greet.js --format json --name Ada --shout -> '{"greeting":"HELLO, ADA"}\n'  exit=0
```

Every usage-error probe printed exactly one line to stderr, zero bytes to stdout and exit 2, with
the reason string the §4.3 table pins: `unknown flag: --nmae` / `--help` / `--version`,
`unexpected argument: Ada`, `missing value for --name` / `--times` / `--lang` / `--format`
(also for `--name -x`), `empty value for --name`, `invalid flag syntax: --name=Ada`,
`invalid argument: --`, `invalid value for --times: <0|6|abc|1.5|03|+2>`,
`invalid value for --lang: <de|ES>`, `invalid value for --format: xml`.

Config probes, one per committed fixture, each with the §4.3 reason string:

```
no-config / empty-config      -> 'Hello, world\n'   exit=0
unknown-key / -inherited      -> 'Hello, Ada\n'    exit=0   (REQ-061)
unknown-key-proto             -> 'Hello, world\n'  exit=0
good-format                   -> '{"greeting":"Hello, world"}\n'  exit=0
name-ada-lang-es              -> 'Hola, Ada\n'     exit=0
name-ada-lang-es --name Bob   -> 'Hola, Bob\n'     exit=0   (REQ-063)
parent-has-config/child       -> 'Hello, world\n'  exit=0   (REQ-064, SEC-006)
parent-has-config             -> 'Bonjour, Config\n'  exit=0  (the parent file IS read when cwd is the parent)
invalid-json / top-level-array / -null / -string / -number / -boolean
            -> 'usage: greet [options] invalid greet.config.json\n'  exit=2
bad-lang / bad-shout / bad-format / name-number / times-zero / times-string / times-fraction / times-six
            -> 'usage: greet [options] invalid value for <key>: <value>\n'  exit=2
name-empty    -> 'usage: greet [options] empty value for name\n'                exit=2
times-six --times 2 -> 'usage: greet [options] invalid value for times: 6\n'  exit=2   (REQ-069)
```

Two further probes: `HOME`/`USERPROFILE`/`XDG_CONFIG_HOME` pointed at a directory holding
`{"name":"HOMEBOSS","lang":"fr"}` printed `Hello, world` (REQ-064's home-directory clause), and a
`greet.config.json` that is a directory printed `usage: greet [options] invalid greet.config.json`
with exit 2 (the branch the first Warning says has no test).

### Load-bearing check (mutations I ran myself, in a copy of the tree under `${TMPDIR:-/tmp}`)

| Mutation | Result |
|---|---|
| `loadConfig`: any read error treated as file absent | **green, 93/93** (the first Warning) |
| `buildGreeting`: upper-case the word only, not the whole line | red: 4, 23, 35, 58 |
| `renderOutput`: JSON with a space after the colon | red: 10 tests (29, 30, 31, 33, 34, 35, 36, 56, 58, 59) |
| `validateTimes`: digit rule relaxed to `/^[0-9]+$/` (accepts `03`) | red: 18, 66, 73 |
| `loadConfig`: config path walks to the parent directory | red: 38-43 and more |
| `loadConfig`: config `times` range check relaxed | red: 49, 86 |
| `loadConfig`: empty config `name` allowed | red: 48, 83 |
| `loadConfig`: unknown key not skipped (read as a path) | red: 38, 39, 91, 92 |
| `mergeOptions`: a flag may turn `shout` off | red: 52 |
| `formatUsage`: the reason is dropped from the line | red: 18 tests (54, 60-76) |
| `bin/greet.js`: exit code 2 becomes 1 | red: 18 tests (54, 60-76) |

Every pinned rule I mutated turns the suite red, so the tests are load-bearing rather than
decorative. The one mutation that stays green is the unreadable-config branch, the first Warning.

## Attention

- `2026-11-20T17:07:32Z` (unit-7): four fix rounds ran, each closing a real P1 in the **test
  harness** (the unknown-key CLI test could not fail; the no-file test did not guard the read half;
  the fs spy observed only part of the fs surface; the network spy missed `fetch`, `node:dns` and a
  spawned `curl`; three `spawnSync` launches skipped the spy preload). The shipped code never
  changed: `src/` and `bin/` import only `fs` and `path` and hold no `exec`, `spawn`, `http`,
  `net`, `fetch` or `eval`. What you are accepting is a large spy harness (about 200 lines) in the
  shipped test file, built over four fix rounds.
- `2026-11-20T13:07:05Z` (unit-5): `formatUsage` no longer returns the reason verbatim as spec §4.1
  line 283 states; it collapses a line break inside the reason to a space, so a value holding a
  newline cannot make stderr hold more than one line. REQ-070 and REQ-072 are absolute and win.
  The spec does not say what a newline-bearing value should look like, so this unit chose "the line
  break becomes a space". Logged as a Difference (`tasks:257`), but the spec's §4.1 wording is
  stale and the choice is the spec owner's to confirm.
- `2026-11-20T11:58:02Z` (phase-3 gate): the user accepted phase 3 with two P2 Warnings open (the
  unreadable-config branch has no test; the spec §8 and Decisions-row fixture lists are stale).
  Both are carried above at the same severity and neither has been closed since.
- `2026-11-20T11:39:17Z` and `2026-11-20T11:45:40Z` (phase-3): the run was stopped twice at the
  phase-3 gate over P2-only verdicts. The pipeline then moved on and the phase was accepted. The
  two Warnings were never closed; they are the first two Warnings above.
- `2026-11-20T12:12:21Z` (unit-4) and `2026-11-20T12:46:00Z` (unit-5): the code-reviewer verdicts
  were `fail` with p1=1 before the fix rounds; both closed their finding and were re-reviewed clean
  before commit. No unit was committed with an open P0 or P1, except phase 3, accepted with two P2
  Warnings.
- `2026-11-20T13:29:09Z` (unit-6): REQ-064's home-directory clause had no test at the phase-6 gate.
  Phase 7 closed it with the SEC-001 spy test, which points `HOME` and `USERPROFILE` at a temp
  directory and asserts the only file opened is `<cwd>/greet.config.json`. The phase-6 Warning is
  closed, not carried.
- `2026-11-20T08:40:00Z` (tasks fix round): the task plan needed a fix round before it passed
  `check-plan.sh` (verdict fail p0=2 p1=5, closed to p0=0 p1=0 p2=1). A plan-quality signal for
  the whole feature, not a code issue.

## Not in the spec

None of consequence. The shipped surface is exactly the five options of REQ-001 plus the one config
file of REQ-060. `src/greet.js` exports one extra symbol, `OPTION_SPECS` (the constant holding the
option list, `src/greet.js:20-26`), which spec §4.1's export list does not name but the plan's
Decisions row requires (`tasks:38`). It is an internal constant, not a new CLI surface, so it is
internal behaviour with no entry needed.

## Contracts (data model, API, config)

- **Option record (spec §3).** `DEFAULT_OPTIONS` (`src/greet.js:4`) is exactly
  `{ name: 'world', shout: false, times: 1, lang: 'en', format: 'text' }`. The merged record holds
  all five keys, and `times` is a number on both the flag and the config path (`parseTimes`,
  `src/greet.js:17`; the config validator, `src/greet.js:128-133`). One type per key, as the
  Decisions row requires (`tasks:41`).
- **Config file (spec §3 table).** All five keys validated as the table pins: `name` a non-empty
  string (`src/greet.js:118-126`), `shout` a boolean (`127`), `times` an integer 1-5 (`128-133`),
  `lang` in `en|es|fr` (`134-135`), `format` in `text|json` (`136-137`). Unknown keys skipped via
  `Object.hasOwn` (`170`), so an `Object.prototype` member name is ignored rather than crashing.
- **Usage-error contract (spec §4.3).** Every row of the §4.3 table was produced byte-for-byte by
  the real CLI, in both the flag and the config form. The prefix is fixed, the reason names the
  offending key or value, and the file contents never appear in a reason.
- **API.** None. The CLI is the only public surface (spec §4.4); there is no HTTP route, no server
  and no library API beyond the `src/greet.js` exports of §4.1, all of which are present.
- **Config values.** `package.json` is unchanged: no dependency, no new script, `bin` still points
  at `bin/greet.js`. `src/` and `bin/` import only `fs` and `path`.
- **Exit model.** `bin/greet.js` sets `process.exitCode` and falls off the end of the script; it
  never calls `process.exit` (spec §4.2, `tasks:47`). An error that is not a `UsageError` is
  re-thrown, so an unexpected failure shows a stack trace rather than a usage line.

## Tasks file

- All 14 task rows (TASK-101 to TASK-702) are ticked with a Done date, and every one is Met on the
  evidence in this report. No ticked task's ids are unmet.
- No unticked task looks done: the four "Guard" rows whose Red cases pass as soon as they are
  written (`tasks:22` explains the convention) each have a real test in the suite.
- The **Requirement traceability** table (`tasks:194-245`) covers every REQ and SEC id, 45 in
  total, and every id maps to at least one ticked task. It does not list the CON, GUD, PAT or TEST
  ids: a plan-bookkeeping gap, not a coverage gap, since every TEST id is exercised by a named test
  and every CON/GUD/PAT id is checked below.
- **Differences from the spec** (`tasks:247-270`) holds 22 entries. Each is a deliberate choice with
  a reason, and I checked each against the code: the `--times` digit rule (`tasks:249`, matches
  `src/greet.js:10`), the count-as-number conversion (`tasks:250`, matches `src/greet.js:17`), the
  own-property key lookup (`tasks:251`, matches `src/greet.js:170`), the `formatUsage` newline
  collapse (`tasks:257`, matches `src/greet.js:186-190`), the fixture contents (`tasks:260`,
  matches `test/fixtures/parent-has-config/greet.config.json`) and the added `&` metacharacter name
  (`tasks:267`, matches `test/greet.test.js:846`). None changes a pinned output byte or an exit
  code.
- One divergence is missing from Differences: the three fixture directories `top-level-string/`,
  `top-level-number/` and `top-level-boolean/` are documented only in the TASK-303 task row
  (`tasks:135`), and the Decisions-row fixture list (`tasks:43`) is stale on the same point. That is
  the second Warning: plan bookkeeping, not behaviour.

## All ids

Met: REQ-001, REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-010, REQ-011, REQ-012, REQ-020,
REQ-021, REQ-030, REQ-031, REQ-032, REQ-033, REQ-040, REQ-041, REQ-050, REQ-051, REQ-052, REQ-053,
REQ-054, REQ-055, REQ-056, REQ-060, REQ-061, REQ-062, REQ-063, REQ-064, REQ-065, REQ-066, REQ-067,
REQ-068, REQ-069, REQ-070, REQ-071, REQ-072, REQ-073, REQ-074, REQ-075, REQ-076, REQ-077, REQ-078,
REQ-079, SEC-001, SEC-002, SEC-003, SEC-004, SEC-005, SEC-006, CON-001, CON-002, CON-003,
CON-004, CON-005, CON-006, GUD-001, GUD-002, GUD-003, GUD-004, GUD-005, PAT-001, TEST-001,
TEST-002, TEST-003, TEST-004, TEST-005, TEST-006, TEST-007, TEST-008, TEST-009, TEST-010,
TEST-011, TEST-012, TEST-013, TEST-014, TEST-015, TEST-016, TEST-017, TEST-018, TEST-019,
TEST-020, TEST-021, TEST-022, TEST-023, TEST-024

No id is Untested, Partial, Missing, Diverging, Accepted or Outdated. The four Warnings above are
coverage and plan-bookkeeping findings; none withholds a grade from an id.

| Id | Status | Tier | Test |
|---|---|---|---|
| (all ids) | ✅ Met | Tested + Verified; CON/GUD/PAT on Inspected (code-review ids) | `test/greet.test.js` › the named test for each id; see the Real run block |

The ids graded on **Inspected** evidence, because the spec marks them "Checked by code review" or
because they are implementation choices no test can observe:

| Id | Where |
|---|---|
| CON-001 | `src/greet.js:1-2` (`fs`, `path` only); `package.json` has no `dependencies` |
| CON-002 | `package.json` `scripts.test` is `node --test`; the suite uses `node:test` and `node:assert` |
| CON-003 | `src/greet.js:36-38`, exported at `:207`; `greet formats the name` passes |
| CON-004 | `src/greet.js:20-26` holds exactly five option specs; no env var, no `--help`, no `--version` (grep over `src/` and `bin/`) |
| CON-005 | `bin/greet.js:8` passes `process.cwd()`; `src/greet.js:141` joins it with the fixed file name |
| CON-006 | `bin/greet.js` has the shebang and `package.json` `bin` still points at it; the tests drive `node bin/greet.js` |
| GUD-001 | `src/greet.js` is the only file under `src/`; the exports are plain functions |
| GUD-002 | `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput` are separate pure functions, each unit-tested |
| GUD-003 | `GREETING_WORDS` is one constant at `src/greet.js:6` |
| GUD-004 | `formatUsage` (`src/greet.js:188`) is the only writer of the usage line, called from `bin/greet.js:15` |
| GUD-005 | every reason is short and lowercase and names the offending value, never a stack trace or file contents |
| PAT-001 | `loadConfig(cwd)` takes the directory as an argument (`src/greet.js:140`), so the tests point it at fixtures |
