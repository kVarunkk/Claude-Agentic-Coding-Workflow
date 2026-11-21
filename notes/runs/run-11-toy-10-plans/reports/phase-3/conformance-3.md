---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 2c26a4f
tests: npm test: 49/49 (log: /tmp/phase3-tests-3.log)
mode: phase 3
---

# Conformance: greet-options (phase 3)

verdict: fail

**Summary:** 16 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms with gaps

Phase 3 owns the unit seam of the config file: `loadConfig` (TASK-301, TASK-303, TASK-304) and
`mergeOptions` (TASK-302). `bin/greet.js` is untouched and still holds the old ad-hoc `--name`
lookup; TASK-401/402/601/602 own the CLI and the config end to end in phases 4 and 6.

This run continues from `reports/phase-3/conformance-2.md` (PARTIAL). Its 16 grades are kept: I
re-read the implementation and the test assertions, ran the suite, and re-ran the mutation pass
independently. Every grade held. The two ids the earlier report graded Partial (REQ-065, REQ-066)
are Met here, and the two Warnings it carried still stand.

## Critical

None.

## Major

None.

## Warnings

- **Coverage smell (the unreadable-config branch, `src/greet.js:146-151`):** the `catch` around
  `fs.readFileSync` has two paths and only the `ENOENT` one is guarded by a test. The mutation
  "any read error is treated as file absent" is still **green** (49 pass, 0 fail) in today's tree,
  so the branch is unproven by the suite. The behaviour is in fact correct: probe with
  `greet.config.json` as a directory gives `UsageError` with reason `invalid greet.config.json`,
  which is what `spec:253` ("a file that cannot be read") and the §4.3 table row "Unreadable or
  malformed config" (`spec:343`) pin. No TEST id and no task row asks for this case, so it is a
  coverage gap, not a spec violation. Same finding as F03/P2 in `reports/phase-3/review-3-2.md:24`
  and as a deliberate "set aside" in `reports/phase-3/review-3a.md:170`.
- **Plan bookkeeping (the three new fixture directories sit outside the spec's §8 fixture
  inventory and outside the plan's Differences section):** TASK-303 adds
  `test/fixtures/top-level-string/`, `top-level-number/` and `top-level-boolean/`. The spec's §8
  inventory (`spec:388`) enumerates 18 fixture directories and does not list these three, and
  `## Differences from the spec` (`tasks:248-253`) has no entry for TASK-303; the widening is
  documented in the TASK-303 task row instead (`tasks:135`), and the Decisions-row fixture list
  (`tasks:43`) stays stale. No behaviour diverges: REQ-066, §4.1 (`spec:254`) "An array, a JSON
  string, a JSON number, a JSON boolean and `null` are not objects", the §4.3 table (`spec:342`)
  and the gate answer Q-5 (`spec:464`) all already require exactly this. So this is a stale
  enumeration in two plan documents, not a divergence in the code. Same finding as F01/P2 in
  `reports/phase-3/review-3a.md:11`.

## Real run

`npm test` (`node --test`): **49 tests, 49 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo.**
Log: `/tmp/phase3-tests-3.log`. Node v22.20.0. `package.json` unchanged (`npm test` still
`node --test`, no dependency added).

The two phase-3a tests ran and passed today:
`loadConfig rejects a top level that is a string, a number or a boolean` (test 39) and
`loadConfig reads the config file exactly once and the merge does not read it again` (test 49).
The 15 phase-3 tests from the earlier report (33 to 48) all still pass; tests 1 to 32 are the
phase-1 and phase-2 tests, unchanged.

Live probes of the phase-3 functions against the real module, used as Verified evidence:

```
REQ-066 top-level-array / -null / -string / -number / -boolean / invalid-json
          -> UsageError "invalid greet.config.json" (each)
REQ-060 no-config -> {} ; empty-config -> {}
REQ-061 unknown-key -> {"name":"Ada"} ; unknown-key-proto -> {}
REQ-062 bad-lang -> "invalid value for lang: de" ; bad-shout -> "invalid value for shout: yes"
          bad-format -> "invalid value for format: xml" ; name-number -> "invalid value for name: 123"
          name-empty -> "empty value for name" ; times-zero -> "invalid value for times: 0"
          times-string -> "invalid value for times: 3" ; times-fraction -> "invalid value for times: 2.5"
          times-six -> "invalid value for times: 6"
REQ-002 merge({},{}) -> {"name":"world","shout":false,"times":1,"lang":"en","format":"text"}
          merged keys -> ["name","shout","times","lang","format"]
REQ-063 merge({name:Config,lang:es},{name:Flag}) -> name Flag, lang es, defaults for the rest
REQ-069 loadConfig(times-six) throws before any merge -> "invalid value for times: 6"
REQ-076 merge({shout:true},{shout:false}).shout -> true ; merge({},{shout:true}).shout -> true
REQ-062 unreadable config (greet.config.json is a directory) -> "invalid greet.config.json"
SEC-004 config {"lang":"de","password":"SUPERSECRETVALUE"} -> "invalid value for lang: de",
          contents absent from the reason
```

The spec names no runnable CLI example for phase 3: the config examples are route-level and belong
to TASK-601 in phase 6, and `bin/greet.js` still holds the old ad-hoc `--name` lookup, so it
cannot read a config yet. The unit seam is the phase-3 seam and it was probed directly.

Mutation pass, re-run independently today in a scratch copy of the tree under `${TMPDIR}`
(`npm test`, 49 tests each). Baseline 49 pass, 0 fail.

| Mutation | Today |
|---|---|
| top-level check narrowed (drop the `typeof` half) | **red** (test 39 fails) |
| top-level check narrowed (drop the `Array.isArray` half) | **red** |
| top-level check narrowed (drop the `null` half) | **red** |
| config file read twice in `loadConfig` | **red** (test 49 fails) |
| `mergeOptions` re-reads `greet.config.json` | **red** (test 49 fails) |
| own-property key guard removed | **red** |
| config `times` upper bound removed | **red** |
| `mergeOptions` lets a flag set `shout` to `false` | **red** |
| `mergeOptions` drops the config layer | **red** |
| config `name` empty allowed | **red** |
| config `shout` non-boolean allowed | **red** |
| config `lang` accepts any value | **red** |
| config `format` accepts any value | **red** |
| unknown key not ignored | **red** |
| `JSON.parse` failure not an error | **red** |
| any read error treated as "file absent" | green (the Warning above) |

## Attention

- `decisions.tsv` row `2026-11-20T11:34:19Z` (unit-3a gate-reason): the TEST-006 fixture-list
  widening is documented in the TASK-303 task row, not under **Differences from the spec**, and the
  Decisions-row fixture list stays stale. The row asks this recheck to decide whether that makes
  the three fixtures an unlogged deviation. Judged here: it does not. No behaviour diverges from
  the spec, because REQ-066, §4.1, the §4.3 table and Q-5 all already name the string, number and
  boolean top levels, and the code and the tests implement exactly that. The gap is a stale
  enumeration in the spec's §8 fixture list and in the plan's Decisions row, reported above as a
  Warning. Same conclusion as `reports/phase-3/review-3a.md:64`.
- `decisions.tsv` row `2026-11-20T11:34:19Z` (unit-3a commit): unit 3a was reviewed clean with 3
  mutations all red and committed. Confirmed: the same mutations are red against today's tree and
  the two new tests pass in today's run.
- `decisions.tsv` row `2026-11-20T11:08:39Z` (unit-3 gate-reason): the unreadable-config branch
  (`src/greet.js:147`) is untested and was judged a test gap only. Confirmed: the behaviour is
  correct (probe above) and the mutation is still green, so the Warning stands.
- The two gaps the first phase-3 report graded as **Major** (REQ-066, REQ-065) were found by that
  report's own mutation pass, not by the unit's review, and were closed by the phase-3a auto-fix
  unit. Both are now **Met** with tests that fail when the behaviour breaks.
- `decisions.tsv` rows `2026-11-20T11:08:32Z`, `11:08:38Z` (unit-3 gate-reason): the three
  Differences logged for TASK-301 (own-property-only key lookup, the `times-six` fixture, two
  extra unknown-key fixtures) all match the spec's REQ-061 and REQ-068 text, so nothing is left
  unapproved. The `11:08:38Z` row records that one fix round ran and closed the two P1 findings.
- `decisions.tsv` rows `2026-11-20T11:08:44Z` and `11:34:19Z` (commit): no unit in phase 3 or
  3a was committed with an open P0 or P1. `review-3-2.md` carries p0=0 p1=0 p2=1 and
  `review-3a.md` carries p0=0 p1=0 p2=1.
- **The decisions trail has an uncommitted row.** `git diff plans/greet-options/decisions.tsv` shows
  one added line: `2026-11-20T11:39:17Z phase-3 stop  spec-matcher restart chain blocked:
  conformance-2.md was written by a restart, so a further spec-matcher spawn with PARTIAL: is refused
  by the hook`. That row records the pipeline stopping to await the user, not a decision about the
  feature. It is the reason this run exists.
- Phase 1 and phase 2 are outside this phase's scope: phase 1 reported p0=0 p1=0 p2=0 and phase
  2's REQ-056 Major was closed by the phase-2c unit (`reports/phase-2/conformance-2.md`).
  `git diff --stat 83e91a7..HEAD -- src/ bin/ test/ package.json` shows `src/greet.js` grown by 88
  additive lines and `bin/greet.js` and `package.json` untouched.
- `bin/greet.js` is untouched by phase 3 and 3a, so the CLI still ignores `greet.config.json`
  entirely and `node bin/greet.js` still prints `Hello, world`. That is correct for this phase
  (none of TASK-301/302/303/304 lists `bin/greet.js` in its Files column) and is owned by
  TASK-401/402/601 in phases 4 and 6. Flagged so nobody reads the current CLI as the finished
  feature.

## Not in the spec

- None. The phase-3a diff (`git diff --stat 7623912..HEAD -- src/ bin/ test/ package.json`) is
  purely additive: 36 lines in `test/greet.test.js` and three fixture files. `src/greet.js` is not
  touched, `bin/greet.js` is not touched, `package.json` is unchanged, no dependency, env var,
  route or CLI surface was added. The test diff has zero removed lines and no `.skip`, `xit` or
  `todo` markers (grep confirms), so no test was weakened to reach green. Both new tests exercise
  exports named in the spec's §4.1 export list (`spec:228-229`). `fs` and `path` are Node
  standard library only (CON-001).

## Contracts (data model, API, config)

- Option record (§3): `mergeOptions` returns exactly the five keys `name`, `shout`, `times`,
  `lang`, `format`, in that order, from `DEFAULT_OPTIONS` plus the config plus the flags
  (`src/greet.js:185-196`). Probe: merged keys `["name","shout","times","lang","format"]`.
  `times` stays a number on both paths, matching §3's `times: 1, // integer, 1 to 5`.
- Config file (§3): the five keys are validated by `CONFIG_VALIDATORS`
  (`src/greet.js:117-138`) against §3's table: `name` a non-empty string, `shout` a boolean,
  `times` a JSON number that is an integer from 1 to 5, `lang` one of `en`/`es`/`fr`, `format`
  `text`/`json`. Every known key has an invalid-value test.
- Config reasons (§4.3): a config reason names the key without the `--` prefix
  (`invalid value for lang: de`) and the empty config name uses `empty value for name`, matching
  §4.3's table (`spec:339-341`). The flag-side reasons keep their `--` prefix, so the two layers
  do not collide.
- `loadConfig(cwd)` joins `cwd` with `greet.config.json` and reads exactly that one path
  (`src/greet.js:141`), so no parent, home or user config directory is consulted (REQ-064's
  mechanism; REQ-064's proof is TASK-601 in phase 6).
- `formatUsage` and the stderr/exit contract (§4.2, §4.3) do not exist yet: they are TASK-402 in
  phase 4. Phase 3 throws `UsageError` and nothing catches it yet, so a bad config in the CLI
  would today print a stack trace. That is expected for this phase and is owned by TASK-602 in
  phase 6.
- §4.4 "no API contracts" holds: the only public surface added in this phase is the two
  `src/greet.js` exports named in §4.1. CommonJS, `require`/`module.exports` (CON-001), `npm test`
  still `node --test` (CON-002).

## Tasks file

- TASK-301, TASK-302, TASK-303 and TASK-304 are all ticked with the date 2026-11-20, and each is
  evidenced. TASK-303's Red list asks for a JSON string, a JSON number and a JSON boolean top
  level to be rejected with the reason `invalid greet.config.json`: covered by
  `test/greet.test.js` › `loadConfig rejects a top level that is a string, a number or a boolean`
  (`test/greet.test.js:269-277`) over the three fixtures
  `test/fixtures/top-level-{string,number,boolean}/greet.config.json`. TASK-304's Red list asks
  for a read-count test and for the count not to rise during the merge: covered by
  `test/greet.test.js` › `loadConfig reads the config file exactly once and the merge does not
  read it again` (`test/greet.test.js:350-373`), which stubs `fs.readFileSync` with a suffix
  filter, asserts the count is 1 and `config` is `{ format: 'json' }`, then asserts the count is
  still 1 after `mergeOptions` with an overriding flag, and restores the original in a `finally`
  block.
- TASK-301's and TASK-302's rows are unchanged since the earlier report, whose evidence still
  holds: every Red-list assertion in those two rows has a matching named test in
  `test/greet.test.js:233-348`, and each Green step has its code in `src/greet.js:117-196`.
- No task outside phase 3 and 3a is ticked: every phase 4 to 7 row is still `[ ]`, and the earlier
  ticks (TASK-101, 102, 201, 202, 204, 205, 206) are unchanged.
- The phase-3a diff touches only files in the two rows' Files columns, plus the plan's own
  front-matter status, the badge, the two Status/Done cells, the traceability rows for REQ-065
  and REQ-066, the pipeline-owned `decisions.tsv`, and the review and fix reports. No task-row
  text was reworded while ticking.
- The three Differences entries for TASK-301 (own-property key lookup, the `times-six` fixture,
  the two extra unknown-key fixtures) are all logged and all agree with the spec's REQ-061 and
  REQ-068 text. The TASK-303 widening is not under Differences; see the second Warning.
- The traceability rows for REQ-060 to REQ-069, REQ-079 and TEST-005 to TEST-007 name TASK-301,
  TASK-302, TASK-303 and TASK-304, all now ticked and graded below.
- Phase 1 and phase 2 findings do not carry into this phase: phase 1 reported p0=0 p1=0 p2=0,
  phase 2's REQ-056 Major was closed by the phase-2c unit, and `git diff --stat 83e91a7..HEAD`
  shows the phase-1 and phase-2 code and tests are unchanged.

## All ids

Met: REQ-002, REQ-060, REQ-061, REQ-062, REQ-063, REQ-065, REQ-066, REQ-067, REQ-068, REQ-069,
REQ-076, REQ-079, SEC-004, TEST-005, TEST-006, TEST-007

No id in this phase's slice is Untested, Partial, Missing, Diverges, Accepted or Outdated. The
grades are unchanged from `conformance-2.md`; the table below records the two ids the first phase-3
report graded Partial and the notes for the ids phase 3 owns only in part.

| Id | Status | Tier | Test |
|---|---|---|---|
| REQ-065 | ✅ Met (was 🟡 Partial) | Tested | `test/greet.test.js` › `loadConfig reads the config file exactly once and the merge does not read it again` (test 49, passes today); the read-twice and merge-re-read mutations are red |
| REQ-066 | ✅ Met (was 🟡 Partial) | Tested | `test/greet.test.js` › `loadConfig rejects a top level that is a string, a number or a boolean` (test 39, passes today), with `loadConfig rejects a top level that is not a plain object` (test 38) for the array and `null` shapes; the narrowed-check mutations are red |

Grade notes for the ids phase 3 owns only in part:

- REQ-002: Met for the merge slice TASK-302 owns (`mergeOptions` starts from `DEFAULT_OPTIONS`).
  The defaults as constants are TASK-101 (phase 1).
- REQ-060: Met for the unit slice TASK-301 owns (an absent config gives `{}`, which merges to
  the built-in defaults). Reading the config at startup before rendering is TASK-601 (phase 6).
- REQ-062: Met for the unit slice TASK-301 owns (the five known keys are validated with the
  three pinned exceptions, and every invalid value is a `UsageError`). The stderr, empty-stdout
  and exit-2 half is TASK-602 (phase 6).
- REQ-063: Met for the merge slice TASK-302 owns (a flag overwrites only its own key). The
  CLI-level proof is TASK-601 (phase 6).
- REQ-065: Met for the unit slice TASK-301, TASK-303 and TASK-304 own. The "read once per
  process run" clause at the CLI level is TASK-601 (phase 6).
- REQ-066: Met for the unit slice TASK-301 and TASK-303 own. The CLI-level usage line for a
  non-object config is TASK-502 and TASK-602 (phases 5 and 6).
- REQ-069: Met for the slice TASK-301 and TASK-302 own (the whole file is validated inside
  `loadConfig`, before `mergeOptions` runs). The "even when a flag supplies a valid value for
  that same key" half is TASK-602 (phase 6).
- REQ-076: Met. A flag may only set `shout` to `true`, never to `false`, so a config
  `shout: true` stays on. `test/greet.test.js` › `mergeOptions never turns a shout off` pins all
  three directions.
- SEC-004: Met. The config is read with `fs.readFileSync` and parsed with `JSON.parse`, a parse
  failure is a `UsageError` with reason `invalid greet.config.json`, and the reason names the key
  or the value and never the file contents. The exact-reason assertions in the invalid-config
  tests prove the contents cannot appear for those cases, and the probe confirms it for a file
  whose contents hold a secret.

Not started in this phase, owned by a later task (not a gap, and not graded here): REQ-010,
REQ-070 to REQ-078, SEC-001, SEC-002, SEC-003, SEC-005, SEC-006, CON-001 to CON-006, GUD-001 to
GUD-005, PAT-001, TEST-001 to TEST-004, TEST-008 to TEST-024, RISK-001 to RISK-005,
ASSUMPTION-001 to ASSUMPTION-004.

---
SUMMARY
verdict: fail
p0: 0
p1: 0
p2: 2
top:
- REQ-065 ✅ Met (was Partial): the read-once rule now has a test, the double-read and merge-re-read mutations are red
- REQ-066 ✅ Met (was Partial): string, number and boolean top levels now have tests, the narrowed-check mutations are red
- REQ-069 ✅ Met: the whole config is validated inside loadConfig, before the merge
- REQ-076 ✅ Met: a flag can only turn shout on, never off
- REQ-063 ✅ Met: a flag overwrites only its own key
report: plans/greet-options/reports/phase-3/conformance-3.md
