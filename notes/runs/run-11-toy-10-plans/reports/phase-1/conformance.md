---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 6d426a5
tests: npm test: 17/17 (log: ${TMPDIR:-/tmp}/greetconf/npm-test.log)
mode: phase 1
---

# Conformance: greet-options (phase 1)

**Summary:** 13 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms

Phase 1 covers TASK-101 and TASK-102 only: the option parser in `src/greet.js` and its unit tests.
The CLI entry point (`bin/greet.js`) is deliberately untouched; TASK-401/402 own it in phase 4.

## Real run

`npm test` (node --test): 17 tests, 17 pass, 0 fail, 0 skipped. Log: `${TMPDIR:-/tmp}/greetconf/npm-test.log`.

Parser probe against the live module (`node -e` against `src/greet.js`), used as Verified evidence:

```
["--nmae","x"]      -> THROW UsageError "unknown flag: --nmae"
["--help"]          -> THROW UsageError "unknown flag: --help"
["--version"]       -> THROW UsageError "unknown flag: --version"
["Ada"]             -> THROW UsageError "unexpected argument: Ada"
["--name",""]       -> THROW UsageError "empty value for --name"
["--name","-x"]     -> THROW UsageError "missing value for --name"
["--name","--shout"]-> THROW UsageError "missing value for --name"
["--times"]         -> THROW UsageError "missing value for --times"
["--lang"]          -> THROW UsageError "missing value for --lang"
["--format"]        -> THROW UsageError "missing value for --format"
["--name=Ada"]      -> THROW UsageError "invalid flag syntax: --name=Ada"
["--"]              -> THROW UsageError "invalid argument: --"
["--times","0"|"6"|"abc"|"1.5"|"03"|"+2"] -> THROW UsageError "invalid value for --times: <value>"
["--lang","de"|"ES"|""]  -> THROW UsageError "invalid value for --lang: <value>"
["--format","xml"]  -> THROW UsageError "invalid value for --format: xml"
["--name","Ada","--name","Bob"] -> {"name":"Bob"}
["--shout","--shout"]            -> {"shout":true}
["--times","5"] -> {"times":5}   (number, matches DEFAULT_OPTIONS.times)
DEFAULT_OPTIONS {"name":"world","shout":false,"times":1,"lang":"en","format":"text"}
GREETING_WORDS  {"en":"Hello","es":"Hola","fr":"Bonjour"}
OPTION_SPECS keys ["--name","--shout","--times","--lang","--format"]
```

## Attention

- `decisions.tsv` row `2026-11-20T10:00:36Z` (unit-1 gate-reason, REQ-032): the Decisions row's `/^[0-9]+$/` was corrected to `/^[1-9][0-9]*$/` inside this unit so it agrees with the code. The correction strengthens the spec rather than weakening it, and the tasks file logs the same under **Differences from the spec** (tasks:223). Nothing to accept, but the user should know the spec's own §11 Q-1 wording was tightened by an implementation unit, not by the spec gate.
- `decisions.tsv` row `2026-11-20T10:00:39Z` (unit-1 gate-reason, REQ-002): `parseOptions` returns `times` as a number, not the string the user typed. The spec's resolved option record (§3) and REQ-068 want the number, so this follows the spec, and it is logged as a Difference (tasks:224). Noted here because the flag path and the config path now carry one type per key, which is the reason the difference is safe.
- `bin/greet.js` still holds the old ad-hoc `--name` lookup, so `node bin/greet.js --nmae x` prints `Hello, world` and exits 0 rather than a usage error. This is correct for phase 1 (the plan's Files column for TASK-101/102 is `src/greet.js` and `test/greet.test.js` only) and is owned by TASK-401/402 in phase 4. Flagged only so nobody reads the current CLI as the finished feature.

## Not in the spec

- None for phase 1. `src/greet.js` exports `OPTION_SPECS` (the option table) and `parseTimes` is a module-local helper; the plan's Decisions table names `OPTION_SPECS` explicitly, and §4.1 lists the exports the feature adds without forbidding the option table. No unplanned public behaviour.

## Contracts (data model, API, config)

- Option record (§3): `DEFAULT_OPTIONS` in `src/greet.js:1` is exactly `{ name: 'world', shout: false, times: 1, lang: 'en', format: 'text' }`, one type per key (numbers for `times`), matching the spec's table.
- `GREETING_WORDS` (`src/greet.js:3`) is exactly `{ en: 'Hello', es: 'Hola', fr: 'Bonjour' }` (REQ-003).
- Option list: `OPTION_SPECS` (`src/greet.js:17-23`) holds exactly the five flags of REQ-001, each with its kind and allowed values; `parseOptions` reads only this table.
- No config file, no API surface, no env var was added in this phase, so §3's `greet.config.json` contract and §4.4's "no API contracts" are untouched.
- `greet(name)` (`src/greet.js:33-35`) is unchanged and still returns `Hello, ${name}` (CON-003); the pre-existing test `greet formats the name` still passes.
- `package.json` unchanged: no new dependency, no new script, `bin` entry still `bin/greet.js` (§8).

## Tasks file

- TASK-101 and TASK-102 are both ticked with the date 2026-11-20, and both are evidenced: their Red lists are covered by the 14 new tests in `test/greet.test.js` and their Green steps by `src/greet.js`.
- No task outside phase 1 is ticked. Every other task row is `[ ]`.
- Phase 1's Files column (`src/greet.js`, `test/greet.test.js`) matches the files the unit actually changed; `git diff 48ffa1e..HEAD` touches only those two plus the plan's own report and decisions files, which the pipeline owns.
- No divergence in phase 1 is missing from **Differences from the spec**: both logged differences (the `--times` digit rule, the numeric `times`) map to phase-1 tasks.

## All ids

Met: REQ-001, REQ-002, REQ-011, REQ-032, REQ-040, REQ-041, REQ-074, REQ-075, REQ-076, REQ-077, REQ-078, TEST-001, TEST-002, TEST-003, TEST-004

| Id | Status | Tier | Test |
|---|---|---|---|
| (all above) | ✅ Met | Tested | `test/greet.test.js` › the 14 new `parseOptions` tests |

Grade notes for the ids that are only partly owned by phase 1 (the rest is later work, not a gap):

- REQ-001: Met for the five-option surface and the unknown-flag error (TASK-101/102). The CLI-level surface is TASK-401/402.
- REQ-002: Met for the `DEFAULT_OPTIONS` export (TASK-101). The merge into a full record is TASK-302, the JSON default is TASK-204.
- REQ-011: Met for the parse-level reason `empty value for --name` (TASK-102). The stderr line and exit code 2 are TASK-501.
- REQ-032: Met for the parse-level validation and reason (TASK-102). The stderr line is TASK-502.
- REQ-040, REQ-041: Met for the parse-level validation and reason (TASK-102). The stderr line is TASK-501.
- REQ-074: Met for every listed bad input at the parse boundary (TASK-102). The end-to-end stdout/stderr/exit-2 contract is TASK-501/502.
- REQ-075, REQ-076: Met for the flag path (TASK-102). A config `shout: true` that a flag cannot turn off is TASK-302.
- REQ-077, REQ-078: Met for the parse-level reasons (TASK-102). The stderr line is TASK-502.
- TEST-001 to TEST-004: Met. TEST-001 › `parseOptions returns only the keys the user gave`; TEST-002 › `parseOptions recognises every option`; TEST-003 › `parseOptions lets the last occurrence of a flag win`; TEST-004 › the eight `parseOptions rejects ...` tests covering `--nmae`, `--help`, the positional, the missing values, the dash value, the empty name, `--flag=value`, `--`, the bad `--times`, `--lang` and `--format` values.

Coverage notes (no severity):

- TEST-004's `--version` case and the empty `--lang` / empty `--format` values are probed and correct but not asserted by a named test. The spec's §4.3 table pins only `de` and `xml`, so this is not a spec gap; TASK-501/502 add the `--version` stderr case.
- Every new test builds its expectation on one shared helper, `reasonOf` (`test/greet.test.js:10-18`), which asserts `err instanceof UsageError` before returning `err.reason`. The helper is not mocked, so the assertions still reach the real throw site.

---

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
top:
- REQ-001 ✅ Met: parseOptions recognises exactly the five flags, every other argument is a usage error
- REQ-032 ✅ Met: --times accepts a plain digit string 1-5, rejecting 0, 6, abc, 1.5, 03, +2
- REQ-074 ✅ Met: every bad input in the spec's list throws a UsageError at the parse boundary
- REQ-075 ✅ Met: last occurrence wins, --shout set twice stays true
- REQ-002 ✅ Met: DEFAULT_OPTIONS is the spec's five-key record with times as a number
report: plans/greet-options/reports/phase-1/conformance.md
