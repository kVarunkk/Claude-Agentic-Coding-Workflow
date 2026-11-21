# spec/review-6.md

target: plans/greet-options/feature-greet-options-spec.md
mode: spec (recheck)
date: 2026-11-19
previous: plans/greet-options/reports/spec/review-5.md
brief: plans/greet-options/feature-greet-options-brief.md (status: agreed, 16 decisions)

## What I read

- `plans/greet-options/feature-greet-options-spec.md` (full, 396 lines)
- `plans/greet-options/reports/spec/review-5.md` (full, the previous review)
- `plans/greet-options/reports/spec/fix-scope.md` (the fix round's scope)
- `plans/greet-options/feature-greet-options-brief.md` (full, 84 lines)
- `plans/greet-options/reports/spec/changes.md`, `plans/greet-options/reports/spec/review-3.md`
- `plans/greet-options/decisions.tsv`
- `bin/greet.js`, `src/greet.js`, `test/greet.test.js`, `package.json`

## What changed since review-5

The spec is still 396 lines. The fix round made exactly the two edits that
`plans/greet-options/reports/spec/fix-scope.md` asked for, and nothing else:

- **spec:177** (section 3 note) now reads: "The value must be a string: a non-string value
  (a number, a boolean, an array, an object, `null`) is invalid and falls back to the default
  `en` or `text`, so a config file holding `{"lang": 42}` never crashes the run."
- **spec:237** (`mergeSettings` per-key rule) now reads: "`lang` and `format`: valid when the value
  is a string AND its trimmed, lower-cased form is one of the allowed values (`en`, `es`, `fr` and
  `text`, `json`), so `"ES"` is valid and read as `es`. A value that is not a string (a number, a
  boolean, an array, an object, `null`) is invalid and falls back to the default, the same as any
  other invalid value for that key (section 3)."
- **spec:348** (TEST-005) now names "a config `name` that is not a string (for example `"name": 42`
  and `"name": true`, which fall back to the default `world`)".

Every other line of the requirement text is unchanged, and every id is stable.

## Previous findings (from review-5)

F17 [P1] spec:62 REQ-034's per-key invalidity rules for `shout` and for `lang`/`format` have no
TEST id, and its "a `name` that is not a non-empty string" branch has none either. **fixed.**

The residual branch review-5 left open is now closed. TEST-005 (spec:348) reads in full:

> `mergeSettings` falls back to the built-in default for an invalid config value and keeps the
> other config values. The invalid values are: a config `name` of only whitespace, a config `name`
> that is not a string (for example `"name": 42` and `"name": true`, which fall back to the default
> `world`), a config `shout` that is not a boolean (including the strings `"true"` and `"false"`,
> which fall back to the default `false`), a config `times` that is not a whole number from 1 to 5,
> a config `lang` or `format` that is not a string, and a config `lang` or `format` whose trimmed,
> lower-cased string value is not one of the allowed values, such as `"de"` for `lang` or `"xml"`
> for `format` (REQ-034). In every one of these cases the other config values still apply.

Checked against REQ-034 (spec:62), which enumerates exactly six invalid-value branches. Each now
has a TEST id:

| REQ-034 branch (spec:62) | TEST id that names it |
|---|---|
| a `name` that is not a non-empty string | TEST-005 (spec:348), `"name": 42` and `"name": true` |
| a `name` that holds only whitespace | TEST-005 (spec:348), "a config `name` of only whitespace" |
| a `shout` that is not a boolean | TEST-005 (spec:348), the strings `"true"` and `"false"` |
| a `times` that is not a whole number in 1 to 5 | TEST-005 (spec:348) |
| a `lang` or `format` that is not a string | TEST-005 (spec:348) |
| a `lang` or `format` whose trimmed, lower-cased value is not allowed | TEST-005 (spec:348), `"de"` and `"xml"` |

No branch is left Untested. The closing sentence "In every one of these cases the other config
values still apply" pins the per-key fallback semantics of REQ-034 ("that single value falls back
to its built-in default and the other config values still apply"), so an implementation that drops
the whole config on the first bad key fails TEST-005.

F20 [P1] spec:237 the config `lang`/`format` validity rule has no type guard, so a non-string
config value crashes the run. **fixed.**

- The `mergeSettings` rule at spec:237 now carries the same type condition the other three keys
  have, and states the consequence explicitly: a non-string value is invalid and falls back to the
  default.
- The section 3 note at spec:177 now carries the same rule and names the crash case directly:
  "so a config file holding `{"lang": 42}` never crashes the run."
- The two statements agree with each other and with REQ-034 (spec:62), which already listed "a
  `lang` or `format` that is not a string" as an invalid branch.

The crash path review-5 described is closed. `mergeSettings` can no longer call `.trim()` on a
number, because the rule requires the value to be a string before the trim. With
`{"lang": 42}` the value is invalid, the key falls back to `en`, and the run continues; that path
is now pinned by TEST-005 and by the section 3 note.

All four config keys now carry an explicit type condition, which confirms the omission was an
oversight and is now closed:

- `name`: spec:234 "valid when it is a non-empty string that is not only whitespace"
- `shout`: spec:235 "valid when it is a boolean"
- `times`: spec:236 and spec:178 "a float, a string, a number outside the range and a missing value
  are all invalid"
- `lang`/`format`: spec:237 "valid when the value is a string AND its trimmed, lower-cased form
  is one of the allowed values"

## New P0/P1 problems introduced by the fix round

None found.

Checks I ran against the three edited lines:

- The new wording at spec:237 does not contradict the other three per-key rules at spec:234 to
  spec:236, and it does not contradict the section 3 note at spec:177. Both places now state the
  same condition in the same order: string first, then trimmed and lower-cased against the allowed
  values.
- The new wording keeps the stored value pinned. It says `"ES"` "is valid and read as `es`", which
  is the assertion TEST-030 (spec:373) makes, so an implementation that validates the trimmed
  form but stores the raw `"ES"` still fails TEST-030.
- The new TEST-005 cases use `"name": 42` and `"name": true`. Both are non-strings, so both fall
  under "valid when it is a non-empty string" at spec:234, and both fall back to `world`. The
  choice is consistent with the existing rules and adds no new behaviour.
- The fix introduced no new ids, so the requirement-to-test mapping is unchanged in shape. Every
  REQ id and every SEC id still has at least one TEST id: REQ-001 to REQ-007 by TEST-003,
  TEST-008, TEST-011, TEST-015, TEST-016, TEST-022, TEST-023, TEST-027, TEST-028; REQ-010 to
  REQ-017 by TEST-001 to TEST-006, TEST-009, TEST-010, TEST-013, TEST-026, TEST-027, TEST-030;
  REQ-020 to REQ-024 by TEST-009, TEST-010, TEST-014, TEST-017, TEST-020; REQ-030 to REQ-037 by
  TEST-004, TEST-005, TEST-012, TEST-018, TEST-019, TEST-025, TEST-029, TEST-030, TEST-031;
  REQ-040 to REQ-042 by TEST-011, TEST-023; SEC-001 to SEC-004 by TEST-021, TEST-024, TEST-025,
  TEST-031.
- The fix round did not touch section 8, so the seeded `test/zz-seeded.test.js` is still named as
  out of scope (spec:336), and `test/greet.test.js` is still listed as unchanged (spec:332).

## Not findings

- The command-line `--lang ES` being a usage error while the config file accepts `"ES"` is
  authorised by the brief's "Left to the spec" (brief:83) and is settled by Q-2 (spec:391). Both
  halves are now tested, by TEST-003 and TEST-030.
- The empty `--name` on the command line being a usage error while an empty config `name` falls
  back to the default is deliberate: D-05 against D-12. TEST-003 covers the first half, TEST-019
  and TEST-005 the second.
- The config `name` rule is not a contradiction with REQ-037. REQ-037's `"  Ada  "` is a non-empty
  string that is not only whitespace, so it is valid and used verbatim; only a whitespace-only name
  is invalid (spec:175, spec:234).
- The spec contains no placeholders, no TODO and no TBD. The `<name>` and `<greeting>` strings in
  the output descriptions are format placeholders inside prose, not unresolved slots.
- The spec contains no em dashes.
- The `USAGE` string at spec:213, spec:278, spec:70 and in the contract table is
  character-for-character the string agreed in D-08.
- The JSON shape is consistent everywhere: spec:246 builds it as
  `'{"greeting": ' + JSON.stringify(repeatedGreeting) + '}'` with one space after the colon, and
  REQ-022 (spec:52), the contract table (spec:290, spec:293), TEST-010 (spec:353) and TEST-017
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
- `scripts/seed-red.sh` writes exactly the seeded trimming test that spec:336 describes, so
  section 8 is accurate.
- `bin/greet.js` today hand-rolls the `--name` lookup and silently ignores anything else, which is
  the superseded behaviour named at spec:77. The spec's replacement is consistent with the
  current `src/greet.js` signature, which the spec keeps unchanged.

## Note for the writer

Both P1s from review-5 are closed. The spec is ready to pass.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
top:
- No open P0 or P1 findings. F17 and F20 from review-5 are both fixed, and the fix round introduced no new P0 or P1.
report: plans/greet-options/reports/spec/review-6.md
