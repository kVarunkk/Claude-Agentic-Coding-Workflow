# spec/review-8.md

Target: `plans/greet-options/feature-greet-options-spec.md` (mode: spec, RECHECK)
Date: 2026-11-19
Previous review: `plans/greet-options/reports/spec/review-6.md` (the RECHECK baseline)
Spec version 0.4, `status: 'Draft'` (the brief is a separate file with `status: agreed`).

Inputs read in full:
- `plans/greet-options/feature-greet-options-spec.md` (311 lines, v0.4)
- `plans/greet-options/feature-greet-options-brief.md` (85 lines)
- `plans/greet-options/decisions.tsv`
- `plans/greet-options/reports/spec/review-6.md` (the RECHECK baseline), `review-7.md` (a PARTIAL run that stopped early and left only the pending skeleton, so there is nothing to carry from it), `review-4.md`, `changes.md`
- `src/greet.js`, `bin/greet.js`, `test/greet.test.js`

## Scope of this review

A fix round ran: the spec moved from v0.3 to v0.4 and now carries the six P2 notes
listed in `plans/greet-options/reports/spec/changes.md` (empty `--opt=` value, empty
name, config read errors, `spawnSync` for the usage-error test, exact reason matching
in RISK-001, and the `D-024` citation).

Per the skill's recheck mode I checked (a) each P0 and P1 finding of review-6, marked
`fixed` or `open`, and (b) new P0 or P1 problems the fix introduced. The old P2s are
carried over unchanged except where the fix round closed them, and no new P2s are
reported.

## Previous findings (from review-6)

F01 [P1] spec:70 SEC-002 discards the whole config on an unknown key. **fixed**
(carried from review-4, still closed in v0.4). SEC-002 (line 70) still reads "any parse
failure, non-object value or invalid value causes the file to be discarded (REQ-023).
Unknown keys are ignored without discarding the file (REQ-025)." REQ-025 (line 47) and
section 4.3 line 194 agree.

F02 [P1] spec:34,154,222,298 the JSON line is not guaranteed to be valid JSON. **fixed**
(carried from review-4, still closed in v0.4). The v0.3 escape-set completion is
untouched by the v0.4 round: REQ-008 (line 34), section 4.5 (lines 224, 226) and section
11 (line 303) still name the complete JSON string escape set and still name
`JSON.stringify` on the value alone as the normative source. TEST-013 (line 286) still
covers a name containing a newline.

F03 [P2] spec:191 "D-024" is not a decision id. **fixed**.
Line 193 now reads "A key with an invalid value -> `{}` for the whole file, not a partial
config (REQ-023, D-07)." D-07 is the brief's config-validation decision, so the citation
now points at the right row. I grepped the whole spec for `D-0[2-9][0-9]`: the only
remaining hits are in the report files themselves, not in the spec.

F04 [P2] spec:53,168 the behaviour of an empty `--opt=` value is unspecified. **fixed**.
REQ-032 (line 53) now reads "An empty value is also a missing value: `--name=`,
`--times=`, `--lang=` and `--format=` (the `--opt=` form with nothing after the `=`) are
usage errors with the reason `missing value for --<opt>`." Section 4.2 line 172 repeats
it, line 174 pins the concrete string `missing value for --name`, and TEST-002b (line
275) asserts all four options. Section 11 line 307 records the decision.

F05 [P2] spec:188 `loadConfig(dir)` does not say what happens when the directory does not
exist or the file cannot be read. **fixed**.
Section 4.3 line 190 now reads "Any read error yields `{}`: a missing file (REQ-022), a
missing directory, an unreadable file (permissions) or a path that is a directory rather
than a file. The read error is not reported to the user and does not change the exit
code; the run continues on the built-in defaults (REQ-022)." TEST-004 (line 277) asserts
the unreadable-file and missing-directory cases. Section 11 line 309 records it.

F06 [P2] spec:81,267,279 the usage-error test cannot use the existing `execFileSync`
helper. **fixed**.
PAT-002 (line 81) now says "A test that must assert a non-zero exit code, stderr or
empty stdout uses `spawnSync` instead of `execFileSync`, because `execFileSync` throws on
a non-zero exit and its error object is not a reliable source of the three values;
alternatively it catches the `execFileSync` error and reads `error.status`,
`error.stdout` and `error.stderr`." Section 9 seam 3 (line 271) and TEST-011 (line 284)
say the same, and section 11 line 310 records it. This is correct against the real code:
`test/greet.test.js:8` wraps `execFileSync` in a `run` helper that has no way to observe
a non-zero exit, so the spec's instruction is right.

F07 [P2] spec:285 vs :52,172 RISK-001's mitigation still says to match the reason
prefix. **fixed**.
RISK-001 (line 290) now reads "the test asserts the reason text exactly (REQ-031 pins
`unknown option --bogus`; section 4.2 lists every reason string) and matches the
usage-summary part of the line, which is the part most likely to be reworded, rather than
matching the whole line." That is exactly the split the finding asked for, and it
agrees with TEST-011's "stderr is exactly one line starting with the exact reason text".

F08 [P2] spec:46,193 an empty `name` is neither accepted nor rejected. **fixed**.
The spec now decides the empty name for both paths and keeps them distinct, as the
brief's D-04 and D-07 require of every invalid value:
- REQ-002 (line 28): "An empty name is not a name: `--name ""` is a usage error with the
  reason `invalid value for --name: ` (REQ-030, REQ-037). The empty `--name=` form is a
  missing value instead (REQ-032)."
- Section 4.2 line 173 gives the reason and says why the two are not folded together:
  "It is not folded into the missing-value case, because the value was supplied and was
  read; it was its content that was rejected."
- Section 4.3 line 195: an empty `name` in the config is an invalid value, so it discards
  the whole file and the run falls back to the built-in defaults; "it is not a usage
  error, because an invalid config never changes the exit code (D-04, D-07)".
- Section 4.1 line 154: "The name reaching the builder is never empty ... so the greeting
  is never `Hello, ` with a trailing space."
- TEST-002b (line 275) and TEST-004 (line 277) assert both paths; section 11 line 308
  records the decision.
This is consistent with REQ-024, which keeps the "same rules as the equivalent flags"
wording and adds "A value that fails its rule triggers REQ-023 rather than exit 2"
(line 46), and with the section 3 data model comment "name: 'world', // string,
non-empty" (line 117).

## New P0/P1 from the fix round

None. The v0.4 edit is confined to the six P2 notes in `changes.md`, plus the REQ-002,
section 4.1, section 4.2, section 4.3 and section 11 sentences that carry them, and it
introduces no new P0 or P1.

I re-checked the new text against the surrounding spec for contradictions:
- The `--name=` versus `--name ""` distinction is stated identically in REQ-002 (line 28),
  REQ-032 (line 53), section 4.2 (lines 172, 173, 174), TEST-002b (line 275) and section
  11 (line 307). The two reasons are pinned as literal strings in five places, so a
  builder and a test writer cannot drift apart.
- The empty-name rule does not contradict REQ-024 or D-04/D-07: an invalid config value
  never becomes a usage error and never changes the exit code, which is exactly what the
  brief decided.
- The config read-error rule at line 190 is compatible with REQ-022 ("When
  `greet.config.json` does not exist, the run uses built-in defaults and succeeds") and
  with RISK-002 (the config is read once at startup and never breaks a run).
- The `spawnSync` instruction at PAT-002, section 9 seam 3 and TEST-011 is consistent
  with each other and with RISK-001's exact-reason matching.

## Brief coverage (re-verified against v0.4)

All 20 brief decisions (D-01 .. D-20) are cited somewhere in the spec and each is
honoured: D-01 (REQ-004), D-02 (REQ-005), D-03 (REQ-009), D-04 (REQ-022, REQ-023),
D-05 (REQ-003), D-06 (REQ-030, REQ-031, REQ-037), D-07 (REQ-024), D-08 (REQ-020,
SEC-003), D-09 (REQ-006), D-10 (REQ-025), D-11 (REQ-010), D-12 (REQ-033), D-13 (line 62),
D-14 (REQ-021), D-15 (REQ-008), D-16 (REQ-005, REQ-033), D-17 (REQ-011), D-18 (REQ-012),
D-19 (REQ-020, CON-003), D-20 (REQ-023). The only broken citation, the stray "D-024",
is gone (F03).

The brief's "Out of scope" list (lines 33-40) is still honoured: no `--help` or
`--version` (REQ-031), no positional arguments or subcommands (REQ-036), config read
only from the working directory (SEC-003), no environment variables (ALT-005, line 175),
no shared parser package and no new dependency (CON-001, DEP-001, ALT-002), and no
pluralising of the name (line 153, brief line 40). The four v0.4 additions are recorded
in section 11 as spec-level decisions, which the brief's "Left to the spec" section
permits, and none of them changes the brief's behaviour.

## Design review (re-run on v0.4)

The module split still matches the brief's chosen approach and the architecture order
still respects the real dependency (config read before flags, D-19; usage error
short-circuits before output, REQ-030). The return contract is consistent across the
diagram (lines 93-97), section 4.2 (lines 161-163) and section 5: `parseArgs` and
`resolveOptions` both return `{ ..., error }` with a string reason or `null`, and a usage
error is carried as a reason rather than a thrown exception, so the CLI alone owns
exit 2. The config shape in section 3 matches `DEFAULTS` in section 4.2 and the
`loadConfig` signature in section 4.3. The v0.4 change keeps validation in
`src/config.js` and in `parseArgs`, keeps escaping in the `json` output path
(`bin/greet.js`) and out of `buildGreeting` (line 152), which are the right seams, and
keeps `buildGreeting` a pure greeting builder. No new design finding.

## Critical challenge (re-run on v0.4)

Re-checked the same missing-case list as review-4 and review-6: empty argv, missing
config file, malformed JSON, non-object config, one invalid config key, unknown config
key, repeated flags, `--shout=true`, positional arguments, `--name` as the last token,
`--name --shout`, out-of-range `--times`, unsupported `--lang` and `--format`, `--times`
with JSON, `--shout` with JSON, config `times` and `format` keys. All are now covered,
including the three that review-6 carried: the empty `--opt=` value (F04), the unreadable
config directory or file (F05) and the empty name (F08). The control-character case in
the JSON value stays covered by REQ-008 and TEST-013.

Scope creep: unchanged, the spec adds only the three modules, the config file and the
CLI wiring the brief asked for. The v0.4 rules are the small set of edge cases the
brief left open, and each is one sentence plus one test. Simpler alternatives remain
correctly rejected in section 6 (ALT-001 hand-written parser in `bin/greet.js`, ALT-002
third-party CLI library).

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
top:
- All eight previous findings from review-6 (F01-F08) are fixed in v0.4; the six P2 notes in changes.md were all applied
- No new P0 or P1 introduced by the v0.4 fix round; the new empty-name and empty `--opt=` rules are stated consistently in five places and are covered by TEST-002b and TEST-004
- Brief coverage re-verified: all 20 brief decisions cited and honoured, every out-of-scope item still excluded
report: plans/greet-options/reports/spec/review-8.md
