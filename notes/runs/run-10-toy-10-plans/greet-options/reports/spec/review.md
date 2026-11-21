# spec/review.md

target: plans/greet-options/feature-greet-options-spec.md
mode: spec
date: 2026-11-19
brief: plans/greet-options/feature-greet-options-brief.md (status: agreed, 16 decisions)

## What I read

- `plans/greet-options/feature-greet-options-spec.md` (full, 347 lines)
- `plans/greet-options/feature-greet-options-brief.md` (full, 84 lines), `plans/greet-options/decisions.tsv`
- `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `package.json`, `scripts/seed-red.sh`
- `.dostuff/skills/writing-specs/SKILL.md` and its template

Brief coverage was checked decision by decision (D-01 to D-16), then every In-scope and
Out-of-scope line, then every REQ, SEC, CON, GUD, PAT and TEST id for testability and
coverage.

## Brief decisions and scope

Honoured, with one gap and one contradiction:

- D-01 to D-16 are all reflected in behaviour. D-11 (no short flags) is the only decision
  never cited by id, though REQ-007 covers the behaviour (see F11).
- Every In-scope bullet has a REQ. Every Out-of-scope bullet is honoured except that the
  brief's explicit "the seeded `scripts/seed-red.sh` trimming test is not part of this
  feature" never appears in the spec (see F09).
- No brief decision is contradicted. The spec takes one decision the brief never covered
  and does not raise it as an open question: the config file's `lang` and `format` are
  matched case-insensitively after trimming (spec:175), while the command line is matched
  exactly (see F03). The brief's "Left to the spec" section does authorise this, so it is
  covered, but it contradicts REQ-034 as written.
- The spec adds no behaviour the brief excluded.

## Findings

F01 [P0] plans/greet-options/feature-greet-options-spec.md:222 The JSON output shape is
contradicted inside the spec. Section 4.1 says `render` returns
`JSON.stringify({ greeting: <repeated greeting> })`, which produces `{"greeting":"Hello, Ada"}`
with no space after the colon. REQ-022 (spec:52), the contract table (spec:266, 268, 269)
and TEST-010 (spec:324) all state the literal stdout `{"greeting": "Hello, Ada"}` with a
space. An implementer who copies section 4.1 verbatim fails REQ-022 and TEST-010; an
implementer who copies REQ-022 must hand-build the JSON string, which is what
`JSON.stringify` is there to avoid. The brief (D-03, "Left to the spec") writes the shape
with a space, so the space is the intended form and section 4.1 is the wrong statement.
Fix: replace the section 4.1 line with the exact output text, for example
`In json format: the string {"greeting": "<repeated greeting>"} (a space after the colon)
followed by a newline; build it with JSON.stringify and then replace the first ":" with
": ", or build it as '{"greeting": ' + JSON.stringify(repeated) + '}'`, and say so in one
sentence.` Keep REQ-022, the table and TEST-010 as they are.

F02 [P1] plans/greet-options/feature-greet-options-spec.md:29 REQ-001 says the CLI with no
arguments prints `Hello, world`, but REQ-030 (spec:58) and REQ-031 (spec:59) say the
config file supplies the `name` default and that every value not set by a flag comes from
the config file. With `greet.config.json` holding `{"name": "Bob"}` and no arguments, the
run must print `Hello, Bob`, so REQ-001 as written is false in exactly the situation the
config feature exists for. The contract table row `greet` -> `Hello, world\n` (spec:263)
has the same defect. Two REQs cannot both hold.
Fix: qualify REQ-001 and the table row with the config precondition, for example
"When the CLI is run with no arguments and no `greet.config.json` in the working
directory, then it prints `Hello, world` followed by a newline on stdout and exits with
code 0."

F03 [P1] plans/greet-options/feature-greet-options-spec.md:62 REQ-034 lists "a `lang` or
`format` that is not one of the allowed values" as an invalid config value that falls back
to the default. The data model note at spec:175 says the config file's `lang` and `format`
are matched case-insensitively after trimming, so `"ES"` is read as `es`. On the literal
reading of REQ-034, `"ES"` is "not one of the allowed values" and must fall back to `en`,
while spec:175 says it is valid. A test writer reading REQ-034 writes the wrong assertion.
Fix: make REQ-034 name the matching rule, for example "a `lang` or `format` that is not one
of the allowed values after the case-insensitive, whitespace-trimmed match described in
section 3".

F04 [P1] plans/greet-options/feature-greet-options-spec.md:212 The contract for
`mergeSettings(flags, config)` states only "A config value is valid only when it has the
right type and, for `times`, is within 1 to 5". That rule contradicts two other parts of
the spec: REQ-036 (spec:64) says a config `"name": ""` falls back to `world`, but an empty
string is a string, so "right type" would make it valid and the name would render as
`Hello, `; and spec:175 says config `lang` and `format` are normalised (trimmed,
lower-cased) before the allowed-value check, which "right type" does not cover either. An
implementer who follows section 4.1 alone ships the wrong config behaviour.
Fix: state the full validity rule for each key in `mergeSettings`, for example "`name` is
valid when it is a non-empty string, used verbatim; `shout` is valid when it is a boolean;
`times` is valid when it is a whole number from 1 to 5; `lang` and `format` are valid when
the trimmed, lower-cased value is one of the allowed values".

F05 [P1] plans/greet-options/feature-greet-options-spec.md:83 SEC-003 is not fully
observable, so it cannot be graded as met. Its second half, "the name is never
interpolated into a shell command", describes an implementation choice: the CLI never
spawns a shell, so no test can observe that nothing was interpolated into one. The
writing-specs rule is that a requirement no test can observe belongs in a PAT ending in
"Checked by code review.".
Fix: split SEC-003. Keep the observable half as SEC-003 ("Values taken from the config file
are treated as plain data: a config value is printed literally, never evaluated"), and add
a PAT, for example "PAT-003: No value from argv or from the config file is ever passed to
a shell or used to build a command string. Checked by code review."

F06 [P1] plans/greet-options/feature-greet-options-spec.md:311 Section 9 lists no test for
several ids, so they will grade Untested in the conformance check. Missing: REQ-017 (the
name is used exactly as given, no trimming), REQ-024 (a newline in the name makes the text
output hold more lines than the repetition count), REQ-036 (config `"name": ""` falls back
to `world`), REQ-037 (config `"name": "  Ada  "` is used verbatim), REQ-042 (no stack trace
and no partial greeting on a usage error), and SEC-001, SEC-002, SEC-003, SEC-004. TEST-005
covers "an invalid config value" generically, which is not the same as pinning REQ-036.
Fix: add test ids to section 9 for the missing ones, for example "TEST-019 (unit): a config
`name` of `""` resolves to `world` and a config `name` of `  Ada  ` resolves to
`  Ada  `, untrimmed", "TEST-020 (route / CLI): a name containing a newline is printed
verbatim in text format, so the output holds more lines than `--times`", "TEST-021 (route
/ CLI): the working directory holds no new or changed files after a run, and a
`greet.config.json` in the parent directory is not read".

F07 [P2] plans/greet-options/feature-greet-options-spec.md:93 GUD-002 says "Flag parsing,
config reading and rendering live in separate modules", but section 4.1 puts `parseArgs`,
`mergeSettings`, `resolveGreeting` and `render` all in `src/options.js`, and section 8 lists
no third module for rendering.
Fix: reword GUD-002 to "Flag parsing, config reading and rendering live outside
`bin/greet.js`, in `src/options.js` and `src/config.js`, so each can be tested on its own
without spawning a process", or add a `src/render.js` to section 8.

F08 [P2] plans/greet-options/feature-greet-options-spec.md:201 The parenthetical
"(process.argv.slice(2))" sits under `parseArgs(argv)`, so it reads as "parseArgs does the
slicing", while section 4.3 (spec:245) says `bin/greet.js` parses `process.argv.slice(2)`.
If both slice, the first two flags are eaten.
Fix: change the line to "Takes the argument list already without the node and script path;
`bin/greet.js` passes `process.argv.slice(2)`."

F09 [P2] plans/greet-options/feature-greet-options-spec.md:297 Section 8 never mentions
`scripts/seed-red.sh` or the `test/zz-seeded.test.js` file it creates. The brief
explicitly puts that trimming test out of scope, and REQ-017 and D-16 honour it, but the
spec does not tell the implementer that `npm test` (CON-003) will pick up that file and
fail until it is removed or the seed is not run. An implementer chasing a green `npm test`
may add trimming, which REQ-017 forbids.
Fix: add to section 8 or section 9 one line, for example "`test/zz-seeded.test.js`, created
by `scripts/seed-red.sh`, is out of scope and is not created or kept by this feature; the
trimming behaviour it checks is excluded by REQ-017."

F10 [P2] plans/greet-options/feature-greet-options-spec.md:50 REQ-020 says the text format
with one repetition holds "exactly one line" and REQ-021 says "exactly one line per
repetition", while REQ-024 says a name containing a newline makes the output hold more
lines than the repetition count. REQ-024 never says it is an exception to REQ-020 and
REQ-021.
Fix: scope REQ-020 and REQ-021, for example "when the name contains no newline character",
or add "even though REQ-020 and REQ-021 count lines, REQ-024 is the exception" to REQ-024.

F11 [P2] plans/greet-options/feature-greet-options-spec.md:207 D-11 (no short flags) is
never cited, and section 4.1 says only that an unrecognised argument is an error. A value
that starts with a single dash is consumed as a flag value, so `greet --name -x` prints
`Hello, -x` and exits 0 while `greet -x` exits 2. That is consistent with the stated
rules, but nothing says a short flag is out of scope.
Fix: add a line to section 4.1, for example "Short flags are not supported (D-11): an
argument that starts with a single dash is not a flag, so `greet -n` is a usage error."

F12 [P2] plans/greet-options/feature-greet-options-spec.md:40 REQ-011 says a `--times`
value that "is not a whole number" is a usage error, but the spec never says how the value
is read. `Number('0x2')` is 2 and `Number('1e1')` is 10, so a hex or exponent form would
either be accepted or be rejected depending on the parse chosen, and neither answer is
written down. The same applies to a value with surrounding spaces, for example
`--times " 3"`.
Fix: say how the value is parsed, for example "`--times` is read with `Number(value)`; the
value is valid only when `Number.isInteger` is true and the number is from 1 to 5, so
`0x2`, `1e1` and `3.5` are all usage errors."

F13 [P2] plans/greet-options/feature-greet-options-spec.md:208 Section 4.1 says
`parseArgs` "Raises a usage error" but never names the mechanism, and section 4.3 says
`bin/greet.js` writes the usage line "On a usage error". An implementer that throws a
plain `Error` and catches only that class still leaks a stack trace on an unexpected
throw, which REQ-042 forbids.
Fix: name the mechanism in one sentence, for example "`parseArgs` throws an `Error` with
the message `usage`; `bin/greet.js` catches every error from the parse and writes the
usage line, so no stack trace ever reaches stderr."

F14 [P2] plans/greet-options/feature-greet-options-spec.md:65 REQ-037 settles the config
name `"  Ada  "`, but a config name that is only whitespace, for example `"   "`, is
neither empty (REQ-036) nor covered by REQ-037, so it is unclear whether it renders as
`Hello,    ` or falls back to `world`.
Fix: extend REQ-036, for example "When `greet.config.json` holds a `name` that is empty or
only whitespace, then the name falls back to the built-in default `world`", or state in
REQ-037 that a whitespace-only name is used verbatim.

F15 [P2] plans/greet-options/feature-greet-options-spec.md:58 REQ-030 lets the config file
set `shout`, but there is no way to turn a config-set `shout` back off: `--shout` only
sets it to true. A user who leaves `{"shout": true}` in the config can never get normal
output again without editing the file. This follows the brief, so it is not a defect, but
it is a sharp edge worth naming.
Fix: add a risk line, for example "RISK-005: a config file that sets `shout: true` cannot
be overridden from the command line, because `--shout` only ever sets the flag. Mitigation:
the user removes the key from `greet.config.json`."

F16 [P2] plans/greet-options/feature-greet-options-spec.md:139 `FORMATS` is exported but
the spec never says who reads it, and the allowed-value checks it would serve are
described only in prose. An unused export is dead weight in a teaching-quality toy.
Fix: either say in section 4.1 that `FORMATS` is the list the `--format` and config
`format` checks use, or drop it from the export list.

## Not findings

- The empty `--name` on the command line being a usage error while an empty config `name`
  falls back to the default is deliberate: D-05 against D-12. The spec keeps them apart
  correctly.
- `--` being an unknown argument matches D-10 and REQ-007.
- Config `lang` and `format` being case-insensitive while the command line is exact is
  authorised by the brief's "Left to the spec" and is raised as Q-2 with a recommended
  answer, so it is not an unraised decision. Only its conflict with REQ-034 is a finding.
- The spec contains no placeholders, no TODO or TBD, and no em dashes.
- The `USAGE` string at spec:197, spec:254 and in REQ-041 is character-for-character the
  string agreed in D-08.
- The three existing tests in `test/greet.test.js` all keep passing under the new
  behaviour, and the spec correctly lists that file as unchanged.

SUMMARY
verdict: fail
p0: 1
p1: 5
p2: 10
top:
- F01 [P0] spec:222 JSON output shape contradicts itself: section 4.1's `JSON.stringify` gives `{"greeting":"x"}` but REQ-022, the contract table and TEST-010 all require `{"greeting": "x"}`.
- F02 [P1] spec:29 REQ-001 (no arguments -> `Hello, world`) contradicts REQ-030/REQ-031 (the config file supplies the name), and the contract table row at spec:263 has the same defect.
- F03 [P1] spec:62 REQ-034 says a config `lang`/`format` that "is not one of the allowed values" falls back, while spec:175 says those values are matched case-insensitively after trimming, so `"ES"` is valid.
- F04 [P1] spec:212 `mergeSettings` validity is stated as "right type" only, which contradicts REQ-036 (config `name: ""` falls back to `world`) and the spec:175 normalisation rule.
- F05 [P1] spec:83 SEC-003 mixes an observable rule with "the name is never interpolated into a shell command", which no test can observe.
- F06 [P1] spec:311 Section 9 has no test id for REQ-017, REQ-024, REQ-036, REQ-037, REQ-042 or SEC-001 to SEC-004.
report: plans/greet-options/reports/spec/review.md
