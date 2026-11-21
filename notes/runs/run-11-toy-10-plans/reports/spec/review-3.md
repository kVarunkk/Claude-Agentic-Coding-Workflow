# spec/review-3.md

Target: `plans/greet-options/feature-greet-options-spec.md`
Mode: spec (recheck, fix round 2)
Date: 2026-11-20
Reviewer: spec-verifier
Previous review: `plans/greet-options/reports/spec/review-2.md`

Recheck scope: the eight P2 findings carried over from review-2 (F06, F07, F08, F09, F11, F12, N01, N02), plus new P0 or P1 problems introduced by the round-2 fix. The fix round is recorded in `plans/greet-options/reports/spec/changes.md` ("Round 2 of the spec gate ... closes the P2 notes ... and records the answers the user gave to the spec gate's open questions"). The changed text is §1 (the new brief-rendering note, line 21), REQ-062 (line 79), the new REQ-079 (line 87), line 75 (the id note), the §3 `name` row (line 202), §4.1 lines 254 and 257, the §4.3 table rows 330, 331 and 338, GUD-001 (line 126), the preserved-behaviour bullet (line 104), §8 lines 386 and 388, §9 lines 401-413, §10 RISK-003, and §11 (the seven gate answers).

The brief (`plans/greet-options/feature-greet-options-brief.md`) was re-read against the spec. All 15 brief decisions (D-01 to D-15), all 6 out-of-scope lines and all 4 "Left to the spec" items are still honoured. The code the spec names (`src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `package.json`) was re-read to check the spec's claims. No files other than this report were written.

## Previous findings

**F06 [P2] `plans/greet-options/feature-greet-options-spec.md:310` the §4.3 table has no row for `--name=Ada` (REQ-077) or `--` (REQ-078). -> fixed**
The table now has a row for each. Line 330: "| `--flag=value` syntax (`greet --name=Ada`) | empty | `usage: greet [options] invalid flag syntax: --name=Ada\n` | 2 |". Line 331: "| End-of-options marker (`greet --`) | empty | `usage: greet [options] invalid argument: --\n` | 2 |". Both match the reason strings that REQ-077 and REQ-078 already named, and both are now asserted by TEST-023 (line 437), which pins the exact stderr for `greet --name=Ada` and `greet --`.

**F07 [P2] `plans/greet-options/feature-greet-options-spec.md:370` one required fixture directory cannot be committed to git. -> fixed**
§8 line 388 now says: "Every fixture directory holds at least one file, so that it can be committed. The directory with no `greet.config.json` holds a `.gitkeep` file and nothing else, and every other directory holds its `greet.config.json`. Git does not track empty directories, so an empty fixture directory would be lost on a fresh clone and the test that needs it would fail." The hazard is now stated as a rule, not just avoided.

**F08 [P2] `plans/greet-options/feature-greet-options-spec.md:381` the new signature of the `run` helper is not pinned. -> fixed**
§9 lines 401-413 now give both helpers verbatim: `run = (...args) => execFileSync(process.execPath, [bin, ...args], { encoding: 'utf8' })` stays exactly as it is, and a second helper `runIn = (cwd, ...args) => execFileSync(process.execPath, [bin, ...args], { cwd, encoding: 'utf8' })` is added next to it. Line 413 states "`runIn` takes the working directory first and the CLI arguments after it, and passes `cwd` to `execFileSync` as the child's working directory." The ambiguity that the finding named (a trailing `cwd` parameter indistinguishable from a CLI argument) is gone.

**F09 [P2] `plans/greet-options/feature-greet-options-spec.md:99` the preserved-behaviour bullet is true only when the working directory has no `greet.config.json`. -> fixed**
Line 104 now reads: "Preserved: `greet` with no arguments prints exactly `Hello, world` on stdout and exits 0 (REQ-002, REQ-073), as long as the working directory holds no `greet.config.json`."

**F10 [P2] `plans/greet-options/feature-greet-options-spec.md:430` Q-7 changes bytes the brief states as a success criterion, so it must be answered at the gate. -> fixed**
Q-7 is now answered at the gate (§11 line 463: "Answered at the spec gate: the JSON output is the compact form `{"greeting":"Hello, world"}`, with no space after the colon. The brief's `{"greeting": "Hello, world"}` is the human-readable rendering of the same shape."), and §1 line 21 now says the same thing to a reader who has not seen the brief: "The brief's success list shows the JSON output as `{"greeting": "Hello, world"}`, with a space after the colon. That is the human-readable rendering of the shape. The pinned output is the compact `JSON.stringify` form `{"greeting":"Hello, world"}`, with no space after the colon (REQ-055), confirmed at the spec gate." RISK-003 (line 445) was updated to match. §12 now says "None." The brief is honoured: the shape and the key are unchanged, only the rendering was made explicit.

**F11 [P2] `plans/greet-options/feature-greet-options-spec.md:325` the pinned reason for an empty `--name` ends with a trailing space. -> fixed**
§4.3 line 338 now reads "| Empty `--name` (`--name ""`) | empty | `usage: greet [options] empty value for --name\n` | 2 |". The trailing space is gone. The reason also agrees with REQ-011 (line 43) and with the §4.1 parse rule (line 246) and is asserted by TEST-023 (line 437).

**F12 [P2] `plans/greet-options/feature-greet-options-spec.md:121` GUD-001 says "no new directories", which §8 and §9 contradict. -> fixed**
GUD-001 (line 126) now reads "No classes, no new dependencies, no new directories under `src/`. The config fixtures live in `test/fixtures/`, which is not part of the shipped package (§8)." The contradiction with the §8 fixture tree is gone.

**N01 [P2] `plans/greet-options/feature-greet-options-spec.md:249` a config whose top level is not an object has no pinned reason string. -> fixed**
§4.1 line 254 now reads: "A top-level value that is not a plain object throws a `UsageError` whose reason is `invalid greet.config.json` (REQ-066)." The §4.3 table gained a matching row (line 340): "| Config top level is not an object (`[1,2]`, `"x"`, `null`, `3`, `true`) | empty | `usage: greet [options] invalid greet.config.json\n` | 2 |". TEST-023 asserts the exact stderr for this case.

**N02 [P2] `plans/greet-options/feature-greet-options-spec.md:197` the config `name` type (string) comes only from the §3 table, not from a requirement. -> fixed**
REQ-079 (line 87) was added: "The `name` key in `greet.config.json` is a JSON string. A non-string value for `name`, such as the JSON number `123` or the JSON boolean `true`, is a usage error (REQ-062)." REQ-062 (line 79) now names it as one of the two exceptions, §3 line 202 cites it, §4.1 line 257 repeats it, and TEST-006 (line 420) covers `{"name": 123}` with a fixture in §8 line 386. The `name` type now has a requirement of its own, in the shape of REQ-067.

### New P0 or P1 problems introduced by the fix round

None. Every changed passage was checked against the brief, against the code the spec names, and against the rest of the spec. The fixes are internally consistent: REQ-079 and §4.1 line 257 agree with the §3 `name` row and with REQ-062's list of exceptions; REQ-062's exception list does not leave `shout`, `lang` or `format` unpinned (REQ-067 pins `shout`, REQ-040 and REQ-041 pin `lang`, REQ-050 pins `format`); the §4.3 table rows added for `--name=Ada` and `--` agree with REQ-077 and REQ-078 and with the §4.1 rules (lines 244, 346); the `.gitkeep` rule in §8 line 388 is consistent with the fixture list in line 386; and the `runIn` helper in §9 line 410 is consistent with the "with `cwd` set to a fixture directory" wording of TEST-016, TEST-017, TEST-020 and TEST-022.

## New P2 notes (not P0/P1, no gate failure)

**N03 [P2] `plans/greet-options/feature-greet-options-spec.md:79` REQ-062 says "the two exceptions", but the config `shout` type is a third deviation from "the same rules as the flags".**
REQ-062 reads "The values in `greet.config.json` are validated with the same rules as the flags, with the two exceptions pinned by REQ-068 and REQ-079: the config `times` value must be a JSON number that is an integer from 1 to 5, and the config `name` value must be a JSON string." A `--shout` flag takes no value at all, so "the same rules as the flags" cannot imply anything about the type of a config `shout` value; that is a third type deviation, pinned by REQ-067 (line 84) and by the §3 table row (line 203). The behaviour is not wrong, REQ-067 and §3 agree with each other, and TEST-006 covers `{"shout": "yes"}`, so no implementation can go wrong on this. The wording undercounts. Fix: say "with the type rules pinned by REQ-067, REQ-068 and REQ-079" and list the `shout` boolean with the other two.

**N04 [P2] `plans/greet-options/feature-greet-options-spec.md:87` the new config `name` rule omits the non-empty constraint that the §3 table carries, so `{"name": ""}` has no pinned rule and no test.**
REQ-079 says the config `name` "must be a JSON string" and gives only non-string examples. The §3 table row (line 202) allows "any non-empty string", and §4.1 line 256 says each known key is validated "with the rules in §3", so `{"name": ""}` is a usage error by that route, and REQ-011 makes the flag form an error too. The behaviour is therefore consistent, but the requirement that owns the config `name` rule says nothing about the empty string, no fixture for it appears in §8 line 386, and no TEST id covers it. Fix: extend REQ-079 to "a JSON string that is not empty", and add `{"name": ""}` to the TEST-006 case list and to the §8 fixture list.

## P2 findings carried over from the previous review (all now closed)

F06, F07, F08, F09, F10, F11, F12, N01 and N02 are all marked fixed above. No P2 note from review-2 remains open.

## Notes carried to the tasks stage

- §12 "Open questions" now reads "None", and §11 records all seven gate answers with the requirement, section and TEST id each one is applied in. The tasks file can be written without further user input.
- The spec's naming is consistent across sections: `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput`, `formatUsage`, `UsageError`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, and the file paths `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `test/fixtures/` all match the code and §8.
- The §8 fixture list names fifteen directories; each one is referenced by at least one TEST id (TEST-005, TEST-006, TEST-016, TEST-017, TEST-020, TEST-022) and none is orphaned.
- Every REQ id (REQ-001 to REQ-079) and every TEST id (TEST-001 to TEST-023) is defined once and well-formed. REQ-079 sits after REQ-069 in the "Config file" group; line 75 explains that it was added later and takes the next free number, so the numbering stays readable.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 2
top:
- F06 fixed: the §4.3 table now has rows for `--name=Ada` (`invalid flag syntax: --name=Ada`) and `--` (`invalid argument: --`), and TEST-023 asserts both
- F07 fixed: §8 now says the empty fixture directory holds a `.gitkeep`, with the reason spelled out
- F08 fixed: §9 now pins both helpers verbatim, `run` unchanged and a new `runIn(cwd, ...args)`
- F09 fixed: the preserved-behaviour bullet now says "as long as the working directory holds no `greet.config.json`"
- N02 fixed: REQ-079 now pins the config `name` type as a JSON string, with §3, §4.1, TEST-006 and a fixture all agreeing
report: plans/greet-options/reports/spec/review-3.md
