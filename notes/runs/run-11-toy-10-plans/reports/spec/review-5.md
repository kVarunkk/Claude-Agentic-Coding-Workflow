# spec/review-5.md

Target: `plans/greet-options/feature-greet-options-spec.md`
Mode: spec (recheck, fix round 4)
Date: 2026-11-20
Reviewer: spec-verifier
Previous review: `plans/greet-options/reports/spec/review-4.md`

Recheck scope: the two P2 findings carried over from review-4 (N05, N06), plus new P0 or P1 problems introduced by the round-4 fix. The fix round is recorded in `plans/greet-options/reports/spec/changes-3.md` ("Spec changes: close the last two P2 notes"). The changed text is the §4.3 table (line 341) and the §8 fixture list (line 388).

The brief (`plans/greet-options/feature-greet-options-brief.md`) was re-read against the spec. The code the spec names (`src/greet.js`, `bin/greet.js`, `test/greet.test.js`) was re-read to check the spec's claims about it. No files other than this report were written.

## Previous findings

**N05 [P2] `plans/greet-options/feature-greet-options-spec.md:388` the `{"name": ""}` fixture entry names only TEST-006, but TEST-024 needs the same directory. -> fixed**
The §8 fixture list (line 388) now reads: "one with `{"name": ""}` (TEST-006, TEST-024)". Both consumers are named, so a reader can find every test that needs the directory. The fixture's content (`{"name": ""}`) is unchanged and still matches TEST-006 (line 422) and TEST-024 (line 440), which both drive the CLI with `cwd` set to that directory.

**N06 [P2] `plans/greet-options/feature-greet-options-spec.md:341` the §4.3 table has no row for a config `name` of the wrong JSON type, such as `{"name": 123}`. -> fixed**
A new row was added at line 341:

```
| Wrong config name type (`{"name": 123}`) | empty | `usage: greet [options] invalid value for name: 123\n` | 2 |
```

The row follows the reason shape the table already pins for other config keys: §4.1 line 256 ("An invalid value throws a `UsageError` whose reason names the key and the offending value, for example `invalid value for lang: de`") and §4.3 line 346 ("a config reason names the config key without it (`invalid value for lang: de`)"). The pinned string `invalid value for name: 123` is the same shape applied to the config `name` key with the JSON number `123` as the offending value.

It is also consistent with REQ-079 (line 87), which names the JSON number `123` as an example of a non-string config `name`, and with §4.1 line 257, which lists the JSON number `123` and a JSON boolean as usage errors for `name`. The row sits next to the empty-name row (line 340, `empty value for name`), and the two do not collide: §4.1 line 256 still says "The one reason that does not follow this shape is the empty `name`", which is true, since the wrong-type case follows the shape.

### New P0 or P1 problems introduced by the fix round

None. The two changed passages were checked against the brief, against the code the spec names, and against the rest of the spec:

- The new §4.3 row pins bytes that no route test asserts (TEST-006, line 422, only asserts that `loadConfig` throws for `{"name": 123}`). That is the same situation as the table's pre-existing rows for `--times 0`, `--times abc` and `--lang de`, whose exact stderr is also not asserted byte for byte, so the table is a contract list rather than a one-to-one test index. Nothing in the spec claims the table is exhaustive, and no requirement lost its test coverage, so this is not a regression.
- The fixture tag change adds TEST-024 to a directory that already existed and whose content is unchanged, so no file list, count or "Layers covered" line needed changing. §9 line 442 still reads "unit (TEST-001 to TEST-009), route/process (TEST-010 to TEST-024)", which matches the twenty-four test ids in the file.

## P2 findings carried over from the previous review (all now closed)

N05 and N06 are both marked fixed above. No P2 note from review-4 remains open.

## Notes carried to the tasks stage

- §12 "Open questions" reads "None", and §11 records all seven gate answers with the requirement, section and TEST id each one is applied in. The tasks file can be written without further user input.
- The spec's naming is consistent across sections: `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput`, `formatUsage`, `UsageError`, `DEFAULT_OPTIONS`, `GREETING_WORDS`, and the file paths `src/greet.js`, `bin/greet.js`, `test/greet.test.js`, `test/fixtures/` all match the code and §8.
- The §8 fixture list names sixteen directories; each one is referenced by at least one TEST id (TEST-005, TEST-006, TEST-016, TEST-017, TEST-020, TEST-022, TEST-024) and none is orphaned.
- Every REQ id (REQ-001 to REQ-079) and every TEST id (TEST-001 to TEST-024) is defined once and well-formed. REQ-079 sits after REQ-069 in the "Config file" group; line 75 explains that it was added later and takes the next free number, so the numbering stays readable.
- Every REQ id has at least one TEST id that exercises it, and the two seams are used as the spec intends: the unit seam for the parse, load, merge and render rules, the route seam for the stdout, stderr and exit-code contract.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
top:
- N05 fixed: the §8 fixture list now tags the `{"name": ""}` directory "(TEST-006, TEST-024)", so both consumers of the fixture are named
- N06 fixed: §4.3 now has a row for a wrong-typed config `name`, pinning `usage: greet [options] invalid value for name: 123\n`, which matches the reason shape the table already uses for other config keys
- No new P0 or P1 problems were introduced by the round-4 fix
report: plans/greet-options/reports/spec/review-5.md
