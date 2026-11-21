# spec/review.md

Target: `plans/greet-options/feature-greet-options-spec.md`
Mode: spec
Date: 2026-11-20
Reviewer: spec-verifier

The brief (`plans/greet-options/feature-greet-options-brief.md`) was read first. All 15 brief decisions (D-01 to D-15), all 6 out-of-scope lines and all 4 "Left to the spec" items are honoured by the spec, so there is no P0. The code the spec names (`src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `package.json`) was read to check the spec's claims about it. No files other than this report were written.

## Findings

### P0

None. The spec is buildable as written and matches the brief.

### P1

**F01 [P1] `plans/greet-options/feature-greet-options-spec.md:291` `process.exit(0)` immediately after `process.stdout.write` can truncate the greeting when stdout is a pipe.**
The §4.2 sketch writes the output and then calls `process.exit(0)`. On POSIX, `process.stdout` is asynchronous when it is a pipe or a socket (synchronous for files and TTYs), so `process.exit()` can cut the write short. The spec's own process seam (§9, line 372) drives the CLI through `execFileSync`, which uses pipes, and Node documents pipes as asynchronous on macOS. The same hazard applies to `process.stderr.write(...)` followed by `process.exit(2)` on line 296. Fix: drop the `process.exit(0)` / `process.exit(2)` calls and set `process.exitCode = 0` / `2` so the process ends naturally after the streams flush, or write inside the write callback.

**F02 [P1] `plans/greet-options/feature-greet-options-spec.md:247` a config file whose top level is `null` is not covered, and the "not a plain object" check can let it through.**
REQ-066 (line 79) says a file "whose top-level value is not an object, or which is not valid JSON, is a usage error". A file containing `null` is valid JSON whose top-level value is not an object, so REQ-066 requires a usage line, exit 2, nothing on stdout (REQ-070, SEC-005). But §4.1 line 247 only names "an array or a JSON string" as not-an-object, and in JavaScript `typeof null === 'object'` and `Array.isArray(null) === false`, so the check as described passes `null` through, and the next step (`Object.keys(null)` or `config.name`) throws a `TypeError`. §4.2 line 298 re-throws a non-`UsageError`, so the user gets a stack trace and a non-zero exit instead of the required one-line usage error. Fix: say in §4.1 that `null` is not an object and is a usage error, and add a `null` fixture to §8 line 364 and to TEST-006 (line 382).

**F03 [P1] `plans/greet-options/feature-greet-options-spec.md:75` the type rule for `times` in `greet.config.json` is ambiguous, so `"times": "3"` and `"times": 2.5` have no pinned outcome.**
REQ-062 says config values "are validated with the same rules as the flags", and REQ-032 states the flag rule in string terms ("a non-integer value such as `abc`, or a fractional value such as `1.5`"). The §3 table (line 197) instead types the config key as `integer` with allowed value `1 to 5`, and the example config on line 187 uses a JSON number. The two statements disagree for a JSON string value: under "the same rules as the flags" a shared string-based validator might accept `"3"`, under the table it is not an integer and is a usage error. No requirement, test or fixture pins either case (TEST-006 only covers `{"times": 0}`). Fix: state the config rule outright (recommended: `times` must be a JSON number that is an integer from 1 to 5; a JSON string or a fractional number is a usage error) and add both cases to TEST-006 and to the §8 fixture list.

**F04 [P1] `plans/greet-options/feature-greet-options-spec.md:372` the process seam never says that `execFileSync` throws when the CLI exits 2, so TEST-015 and TEST-017 have no specified way to observe the exit code, the empty stdout and the stderr line.**
§9 says the process seam "proves the stdout, stderr and exit-code contract" and gives the exact call `execFileSync(process.execPath, [bin, ...args], { cwd, encoding: 'utf8' })`. `execFileSync` raises on a non-zero exit, so a test written straight from this text cannot read the child's output; the implementer has to decide to catch the error and read `err.status`, `err.stdout` and `err.stderr`. TEST-015 (line 391) and TEST-017 (line 393) both depend on that. Fix: add one sentence to §9 stating that the helper catches the error from a non-zero exit and asserts on `err.status === 2`, `err.stdout === ''` and the exact `err.stderr` string.

**F05 [P1] `plans/greet-options/feature-greet-options-spec.md:249` nothing says whether an invalid config value is still a usage error when a flag overrides that same key.**
§4.1 validates each known key inside `loadConfig`, before the merge, so `greet --times 2` in a directory whose `greet.config.json` holds `{"times": 6}` fails with a usage error under the spec as written. REQ-063 (line 76) reads the other way: "A command-line flag overrides the config value for that key only", so a reader may expect the overridden bad value to be ignored. The brief's rationale for D-04 (fail loudly rather than "greet with a value nobody asked for") also cuts both ways here, because the flag did supply the value. No requirement and no test covers the combination (TEST-017 uses a bad config with no flags). Fix: add a requirement that the config is validated in full regardless of which flags are given, so an invalid config value is a usage error even when a flag overrides that key, and add the case to TEST-017.

### P2

**F06 [P2] `plans/greet-options/feature-greet-options-spec.md:310` the §4.3 table has no row for `--name=Ada` (REQ-077) or `--` (REQ-078), although line 324 says "The reason text after the prefix is the exact string in the table".**
Two named usage errors therefore have no pinned stderr text, and the natural implementation (they are unrecognised flags) yields `unknown flag: --name=Ada` rather than a syntax-specific reason. Fix: add rows for both to the §4.3 table, or say which existing reason they use.

**F07 [P2] `plans/greet-options/feature-greet-options-spec.md:364` one required fixture directory cannot be committed to git.**
§8 says the fixtures are "committed, not generated at run time", but one of the listed directories (TEST-005) has no `greet.config.json` and nothing else in it. Git does not track empty directories, so that fixture is lost on a fresh clone and TEST-005 fails. Fix: say that the directory holds a `.gitkeep` (or a short README) so it can be committed.

**F08 [P2] `plans/greet-options/feature-greet-options-spec.md:375` the new signature of the `run` helper is not pinned.**
§9 says the existing helper "gains an optional `cwd` argument, keeping its current signature working for the existing tests". The current helper is `run = (...args) => execFileSync(process.execPath, [bin, ...args], ...)` (`test/greet.test.js:8`), where every argument is a CLI argument, so an appended `cwd` parameter is indistinguishable from a CLI argument. Fix: state the new signature, for example `run(args = [], cwd)` or a separate `runIn(cwd, ...args)`.

**F09 [P2] `plans/greet-options/feature-greet-options-spec.md:97` the preserved-behaviour bullet is true only when the working directory has no `greet.config.json`.**
"`greet` with no arguments prints exactly `Hello, world` on stdout and exits 0" holds only in a directory without a config file; with one, `greet` prints the config's greeting. The bullet does not say so, and RISK-002 (line 404) shows the spec knows the difference. Fix: qualify the bullet with "and no `greet.config.json` in the working directory".

**F10 [P2] `plans/greet-options/feature-greet-options-spec.md:423` Q-7 changes bytes the brief states as a success criterion, so it must be answered at the gate, not left as a recommendation.**
The brief's success list says `greet --format json` prints `{"greeting": "Hello, world"}` (with a space); REQ-055 (line 68) pins the compact `JSON.stringify` form `{"greeting":"Hello, world"}` (no space). Q-7 asks the right question and recommends the compact form, and RISK-003 (line 405) records the risk, but the brief line is an agreed success criterion that the spec renders differently in bytes. Fix: answer Q-7 at the spec gate and, if the compact form is confirmed, note in §1 that the brief's rendering was the human-readable one.

**F11 [P2] `plans/greet-options/feature-greet-options-spec.md:319` the pinned reason for an empty `--name` ends with a trailing space.**
The table pins `usage: greet [options] invalid value for --name: \n`, so stderr carries a space before the newline. GUD-005 (line 123) asks for short lowercase messages that name the offending value, and a trailing space is an odd byte to freeze into a test. Fix: use a reason such as `empty value for --name` and update the table.

**F12 [P2] `plans/greet-options/feature-greet-options-spec.md:119` GUD-001 says "no new directories", which §8 and §9 contradict.**
GUD-001 reads "All logic lives in `src/greet.js` as plain exported functions, matching the existing one-file layout. No classes, no new dependencies, no new directories." §8 line 364 adds a new `test/fixtures/` tree with about ten directories and §9 line 375 points the config tests at it. The intent is clearly "no new directories in the shipped source layout", but as written a numbered guideline contradicts §8. Fix: qualify GUD-001 as "no new directories under `src/`" or "no new directories in the shipped package".

## Notes carried to the tasks stage

- The brief and the spec agree on every decision; the open questions Q-1 to Q-7 in §11 are the only items that need a user answer before the tasks file is written. Q-1 (`--times 03`), Q-2 (`--name -x`) and Q-5 (a config file that is not an object) each change a REQ and a TEST id, so they should be resolved at the spec gate.
- The spec's naming is consistent across sections: `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput`, `formatUsage`, `UsageError`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, and the file paths `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `test/fixtures/` all match the code and §8.

SUMMARY
verdict: fail
p0: 0
p1: 5
p2: 7
top:
- F01 `process.exit(0)` right after `process.stdout.write` can truncate the greeting on a pipe (the spec's own seam uses pipes)
- F02 a config file whose top level is `null` can escape the "not a plain object" check and produce a stack trace instead of the required usage line
- F03 the config `times` type rule is ambiguous between "same rules as the flags" and the §3 table, so `"times": "3"` has no pinned outcome
- F04 the process seam never says `execFileSync` throws on exit 2, so TEST-015 and TEST-017 have no specified way to observe the exit code and stderr
- F05 nothing says whether an invalid config value is still a usage error when a flag overrides that same key
report: plans/greet-options/reports/spec/review.md
