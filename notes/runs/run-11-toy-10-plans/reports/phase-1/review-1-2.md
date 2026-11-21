# Review: plans/greet-options unit 1 (TASK-101, TASK-102) - recheck

Date: 2026-11-20
Base: 48ffa1ead95959418a41241775823795fb225324
Recheck of: plans/greet-options/reports/phase-1/review-1.md

Findings: P0 0 - P1 0 - P2 0 - P3 0    Partitions reviewed: 5

### Index
No open findings. The previous review's single P1 (F01) is fixed and the fix is guarded by a test.

### F01 (previous): The `times` value stays a string and no task in the plan converts it - FIXED
- Severity / confidence: was P1 / High - now fixed / High
- Location: `src/greet.js:13-14` (`parseTimes`), `src/greet.js:20` (`OPTION_SPECS['--times'].parse`), `src/greet.js:85` (`parsed[...] = spec.parse ? spec.parse(value) : value`).
- Status: **fixed**. The fix converts the validated digit string to a number at the parse boundary.
- Evidence:
  - `parseOptions(['--times', '3'])` -> `{"times":3}`, `typeof times === 'number'` (probe on the staged code).
  - `parseOptions(['--times','3','--times','4'])` -> `{"times":4}` (last-wins still holds after the conversion).
  - The conversion runs after `spec.validate`, so `validateTimes` still sees the raw digit string and `03` / `+2` / `6` are still rejected before any conversion.
  - The type now matches `DEFAULT_OPTIONS.times` (number `1`) and the config path's JSON number (REQ-068), so the merged record (spec §3) holds one type per key.
- Test added: `test/greet.test.js:44-48` `parseOptions returns the count as a number, like the config path does` asserts both `typeof times === 'number'` and `times === 3`. The happy-path test at `test/greet.test.js:37-42` was updated from `times: '3'` to `times: 3`.
- Plan side: the Decisions table gains the row "What type the count carries" (`feature-greet-options-tasks.md:41`), the TASK-101 Red text gains the "count being a number rather than the string the user typed" clause (`feature-greet-options-tasks.md:71`), and the Differences section logs the divergence from the literal spec §4.1 wording (`feature-greet-options-tasks.md:225`). The change is authorised, not scope drift: the spec's resolved option record (§3, `times: 1, // integer, 1 to 5`) and REQ-068 require the number, and the spec's §4.1 `parseOptions` bullet list never states that the flag path keeps the string.
- Mutation: revert `parseTimes` to `(value) => value` -> `npm test` red (2 failed: "parseOptions recognises every option", "parseOptions returns the count as a number, like the config path does").
- Mutation: drop the `spec.parse` application (`parsed[arg.slice(2)] = value`) -> `npm test` red (2 failed, the same two tests).

### Tests
The 14 new tests are still real red-then-green. With only the new `test/greet.test.js` copied onto the base tree (`scratch-copy.sh <dir> --base 48ffa1e`), 14 of the 14 new tests fail and the 3 pre-existing tests pass (`# pass 3 # fail 14`), so the new tests genuinely gate the new code. With the change: 17 tests, 17 pass, 0 fail.

The gap the previous review named ("nothing pins the *type* of the returned `times`") is now closed by the dedicated test at `test/greet.test.js:44`.

### Open questions
None. The previous review's Q01 ("Should `parseOptions` return `times` as a number?") is answered by the plan's new Decisions row and the Differences entry, and the code now matches.

### Set aside
- The plan-wide Files-column de-annotation and the new `plans/greet-options/reports/tasks/fix-scope.md`: a staging-tool fix, not unit-1 behaviour. Verified by diffing every `| TASK-` row in the base against the staged version: for units 2 to 7 the only change is the Files cell losing its parenthetical, the detail moving into a `**Files note:**` in the task text, and the Spec column and the Red/Green text staying byte-identical once the `**Files note:**` is stripped. `stage-unit.sh plans/greet-options 1` now exits 0 ("staged 7 path(s) for unit 1") and `check-plan.sh plans/greet-options` reports OK.
- The Decisions-row edit from `/^[0-9]+$/` to `/^[1-9][0-9]*$/`: a legitimate correction, not a weakening. `/^[0-9]+$/` matches `03`, so the old rule could not implement REQ-032 and Q-1. Mutation 6 confirms the corrected rule is what the test guards.
- The previous review's F03 (`OPTION_SPECS` mixes an allowed-values array with a `validate` function) is unchanged in substance and has grown a third shape (`parse`). It stays a P2 and is not re-reported here, per the recheck rule that no new P2s are reported. Noted for the author: a sixth flag now has three possible mechanisms to choose from (`values`, `validate`, `parse`).
- The previous review's F04 (`validateName` sits away from `validateTimes`): not addressed, still P3. Not re-reported per the recheck rule.
- `parseOptions(['--nmae=Ada'])` -> `invalid flag syntax: --nmae=Ada` rather than `unknown flag: --nmae`: the `=` check runs before the unknown-flag check. REQ-077 pins `invalid flag syntax: <argument>` for the `--flag=value` form and does not restrict it to known flags.
- `parseOptions(['--name', '--'])` -> `missing value for --name`: a value that starts with `-` is never consumed (REQ-074, Q-2).
- Prototype-pollution reachability through `OPTION_SPECS[arg]` and `parsed[arg.slice(2)] = value`: the key is always one of `name`, `shout`, `times`, `lang`, `format`. `--__proto__`, `--constructor`, `--toString`, `--hasOwnProperty` and `--valueOf` all give `unknown flag` (probe).
- The empty `--lang` and `--format` values are usage errors (REQ-040) with the reason `invalid value for --lang: ` (trailing space), unpinned by any test. The spec's §4.3 table pins only the `de` and `xml` cases, so this is not a spec gap. Unchanged from the previous review and not re-reported.

### Checked and fine
- The `--times` validation: `/^[1-9][0-9]*$/` plus `Number(value) > 5` rejects `0`, `6`, `abc`, `1.5`, `03`, `+2` and accepts `1` to `5`. Matches REQ-032 and Q-1. The range check runs on the digit string, and the conversion happens only after validation, so no invalid value can be converted into a valid-looking one.
- The value-that-starts-with-a-dash rule: `--name -x` and `--name --shout` both give `missing value for --name`, and the dash value is never consumed. Matches REQ-074 and Q-2.
- The missing-value rule is uniform: `--name`, `--times`, `--lang` and `--format` all give `missing value for <flag>` with no flag special-cased. Matches TASK-102.
- Last-occurrence-wins for values and `shout` staying `true` when set twice, including after the `parse` hook. Matches REQ-075 and REQ-076.
- The `--` marker gives `invalid argument: --` and the `--flag=value` form gives `invalid flag syntax: <argument>`. Matches REQ-077 and REQ-078.
- The `--lang` and `--format` allowed sets are exact and case-sensitive: `de`, `ES` and `xml` are rejected. Matches REQ-040 and REQ-041.
- `parseOptions([])` returns `{}` with no default keys, and `parseOptions(['--shout'])` returns `{ shout: true }`. Matches TEST-001.
- The exports are exactly the six the unit asks for: `greet`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, `OPTION_SPECS`, `parseOptions`, `UsageError`, and `greet('Ada')` still returns `Hello, Ada`. The existing `greet` export and its `module.exports` line still work, as CON-003 requires.
- `DEFAULT_OPTIONS` is `{ name: 'world', shout: false, times: 1, lang: 'en', format: 'text' }` and `GREETING_WORDS` is `{ en: 'Hello', es: 'Hola', fr: 'Bonjour' }`. Matches REQ-002 and REQ-003.
- `UsageError` is an `Error` subclass with a `reason` property and a short lowercase reason, and `err instanceof UsageError` holds. Matches GUD-004, GUD-005 and the task's own requirement.
- Gate integrity: no test was deleted, skipped or relaxed; the only removed line in `test/greet.test.js` is the old destructuring import, which was widened to `const { greet, parseOptions, UsageError }`. No lint, type or CI config was touched, no threshold was lowered.
- Scope: `src/greet.js` and `test/greet.test.js` are the Files column of TASK-101 and TASK-102. The other staged files are under the plan directory, which `stage-unit.sh` owns. Only TASK-101 and TASK-102 are ticked, and only TASK-101's Red text changed (the count-as-a-number clause that the F01 fix needs).

### Guards
Eight named mutations, one per guarded behaviour, each run in a scratch copy of the working tree (`${TMPDIR:-/tmp}/mut-unit1b`) with `TEST_CMD="npm test"`. All eight turned the suite red.

- mutation: revert `parseTimes` to `(value) => value` (the F01 fix undone) -> `npm test` red (2 failed)
- mutation: drop the `spec.parse` application, `parsed[arg.slice(2)] = value` -> `npm test` red (2 failed)
- mutation: `parseOptions` returns `{ ...DEFAULT_OPTIONS, ...parsed }` (absent keys get a default) -> `npm test` red (2 failed)
- mutation: drop `'--format'` from `OPTION_SPECS` (a flag stops being recognised) -> `npm test` red (3 failed)
- mutation: drop the `value.startsWith('-')` check (a dash value gets consumed) -> `npm test` red (1 failed)
- mutation: revert the `--times` digit rule to `/^[0-9]+$/` -> `npm test` red (1 failed)
- mutation: drop the `Number(value) > 5` range check (the range half of REQ-032) -> `npm test` red (1 failed)
- mutation: keep the first occurrence of a flag instead of the last -> `npm test` red (1 failed)

Base check: with only `test/greet.test.js` copied onto the base tree (`scratch-copy.sh <dir> --base 48ffa1e`), 14 of the 14 new tests fail and the 3 pre-existing tests pass, so the new tests genuinely gate the new code.

Scope: clean

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
scope: clean
mutations: 8 run, 0 still green
top:
report: plans/greet-options/reports/phase-1/review-1-2.md
