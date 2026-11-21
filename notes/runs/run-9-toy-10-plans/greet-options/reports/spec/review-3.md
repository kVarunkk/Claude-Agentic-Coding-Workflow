# spec/review-3.md

Target: `plans/greet-options/feature-greet-options-spec.md` (mode: spec)
Date: 2026-11-19
Spec version 0.1, status `Draft` (matches the `writing-specs` template default; the brief is a separate file with `status: agreed`).

Inputs read in full:
- `plans/greet-options/feature-greet-options-spec.md` (294 lines)
- `plans/greet-options/feature-greet-options-brief.md` (85 lines)
- `plans/greet-options/decisions.tsv`
- `plans/greet-options/reports/spec/review-2.md` (the PARTIAL report)
- `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `.dostuff/pipeline.conf`
- `.dostuff/skills/writing-specs/SKILL.md` and its `templates/spec.md`

## Scope of this review

This is a `PARTIAL:` run. The earlier verifier's report (`review-2.md`) contained a full first-pass
review with 7 findings (2 P1, 5 P2). The spec file is byte-for-byte unchanged since that review:
every line number cited in review-2 still resolves to the same text (`SEC-002` at line 70,
"D-024" at line 191, "no trimming, casing or escaping" at line 154, and so on). No fix round
appears to have run, so all 7 findings are re-verified here and carried forward.

I re-read every review-2 finding against the current spec text and confirmed each still holds.
I then ran an independent pass (brief coverage, id coverage, design review, critical challenge)
looking for anything review-2 missed. The independent pass found no new P0 and no new P1.
It did add one extra P2 (F08, empty `name` in the config) and sharpened F02 with a sub-point
about a mis-attributed "out of scope in the brief" note.

## Brief coverage (re-verified)

All 20 brief decisions (D-01 .. D-20) are cited somewhere in the spec and each is honoured:
D-01 (whole-string upper case, REQ-004), D-02 (one line per repetition, REQ-005), D-03 (`--times`
does not multiply JSON, REQ-009), D-04 (missing/invalid config is ignored, REQ-022/REQ-023),
D-05 (`--opt value` and `--opt=value`, REQ-003), D-06 (single usage line, REQ-030/REQ-037),
D-07 (config validated like flags, REQ-024), D-08 (working directory, REQ-020/SEC-003),
D-09 (language table, REQ-006), D-10 (unknown config keys ignored, REQ-025), D-11 (`--shout`
affects the JSON value, REQ-010), D-12 (non-numeric `--times` is a usage error, REQ-033),
D-13 (`greet(name)` kept, "Preserved" at line 62), D-14 (per-key precedence, REQ-021),
D-15 (exact JSON shape, REQ-008), D-16 (range 1..5, REQ-005/REQ-033), D-17 (last occurrence
wins, REQ-011), D-18 (`--shout` boolean, REQ-012), D-19 (config read before flags, once,
REQ-020/CON-003), D-20 (non-object config ignored, REQ-023).

The brief's "Out of scope" list (brief lines 33-40) is honoured: no `--help`/`--version` (an
unknown option is a usage error, REQ-031), no positional arguments or subcommands (REQ-036),
config read only from the working directory (SEC-003), no environment variables (ALT-005), no
shared parser package and no new dependencies (CON-001/DEP-001/ALT-002), and no pluralising
of the name (line 153, brief line 40).

Every REQ id is claimed by at least one TEST id and every TEST id claims at least one REQ.
File and function names (`src/options.js`, `src/config.js`, `src/greet.js`, `bin/greet.js`,
`parseArgs`, `resolveOptions`, `formatUsage`, `loadConfig`, `buildGreeting`, `GREETINGS`,
`DEFAULTS`) are spelled consistently in the front matter, the architecture diagram, the data
model, the components and the Files section. No placeholder (`<...>`, TODO, TBD) appears outside
the legitimate format placeholders in the REQ text and code samples.

## Findings

F01 [P1] plans/greet-options/feature-greet-options-spec.md:70 SEC-002 says an unknown key in
`greet.config.json` "causes the file to be discarded", which contradicts REQ-025 (line 47, "that
key is silently ignored and the rest of the file still applies", D-10) and section 4.3 line 192
("Unknown keys are ignored without invalidating the file"). A builder who follows SEC-002
discards the whole config when it holds one extra key, so REQ-025 and the TEST-004 unknown-key
case fail. SEC-002 also cites REQ-025 as support for discarding, which mis-cites it.
Fix: drop "unknown key" from SEC-002's discard list so it reads "any parse failure,
non-object value or invalid value causes the file to be discarded (REQ-023)", and drop the
`(REQ-023, REQ-025)` citation down to `(REQ-023)`.

F02 [P1] plans/greet-options/feature-greet-options-spec.md:154,222 The JSON output is not
guaranteed to be valid JSON. Section 4.1 says the name is used verbatim with "no trimming, casing
or escaping", and section 4.5 says the JSON line is "produced by building the string from the
greeting value, not by `JSON.stringify` of a wider object". A name containing `"` or `\` therefore
yields `{"greeting": "Hello, Ada "X""}`, which does not parse as JSON, while REQ-008 describes the
output as exactly one JSON object and the feature's goal is scriptable output. The brief did not
settle escaping, so the spec took a decision that changes what gets built without an Open
question. Compounding it, line 154 attributes the no-escaping rule to the brief ("out of scope in
the brief"), but the brief's out-of-scope list (lines 33-40) says nothing about escaping, so the
spec mis-attributes a decision the brief never made.
Fix: state that in `json` format the greeting value is JSON-escaped before it is embedded (escape
`"` and `\`), that the `text` format still uses the verbatim name, correct the line 154 attribution
to the brief's "Left to the spec" section, and add a TEST case that `--format json` with a name
containing a quote produces a line `JSON.parse` accepts.

F03 [P2] plans/greet-options/feature-greet-options-spec.md:191 "D-024" is not a decision id: the
brief's decision table ends at D-20, and no other spec line cites D-024. Fix: cite D-07 (the
config validation rules) instead.

F04 [P2] plans/greet-options/feature-greet-options-spec.md:53,168 REQ-003 requires the
`--opt=value` form, but the behaviour of an empty value (`--name=`, `--times=`) is unspecified.
REQ-032 calls a missing value a usage error and REQ-033 calls a non-integer `--times` a usage
error; `--times=` fits both, and the empty name has no defined result at all. The
`writing-specs` rule "Silence isn't permission" names empty as an input the spec must name.
Fix: add a sentence to REQ-032 stating that an empty `--opt=` value counts as a missing value
(usage error).

F05 [P2] plans/greet-options/feature-greet-options-spec.md:188 `loadConfig(dir)` only specifies
"Missing file -> {}". It does not say what happens when the directory does not exist, or the file
cannot be read (EACCES, EISDIR). Fix: state that any read error, including a missing directory or
an unreadable file, yields `{}`.

F06 [P2] plans/greet-options/feature-greet-options-spec.md:81,267,279 and test/greet.test.js:8
TEST-011 must assert empty stdout, a one-line stderr and exit code 2, but PAT-002 and section 9
point at the existing `execFileSync` helper in `test/greet.test.js`, and `execFileSync` throws on
a non-zero exit. A builder who copies the existing `run` helper gets an exception instead of a
status, stdout and stderr to assert. Fix: state that the usage-error test uses `spawnSync`, or
catches the `execFileSync` error and reads `error.status`, `error.stdout` and `error.stderr`.

F07 [P2] plans/greet-options/feature-greet-options-spec.md:284 vs :52,172 RISK-001's mitigation
says to "match the reason prefix ... rather than the whole line", but REQ-031 pins the exact
reason text `unknown option --bogus` and section 4.2 enumerates the exact reason strings the
parser returns. A test that only matches a prefix would not check the REQ-031 wording.
Fix: narrow RISK-001 to the usage-summary part of the line and state that the reason text itself
is asserted exactly.

F08 [P2] plans/greet-options/feature-greet-options-spec.md:193,184 REQ-024 and section 4.3
validate the config `name` key as "a string", so an empty string `""` passes validation and
`loadConfig` returns `{ name: '' }`, which yields the greeting `Hello, ` (a trailing space and an
empty name). The spec never says whether an empty `name` is valid, and the text format then
prints a line that looks like a bug. The same silence exists for an empty `--name ""` on the
command line. Fix: state that an empty `name` (in the config or as `--name ""`) is either a usage
error or is accepted and produces `Hello, `, and pick one so the tests can assert it.

## Design review

The module split matches the brief's chosen approach (`src/options.js` for parsing and defaults,
`src/config.js` for loading, `src/greet.js` for the greeting) and the order in the architecture
diagram respects the real dependency: config is read before flags are resolved (D-19), and a
usage error in step 3 short-circuits before any output (REQ-030). The return contract is
consistent across the diagram (lines 93-97), the component section (lines 161-163) and the prose
(lines 167, 176-179): `parseArgs` and `resolveOptions` both return `{ ..., error }` with `error`
as a string or `null`, and section 5 states that a usage error is carried as a reason string
rather than a thrown exception, which keeps the CLI the only place that decides on exit 2.
The config shape in section 3 matches `DEFAULTS` in section 4.2 and the `loadConfig` signature in
section 4.3. No finding here.

## Critical challenge

Missing cases checked and found covered: empty argv (REQ-001), missing config file (REQ-022),
malformed JSON (REQ-023), non-object config (REQ-023, D-20), one invalid config key (REQ-024),
unknown config key (REQ-025), repeated flags (REQ-011), `--shout=true` (REQ-012), positional
arguments (REQ-036), `--name` as the last token and `--name --shout` (REQ-032), out-of-range
`--times` (REQ-033), unsupported `--lang`/`--format` (REQ-034/REQ-035), `--times` with JSON
(REQ-009), `--shout` with JSON (REQ-010), config `times`/`format` keys via REQ-020/REQ-021 and
section 4.4. Not covered, and raised as F02 (JSON escaping), F04 (empty `--opt=` value),
F05 (unreadable config directory) and F08 (empty `name`).

Scope creep checked: the spec adds only the three modules, the config file and the CLI wiring the
brief asked for. No `--help`, no environment layer, no dependency. The `src/greet.js` language
table is placed in the existing module, as the brief recommended. No unrequested infrastructure.
Proportion is right.

Simpler alternative considered and correctly rejected in the spec: a hand-written parser inside
`bin/greet.js` (ALT-001) and a third-party CLI library (ALT-002). No further simplification is
available that keeps REQ-003's two flag forms and REQ-023's whole-file config validation.

SUMMARY
verdict: fail
p0: 0
p1: 2
p2: 6
top:
- F01 [P1] spec:70 SEC-002 discards the whole config on an unknown key, contradicting REQ-025 and section 4.3 line 192
- F02 [P1] spec:154,222 the JSON line is built without escaping and the name is used verbatim, so a name containing a quote produces invalid JSON
- F03 [P2] spec:191 cites D-024, which does not exist in the brief (decisions end at D-20)
- F04 [P2] spec:53,168 empty `--opt=` values are unspecified (missing value or invalid value)
- F06 [P2] spec:81,267,279 TEST-011 needs exit-code and stderr assertions that the existing execFileSync helper cannot give
report: plans/greet-options/reports/spec/review-3.md
