# spec/review-4.md

Target: `plans/greet-options/feature-greet-options-spec.md`
Mode: spec (recheck, fix round 3)
Date: 2026-11-20
Reviewer: spec-verifier
Previous review: `plans/greet-options/reports/spec/review-3.md`

Recheck scope: the two P2 findings carried over from review-3 (N03, N04), plus new P0 or P1 problems introduced by the round-3 fix. The fix round is recorded in `plans/greet-options/reports/spec/changes-2.md` ("Spec changes: close the last two P2 notes"). The changed text is REQ-062 (line 79), REQ-079 (line 87), the id note (line 75), the §3 `name` row (line 202), §4.1 lines 256-257, the §4.3 table row (line 340), the §8 fixture list (line 387, the `{"name": ""}` entry), §9 TEST-006 (line 421) and the new TEST-024 (line 439).

The brief (`plans/greet-options/feature-greet-options-brief.md`) was re-read against the spec. All 15 brief decisions (D-01 to D-15), all 6 out-of-scope lines and all 4 "Left to the spec" items are still honoured. The code the spec names (`src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `package.json`) was re-read to check the spec's claims about it. No files other than this report were written.

## Previous findings

**N03 [P2] `plans/greet-options/feature-greet-options-spec.md:79` REQ-062 says "the two exceptions", but the config `shout` type is a third deviation from "the same rules as the flags". -> fixed**
REQ-062 (line 79) now reads: "The values in `greet.config.json` are validated with the same rules as the flags, with three exceptions, because a flag has no value where the config has one. The exceptions are pinned by REQ-067, REQ-068 and REQ-079: the config `shout` value must be a JSON boolean, the config `times` value must be a JSON number that is an integer from 1 to 5, and the config `name` value must be a non-empty JSON string." The count is now three and all three are named with their types. The count is also correct: `lang` and `format` need no exception, because REQ-041 (case-sensitive `en`/`es`/`fr`) and REQ-050 (`text`/`json`) apply to the config values exactly as they do to the flag values.

**N04 [P2] `plans/greet-options/feature-greet-options-spec.md:87` the config `name` rule omits the non-empty constraint that the §3 table carries, so `{"name": ""}` has no pinned rule and no test. -> fixed**
REQ-079 (line 87) now reads: "The `name` key in `greet.config.json` is a JSON string that is not empty. A non-string value for `name`, such as the JSON number `123` or the JSON boolean `true`, and the empty string `""`, are usage errors (REQ-062). ... The usage line for the empty config value uses the reason `empty value for name`." The rule is now consistent in every section that states it:
- §3 table row (line 202): "| `name` | string | any non-empty string; the empty string `""` is a usage error | usage error (REQ-062, REQ-079) |".
- §4.1 line 256: "The one reason that does not follow this shape is the empty `name`, which uses `empty value for name` (REQ-079)."
- §4.1 line 257: "The `name` value must be a JSON string that is not empty (REQ-079). ... The empty string uses the reason `empty value for name`, matching the flag reason `empty value for --name` (REQ-011) with the config key's own name."
- §4.3 table row (line 340): "| Empty config name (`{"name": ""}`) | empty | `usage: greet [options] empty value for name\n` | 2 |".
- §8 fixture list (line 387): "one with `{"name": ""}` (TEST-006)".
- TEST-006 (line 421) now includes `{"name": ""}` in the list of configs `loadConfig` must reject.
- The new TEST-024 (line 439) pins the exact stderr `usage: greet [options] empty value for name\n` end to end.

The reason string follows the spec's own rule at §4.3 line 345 ("a config reason names the config key without it"), so `empty value for name` is the right rendering and not a new shape.

### New P0 or P1 problems introduced by the fix round

None. Every changed passage was checked against the brief, against the code the spec names, and against the rest of the spec, and the fix is internally consistent: REQ-079's non-empty rule agrees with the §3 `name` row, with §4.1 lines 256-257, with the §4.3 table and with REQ-011's flag-side rule; REQ-062's three named exceptions match REQ-067, REQ-068 and REQ-079 one for one, so no known key is left unpinned; the new TEST-024 uses the `runIn(cwd, ...args)` helper pinned in §9 line 411 and the `{"name": ""}` fixture listed in §8 line 387; and §9 line 441 still correctly reads "unit (TEST-001 to TEST-009), route/process (TEST-010 to TEST-024)".

## New P2 notes (not P0/P1, no gate failure)

**N05 [P2] `plans/greet-options/feature-greet-options-spec.md:387` the `{"name": ""}` fixture entry names only TEST-006, but TEST-024 needs the same directory.**
The §8 fixture list tags each directory with the TEST ids that use it, for example "one with an invalid `lang` (TEST-006, TEST-017)" and "one with `{"times": 6}` (TEST-017)". The new entry reads "one with `{"name": ""}` (TEST-006)" only, but TEST-024 (line 439) also drives the CLI with `cwd` set to "a fixture directory holding a `greet.config.json` with `{"name": ""}`". The directory itself is listed and its content is pinned, so nothing is unbuildable; only the cross-reference is missing. Fix: change the tag to "(TEST-006, TEST-024)".

**N06 [P2] `plans/greet-options/feature-greet-options-spec.md:340` the §4.3 table has no row for a config `name` of the wrong JSON type, such as `{"name": 123}`.**
The table now has a row for the empty config name (line 340) but not for a non-string config name. §4.1 line 256 gives the general rule ("An invalid value throws a `UsageError` whose reason names the key and the offending value, for example `invalid value for lang: de`"), so `{"name": 123}` reads as `usage: greet [options] invalid value for name: 123\n`, and TEST-006 covers the throw. The row would only pin the exact bytes. Fix: add a row "| Wrong config name type (`{"name": 123}`) | empty | `usage: greet [options] invalid value for name: 123\n` | 2 |" if the table is meant to be exhaustive, or say in the table preamble that the listed rows are the pinned examples and the general rule covers the rest.

## P2 findings carried over from the previous review (all now closed)

N03 and N04 are both marked fixed above. No P2 note from review-3 remains open.

## Notes carried to the tasks stage

- §12 "Open questions" reads "None", and §11 records all seven gate answers with the requirement, section and TEST id each one is applied in. The tasks file can be written without further user input.
- The spec's naming is consistent across sections: `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput`, `formatUsage`, `UsageError`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, and the file paths `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `test/fixtures/` all match the code and §8.
- The §8 fixture list names sixteen directories; each one is referenced by at least one TEST id (TEST-005, TEST-006, TEST-016, TEST-017, TEST-020, TEST-022, TEST-024) and none is orphaned.
- Every REQ id (REQ-001 to REQ-079) and every TEST id (TEST-001 to TEST-024) is defined once and well-formed. REQ-079 sits after REQ-069 in the "Config file" group; line 75 explains that it was added later and takes the next free number, so the numbering stays readable.
- Every REQ id has at least one TEST id that exercises it, and the two seams are used as the spec intends: the unit seam for the parse, load, merge and render rules, the route seam for the stdout, stderr and exit-code contract.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 2
top:
- N03 fixed: REQ-062 now names all three type exceptions (`shout`, `times`, `name`) and their types, and the count is correct
- N04 fixed: REQ-079 now pins the config `name` as a non-empty JSON string with the reason `empty value for name`, and §3, §4.1, §4.3, §8, TEST-006 and the new TEST-024 all agree
- N05 [P2]: the §8 fixture list tags the `{"name": ""}` directory "(TEST-006)" only, but the new TEST-024 drives the same directory; tag it "(TEST-006, TEST-024)"
- N06 [P2]: the §4.3 table has no row for a wrong-typed config `name` such as `{"name": 123}`, though the §4.1 general rule covers it; add the row or say the rows are examples
report: plans/greet-options/reports/spec/review-4.md
