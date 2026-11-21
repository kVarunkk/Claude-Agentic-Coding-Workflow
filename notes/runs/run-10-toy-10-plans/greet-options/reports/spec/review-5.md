# spec/review-5.md

target: plans/greet-options/feature-greet-options-spec.md
mode: spec (recheck)
date: 2026-11-19
previous: plans/greet-options/reports/spec/review-4.md
brief: plans/greet-options/feature-greet-options-brief.md (status: agreed, 16 decisions)

## What I read

- `plans/greet-options/feature-greet-options-spec.md` (full, 396 lines)
- `plans/greet-options/reports/spec/review-4.md` (full, the previous review)
- `plans/greet-options/feature-greet-options-brief.md` (full, 84 lines)
- `plans/greet-options/reports/spec/changes.md`, `plans/greet-options/reports/spec/review-3.md`
- `plans/greet-options/decisions.tsv`
- `bin/greet.js`, `src/greet.js`, `test/greet.test.js`, `package.json`, `scripts/seed-red.sh`

## What changed since review-4

The spec grew from 394 to 396 lines. The requirement text is byte-identical: every line
reference quoted in review-4 still resolves to the same text (REQ-034 at spec:62, the config
`lang`/`format` rule at spec:177, the `readConfig` guard at spec:263, and so on). The fix round
touched only the Testing section:

- **TEST-005** (spec:348) expanded. It now names the invalid config `shout` (including the
  strings `"true"` and `"false"`) and the invalid config `lang`/`format` (`"de"`, `"xml"`).
- **TEST-007** (spec:350) expanded. It now names a config file holding valid JSON that is not a
  JSON object (`[1, 2]`, `"hello"`, `42`, `null`).
- **TEST-030** (spec:373) added: the config-side case-insensitive and trimmed matching.
- **TEST-031** (spec:374) added: a route test for a config file whose content is `null`.

## Previous findings (from review-4)

F17 [P1] spec:62 REQ-034's per-key invalidity rules for `shout` and for `lang`/`format` have no
TEST id. **open** on one residual branch; the rest is fixed.

Fixed:
- The invalid config `shout` rule is now tested. TEST-005 (spec:348) reads "a config `shout` that
  is not a boolean (including the strings `"true"` and `"false"`, which fall back to the default
  `false`)". This matches REQ-034 (spec:62), spec:176 and spec:235.
- The invalid config `lang`/`format` rule is now tested. TEST-005 (spec:348) reads "a config `lang`
  or `format` whose trimmed, lower-cased value is not one of the allowed values, such as `"de"` for
  `lang` or `"xml"` for `format` (REQ-034)". This matches REQ-034, spec:177 and spec:237.

Still open (the residual of the same REQ-034 clause):
- REQ-034 (spec:62) lists five invalid-value cases. Four of them now have a TEST id. The first
  one, "a `name` that is not a non-empty string", still has none. TEST-005 names "a config `name`
  of only whitespace"; TEST-019 (spec:362) names `""` and `"  Ada  "`; TEST-007 (spec:350) covers a
  non-object *file*, not a non-string `name` *inside* an object. No listed test writes a config
  file with `"name": 42`, `"name": null` or `"name": true`.
  An implementation that validates the config `name` with `cfg.name ?? 'world'` and then
  interpolates it, or that coerces it with `String(cfg.name)`, passes every listed test and still
  fails REQ-034, printing `Hello, 42` where the spec requires the built-in default `world`. The
  natural reading of spec:234 ("valid when it is a non-empty string that is not only whitespace")
  is correct, but the conformance check grades REQ-034 clause by clause against the TEST ids, so
  the branch is graded Untested.
  Fix: extend TEST-005 (spec:348) with a non-string config `name` case, for example `"name": 42`,
  falling back to `world`.

F18 [P1] spec:177 the config-side case-insensitive and trimmed matching, the whole point of Q-2,
has no TEST id. **fixed.**

TEST-030 (spec:373) now reads: "`mergeSettings` reads a config `lang` or `format` case-insensitively
after trimming, so a config `"lang": "ES"` resolves to `es` and a config `"format": " JSON "`
resolves to `json`, while a command-line `--lang ES` stays a usage error (REQ-034, Q-2)."

This is exactly the asymmetry Q-2 (spec:391) settles, and it pins the stored value ("resolves to
`es`"), not just the validation, so an implementation that validates but stores the raw
`"ES"` cannot pass. The command-line half is already pinned by TEST-003 (spec:346) and TEST-027
(spec:370). Q-2 now cites TEST-030 at spec:391, so the settled question and its test agree.

F19 [P1] spec:61 REQ-033's "or is not a JSON object" clause has no TEST id, and its failure mode
is a crash. **fixed.**

- The unit seam is covered: TEST-007 (spec:350) now reads "A file holding valid JSON that is not a
  JSON object, such as `[1, 2]`, `"hello"`, `42` or `null`, also returns `{}`, so `mergeSettings`
  never reads a property of a non-object (REQ-033)". This matches spec:263.
- The process seam is covered too, which is stronger than review-4 asked for: TEST-031 (spec:374)
  reads "running `bin/greet.js` in a directory holding a `greet.config.json` whose content is `null`
  prints `Hello, world` on stdout, writes nothing to stderr and exits 0, so a config file that is
  not a JSON object never crashes the run (REQ-033, SEC-004)". This pins the crash mode directly:
  a `readConfig` that returned the parsed `null` as-is would make `mergeSettings` throw a
  TypeError, which is not a `UsageError`, which spec:270 says `bin/greet.js` does not catch, so the
  run would print a stack trace and exit non-zero. TEST-031 fails for that implementation.
  SEC-004 now has a TEST id of its own, which it did not before.

## New P0/P1 problems introduced by the fix round

F20 [P1] spec:237 the config `lang`/`format` validity rule has no type guard, so a non-string
config value crashes the run. Fix: state that the value is valid only when it is a string whose
trimmed, lower-cased form is one of the allowed values, and add a non-string config value to
TEST-005.

This is a direct consequence of the precise rule the fix round introduced. The round made the
config matching exact ("the trimmed, lower-cased value is one of the allowed values", spec:237,
and "matched case-insensitively after trimming the value", spec:177) and added TEST-030 to test
it, but the wording asks for a `.trim()` and a `.toLowerCase()` on the config value without saying
the value must be a string first.

A config file may hold anything (spec:264 says "unknown keys and wrong types are handled in one
place (REQ-034, REQ-035)"; the config shape at spec:153-160 is a description of valid values, not
a constraint on what a file can contain). With `{"lang": 42}` in `greet.config.json`:

- `mergeSettings` applies the spec:237 rule, calling `.trim()` on the number.
- That throws a TypeError. It is not a `UsageError`, and spec:270 says `bin/greet.js` catches
  `UsageError` and nothing else.
- The CLI dies with a stack trace on stderr and a non-zero exit code.

That breaks REQ-033's "uses the built-in defaults and exits 0", SEC-004's "cannot crash the run:
the parse is wrapped so that any failure leaves the built-in defaults in place and the CLI still
exits 0", and REQ-042's "no stack trace". The crash is exactly the failure mode SEC-004 exists to
prevent, and the spec's own design puts the type check in `mergeSettings`, where the guard is
missing for this one key.

The other three keys are guarded, which shows the omission is an oversight rather than a
deliberate choice:
- `name`: spec:234 "valid when it is a non-empty string that is not only whitespace".
- `shout`: spec:235 "valid when it is a boolean".
- `times`: spec:236 and spec:178 "a float, a string, a number outside the range and a missing
  value are all invalid".
- `lang`/`format`: spec:237 has no type condition.

An implementation that writes `String(value).trim().toLowerCase()` is safe by accident, but an
implementation that writes `value.trim().toLowerCase()` crashes, and the spec does not say which
one to write. No TEST id covers it either: TEST-005 (spec:348) names the string cases `"de"` and
`"xml"`, TEST-007 (spec:350) covers a non-object *file*, TEST-030 (spec:373) covers string case
variants.

Fix, smallest change: amend spec:237 to read "`lang` and `format`: valid when the value is a
string whose trimmed, lower-cased form is one of the allowed values (`en`, `es`, `fr` and `text`,
`json`), so `"ES"` is valid and read as `es` (section 3); a value that is not a string is invalid
and falls back to the default." and add a non-string case to TEST-005, for example a config
`"lang": 42` falling back to `en`.

## Not findings

- The `name`-not-a-string residual under F17 is not raised as a new finding. It is the same
  REQ-034 clause and the same TEST-005 line that F17 asked the writer to extend, so it is marked
  open under F17 rather than double-counted as F21.
- The command-line `--lang ES` being a usage error while the config file accepts `"ES"` is
  authorised by the brief's "Left to the spec" and is settled by Q-2 (spec:391). TEST-030 now
  tests both halves of that asymmetry.
- The empty `--name` on the command line being a usage error while an empty config `name` falls
  back to the default is deliberate: D-05 against D-12.
- The spec contains no placeholders, no TODO and no TBD. The `<name>` and `<greeting>` strings in
  the output descriptions are format placeholders inside prose, not unresolved slots.
- The spec contains no em dashes.
- The `USAGE` string at spec:213, spec:278, spec:70 and in the contract table is
  character-for-character the string agreed in D-08.
- The JSON shape is consistent everywhere: spec:246 builds it as
  `'{"greeting": ' + JSON.stringify(repeatedGreeting) + '}'` with one space after the colon, and
  REQ-022 (spec:52), the contract table (spec:290, 293), TEST-010 (spec:353) and TEST-017
  (spec:360) all show `{"greeting": "..."}`.
- Every brief decision D-01 to D-16 is cited in the spec, every brief scope line is honoured and
  every brief out-of-scope line is honoured: no trimming (REQ-017, D-16, and the seeded test named
  at spec:336), no short flags (spec:223, D-11), no `--` separator and no positionals (spec:225,
  D-10), the config file only from the working directory (SEC-001, D-07, ALT-003), no
  parent-directory search (ALT-003), only `greet.config.json` (spec:261), and nothing beyond the
  five named flags.
- The three existing tests in `test/greet.test.js` keep passing under the new behaviour:
  `greet('Ada')` is `Hello, Ada` (untouched by this feature), `run()` is `Hello, world\n` when no
  `greet.config.json` is present (REQ-001 with its precondition), and `run('--name', 'Ada')` is
  `Hello, Ada\n` (REQ-002). The spec correctly lists that file as unchanged (spec:332).
- `package.json` has no `dependencies` and no `devDependencies`, `bin` maps `greet` to `bin/greet.js`
  and `npm test` runs `node --test`, which matches CON-002, CON-003 and CON-004.
- `scripts/seed-red.sh` (lines 5-13) writes exactly the seeded trimming test that spec:336
  describes, so section 8 is accurate.
- TEST-031 does not contradict TEST-007 or spec:263: a config file holding `null` yields `{}` from
  `readConfig`, so `mergeSettings` sees an empty config and returns the built-in defaults, which
  is `Hello, world` and exit 0.

## Note for the writer

Two of the three previous P1s are closed. The one that is still open and the one new P1 are the
same shape: the config-side validity rules need a TEST id for every branch, and every branch needs
a type condition. The cheapest fix for both is the same two edits:

- TEST-005 (spec:348): add a config `name` that is not a string (for example `"name": 42`) and a
  config `lang` that is not a string (for example `"lang": 42`), each falling back to its default.
- spec:237: add the type condition to the `lang`/`format` rule, so a non-string value is invalid
  and falls back to the default rather than throwing.

SUMMARY
verdict: fail
p0: 0
p1: 2
p2: 0
top:
- F20 [P1] spec:237 the config `lang`/`format` validity rule has no type guard, so a config file with `"lang": 42` makes `mergeSettings` call `.trim()` on a number, throw a TypeError that `bin/greet.js` does not catch (spec:270), and crash the run with a stack trace, breaking REQ-033, SEC-004 and REQ-042.
- F17 [P1] spec:62 REQ-034's "a `name` that is not a non-empty string" branch still has no TEST id, so an implementation that interpolates a numeric config `name` passes every listed test and still fails REQ-034.
report: plans/greet-options/reports/spec/review-5.md
