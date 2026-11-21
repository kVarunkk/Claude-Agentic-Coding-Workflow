# spec/review-2.md

Target: `plans/greet-options/feature-greet-options-spec.md`
Mode: spec (recheck, fix round 1)
Date: 2026-11-20
Reviewer: spec-verifier
Previous review: `plans/greet-options/reports/spec/review.md`

Recheck scope: the five P1 findings of the previous review, plus new P0/P1 problems introduced by the fix round. The fix round is recorded in `plans/greet-options/decisions.tsv` (row 2, "fix-round ... spec review found 5 P1 findings"). The changed text is REQ-062, REQ-068, the new REQ-069, the §3 `times` table row, §4.1 lines 248-253, §4.2 lines 296-312, the §8 fixture list, §9 line 378, and the new TEST-006 and TEST-022 cases.

The brief (`plans/greet-options/feature-greet-options-brief.md`) was re-read against the spec. All 15 brief decisions (D-01 to D-15), all 6 out-of-scope lines and all 4 "Left to the spec" items are still honoured. The code the spec names (`src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `package.json`) was re-read to check the spec's claims. No files other than this report were written.

## Previous findings

**F01 [P1] `plans/greet-options/feature-greet-options-spec.md:291` `process.exit(0)` right after `process.stdout.write` could truncate the greeting on a pipe. -> fixed**
The §4.2 sketch now sets `process.exitCode = 0` (line 296) and `process.exitCode = 2` (line 300) instead of calling `process.exit`, and line 312 states why: "The process ends by falling off the end of the script, not by calling `process.exit`. `process.stdout` is asynchronous when it is a pipe or a socket, so `process.exit` right after a `write` can truncate the output; setting `process.exitCode` lets Node flush the stream before the process ends. The same applies to the stderr write on the usage-error path." The hazard the finding named is now written into the spec as a rule, not just avoided by accident.

**F02 [P1] `plans/greet-options/feature-greet-options-spec.md:247` a config file whose top level is `null` was not covered. -> fixed**
§4.1 line 249 now names `null` explicitly ("An array, a JSON string, a JSON number, a JSON boolean and `null` are not objects") and gives the reason the check must reject it explicitly ("`typeof null === 'object'` in JavaScript and `Array.isArray(null) === false`, so a plain `typeof` or `Array.isArray` test alone lets `null` through and the next access throws a `TypeError` instead of a usage error"). The `null` fixture is in the §8 list (line 370) and in TEST-006 (line 388).

**F03 [P1] `plans/greet-options/feature-greet-options-spec.md:75` the config `times` type rule was ambiguous. -> fixed**
REQ-062 now reads "validated with the same rules as the flags, with the one exception pinned by REQ-068: the config `times` value must be a JSON number that is an integer from 1 to 5". REQ-068 (line 81) rules out the two cases the finding named: "A JSON string such as `"3"`, a fractional number such as `2.5`, a number outside 1 to 5, and any other non-number type are usage errors". The §3 table row now types the key as `JSON number` (line 199), §4.1 line 252 repeats it, and TEST-006 (line 388) plus the §8 fixture list (line 370) cover `{"times": "3"}` and `{"times": 2.5}`.

**F04 [P1] `plans/greet-options/feature-greet-options-spec.md:372` the process seam never said that `execFileSync` throws on exit 2. -> fixed**
§9 line 378 now says: "`execFileSync` raises an error when the child exits with a non-zero status, so the helper catches that error and asserts on `err.status === 2`, `err.stdout === ''` and the exact `err.stderr` string for the usage-error cases." TEST-015 and TEST-017 now have a specified way to observe the exit code, the empty stdout and the stderr line.

**F05 [P1] `plans/greet-options/feature-greet-options-spec.md:249` nothing said whether an invalid config value is still a usage error when a flag overrides that key. -> fixed**
REQ-069 (line 82) was added: "The whole config file is validated before the merge, whether or not a flag overrides the offending key. An invalid value for a config key is a usage error even when a command-line flag supplies a valid value for that same key (REQ-062)." §4.1 line 253 repeats it, and TEST-022 (line 404) covers the case with a `{"times": 6}` fixture and `--times 2`. This also removes the earlier tension with REQ-063, which now reads as a merge rule only.

### New P0 or P1 problems introduced by the fix round

None. Every changed passage was checked against the brief, against the code the spec names, and against the rest of the spec. The five fixes are internally consistent: REQ-069 and §4.1 line 253 agree with the §2 diagram (loadConfig throws before mergeOptions runs), REQ-065 ("read once per process run and is not re-read") is not contradicted by REQ-069 (validated, not re-read), and REQ-062's single named exception does not leave `name`, `shout`, `lang` or `format` unpinned.

### New P2 notes (not P0/P1, no gate failure)

**N01 [P2] `plans/greet-options/feature-greet-options-spec.md:249` a config whose top level is not an object has no pinned reason string, while §4.3 line 330 says the reason is the exact string in the table.**
Line 248 pins `invalid greet.config.json` only for "A JSON parse failure, or a file that cannot be read". Line 249 says a non-object top level "throws a `UsageError` (REQ-066)" without naming the reason, and the §4.3 table (lines 316-328) has no row for it. The implementer must pick a string. This sits in text the fix round rewrote, but it does not fail a test: TEST-006 only asserts that a `UsageError` is thrown, and no route test asserts the stderr string for that case. Fix: name the reason in line 249 (for example `invalid greet.config.json`) or add a row to the §4.3 table.

**N02 [P2] `plans/greet-options/feature-greet-options-spec.md:197` the config `name` type (string) comes only from the §3 table, not from a requirement.**
REQ-062 says config values are validated "with the same rules as the flags", but the flag `--name` value is always a string, so "the same rules" implies no type check for the config. The type is pinned only by the §3 table (`name` | `string`) and §4.1 line 251 ("Validates each known key with the rules in §3"). The two agree, so `{"name": 123}` reads as a usage error, but a reader who takes REQ-062 alone could expect the number to be accepted. This is pre-existing (the §3 `name` row and the REQ-062 phrase "the same rules as the flags" both predate the fix round); REQ-068 covers the `times` type but nothing covers `name`. Fix: add a REQ in the shape of REQ-067, for example "The `name` key in `greet.config.json` is a JSON string; a non-string value is a usage error (REQ-062)."

## P2 findings carried over from the previous review (unchanged)

**F06 [P2] `plans/greet-options/feature-greet-options-spec.md:310` the §4.3 table has no row for `--name=Ada` (REQ-077) or `--` (REQ-078), although line 330 says "The reason text after the prefix is the exact string in the table".** Still open. Two named usage errors have no pinned stderr text, and the natural implementation (they are unrecognised flags) yields `unknown flag: --name=Ada` rather than a syntax-specific reason. Fix: add rows for both to the §4.3 table, or say which existing reason they use.

**F07 [P2] `plans/greet-options/feature-greet-options-spec.md:370` one required fixture directory cannot be committed to git.** Still open. §8 says the fixtures are "committed, not generated at run time", but the directory listed for TEST-005 ("one with no `greet.config.json`") has no `greet.config.json` and nothing else in it. Git does not track empty directories, so that fixture is lost on a fresh clone and TEST-005 fails. Fix: say that the directory holds a `.gitkeep` (or a short README) so it can be committed.

**F08 [P2] `plans/greet-options/feature-greet-options-spec.md:381` the new signature of the `run` helper is not pinned.** Still open. §9 says the existing helper "gains an optional `cwd` argument, keeping its current signature working for the existing tests". The current helper is `run = (...args) => execFileSync(process.execPath, [bin, ...args], ...)` (`test/greet.test.js:8`), where every argument is a CLI argument, so an appended `cwd` parameter is indistinguishable from a CLI argument. Fix: state the new signature, for example `run(args = [], cwd)` or a separate `runIn(cwd, ...args)`.

**F09 [P2] `plans/greet-options/feature-greet-options-spec.md:99` the preserved-behaviour bullet is true only when the working directory has no `greet.config.json`.** Still open. "`greet` with no arguments prints exactly `Hello, world` on stdout and exits 0" holds only in a directory without a config file; with one, `greet` prints the config's greeting. The bullet does not say so, and RISK-002 (line 411) shows the spec knows the difference. Fix: qualify the bullet with "and no `greet.config.json` in the working directory".

**F10 [P2] `plans/greet-options/feature-greet-options-spec.md:430` Q-7 changes bytes the brief states as a success criterion, so it must be answered at the gate, not left as a recommendation.** Still open. The brief's success list says `greet --format json` prints `{"greeting": "Hello, world"}` (with a space); REQ-055 (line 68) pins the compact `JSON.stringify` form `{"greeting":"Hello, world"}` (no space). Q-7 asks the right question and recommends the compact form, and RISK-003 (line 412) records the risk, but the brief line is an agreed success criterion that the spec renders differently in bytes. Fix: answer Q-7 at the spec gate and, if the compact form is confirmed, note in §1 that the brief's rendering was the human-readable one.

**F11 [P2] `plans/greet-options/feature-greet-options-spec.md:325` the pinned reason for an empty `--name` ends with a trailing space.** Still open. The table pins `usage: greet [options] invalid value for --name: \n`, so stderr carries a space before the newline. GUD-005 (line 125) asks for short lowercase messages that name the offending value, and a trailing space is an odd byte to freeze into a test. Fix: use a reason such as `empty value for --name` and update the table.

**F12 [P2] `plans/greet-options/feature-greet-options-spec.md:121` GUD-001 says "no new directories", which §8 and §9 contradict.** Still open. GUD-001 reads "All logic lives in `src/greet.js` as plain exported functions, matching the existing one-file layout. No classes, no new dependencies, no new directories." §8 line 370 adds a new `test/fixtures/` tree with about fourteen directories and §9 line 381 points the config tests at it. The intent is clearly "no new directories in the shipped source layout", but as written a numbered guideline contradicts §8. Fix: qualify GUD-001 as "no new directories under `src/`" or "no new directories in the shipped package".

## Notes carried to the tasks stage

- The brief and the spec agree on every decision; the open questions Q-1 to Q-7 in §11 are the only items that need a user answer before the tasks file is written. Q-1 (`--times 03`), Q-2 (`--name -x`) and Q-5 (a config file that is not an object) each change a REQ and a TEST id, so they should be resolved at the spec gate. Q-5 in particular is now partly answered in the spec body (REQ-066, §4.1 line 249), so it should be closed rather than left as a recommendation.
- The spec's naming is consistent across sections: `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput`, `formatUsage`, `UsageError`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, and the file paths `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `test/fixtures/` all match the code and §8.
- The §8 fixture list now names fourteen directories and each one is referenced by at least one TEST id (TEST-005, TEST-006, TEST-016, TEST-017, TEST-020, TEST-022). No fixture is orphaned.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 9
top:
- F01 fixed: the CLI now sets `process.exitCode` instead of calling `process.exit`, and the spec states the pipe-truncation reason
- F02 fixed: `null` is named as a non-object config top level, with the `typeof null` trap spelled out, plus a fixture and a TEST-006 case
- F03 fixed: REQ-068 now pins the config `times` rule outright (JSON number, integer 1 to 5), with `"3"` and `2.5` in TEST-006
- F04 fixed: §9 now says the helper catches the `execFileSync` error and asserts on `err.status`, `err.stdout` and `err.stderr`
- F05 fixed: the new REQ-069 and TEST-022 pin that an invalid config value is a usage error even when a flag overrides that key
report: plans/greet-options/reports/spec/review-2.md
