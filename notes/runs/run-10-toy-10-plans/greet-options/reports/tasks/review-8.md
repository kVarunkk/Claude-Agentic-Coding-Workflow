# tasks/review-8.md

Target: `plans/greet-options/feature-greet-options-tasks.md` (v0.1), reviewed against `plans/greet-options/feature-greet-options-spec.md` (v0.3) and `plans/greet-options/feature-greet-options-brief.md`.

Date: 2026-11-19

Mode: `tasks`, RECHECK of `plans/greet-options/reports/tasks/review-7.md`. This round checks (a) each P0 and P1 finding of review-7, marked `fixed` or `open`, and (b) new P0 or P1 problems the fix round introduced. The three P2 findings of review-7 Part C are carried over unchanged and are not re-litigated.

## Mechanical checks

`bash .dostuff/scripts/check-plan.sh plans/greet-options` → exit 0, no FAIL, no WARN.

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 35 REQ/SEC ids, 18 tasks.
OK
```

The script does not compare the traceability table against the tasks' Spec columns, so the drift review-7 recorded in Part C is invisible to it. I compared them myself (see Part D).

## Part A: review-7 P0 and P1 findings

### F17 [P1] tasks.md:112, :125, :126 No task's Green step puts `times` or `format` into the settings object — **fixed**

The wiring is now stated in the three places review-7 said it was missing.

- TASK-040's Green step (tasks.md:112) now names all five keys and the rule that produces them: "`bin/greet.js` builds the settings from the parsed flags and `DEFAULTS` and prints `resolveGreeting(settings)` instead of `greet(name)`; **every key of the settings object is read from the flags when the key is present and from `DEFAULTS` otherwise, so the settings always holds all five keys `name`, `shout`, `times`, `lang` and `format`, and no key is ever `undefined`.** The name and the language are read this way from the start; `shout` is added by TASK-041, and `times` and `format` are read this way from the start as well, so the settings object is complete before `render` is built in TASK-050 and TASK-051."
- TASK-050's Green step (tasks.md:125) now names the key it consumes: "`bin/greet.js` puts the parsed `times` into the settings, falling back to `DEFAULTS.times`, so `render` repeats the greeting that many times; the settings object is the one TASK-040 builds, and `times` is one of its five keys."
- TASK-051's Green step (tasks.md:126) now names its key the same way: "`bin/greet.js` puts the parsed `format` into the settings, falling back to `DEFAULTS.format`, so `render` takes the json branch; the settings object is the one TASK-040 builds, and `format` is one of its five keys."
- The Decisions row (tasks.md:48) was widened to match: "Phases 4 to 6 read the flag values in `bin/greet.js` and fall back to `DEFAULTS` there, **for all five keys** `name`, `shout`, `times`, `lang` and `format` ... The keys are read into the settings in TASK-040 (`name`, `lang`, `times`, `format`) and TASK-041 (`shout`), and TASK-050 and TASK-051 each name the key they consume."

The old contradiction is gone: review-7 quoted TASK-040 as saying "`DEFAULTS` (name, lang)"; the current TASK-040 names all five keys and points at the two tasks that add `shout` and that consume `times` and `format`. The phase order also supports the wording, because Phase 4 is `depends: 1, 3` (tasks.md:106), so TASK-030's `Number` conversion of `times` and TASK-031's membership checks for `lang` and `format` are already green when TASK-040 builds the settings.

### F18 [P1] tasks.md:139 The whitespace-only config name fallback has a rule but no test — **fixed**

TASK-061's Red step (tasks.md:139) now carries the case: "Then the fallback cases: a config `name` of `''` resolves to `world`; **a config `name` of `'   '`, a name holding only whitespace, resolves to `world`, because a name that is entirely whitespace is not a valid name**; a config `name` of `'  Ada  '` resolves to `'  Ada  '`, untrimmed; ...".

This closes the branch that REQ-034 names (spec.md:62, "a `name` that holds only whitespace") and that TEST-005 lists among the invalid values (spec.md:348, "a config `name` of only whitespace"). The neighbouring case, a config name of `'  Ada  '` kept verbatim, is still there, so the pair that is easy to confuse remains asserted side by side. The Green step's rule ("The config `name` is valid when it is a non-empty string that is not only whitespace") is now backed by a test.

### F19 [P1] tasks.md:86, :99 Two units with the same `depends:` set list the same files — **fixed**

Phase 3's dependency was changed. Phase 2 is `depends: 1` (tasks.md:80); Phase 3 is now `depends: 1, 2` (tasks.md:93). I listed the `depends:` set of every phase and grouped by set:

| Phase | depends | Phase | depends |
|---|---|---|---|
| 1 | (none) | 6 | 1, 2, 3 |
| 2 | 1 | 7 | 1, 6 |
| 3 | 1, 2 | 8 | 7 |
| 4 | 1, 3 | 9 | 3, 5, 7 |
| 5 | 3, 4 | | |

No two phases share a `depends:` set, so the disjoint-files rule for sibling units no longer applies anywhere in the plan. The substantive ordering matches too: TASK-021's Green step says a single-dash argument in value position "is an ordinary value (TASK-020)", and TASK-030 and TASK-031 both build on the `parseArgs` that TASK-020 and TASK-021 shape, so `depends: 1, 2` on Phase 3 is the real dependency, not just a graph tidy-up.

## Part B: new P0 and P1 problems

None found. The fix round did not introduce a new P0 or P1.

I re-checked the areas the fix touched, because that is where a regression would land:

- **The widened TASK-040 Green step against TASK-010's Red step.** TASK-010's Red asserts the exact objects `parseArgs([])` returns `{}` and `parseArgs(['--name', 'Ada'])` returns `{ name: 'Ada' }` (tasks.md:73). The widened TASK-040 Green step does not change what `parseArgs` returns, only what `bin/greet.js` does with the result, so the exact-object assertions are untouched and TASK-010 stays green.
- **The `shout` ownership across TASK-040 and TASK-041.** TASK-040's Green names TASK-041 as the owner of `shout`, and TASK-041's Green says "`bin/greet.js` passes `shout` from the parsed flag, which is `true` only when `--shout` was given" (tasks.md:113). TASK-041's Red (the binary run with `--shout --name Ada` prints `HELLO, ADA\n`) is therefore genuinely Red, because TASK-040 does not yet read the `shout` flag. No unit holds a Red that passes before its own code exists.
- **`times` and `format` as raw strings before their units.** TASK-010's Green says "At this stage the `--times`, `--lang` and `--format` values are read as raw strings, without the conversion and the membership check that TASK-030 and TASK-031 add" (tasks.md:73). TASK-030's Red then asserts the converted number (`{ times: 3 }`) and TASK-031's Red the membership check, so each Red still fails for the right reason. TASK-040 runs after Phase 3 (`depends: 1, 3`), so by the time its settings object reads `times` and `format` from the flags, the values are already numbers and already validated.
- **The temporary merge is still deleted exactly once.** TASK-070's Green says "The temporary flag-to-default merge that lived in `bin/greet.js` is deleted in this task" (tasks.md:151), and the Decisions row (tasks.md:48) says the same. The widened TASK-040 wording does not introduce a second, competing merge.
- **The seeded trimming test.** TASK-091's Green still confirms "the seeded trimming test in `test/zz-seeded.test.js` still fails, because REQ-017 and D-16 forbid trimming" (tasks.md:178). `scripts/seed-red.sh` writes that file, and it does not exist in the working tree today, so the plan's treatment of it matches how the build seeds it.

## Part C: traceability table drift (carried over from review-7, unchanged)

review-7 Part C graded three drift items as P2. I checked the current file against the same three rows and found all three closed, so the P2 count for this round drops by three. The drift was between the "Requirement traceability" table and the tasks' Spec columns; the table does not agree with the Spec columns anywhere now.

I compared every REQ and SEC id in the table against the ids in the tasks' Spec columns, in both directions. The result is empty in both directions:

- No row of the table names a task whose Spec column omits that id.
- No task's Spec column names an id that the table omits.
- REQ-005 is now `| REQ-005 | TASK-020 |` (tasks.md:190), and TASK-090's Spec column is `REQ-023, REQ-024` (tasks.md:177), so the stale TASK-090 entry is gone.
- REQ-010 is now `| REQ-010 | TASK-050, TASK-051 |` (tasks.md:193), and TASK-051's Spec column is `REQ-010, REQ-015, REQ-022, REQ-023, D-03` (tasks.md:126), so the short Spec column was widened.
- REQ-015 is now `| REQ-015 | TASK-010, TASK-041, TASK-051, TASK-080 |` (tasks.md:198), and TASK-080's Spec column is `REQ-015, REQ-031, RISK-005` (tasks.md:164), so TASK-080 was added to the row.

## Part D: coverage confirmation

Set comparisons against the spec, both directions, all clean:

- All 35 REQ and SEC ids in the spec appear in the tasks file, and every one of them is named by at least one task's Spec column and by the traceability table.
- All 31 TEST ids in the spec appear in the tasks file, in at least one task's Tests column, and no task names a TEST id that the spec does not have.
- Every phase holds at most 2 tasks, within `MAX_UNIT_TASKS=2` in `.dostuff/pipeline.conf`.
- Every task's Files column names the files its Red, Green and code-review steps touch, tests included.

The plan's claims about the existing code hold. `bin/greet.js` today holds the hand-rolled `--name` lookup that TASK-010 removes, `src/greet.js` exports `greet(name)` and keeps its signature, `package.json` has no `dependencies` and its test script is `node --test`, and `test/greet.test.js` holds the three tests that the spec keeps unchanged. `scripts/seed-red.sh` is the script that writes `test/zz-seeded.test.js`.

## Part E: new P2 (cost and clarity)

### F20 [P2] tasks.md:112 TASK-040's Green step says "every key of the settings object is read from the flags" and then, two clauses later, says `shout` is added by TASK-041

The Green step first states the general rule ("every key of the settings object is read from the flags when the key is present and from `DEFAULTS` otherwise, so the settings always holds all five keys"), then carves out `shout` ("`shout` is added by TASK-041"). A reader who takes the general rule literally at the moment TASK-040 is implemented may wire the `shout` flag there, because TASK-010 already teaches `parseArgs` to recognise `--shout` (tasks.md:73). That would make TASK-041's Red (the binary run with `--shout --name Ada` prints `HELLO, ADA\n`, tasks.md:113) pass before TASK-041's Green, which breaks the unit's Red step.

The plan does not actually leave this open: the same sentence names TASK-041 as the owner of `shout`, the Decisions row (tasks.md:48) names TASK-041 as the owner too, and TASK-041's Green repeats the ownership. The cost is one sentence that reads two ways.

Fix: make the general rule scope the exception, for example "`bin/greet.js` builds the settings from the parsed flags and `DEFAULTS`: the `name`, `lang`, `times` and `format` keys are read from the flags when the key is present and from `DEFAULTS` otherwise, so the settings always holds all five keys `name`, `shout`, `times`, `lang` and `format`, and no key is ever `undefined`; `shout` is taken from `DEFAULTS` in this task and wired to the flag by TASK-041".

## Summary of this round

All three P1 findings of review-7 are closed, and the fix round introduced no new P0 or P1. The three P2 drift findings of review-7 Part C are also closed, which leaves one new P2 (F20).

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
top:
- F20 [P2] TASK-040's Green step states the "every key is read from the flags" rule before carving out `shout`, which could make TASK-041's Red pass before its own Green
report: plans/greet-options/reports/tasks/review-8.md
