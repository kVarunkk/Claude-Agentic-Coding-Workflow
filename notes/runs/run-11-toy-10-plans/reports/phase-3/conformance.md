---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 7623912
tests: npm test: 47/47 (/tmp/phase3-tests.log)
mode: phase 3
---

# Conformance: greet-options (phase 3)

verdict: fail

**Summary:** 14 met · 0 untested · 2 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms with gaps

Phase 3 covers TASK-301 (`loadConfig`) and TASK-302 (`mergeOptions`), the unit seam of the config
file. `bin/greet.js` is deliberately untouched; TASK-401/402/601/602 own the CLI and the config
end to end in phases 4 and 6.

## Major

- **REQ-066** 🟡 Partial: the id says "`greet.config.json` is a JSON object. A file whose top-level value is not an object, or which is not valid JSON, is a usage error". The implementation rejects every non-object top level (`src/greet.js:162`, `parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)`), and the spec names five non-object shapes: an array, a JSON string, a JSON number, a JSON boolean and `null` (spec:254, spec:342, Q-5 at spec:464). Only **two** of the five have a test: `test/greet.test.js` › `loadConfig rejects a top level that is not a plain object` asserts the `top-level-array` and `top-level-null` fixtures. There is no fixture and no test for a top level of `"hello"`, `42`, `true` or `false`. Evidence that the gap is real: the mutation that keeps the array and `null` checks but drops the `typeof` check (letting a string, number or boolean top level through) leaves the suite green, 47 pass, 0 fail. The behaviour is in fact correct, confirmed by probe: `"hello"`, `42`, `true` and `false` each throw `UsageError` with reason `invalid greet.config.json`. A fixture per shape, or one fixture that is asserted through a loop, would close this.
- **REQ-065** 🟡 Partial: the id says "The config file is read once per process run and is not re-read when a flag overrides one of its keys". Phase 3's own row asks for the unit-level half of this, TASK-301's Green: "reads it once with `fs.readFileSync`". No test asserts the read count, and the mutation that reads the file twice leaves the suite green, 47 pass, 0 fail. The behaviour is in fact correct: probe with `fs.readFileSync` wrapped shows exactly **1** read for one `loadConfig` call, and `mergeOptions` (`src/greet.js:184-196`) takes an already-loaded plain object and does no I/O at all, so it cannot re-read. The "not re-read when a flag overrides one of its keys" half of the id belongs to the CLI layer and is owned by TASK-601 in phase 6. A read-count assertion (or a merge-level assertion that no file is touched) would close the phase-3 half.

## Warnings

- **Coverage smell (the unreadable-config branch, `src/greet.js:146-151`):** the `catch` around `fs.readFileSync` has two paths and only one is guarded. The `ENOENT` path is covered by `loadConfig returns an empty object when the file is absent or empty`, but the other path, a file that exists and cannot be read, has no test. The mutation that treats any read error as "file absent" leaves the suite green. The behaviour is in fact correct: probe with `greet.config.json` as a directory gives `UsageError` with reason `invalid greet.config.json`, which is what spec:253 asks for ("a file that cannot be read"). The same gap is recorded as F03/P2 in `plans/greet-options/reports/phase-3/review-3-2.md:24`. No TEST id and no task row asks for this case, so it is a coverage gap, not a spec violation.
- **Coverage smell (phase 3 only):** the two `mergeOptions` tests and the three `loadConfig` "returns" tests all call the function directly with a fixture path, and no test drives `loadConfig` into `mergeOptions` as a pair, so the "validated before the merge" seam (REQ-069) is proven only by the two halves separately. The composition is exercised for real from phase 6 (TASK-601/602) once `bin/greet.js` calls the pipeline.

## Real run

`npm test` (`node --test`): 47 tests, 47 pass, 0 fail, 0 skipped, 0 todo. Log: `/tmp/phase3-tests.log`.
Node v22.20.0, `package.json` unchanged (`npm test` still `node --test`, no new dependency).

The 15 phase-3 tests that ran and passed (all `ok`, none skipped): `loadConfig returns an empty
object when the file is absent or empty`, `loadConfig ignores an unknown key`, `loadConfig ignores
an unknown key that names an Object.prototype member`, `loadConfig honours a valid format`,
`loadConfig rejects a file that is not valid JSON`, `loadConfig rejects a top level that is not a
plain object`, `loadConfig rejects an unsupported language`, `loadConfig rejects a shout value that
is not a boolean`, `loadConfig rejects an unsupported format`, `loadConfig rejects a name that is not
a string`, `loadConfig rejects an empty name`, `loadConfig rejects a count that is not an integer
from 1 to 5`, `mergeOptions lets a flag override only its own key`, `mergeOptions with neither layer
set returns the built-in defaults`, `mergeOptions never turns a shout off`.

Live probes of the phase-3 functions against the real module (`node` against `src/greet.js`), used as
Verified evidence for the claims the tests do not cover:

```
REQ-069 loadConfig(times-six) throws: UsageError | invalid value for times: 6
REQ-065 reads for one loadConfig call: 1
REQ-061 unknown-key {"name":"Ada","unknownKey":1} -> {"name":"Ada"}
REQ-002 merge({},{}) -> {"name":"world","shout":false,"times":1,"lang":"en","format":"text"}
REQ-076 merge({shout:true},{shout:false}).shout -> true ; merge({shout:false},{shout:true}) -> true
REQ-066 top level "hello" / 42 / true / false -> invalid greet.config.json (each)
REQ-062 name:true -> invalid value for name: true ; name:null, shout:null, times:null, times:true -> same shape
REQ-066 unreadable config (greet.config.json is a directory) -> invalid greet.config.json
SEC-004 reason for {"name":"SUPERSECRETVALUE","lang":"de"} -> "invalid value for lang: de" (contents absent)
SEC-004 reason for invalid JSON containing TOPSECRET123 -> "invalid greet.config.json" (contents absent)
merged keys after loadConfig+mergeOptions -> ["name","shout","times","lang","format"]
prototype pollution through mergeOptions -> undefined
```

The spec names no runnable CLI example for phase 3: the config examples (`greet` in a directory with
a `greet.config.json`) are route-level and belong to TASK-601 in phase 6, and `bin/greet.js` still
holds the old ad-hoc `--name` lookup, so it cannot read a config yet. The unit seam is the phase-3
seam and it was probed directly.

Mutation results, in a scratch copy of the tree under `${TMPDIR}` (`npm test`, 47 tests each):
top-level object check removed entirely -> red (1 fails) | narrowed to array+null only -> **green**
(REQ-066 gap) | config file read twice -> **green** (REQ-065 gap) | any read error treated as "file
absent" -> **green** (unreadable-config gap) | unknown-key own-property guard removed -> red (2
fail) | config `times` upper bound removed -> red | config `shout` type check removed -> red | config
empty-`name` check removed -> red | `mergeOptions` lets a flag set `shout` to `false` -> red |
`mergeOptions` drops the config layer -> red (2 fail).

## Attention

- `decisions.tsv` row `2026-11-20T11:08:39Z` (unit-3 gate-reason): one mutation stayed green, the unreadable-config branch (`src/greet.js:147`) is untested. The recorded judgement is that this is a test gap only and that no task row or TEST id asks for the case. Confirmed here: the behaviour is correct, and the same gap is reported above as a Warning.
- `decisions.tsv` rows `2026-11-20T11:08:32Z` and `2026-11-20T11:08:38Z` (unit-3 gate-reason): the three differences logged for TASK-301 (own-property-only key lookup, the `times-six` fixture moved into this unit, two extra unknown-key fixtures) all match the spec's REQ-061 and REQ-068 text, so nothing is left unapproved. The row at `2026-11-20T11:08:38Z` also records that one fix round ran and closed the two P1 findings.
- `decisions.tsv` row `2026-11-20T11:08:44Z` (unit-3 commit): unit 3 was reviewed clean after one fix round and committed. `plans/greet-options/reports/phase-3/review-3-2.md` carries verdict pass with p0=0 p1=0 p2=1. No unit was committed with an open P0 or P1.
- The two gaps this report grades as Major (REQ-066, REQ-065) were **not** found by the unit's own review: `review-3-2.md` lists 18 mutations and the three green ones are the top-level narrowing, the double read and the read-error path, but only the read-error path was carried as a finding. Nothing here needs a user decision, but the unit's "clean" verdict rests on a smaller mutation set than it reports.
- Phase 1 and phase 2 (earlier `decisions.tsv` rows) are outside this phase: phase 1 reported no findings and phase 2's REQ-056 Major was closed by the phase-2c auto-fix unit (`plans/greet-options/reports/phase-2/conformance-2.md:41`).
- `bin/greet.js` is untouched by phase 3, so the CLI still ignores `greet.config.json` entirely and `node bin/greet.js` still prints `Hello, world`. That is correct for this phase (neither TASK-301 nor TASK-302 lists `bin/greet.js` in its Files column) and is owned by TASK-401/402/601 in phases 4 and 6. Flagged so nobody reads the current CLI as the finished feature.

## Not in the spec

- None. The phase-3 diff (`git diff --stat 83e91a7..7623912 -- src/ test/ bin/`) is purely additive:
  88 lines in `src/greet.js` (`CONFIG_VALIDATORS`, `loadConfig`, `mergeOptions` and the two new
  `module.exports` names), 108 lines in `test/greet.test.js`, and 18 fixture files. `bin/greet.js`
  is untouched, `package.json` is unchanged, no dependency was added, no env var, no route and no
  CLI surface. `fs` and `path` are Node standard library only (CON-001). Every new export
  (`loadConfig`, `mergeOptions`) is named in the spec's §4.1 export list (spec:228-229).

## Contracts (data model, API, config)

- Option record (§3): `mergeOptions` returns exactly the five keys `name`, `shout`, `times`, `lang`, `format`, in that order, from `DEFAULT_OPTIONS` plus the config plus the flags (`src/greet.js:185-196`). Probe: merged keys `["name","shout","times","lang","format"]`. `times` stays a number on both paths, matching §3's `times: 1, // integer, 1 to 5`.
- Config file (§3): the five keys are validated by `CONFIG_VALIDATORS` (`src/greet.js:117-138`) against §3's table: `name` a non-empty string, `shout` a boolean, `times` a JSON number that is an integer from 1 to 5, `lang` one of `en`/`es`/`fr`, `format` `text`/`json`. Every known key has an invalid-value test.
- Config reasons (§4.3): a config reason names the key without the `--` prefix (`invalid value for lang: de`) and the empty config name uses `empty value for name`, matching §4.3's table (spec:339-341). The flag-side reasons keep their `--` prefix, so the two layers do not collide.
- `loadConfig(cwd)` joins `cwd` with `greet.config.json` and reads exactly that one path (`src/greet.js:141`), so no parent, home or user config directory is consulted (REQ-064's mechanism; REQ-064's proof is TASK-601 in phase 6).
- `formatUsage` and the stderr/exit contract (§4.2, §4.3) do not exist yet: they are TASK-402 in phase 4. Phase 3 throws `UsageError` and nothing catches it yet, so a bad config in the CLI would today print a stack trace. That is expected for this phase and is owned by TASK-602 in phase 6.
- §4.4 "no API contracts" holds: the only public surface added is the two `src/greet.js` exports named in §4.1 (spec:228-229). CommonJS, `require`/`module.exports` (CON-001), `npm test` still `node --test` (CON-002).

## Tasks file

- TASK-301 and TASK-302 are ticked with the date 2026-11-20, and each is evidenced: every Red-list assertion in those two rows has a matching named test in `test/greet.test.js:233-337`, and each Green step has its code in `src/greet.js:117-196`. TASK-301's Red list also asks for the `{"format": "json"}` fixture to be honoured, covered by `loadConfig honours a valid format`.
- No task outside phase 3 is ticked: every phase 4 to 7 row is still `[ ]`, and the earlier ticks (TASK-101, 102, 201, 202, 204, 205, 206) are unchanged.
- The phase-3 diff touches only files in the two rows' Files columns, plus the plan's own front-matter status, the badge, the two Status/Done cells, the three Differences entries, and the pipeline-owned `decisions.tsv` and the two review reports. No task-row text was reworded while ticking.
- The three Differences entries for this unit (own-property key lookup, the `times-six` fixture, the two extra unknown-key fixtures) are all logged and all agree with the spec's REQ-061 and REQ-068 text. No divergence is missing from **Differences from the spec**.
- The traceability rows for REQ-060 to REQ-069, REQ-079 and TEST-005 to TEST-007 name TASK-301 and TASK-302, both now ticked and graded above.
- Phase 1 and phase 2 findings do not carry into this phase: phase 1 reported p0=0 p1=0 p2=0, phase 2's REQ-056 Major was closed by the phase-2c unit, and `git diff --stat 83e91a7..7623912` shows the phase-1 and phase-2 code and tests are unchanged.

## All ids

Met: REQ-002, REQ-060, REQ-061, REQ-062, REQ-063, REQ-067, REQ-068, REQ-069, REQ-076, REQ-079, SEC-004, TEST-005, TEST-006, TEST-007

| Id | Status | Tier | Test |
|---|---|---|---|
| REQ-065 | 🟡 Partial | Tested + Inspected | `test/greet.test.js` › `mergeOptions with neither layer set returns the built-in defaults`; no read-count assertion, double-read mutation green |
| REQ-066 | 🟡 Partial | Tested + Inspected | `test/greet.test.js` › `loadConfig rejects a top level that is not a plain object` (array and `null` only); string, number and boolean top levels untested |

Grade notes for the ids phase 3 owns only in part:

- REQ-002: Met for the merge slice TASK-302 owns (`mergeOptions` starts from `DEFAULT_OPTIONS`). The defaults as constants are TASK-101 (phase 1).
- REQ-060: Met for the unit slice TASK-301 owns (an absent config gives `{}`, which merges to the built-in defaults). Reading the config at startup before rendering is TASK-601 (phase 6).
- REQ-062: Met for the unit slice TASK-301 owns (the five known keys are validated with the three pinned exceptions, and every invalid value is a `UsageError`). The stderr, empty-stdout and exit-2 half is TASK-602 (phase 6).
- REQ-063: Met for the merge slice TASK-302 owns (a flag overwrites only its own key). The CLI-level proof is TASK-601 (phase 6).
- REQ-069: Met for the slice TASK-301 and TASK-302 own (the whole file is validated inside `loadConfig`, before `mergeOptions` runs). The "even when a flag supplies a valid value for that same key" half is TASK-602 (phase 6).
- REQ-076: Met. A flag may only set `shout` to `true`, never to `false`, so a config `shout: true` stays on. `test/greet.test.js` › `mergeOptions never turns a shout off` pins all three directions.
- SEC-004: Met. The config is read with `fs.readFileSync` and parsed with `JSON.parse`, a parse failure is a `UsageError` with reason `invalid greet.config.json`, and the reason names the key or the value and never the file contents. The exact-reason assertions in the invalid-config tests prove the contents cannot appear for those cases, and the probe confirms it for a file whose contents are a secret.

Not started in this phase, owned by a later task (not a gap, and not graded here): REQ-010,
REQ-070 to REQ-078, SEC-001, SEC-002, SEC-003, SEC-005, SEC-006, CON-001 to CON-006, GUD-001 to
GUD-005, PAT-001, TEST-001 to TEST-004, TEST-008 to TEST-024, RISK-001 to RISK-005, ASSUMPTION-001
to ASSUMPTION-004.

---
SUMMARY
verdict: fail
p0: 0
p1: 2
p2: 2
top:
- REQ-066 🟡 Partial: only the array and null top levels are tested, a string, number or boolean top level would pass unnoticed
- REQ-065 🟡 Partial: the read-once rule has no assertion, a double-read mutation stays green
- REQ-069 ✅ Met: the whole config is validated inside loadConfig, before the merge
- REQ-076 ✅ Met: a flag can only turn shout on, never off
- REQ-063 ✅ Met: a flag overwrites only its own key
report: plans/greet-options/reports/phase-3/conformance.md
