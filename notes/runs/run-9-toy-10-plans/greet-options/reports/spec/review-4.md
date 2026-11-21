# spec/review-4.md

Target: `plans/greet-options/feature-greet-options-spec.md` (mode: spec, RECHECK)
Date: 2026-11-19
Previous review: `plans/greet-options/reports/spec/review-3.md`
Spec version 0.2, `status: 'Draft'` (brief is a separate file with `status: agreed`).

Inputs read in full:
- `plans/greet-options/feature-greet-options-spec.md` (299 lines, v0.2)
- `plans/greet-options/feature-greet-options-brief.md` (85 lines)
- `plans/greet-options/decisions.tsv`
- `plans/greet-options/reports/spec/review-3.md` (the previous report) and `review-2.md`
- `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `.dostuff/pipeline.conf`
- `.dostuff/skills/writing-specs/SKILL.md` and `templates/spec.md`

## Scope of this review

A fix round ran: the spec moved from v0.1 to v0.2 and now carries a JSON-escaping
decision (front matter `version: 0.2`, section 11 "Settled in v0.2"). Per the skill's
recheck mode I checked (a) each P0 and P1 finding of review-3, marked `fixed` or `open`,
and (b) new P0 or P1 problems the fix introduced. Old P2s are carried over unchanged and
no new P2s are reported.

## Previous findings

F01 [P1] spec:70 SEC-002 discards the whole config on an unknown key. **fixed**.
SEC-002 now reads "any parse failure, non-object value or invalid value causes the file
to be discarded (REQ-023). Unknown keys are ignored without discarding the file (REQ-025)."
The mis-cited `(REQ-023, REQ-025)` is now split correctly, and REQ-025 (line 47) and
section 4.3 line 192 agree with it.

F02 [P1] spec:34,154,222,298 the JSON line is not guaranteed to be valid JSON. **open**
(the `"` and `\` part is fixed, the guarantee is not). The fix added the escaping
decision, the corrected line 154 attribution ("The brief did not settle escaping, so the
spec settles it here", no longer claimed as a brief out-of-scope item), the section 4.5
escaping sentence and TEST-013. But the escape set the spec names is `"` and `\` only,
while the spec states three times that the line "always parses as JSON" (line 34),
"always parses with `JSON.parse`" (line 222) and "the line always parses with
`JSON.parse`" (line 298). JSON also requires escaping control characters (U+0000 to
U+001F). A name containing a newline, reachable from the command line
(`--name $'A\nB'`) or from a config file (`{"name": "A\nB"}`), leaves a raw LF inside
the string literal: `JSON.parse` rejects it ("Bad control character in string literal")
and the output spans two lines, breaking REQ-008's "exactly one line". A builder who
implements exactly what the spec says produces invalid JSON. See F09.

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
helper. **open** (carried unchanged). PAT-002 (line 81) and section 9 seam 3 (line 267)
still mandate `execFileSync`, and `test/greet.test.js:8` uses it; `execFileSync` throws on
a non-zero exit, so it cannot yield the stdout, stderr and exit code 2 that TEST-011
(line 279) must assert.
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

F09 [P1] plans/greet-options/feature-greet-options-spec.md:34,222,298 The escaping
contract is incomplete but stated as absolute. The spec names exactly two escapes, a
double quote becomes a backslash-quote and a backslash becomes a double backslash
(line 222), and then claims "so the printed line always parses with `JSON.parse`"
(line 222), "the line always parses as JSON" (line 34) and "the line always parses with
`JSON.parse`" (line 298). JSON string literals also forbid raw control characters
(U+0000 to U+001F), so a name with a newline, tab or other control character leaves it
raw in the output. Two things then break at once: `JSON.parse` rejects the line ("Bad
control character in string literal"), and the output is no longer the single line
REQ-008 requires. Both inputs are reachable, through `--name $'A\nB'` and through a
config file with a newline in the `name` value. TEST-013 (line 281) only exercises a
double quote and a backslash, so the gap is not caught by the planned tests either. The
fix round introduced this by promising a guarantee the named escape set cannot deliver.
Fix: name a complete escape set. The smallest change is to say the greeting value is
escaped as a JSON string, i.e. `JSON.stringify(greeting)` is used for the value and the
object is then assembled by hand as `{"greeting": " + escapedValue + "}` so the key order
and the one space after the colon stay fixed (section 4.5 already builds the line by
hand). If the manual route is kept, list the control-character escapes (`\n`, `\t`,
`\r`, `\b`, `\f`, and `\u00XX` for the rest) alongside the quote and the backslash. Then
add a TEST-013 case with a name containing a newline that asserts `JSON.parse` accepts
the line and the parsed value equals the raw greeting.

## Brief coverage (re-verified against v0.2)

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
(line 153, brief line 40). The v0.2 escaping decision is a new spec-level decision, which
the brief's "Left to the spec" section permits, and section 11 records it explicitly.

## Design review (re-run on v0.2)

The module split still matches the brief's chosen approach and the architecture order
still respects the real dependency (config read before flags, D-19; usage error
short-circuits before output, REQ-030). The return contract is consistent across the
diagram (lines 93-97), section 4.2 (lines 161-163) and section 5: `parseArgs` and
`resolveOptions` both return `{ ..., error }` with a string reason or `null`, and a usage
error is carried as a reason rather than a thrown exception, so the CLI alone owns exit 2.
The config shape in section 3 matches `DEFAULTS` in section 4.2 and the `loadConfig`
signature in section 4.3. The v0.2 change keeps escaping in the `json` output path
(`bin/greet.js`) and out of `buildGreeting` (line 152), which is the right seam. No new
design finding beyond F09.

## Critical challenge (re-run on v0.2)

Re-checked the same missing-case list as review-3: empty argv, missing config file,
malformed JSON, non-object config, one invalid config key, unknown config key, repeated
flags, `--shout=true`, positional arguments, `--name` as the last token, `--name --shout`,
out-of-range `--times`, unsupported `--lang` and `--format`, `--times` with JSON,
`--shout` with JSON, config `times` and `format` keys. Still uncovered, and still carried:
empty `--opt=` value (F04), unreadable config directory or file (F05), empty `name`
(F08), and now the control-character case in the JSON value (F09).

Scope creep: unchanged, the spec adds only the three modules, the config file and the CLI
wiring the brief asked for. The v0.2 escaping rule is needed for the JSON contract to
hold, so it is in proportion. Simpler alternatives remain correctly rejected in section 6
(ALT-001 hand-written parser in `bin/greet.js`, ALT-002 third-party CLI library).

SUMMARY
verdict: fail
p0: 0
p1: 2
p2: 6
top:
- F09 [P1] spec:34,222,298 the escape set covers only the quote and the backslash, yet the spec promises the JSON line always parses; a name with a control character breaks both the JSON and the one-line shape
- F02 [P1] spec:34,154,222,298 open: the no-escaping part is fixed, but the "always valid JSON" guarantee the fix added is not true for control characters
- F03 [P2] spec:191 cites D-024, which does not exist in the brief (decisions end at D-20)
- F04 [P2] spec:53,168 empty `--opt=` values are unspecified (missing value or invalid value)
- F06 [P2] spec:81,267,279 TEST-011 needs exit-code and stderr assertions that the existing execFileSync helper cannot give
report: plans/greet-options/reports/spec/review-4.md
