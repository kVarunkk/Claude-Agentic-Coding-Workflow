# spec/review-6.md

Target: `plans/greet-options/feature-greet-options-spec.md` (mode: spec, RECHECK)
Date: 2026-11-19
Previous review: `plans/greet-options/reports/spec/review-4.md` (the RECHECK baseline), `plans/greet-options/reports/spec/review-5.md` (a PARTIAL run that stopped early and recorded no findings, so there is nothing to carry from it)
Spec version 0.3, `status: 'Draft'` (the brief is a separate file with `status: agreed`).

Inputs read in full:
- `plans/greet-options/feature-greet-options-spec.md` (301 lines, v0.3)
- `plans/greet-options/feature-greet-options-brief.md` (85 lines)
- `plans/greet-options/decisions.tsv`
- `plans/greet-options/reports/spec/review-4.md`, `review-3.md`, `review-5.md`
- `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `.dostuff/pipeline.conf`

## Scope of this review

A fix round ran: the spec moved from v0.2 to v0.3 and now completes the JSON escaping
decision (front matter `version: 0.3`, section 11 "Settled in v0.2, completed in v0.3").
Per the skill's recheck mode I checked (a) each P0 and P1 finding of review-4, marked
`fixed` or `open`, and (b) new P0 or P1 problems the fix introduced. The old P2s are
carried over unchanged and no new P2s are reported.

## Previous findings (from review-4)

F01 [P1] spec:70 SEC-002 discards the whole config on an unknown key. **fixed**.
SEC-002 still reads "any parse failure, non-object value or invalid value causes the file
to be discarded (REQ-023). Unknown keys are ignored without discarding the file (REQ-025)."
The mis-cited `(REQ-023, REQ-025)` stays correctly split, and REQ-025 (line 47) and
section 4.3 line 192 agree with it.

F02 [P1] spec:34,154,222,298 the JSON line is not guaranteed to be valid JSON. **fixed**.
The escape set is now complete and the guarantee it makes is one it can keep. See F09
below for the detail; the two findings are the same underlying defect and are both closed
by the v0.3 edit.

F03 [P2] spec:191 "D-024" is not a decision id. **open** (carried unchanged). Line 191
still reads "A key with an invalid value -> `{}` for the whole file, not a partial config
(REQ-023, D-024)." The brief's decision table ends at D-20.
Fix: cite D-07 (the config validation rules) instead.

F04 [P2] spec:53,168 the behaviour of an empty `--opt=` value is unspecified. **open**
(carried unchanged). REQ-032 (line 53) still covers only `--name` as the last argument and
`--name --shout`; section 4.2 line 168 still says nothing about `--name=` or `--times=`.
Fix: add a sentence to REQ-032 stating that an empty `--opt=` value counts as a missing
value (usage error).

F05 [P2] spec:188 `loadConfig(dir)` does not say what happens when the directory does not
exist or the file cannot be read. **open** (carried unchanged). Section 4.3 still lists
only "Missing file -> `{}` (REQ-022)" and "Malformed JSON -> `{}` (REQ-023)".
Fix: state that any read error, including a missing directory or an unreadable file,
yields `{}`.

F06 [P2] spec:81,267,279 the usage-error test cannot use the existing `execFileSync`
helper. **open** (carried unchanged). PAT-002 (line 81) and section 9 seam 3 (line 269)
still mandate `execFileSync`, and `test/greet.test.js:8` uses it; `execFileSync` throws on
a non-zero exit, so it cannot yield the stdout, stderr and exit code 2 that TEST-011
(line 281) must assert.
Fix: state that the usage-error test uses `spawnSync`, or catches the `execFileSync`
error and reads `error.status`, `error.stdout` and `error.stderr`.

F07 [P2] spec:285 vs :52,172 RISK-001's mitigation still says to match the reason
prefix. **open** (carried unchanged). REQ-031 pins the exact reason text
`unknown option --bogus` and section 4.2 line 172 enumerates the exact reason strings, so
a prefix-only match would not check the REQ-031 wording.
Fix: narrow RISK-001 to the usage-summary part of the line and state that the reason text
itself is asserted exactly.

F08 [P2] spec:46,193 an empty `name` is neither accepted nor rejected. **open** (carried
unchanged). REQ-024 (line 46) and section 4.3 line 193 validate `name` as "a string", so
`""` passes and the greeting becomes `Hello, ` (trailing space). The same silence exists
for `--name ""` on the command line.
Fix: state whether an empty `name` (config or `--name ""`) is a usage error or produces
`Hello, `, and pick one so the tests can assert it.

## New P0/P1 from the fix round

None. The v0.3 edit is confined to the escaping contract and I found no new P0 or P1 in it.

F09 [P1] plans/greet-options/feature-greet-options-spec.md:34,222,298 The escaping
contract is incomplete but stated as absolute. **fixed**.
The v0.3 edit closes the gap review-4 identified. Concretely:
- REQ-008 (line 34) now names the complete escape set: "a name containing a control
  character (U+0000 to U+001F) appears as `\n`, `\t`, `\r`, `\b`, `\f` or `\u00XX`, so no
  raw newline reaches stdout." The guarantee "the line always parses as JSON and always
  stays one line" now rests on a rule that can deliver it.
- Section 4.5 (line 222) repeats the complete set and adds "and no raw control character
  survives into the output".
- Section 4.5 (line 224) now names the implementation: "The escape is produced by
  `JSON.stringify(greeting)` on the value alone, which returns the surrounding double
  quotes as well; the implementation drops exactly those two outer quotes and embeds the
  remainder between the quotes of `{"greeting": "..."}`. `JSON.stringify` is the normative
  source of the escape set." This is the route review-4 recommended, it keeps the fixed
  key order and the single space after the colon (REQ-008, D-15), and the escape set it
  produces matches line 222 exactly: `JSON.stringify` escapes `"` and `\`, escapes every
  control character in U+0000 to U+001F (as `\b`, `\t`, `\n`, `\f`, `\r`, or `\u00xx` with
  lower-case hex digits), and leaves no raw newline in the result.
- TEST-013 (line 283) now covers the missing case: "the CLI prints a `--format json` line
  that `JSON.parse` accepts when the name contains a `"`, a `\` or a newline, and the
  parsed `greeting` value equals the raw greeting; the printed output contains exactly one
  newline, the terminating one". The newline case was the one review-4 said the planned
  tests missed. The config-file path and the verbatim `text` format are covered too.
- Section 11 (line 300) records the completion and why: "v0.3 completes the escape set:
  v0.2 named only the quote and the backslash, which could not deliver the promised
  guarantee for a name containing a control character."

Nothing else in the spec was touched by the fix round: line 154 ("The only transformation
applied to the name is escaping it as a JSON string, and only when the value is embedded
in the `json` output"), line 152 (escaping stays out of `buildGreeting`) and section 4.4
line 202 (the escape set lives in the `json` output path in `bin/greet.js`) all stay
consistent with the new text, so the escaping rule has one home and no contradiction.

## Brief coverage (re-verified against v0.3)

All 20 brief decisions (D-01 .. D-20) are cited somewhere in the spec and each is
honoured: D-01 (REQ-004), D-02 (REQ-005), D-03 (REQ-009), D-04 (REQ-022, REQ-023),
D-05 (REQ-003), D-06 (REQ-030, REQ-037), D-07 (REQ-024), D-08 (REQ-020, SEC-003),
D-09 (REQ-006), D-10 (REQ-025), D-11 (REQ-010), D-12 (REQ-033), D-13 (line 62),
D-14 (REQ-021), D-15 (REQ-008), D-16 (REQ-005, REQ-033), D-17 (REQ-011), D-18 (REQ-012),
D-19 (REQ-020, CON-003), D-20 (REQ-023). The only broken citation is the stray "D-024"
at line 191 (F03).

The brief's "Out of scope" list (lines 33-40) is still honoured: no `--help` or
`--version` (REQ-031), no positional arguments or subcommands (REQ-036), config read only
from the working directory (SEC-003), no environment variables (ALT-005), no shared parser
package and no new dependency (CON-001, DEP-001, ALT-002), and no pluralising of the name
(line 153, brief line 40). The escaping decision remains a spec-level decision, which the
brief's "Left to the spec" section permits, and section 11 records it explicitly.

## Design review (re-run on v0.3)

The module split still matches the brief's chosen approach and the architecture order
still respects the real dependency (config read before flags, D-19; usage error
short-circuits before output, REQ-030). The return contract is consistent across the
diagram (lines 93-97), section 4.2 (lines 161-163) and section 5: `parseArgs` and
`resolveOptions` both return `{ ..., error }` with a string reason or `null`, and a usage
error is carried as a reason rather than a thrown exception, so the CLI alone owns exit 2.
The config shape in section 3 matches `DEFAULTS` in section 4.2 and the `loadConfig`
signature in section 4.3. The v0.3 change keeps escaping in the `json` output path
(`bin/greet.js`) and out of `buildGreeting` (line 152), which is the right seam, and the
`JSON.stringify`-on-the-value-alone route keeps `buildGreeting` a pure greeting builder.
No new design finding.

## Critical challenge (re-run on v0.3)

Re-checked the same missing-case list as review-4: empty argv, missing config file,
malformed JSON, non-object config, one invalid config key, unknown config key, repeated
flags, `--shout=true`, positional arguments, `--name` as the last token, `--name --shout`,
out-of-range `--times`, unsupported `--lang` and `--format`, `--times` with JSON,
`--shout` with JSON, config `times` and `format` keys. Still uncovered, and still carried:
empty `--opt=` value (F04), unreadable config directory or file (F05), and empty `name`
(F08). The control-character case in the JSON value is now covered by REQ-008 and
TEST-013, and the empty-name case is unchanged.

Scope creep: unchanged, the spec adds only the three modules, the config file and the CLI
wiring the brief asked for. The escaping rule is needed for the JSON contract to hold, so
it is in proportion. Simpler alternatives remain correctly rejected in section 6
(ALT-001 hand-written parser in `bin/greet.js`, ALT-002 third-party CLI library).

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 6
top:
- F03 [P2] spec:191 cites D-024, which does not exist in the brief (decisions end at D-20)
- F04 [P2] spec:53,168 empty `--opt=` values are unspecified (missing value or invalid value)
- F05 [P2] spec:188 loadConfig does not say what happens when the directory or file cannot be read
- F06 [P2] spec:81,269,281 TEST-011 needs exit-code and stderr assertions that the existing execFileSync helper cannot give
- F07 [P2] spec:287 vs :52,172 RISK-001 tells the test to match the reason prefix, which would not check REQ-031's exact wording
report: plans/greet-options/reports/spec/review-6.md
