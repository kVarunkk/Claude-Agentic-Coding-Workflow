# spec/review-4.md

target: plans/greet-options/feature-greet-options-spec.md
mode: spec (recheck)
date: 2026-11-19
previous: plans/greet-options/reports/spec/review-3.md
brief: plans/greet-options/feature-greet-options-brief.md (status: agreed, 16 decisions)

## What I read

- `plans/greet-options/feature-greet-options-spec.md` (full, 394 lines)
- `plans/greet-options/reports/spec/review-3.md` (full, the previous review)
- `plans/greet-options/reports/spec/changes.md` (the fix request that produced this round)
- `plans/greet-options/feature-greet-options-brief.md` (full, 84 lines)
- `plans/greet-options/decisions.tsv`
- `bin/greet.js`, `src/greet.js`, `test/greet.test.js`, `package.json`, `scripts/seed-red.sh`

## What changed since review-3

The fix round was substantial. The spec grew from 360 to 394 lines and gained:
- `UsageError` as a named error type (spec:197-208) and a `USAGE` constant (spec:210-214),
  both exported from `src/options.js` (spec:188).
- Section 4 rewritten into 4.1 `src/options.js`, 4.2 `src/config.js`, 4.3 `bin/greet.js`,
  4.4 API contracts, with a process contract table (spec:285-296).
- Section 3 "Who reads what" now names the reader of every exported constant (spec:173).
- `RISK-005` (spec:380), `TEST-027` (spec:370), `TEST-028` (spec:371), `TEST-029` (spec:372).
- Section 8 now names `scripts/seed-red.sh` and the seeded trimming test (spec:336).
- `last_updated` bumped to 2026-11-19, `version` 0.3, `status: Draft`.

The fix request (`changes.md`) asked for the F07 to F16 P2 fixes plus the three settled
questions. All of it landed.

## Previous findings (from review-3)

F07 [P2] spec:93 GUD-002 said parsing, config reading and rendering live in separate modules,
but section 4.1 put them all in `src/options.js`. **fixed.** GUD-002 (spec:93) now reads "The
option parsing, the merge, the greeting resolution and the rendering live in one module,
`src/options.js`, and the config file reading lives in a second module, `src/config.js`", which
is exactly the split in sections 4.1 and 4.2.

F08 [P2] spec:201 the "(process.argv.slice(2))" parenthetical read as "parseArgs does the
slicing". **fixed.** spec:217 says "`bin/greet.js` does the slicing (`process.argv.slice(2)`)
and hands the result to `parseArgs`; `parseArgs` never touches `process.argv` itself", and
spec:269 repeats it in section 4.3.

F09 [P2] spec:302 section 8 never mentioned `scripts/seed-red.sh` or the seeded test it
creates. **fixed.** spec:336 now has a "Not part of this feature" block naming the script, the
seeded file, the contradiction with REQ-017 and D-16, and the instruction that "the
implementation must not add trimming to make it pass, and `npm test` is expected to fail on that
seeded file while the feature is built". spec:342 repeats it in section 9. This matches what
`scripts/seed-red.sh` (lines 5-13) actually writes.

F10 [P2] spec:50 REQ-020/REQ-021 counted lines while REQ-024 added lines of its own. **fixed.**
REQ-024 (spec:54) now says "This is the only exception to the line-count rules in REQ-020 and
REQ-021".

F11 [P2] spec:207 D-11 (no short flags) was never cited. **fixed.** spec:223 now reads "There
are no short flags: `-n`, `-h` and every other single-dash argument are unknown arguments and
usage errors ... (D-11, out of scope)", and spec:222 states the other half, that a value
starting with a single `-` is an ordinary value.

F12 [P2] spec:40 the spec never said how a `--times` value is read. **fixed.** REQ-011
(spec:40) names the `^[0-9]+$` pattern and lists the rejected forms; spec:227 gives the same
rule as "the value string must match `^[0-9]+$` exactly, and it is then converted with
`Number`". The command-line path is now as precise as the config path (spec:178).

F13 [P2] spec:209 the usage-error mechanism was unnamed, so REQ-042's no-stack-trace rule was
unguaranteed. **fixed.** spec:197-208 define `UsageError`, spec:208 says "Every usage error is
raised as a `UsageError`. `bin/greet.js` catches `UsageError` and nothing else, so REQ-042's
no-stack-trace rule is guaranteed", spec:270 repeats it in section 4.3, and spec:340 adds the
unit-level guard ("The unit tests assert that `parseArgs` throws the `UsageError` type, not a
plain `Error`").

F14 [P2] spec:64 a whitespace-only config `name` was undecided. **fixed.** REQ-034 (spec:62)
names it, spec:175 names it, spec:234 names it ("A name of only whitespace (for example
`"   "`) is invalid and falls back to the default `world`, the same as an empty name (D-12)"),
and TEST-005 (spec:348) names it as a tested case.

F15 [P2] spec:58 a config-set `shout: true` could not be turned off from the command line.
**fixed.** REQ-031 (spec:59) states it as the accepted consequence, RISK-005 (spec:380) states
it plainly, and TEST-029 (spec:372) is a route test for it.

F16 [P2] spec:139 `FORMATS` was exported with no stated reader. **fixed.** spec:173 now says
"`FORMATS` is read by `parseArgs` to validate the `--format` value and by `mergeSettings` to
validate the config `format` value". The same line names the reader of `DEFAULTS`, `LANGS`,
`TIMES_MIN`, `TIMES_MAX` and `USAGE`.

All ten carried P2 findings are fixed. None is open.

## New P0/P1 problems introduced by the fix round

The fix round added a lot of specification, and the additions are internally consistent. I found
no P0. The three P1s below are all in the same class: the fix round specified a config-side rule
precisely, but did not add a TEST id for it, so the rule has no test that will check it. The
spec's own Testing section (spec:338-372) is the contract the tasks file is derived from, and
`checking-spec-conformance` grades each REQ id as met, untested or partial against those tests.
A REQ clause with no TEST id will be graded untested whatever the code does.

F17 [P1] spec:62 REQ-034's per-key invalidity rules for `shout` and for `lang`/`format` have no
TEST id. Fix: add the invalid-`shout` and invalid-`lang`/`format` config cases to TEST-005
(spec:348), or add a new unit test id naming them.

The rule is stated three times and tested zero times:
- spec:62 (REQ-034) lists "a `shout` that is not a boolean" and "a `lang` or `format` whose
  trimmed, lower-cased value is not one of the allowed values".
- spec:176 says "The strings `"true"` and `"false"` are not accepted; a non-boolean value is
  ignored and the default `false` applies."
- spec:235 and spec:237 restate both rules for `mergeSettings`.

The TEST ids that touch the config file are TEST-005 (spec:348, an invalid config `name`),
TEST-007 (spec:350, `readConfig`), TEST-018 (spec:361, an invalid config `times` and an unknown
key), TEST-019 (spec:362, config `name` of `""` and of `"  Ada  "`) and TEST-029 (spec:372, a
*valid* config `shout: true`). None of them exercises an invalid config `shout` or an invalid
config `lang` or `format`. An implementer that read the config `shout` as truthy for the string
`"true"`, or that accepted a config `lang` of `"de"`, would pass every listed test and fail
REQ-034. The same happens if the config `lang`/`format` validation is dropped entirely, since
no test reaches it.

F18 [P1] spec:177 the config-side case-insensitive and trimmed matching, which is the whole
point of Q-2, has no TEST id. Fix: add a config `lang` or `format` case-variant to TEST-005 or a
new route test.

Q-2 (spec:389) was settled at the spec gate and is binding: "The command-line `--lang` and
`--format` values stay case-sensitive ... The config file stays case-insensitive and trimmed.
The two sources differ on purpose." spec:177 states the config side ("`lang` and `format` in
the config file are matched case-insensitively after trimming the value, so `"ES"` is read as
`es`"), and spec:237 repeats it for `mergeSettings`.

The only test that touches a case variant is TEST-003 (spec:346), and it pins the *command-line*
side: "an unsupported `--lang` (including the case-variant `ES`)" and "an unsupported `--format`
(including the case-variant `JSON`)". No test writes a config file with `"lang": "ES"` or
`"format": " JSON "`. So the asymmetry that Q-2 exists to settle has no test on its config half:
an implementation that matched the config values case-sensitively, exactly like the command
line, would pass every listed test. That is the single most likely wrong turn here, because the
command-line rule is stated twice as loudly and is the one that is tested.

F19 [P1] spec:61 REQ-033's "or is not a JSON object" clause has no TEST id, and its failure
mode is a crash. Fix: add a non-object config case (an array, or `null`) to TEST-007 (spec:350).

REQ-033 (spec:61) has two disjuncts: "When `greet.config.json` is not valid JSON, or is not a
JSON object, then the CLI ignores it, uses the built-in defaults and exits 0 (D-04)." The
second disjunct is a real rule with its own line in section 4.2: spec:263 "When the parsed value
is not a plain object (an array, a string, a number, `null`), returns `{}`."

TEST-007 (spec:350) covers three cases: "returns `{}` when the file is missing, returns `{}` for
malformed JSON and returns the parsed object for a valid file". A file holding `[1, 2]` or
`"hello"` or `42` or `null` is *well-formed* JSON, so it is not "malformed JSON", and it is not
"a valid file" in the sense of a config object either. No listed test covers it.

The `null` case is the one that hurts. If `readConfig` returned the parsed `null` as-is, then
`mergeSettings` reading `config.name` throws a TypeError, the CLI crashes, and the run exits
non-zero. That breaks REQ-033 ("exits 0"), SEC-004 ("the CLI still exits 0") and the "a stale
config should not stop a greeting" rule in spec:304, and it produces a stack trace on stderr,
which is exactly what REQ-042 forbids. spec:263 states the guard, but with no test the guard
can be dropped and nothing fails.

## Not findings

- The command-line `--lang ES` being a usage error while the config file accepts `"ES"` is
  authorised by the brief's "Left to the spec" and is settled by Q-2. The asymmetry is
  deliberate and is now stated in REQ-013, REQ-014, spec:177 and spec:389.
- The empty `--name` on the command line being a usage error while an empty config `name`
  falls back to the default is deliberate: D-05 against D-12.
- REQ-006 names the empty equals form `--name=`, and TEST-003 says "an empty name" without
  pinning the form. TEST-001 ("both forms give the same parsed value") and TEST-026 (the
  equals form with a non-empty value) narrow it, but do not close it outright. Not raised as a
  finding, per the recheck rule on new P2s.
- The spec contains no placeholders, no TODO and no TBD. The `<name>` and `<greeting>` strings
  in the output descriptions are format placeholders inside prose, not unresolved slots.
- The spec contains no em dashes.
- The `USAGE` string at spec:213, spec:278 and in REQ-041 (spec:70) is character-for-character
  the string agreed in D-08, and section 4.4's contract table (spec:285-296) agrees with it.
- The JSON shape is consistent everywhere: spec:246 builds it as
  `'{"greeting": ' + JSON.stringify(repeatedGreeting) + '}'` with one space after the colon,
  REQ-022 (spec:52), the contract table (spec:290, 293) and TEST-010 (spec:353) all show
  `{"greeting": "..."}`.
- `parseArgs` returning `shout?: true` (spec:147) is what makes RISK-005 and REQ-031 true, and
  the two agree.
- Every brief decision D-01 to D-16 is cited in the spec, every brief scope line is honoured and
  every brief out-of-scope line is honoured: no trimming (REQ-017, D-16, and the seeded test
  named at spec:336), no short flags (spec:223, D-11), no `--` separator and no positionals
  (spec:225, D-10), the config file only from the working directory (SEC-001, D-07, ALT-003),
  no parent-directory search (ALT-003), only `greet.config.json` (spec:261), and nothing beyond
  the five named flags.
- The three existing tests in `test/greet.test.js` keep passing under the new behaviour:
  `greet('Ada')` is `Hello, Ada` (untouched by this feature), `run()` is `Hello, world\n` when
  no `greet.config.json` is present (REQ-001 with its precondition), and `run('--name', 'Ada')`
  is `Hello, Ada\n` (REQ-002). The spec correctly lists that file as unchanged (spec:332).
- `package.json` today has no `dependencies` and no `devDependencies`, and the spec keeps it
  unchanged (CON-002, spec:333). `npm test` already runs `node --test` (CON-003).
- Section 4.4's contract table agrees with the requirement text on every row I checked,
  including `greet Ada` (a bare positional, REQ-007) and `greet --times 9` (REQ-012).

## Note for the writer

The three P1s share one shape. The fix round made the config rules precise, which was the
point, but each precise rule needs a TEST id beside it or the tasks file will carry no unit for
it. The cheapest fix is to extend the existing config test ids rather than add new ones:
TEST-005 (spec:348) is the natural home for the invalid `shout` and invalid `lang`/`format`
cases (F17), a config `"lang": "ES"` case belongs next to it (F18), and TEST-007 (spec:350) is
the natural home for a non-object config file (F19).

SUMMARY
verdict: fail
p0: 0
p1: 3
p2: 0
top:
- F17 [P1] spec:62 REQ-034's per-key invalidity rules for `shout` and for `lang`/`format` have no TEST id, so an implementation that reads the config `shout` as truthy for `"true"`, or drops the config `lang`/`format` validation, passes every listed test and still fails REQ-034.
- F18 [P1] spec:177 the config-side case-insensitive and trimmed matching, the whole point of the settled Q-2, has no TEST id; only the command-line side is tested (TEST-003), so matching the config values case-sensitively would pass every listed test.
- F19 [P1] spec:61 REQ-033's "or is not a JSON object" clause has no TEST id, and its failure mode is a crash: a config file holding `null` that reaches `mergeSettings` throws a TypeError, breaking REQ-033, SEC-004 and REQ-042's no-stack-trace rule.
report: plans/greet-options/reports/spec/review-4.md
