# spec/review-3.md

target: plans/greet-options/feature-greet-options-spec.md
mode: spec (recheck)
date: 2026-11-19
previous: plans/greet-options/reports/spec/review-2.md
brief: plans/greet-options/feature-greet-options-brief.md (status: agreed, 16 decisions)

## What I read

- `plans/greet-options/feature-greet-options-spec.md` (full, 360 lines)
- `plans/greet-options/reports/spec/review-2.md` (full, the previous review)
- `plans/greet-options/feature-greet-options-brief.md` (full, 84 lines)
- `bin/greet.js`, `src/greet.js`, `package.json`, `scripts/seed-red.sh`

## What changed since review-2

One addition: `TEST-026` (spec:345). Nothing else in the file differs materially from the
version review-2 read.

## Previous findings

F01 [P0] spec:222 JSON output shape contradicted itself. **fixed** (carried from review-2).
Line 227 now reads `{"greeting": "<repeated greeting>"}` with one space after the colon and
names the build `'{"greeting": ' + JSON.stringify(repeatedGreeting) + '}'`. REQ-022, the
contract table (spec:271, 273, 274) and TEST-010 (spec:329) all agree with it.

F02 [P1] spec:29 REQ-001 contradicted REQ-030/REQ-031. **fixed** (carried from review-2).
REQ-001 (spec:29) now carries the precondition "and no `greet.config.json` in the process
working directory" and adds "When a config file is present, the name comes from it
(REQ-030)". The contract table row (spec:268) and the "Preserved" line (spec:76) carry the
same precondition, and TEST-008 (spec:327) and TEST-022 (spec:341) pin both sides.

F03 [P1] spec:62 REQ-034's allowed-value rule conflicted with the case-insensitive matching
in spec:176. **fixed** (carried from review-2). REQ-034 now reads "a `lang` or `format` whose
trimmed, lower-cased value is not one of the allowed values, as matched in section 3", which
matches spec:176 and spec:218.

F04 [P1] spec:212 `mergeSettings` validity was stated as "right type" only. **fixed** (carried
from review-2). Lines 214-218 state the rule per key: `name` is a non-empty string used
verbatim; `shout` is a boolean; `times` is a whole number from 1 to 5; `lang` and `format`
are the trimmed, lower-cased allowed values. This agrees with REQ-034, REQ-036, REQ-037 and
spec:175-177.

F05 [P1] spec:83 SEC-003 mixed an observable rule with an implementation choice. **fixed**
(carried from review-2). SEC-003 (spec:83) is now only the observable half ("a config value is
printed literally, never evaluated as code"), and the shell clause moved to PAT-003 (spec:97),
which ends in "Checked by code review." There is exactly one PAT-003 in the file.

F06 [P1] spec:311 REQ-017 had no test id. **fixed.** TEST-026 was added (spec:345):
"running `bin/greet.js` with `--name \"  Ada  \"` prints `Hello,   Ada  ` on stdout, the name
used untrimmed with its surrounding whitespace intact, and exits 0 (REQ-017). The equals form
`--name=  Ada  ` prints the same line." This closes the command-line half of REQ-017 that
TEST-019 (config path only) and TEST-020 (newline in the name) did not cover.

I checked the new test against the rest of the file before accepting it:
- The expected line `Hello,   Ada  ` is the correct concatenation of `Hello, ` and the
  untrimmed `  Ada  ` (three spaces before `Ada`, two trailing).
- It does not collide with REQ-006 (spec:34): `  Ada  ` is not an empty name, so it is not a
  usage error.
- It does not collide with REQ-024 (spec:54): that rule is about a newline in the name, and
  whitespace around the name is still printed verbatim, which is what REQ-017 requires.
- The equals form is consistent with REQ-002 (spec:30) and PAT-002 (spec:96): the value
  after `=` is `  Ada  `, used verbatim.
So REQ-017 is now covered on both the command-line and the config path, and the last P1 from
review-2 is closed.

F07 [P2] spec:93 GUD-002 says parsing, config reading and rendering live in separate modules,
but section 4.1 puts `parseArgs`, `mergeSettings`, `resolveGreeting` and `render` in
`src/options.js`. **open.** Unchanged.

F08 [P2] spec:201 the parenthetical "(process.argv.slice(2))" still reads as "parseArgs does
the slicing" while section 4.3 (spec:250) says `bin/greet.js` parses `process.argv.slice(2)`.
**open.** Unchanged.

F09 [P2] spec:302 section 8 never mentions `scripts/seed-red.sh` or the `test/zz-seeded.test.js`
it creates. **open.** Unchanged. `scripts/seed-red.sh` (lines 5-13) writes a test asserting
`greet('  Ada  ')` trims to `'Hello, Ada'`, which REQ-017 (spec:46) and D-16 forbid, so an
implementer chasing a green `npm test` could add trimming against the spec. The brief agrees
that this seeded test "is not part of this feature", but the spec never says so.

F10 [P2] spec:50 REQ-020/REQ-021 count lines while REQ-024 says a newline in the name makes
the output hold more lines than the repetition count. **open.** Unchanged; REQ-024 still does
not say it is the exception to REQ-020 and REQ-021.

F11 [P2] spec:207 D-11 (no short flags) is never cited. **open.** Unchanged. Section 4.1
still says only that an unrecognised argument is an error, so `greet -x` exits 2 while
`greet --name -x` prints `Hello, -x` and exits 0, with nothing in the spec naming short flags
as out of scope. The brief lists short flags under "Out of scope" and D-11, so the spec should
cite it.

F12 [P2] spec:40 the spec never says how a `--times` value is read, so `0x2`, `1e1` and `" 3"`
are undecided. **open.** Unchanged. Line 209 still says only "a `--times` value that is not a
whole number". Note that the config path is clearer (spec:177 says a float or a string is
invalid) than the command-line path, so the two sources may diverge on `"3"` and `" 3"`.

F13 [P2] spec:209 the usage-error mechanism is never named, so an implementer that throws a
plain `Error` may leak a stack trace, which REQ-042 forbids. **open.** Unchanged. GUD-003
(spec:94) says "a single function raises the usage error", but section 4.1 (spec:209) still says
only "Raises a usage error" and section 4.3 (spec:251) still says only "On a usage error".
Nothing says `bin/greet.js` catches every error from the parse.

F14 [P2] spec:64 a config `name` that is only whitespace is neither empty (REQ-036) nor
covered by REQ-037, so it is undecided. **open.** Unchanged.

F15 [P2] spec:58 a config-set `shout: true` cannot be turned off from the command line.
**open.** Unchanged, no RISK-005. `parseArgs` returns `shout?: true` (spec:147), so there is
no `--no-shout`, and `mergeSettings` (spec:213) gives the flag precedence only when present.

F16 [P2] spec:139 `FORMATS` is exported but no part of the spec says who reads it. **open.**
Unchanged.

## New P0/P1 problems introduced by the fix round

None found. The single change, TEST-026 (spec:345), is consistent with REQ-002, REQ-006,
REQ-017, REQ-024, REQ-036, REQ-037, PAT-002, TEST-019 and TEST-020, and it introduces no new
requirement of its own. The rest of the file is unchanged from the version review-2 accepted
apart from F06.

## Not findings

- The command-line `--lang ES` being a usage error while the config file accepts `"ES"` is
  authorised by the brief's "Left to the spec" and is raised as Q-2 with a recommended answer.
- The empty `--name` on the command line being a usage error while an empty config `name`
  falls back to the default is deliberate: D-05 against D-12.
- The spec contains no placeholders, no TODO or TBD, and no em dashes.
- The `USAGE` string at spec:198, spec:259 and in REQ-041 is character-for-character the
  string agreed in D-08.
- The three existing tests in `test/greet.test.js` keep passing under the new behaviour, and
  the spec correctly lists that file as unchanged (spec:313).
- Every brief decision D-01 to D-16, every scope line and every out-of-scope line is honoured
  by the spec. No brief decision is dropped, and no brief out-of-scope behaviour is added.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 10
top:
- F13 [P2] spec:209 the usage-error mechanism is still unnamed; GUD-003 says a function raises it but nothing says `bin/greet.js` catches every parse error, so REQ-042's no-stack-trace rule is unguaranteed.
- F12 [P2] spec:209 the spec still never says how a `--times` value is read, so `0x2`, `1e1` and `" 3"` stay undecided, and the command-line path is less precise than the config path (spec:177).
- F09 [P2] spec:302 section 8 still does not mention `scripts/seed-red.sh`, whose seeded trimming test contradicts REQ-017 and D-16.
- F11 [P2] spec:208 D-11 (no short flags) is still never cited, and `greet --name -x` prints `Hello, -x` and exits 0 with nothing in the spec naming short flags as out of scope.
- F07 [P2] spec:93 GUD-002 still says parsing, config reading and rendering live in separate modules, but section 4.1 puts `parseArgs`, `mergeSettings`, `resolveGreeting` and `render` in `src/options.js`.
report: plans/greet-options/reports/spec/review-3.md
