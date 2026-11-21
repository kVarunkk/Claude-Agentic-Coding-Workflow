# Review: plans/greet-options unit 1 (TASK-101, TASK-102)

Date: 2026-11-20
Base: 48ffa1ead95959418a41241775823795fb225324

Findings: P0 0 - P1 1 - P2 2 - P3 1    Partitions reviewed: 6

### Index
1. [P1][Med] F01: The `times` value stays a string and no task in the plan converts it; the Differences entry names a layer that does not exist `src/greet.js:82`
2. [P2][Low] F02: `parseOptions` returns `times` as a string while `DEFAULT_OPTIONS.times` and the config path return a number, so the merged option record has two types for one key `src/greet.js:82`
3. [P2][Low] F03: The two validators use two different mechanisms and one of them sits far from the others `src/greet.js:14`
4. [P3][Nit] F04: `validateName` is declared between `greet` and `parseOptions`, away from the other validator `src/greet.js:34`

### F01: The `times` value stays a string and no task in the plan converts it; the Differences entry names a layer that does not exist
- Severity / confidence: P1 / High
- Location: `src/greet.js:82` (`parseOptions`), `plans/greet-options/feature-greet-options-tasks.md:223` (Differences entry). Also affects: TASK-201 (`buildGreeting` sets `count: options.times`), TASK-204 (`renderOutput` uses `greeting.count`), TASK-302 (`mergeOptions`).
- Lens: spec / data-shape
- Failure: `parseOptions(['--times', '3'])` returns `{ times: '3' }`, a string. The spec's resolved option record (spec §3, `plans/greet-options/feature-greet-options-spec.md:180`) says `times: 1, // integer, 1 to 5`, and REQ-068 requires the config `times` to be a JSON number, so the two layers of the merge produce different types for the same key. The Differences entry defers the conversion to "the layer that validates and resolves the count", but no such layer exists: TASK-302 (`mergeOptions`) is specified as "starts from `DEFAULT_OPTIONS`, applies the config values and then the flag values", TASK-301 (`loadConfig`) returns the file's number as is, and TASK-201 (`buildGreeting`) sets `count: options.times` unchanged. `grep -rn "Number(\|parseInt" plans/greet-options/` returns nothing. The string count then silently misbehaves downstream: `new Array('3').length === 1`, so a `renderOutput` built on `new Array(greeting.count)` prints one line for `--times 3` instead of three, and `'1' === 1` is false, so the JSON branch's "the single line when `greeting.count` is 1" test (spec §4.1, `feature-greet-options-spec.md:278`) takes the "joined" branch on a count of one.
- Evidence: probe on the staged code: `parseOptions(['--times','3'])` -> `{"times":"3"}`; `new Array('3').length` -> `1`; `'1' === 1` -> `false`. Plan search: `grep -rn "Number(\|parseInt\|Number " plans/greet-options/` -> no matches. Spec line: `feature-greet-options-spec.md:180` `times:  1,        // integer, 1 to 5` and `:258` "The `times` value must be a JSON number that is an integer from 1 to 5 (REQ-068)". Differences entry: `feature-greet-options-tasks.md:223`.
- Fix: convert in `parseOptions` so the flag path yields the same type as the config path, for example keep the validated digit string and store `Number(value)` for `--times`, and assert the number in the unit test (`{ name: 'Ada', times: 3, lang: 'es', format: 'json', shout: true }`). If the string is deliberate, add a task that owns the conversion (in `mergeOptions`) and a test that pins it, and correct the Differences entry to name that task rather than a layer that does not exist.

### F02: `parseOptions` returns `times` as a string while `DEFAULT_OPTIONS.times` and the config path return a number, so the merged option record has two types for one key
- Severity / confidence: P2 / High
- Location: `src/greet.js:82` (`parseOptions`), `src/greet.js:1` (`DEFAULT_OPTIONS`).
- Lens: data-shape
- Failure: `mergeOptions({ times: 3 }, {})` yields `times: 3` (number) and `mergeOptions({}, { times: '3' })` yields `times: '3'` (string). The merged record is the shape every later layer consumes (spec §3), so a consumer that compares with `===` against a number, or that builds an array with `new Array`, behaves differently depending on where the value came from. This is the mechanism behind F01 and is recorded separately because the fix for F01 (converting at the parse boundary) also removes it.
- Evidence: probe on the staged code: `parseOptions(['--times','3'])` -> `{"times":"3"}` against `DEFAULT_OPTIONS` -> `{"times":1}`; `new Array('3').length` -> `1` against `new Array(3).length` -> `3`.
- Fix: covered by F01.

### F03: The two validators use two different mechanisms and one of them sits far from the others
- Severity / confidence: P2 / Medium
- Location: `src/greet.js:14` (`OPTION_SPECS`).
- Lens: design
- Failure: `OPTION_SPECS` expresses "allowed values" in two shapes: an array (`values: ['en', 'es', 'fr']`) for `--lang` and `--format`, and a `validate` function for `--name` and `--times`. A reader adding a sixth flag has to guess which shape to use, and `parseOptions` runs both checks in two separate blocks (`spec.values` then `spec.validate`) with two different reason templates (`invalid value for --flag: v` versus the function's own string). The two reason templates already differ in one respect that matters: the array path emits `invalid value for --lang: ` (with a trailing space) for an empty value, while the function path emits `empty value for --name` for an empty name. Both are usage errors, so no output is wrong, but the message shapes are not uniform.
- Evidence: `src/greet.js:14-20` (the two shapes), `src/greet.js:72-80` (the two check blocks). Probe: `parseOptions(['--lang',''])` -> `"invalid value for --lang: "`, `parseOptions(['--name',''])` -> `"empty value for --name"`.
- Fix: give every spec entry the same shape, for example `values` for the enumerated flags and `validate` for `--name` and `--times`, but route both through one helper that builds the reason, so a new flag has one obvious place to go. The plan's RISK-004/GUD-001 already name `OPTION_SPECS` as the single place the option list lives, so this is where to make the shape uniform.

### F04: `validateName` is declared between `greet` and `parseOptions`, away from the other validator
- Severity / confidence: P3 / High
- Location: `src/greet.js:34` (`validateName`).
- Lens: design
- Failure: `validateTimes` sits at `src/greet.js:6` next to the comment that explains the digit-string rule, and `validateName` sits at `src/greet.js:34` below `greet`, with no comment. The two validators that `OPTION_SPECS` references are split across the file.
- Evidence: `src/greet.js:5-11` and `src/greet.js:34-39`.
- Fix: move `validateName` up next to `validateTimes` (both are hoisted function declarations, so the move is safe).

### Tests
The 13 new tests are real red-then-green: at the base commit with only the new test file copied in, all 13 fail (`# pass 3 # fail 13`); with the change all 16 pass. Six named mutations, one per guarded behaviour, each turned the suite red (see Guards).

Two gaps worth naming, neither of them a wrong-output defect:
- Nothing pins the *type* of the returned `times`. The happy-path test asserts `times: '3'`, so it locks in the string that F01 is about. A test asserting `times: 3` would have caught the divergence from the spec's option record.
- The empty `--lang` and `--format` values are usage errors (REQ-040) but are not covered by a test, so their reason text (`invalid value for --lang: `, with a trailing space) is unpinned. The spec's §4.3 table pins the `de` and `xml` cases only, so this is not a spec gap, but a trailing space in a message is easy to regress.

### Open questions
Q01: Should `parseOptions` return `times` as a number, or is the string the agreed contract for the whole feature? The spec's option record (§3) and REQ-068 say number; the plan never says. If the string is intended, the plan needs a task that owns the conversion. Blocking: yes
Q02: Is `mergeOptions` (TASK-302) the intended place for the count conversion, and does its task text need to say so? As written it says only "applies the config values and then the flag values". Blocking: no

### Set aside
- The plan-wide Files-column de-annotation (all units' Files cells) and the new `plans/greet-options/reports/tasks/fix-scope.md`: a staging-tool fix, not unit-1 behaviour. Verified that no spec requirement, task Red/Green text or tick for units 2 to 7 changed; only the Files cell lost its parenthetical, the detail moved into a `**Files note:**` in the task text, and the two unit-1 tasks got their `[x]` and date. `stage-unit.sh plans/greet-options 1` now succeeds, and `check-plan.sh plans/greet-options` reports OK.
- The Decisions-row edit from `/^[0-9]+$/` to `/^[1-9][0-9]*$/`: a legitimate correction, not a weakening. `/^[0-9]+$/` matches `03`, so the old rule could not implement the spec's REQ-032 and Q-1, which require `03` to be a usage error. Mutation 4 below confirms the corrected rule is what the test guards.
- `parseOptions(['--nmae=Ada'])` -> `invalid flag syntax: --nmae=Ada` rather than `unknown flag: --nmae`: the `=` check runs before the unknown-flag check. REQ-077 pins `invalid flag syntax: <argument>` for the `--flag=value` form and does not restrict it to known flags, so this matches the spec.
- `parseOptions(['--name', '--'])` -> `missing value for --name`: the value that starts with `-` is never consumed (REQ-074, Q-2), and `--` starts with `-`. Correct.
- Prototype-pollution reachability through `parsed[arg.slice(2)] = value`: the key is always one of `name`, `shout`, `times`, `lang`, `format`, because `OPTION_SPECS[arg]` must match first. `--__proto__`, `--constructor`, `--toString` and `--hasOwnProperty` all give `unknown flag`. Not reachable.
- The `=` check rejecting `--name=` and `--=x` as `invalid flag syntax`: consistent with REQ-077. Not a defect.
- The `unexpected argument: ` reason for an empty-string argument (`parseOptions([''])`): no spec line covers it and no output is wrong. Noted, not reported.

### Checked and fine
- The `--times` validation: `/^[1-9][0-9]*$/` plus `Number(value) > 5` rejects `0`, `6`, `abc`, `1.5`, `03`, `+2`, `00003` and `007`, and accepts `1` to `5`. Matches REQ-032 and Q-1.
- The value-that-starts-with-a-dash rule: `--name -x` and `--name --shout` both give `missing value for --name`, and the dash value is never consumed. Matches REQ-074 and Q-2.
- The missing-value rule is uniform: `--name`, `--times`, `--lang` and `--format` all give `missing value for <flag>` with no flag special-cased. Matches TASK-102.
- Last-occurrence-wins for values and `shout` staying `true` when set twice. Matches REQ-075 and REQ-076.
- The `--` marker gives `invalid argument: --` and the `--flag=value` form gives `invalid flag syntax: <argument>`. Matches REQ-077 and REQ-078.
- The `--lang` and `--format` allowed sets are exact and case-sensitive: `de`, `ES` and `xml` are rejected. Matches REQ-040 and REQ-041.
- `parseOptions([])` returns `{}` with no default keys, and `parseOptions(['--shout'])` returns `{ shout: true }`. Matches TEST-001.
- The exports are exactly the six the unit asks for: `greet`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, `OPTION_SPECS`, `parseOptions`, `UsageError`, and `greet('Ada')` still returns `Hello, Ada`. The existing `greet` export and its `module.exports` line still work, as CON-003 requires.
- `DEFAULT_OPTIONS` is `{ name: 'world', shout: false, times: 1, lang: 'en', format: 'text' }` and `GREETING_WORDS` is `{ en: 'Hello', es: 'Hola', fr: 'Bonjour' }`. Matches REQ-002 and REQ-003.
- `UsageError` is an `Error` subclass with a `reason` property and a short lowercase reason, and `err instanceof UsageError` holds. Matches GUD-004, GUD-005 and the task's own requirement.
- Gate integrity: no test was deleted, skipped or relaxed; the only removed line in `test/greet.test.js` is the old destructuring import, which was widened to `const { greet, parseOptions, UsageError }`. No lint, type or CI config was touched, no threshold was lowered.
- Scope: `src/greet.js` and `test/greet.test.js` are the Files column of TASK-101 and TASK-102. The other two staged files are under the plan directory, which `stage-unit.sh` owns, and the tasks-file change adds no behaviour beyond the two tasks and the two logged Differences.
- `npm test` is green at the staged state: 16 tests, 16 pass, 0 fail.

### Guards
Six named mutations, one per guarded behaviour, each run in a scratch copy of the working tree (`${TMPDIR:-/tmp}/mut-unit1`) with `TEST_CMD="npm test"`. All six turned the suite red.

- mutation: `parseOptions` returns `{ ...DEFAULT_OPTIONS, ...parsed }` (absent keys get a default) -> `npm test` red (2 failed: "returns only the keys the user gave", "lets the last occurrence of a flag win")
- mutation: drop `'--format'` from `OPTION_SPECS` (a flag stops being recognised) -> `npm test` red (3 failed: "recognises every option", "reports a missing value for every value-taking flag", "rejects an unsupported format")
- mutation: drop the `value.startsWith('-')` check (a dash value gets consumed) -> `npm test` red (1 failed: "never consumes a value that starts with a dash")
- mutation: revert the `--times` digit rule to `/^[0-9]+$/` (the Decisions-row rule that was corrected) -> `npm test` red (1 failed: "rejects a --times value outside 1 to 5 or that is not a plain digit string")
- mutation: drop the `Number(value) > 5` range check (the range half of REQ-032) -> `npm test` red (1 failed: "rejects a --times value outside 1 to 5 or that is not a plain digit string")
- mutation: keep the first occurrence of a flag instead of the last -> `npm test` red (1 failed: "lets the last occurrence of a flag win")

Base check: with only `test/greet.test.js` copied onto the base tree (`scratch-copy.sh <dir> --base 48ffa1e`), 13 of the 13 new tests fail and the 3 pre-existing tests pass, so the new tests genuinely gate the new code.

Scope: clean

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 2
scope: clean
mutations: 6 run, 0 still green
top:
- F01 [P1] src/greet.js:82 `times` stays a string and no task in the plan converts it; the Differences entry names a layer that does not exist
- F02 [P2] src/greet.js:82 the merged option record carries `times` as a number from the config and a string from the flags
- F03 [P2] src/greet.js:14 OPTION_SPECS mixes an allowed-values array with a validate function, with two reason templates
report: plans/greet-options/reports/phase-1/review-1.md
