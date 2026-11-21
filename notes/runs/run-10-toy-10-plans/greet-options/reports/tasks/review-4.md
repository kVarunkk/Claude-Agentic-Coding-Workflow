# tasks/review-4.md

Target: `plans/greet-options/feature-greet-options-tasks.md` (v0.1), reviewed against `plans/greet-options/feature-greet-options-spec.md` (v0.3) and `plans/greet-options/feature-greet-options-brief.md`.

Date: 2026-11-19

Mode: `tasks`, RECHECK of `plans/greet-options/reports/tasks/review-3.md`. This round checks (a) each P0 and P1 finding of review-3, marked `fixed` or `open`, and (b) new P0 or P1 problems the fix round introduced. The ten P2 findings of review-2 were closed in review-3 and are not re-litigated here.

## Mechanical checks

`bash .dostuff/scripts/check-plan.sh plans/greet-options` → exit 0, no FAIL, no WARN.

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 35 REQ/SEC ids, 18 tasks.
OK
```

Id coverage was re-verified mechanically against the spec: all 35 REQ/SEC ids and all 31 TEST ids in the spec appear in the tasks file, and no id appears on only one side. Every phase holds at most 2 tasks (`MAX_UNIT_TASKS=2` in `.dostuff/pipeline.conf`).

## Part A: review-3 P0 and P1 findings

### F15 [P1] tasks.md:72 (TASK-010) TASK-010's new `--times` assertion required a value conversion its Green step never introduced — **fixed**

The first of the two fixes review-3 offered was applied, and it was applied completely.

- The repeated-flag cases were moved to the units that own each value's semantics. TASK-030's Red step now writes `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }` with no error (tasks.md:99). TASK-031's Red step now writes `parseArgs(['--lang', 'es', '--lang', 'fr'])` returns `{ lang: 'fr' }` and `parseArgs(['--format', 'json', '--format', 'text'])` returns `{ format: 'text' }`, both with no error (tasks.md:100).
- TASK-010's Red step now keeps only the `--name` repetition case and states where the others live: "The repeated-flag cases for `--times`, `--lang` and `--format` are written in TASK-030 and TASK-031, which own the conversion and the membership check for those values" (tasks.md:73).
- TASK-010's Green step was updated to remove the gap review-3 pointed at: "At this stage the `--times`, `--lang` and `--format` values are read as raw strings, without the conversion and the membership check that TASK-030 and TASK-031 add; their repeated-flag cases are therefore tested in those two tasks, not here" (tasks.md:73).
- REQ-003 was added to TASK-030's and TASK-031's Spec columns (tasks.md:99, :100), and the traceability row reads `| REQ-003 | TASK-010, TASK-030, TASK-031 |` (tasks.md:188). The row and the two Spec columns agree.
- A new Decisions row records the split so the choice is written down rather than left to the implementer: "The repeated-flag cases are split by the flag that owns the value's semantics, so each unit's Green step builds what its own Red step asserts" (tasks.md:51).

I re-checked both readings review-3 warned about and both are now closed. TASK-030's assertion `{ times: 4 }` is a number and TASK-030's Green step introduces the `Number` conversion, so the Red is genuine at that point (TASK-010 leaves the value as the raw string `'4'`). TASK-031's `--lang` and `--format` cases and TASK-030's `--times` case are each in the unit whose Green step produces the asserted value, so no unit contains a Red that passes before its own code exists. REQ-003 now has a test for each of the four flags it names, and each test lives in the unit that builds the behaviour it asserts.

## Part B: new P0 and P1 problems

### F16 [P1] tasks.md:73, :87, :113 No task's Green step makes `parseArgs` recognise `--shout` and return `{ shout: true }`

This is a gap in the plan that review-2 and review-3 did not catch. It is not introduced by the fix round, so it is not a recheck regression, but it is a P1 and the plan cannot be built as written without the implementer guessing.

`--shout` is one of the five flags the brief puts in scope ("Five long flags: `--name NAME`, `--shout`, `--times N`, `--lang en|es|fr`, `--format text|json`", brief.md:23) and the spec's `parseArgs` contract names it: "`--shout` takes no value. `--shout=true` is not accepted: it is an unknown flag and a usage error" (spec.md:220).

No task builds it. Reading every task's Green step for the word `shout` gives only three hits, and none of them adds the flag to the parser:

- TASK-021's Green (tasks.md:87) says "`parseArgs` treats any argument that is not one of the five recognised long flags and is not consumed as a flag value as a usage error ... `--shout` takes no value, so `--shout=true` is an unknown flag". This presumes `--shout` is already one of the five recognised flags, but says nothing about how it becomes one or what `parseArgs` returns for it.
- TASK-041's Green (tasks.md:113) says "`bin/greet.js` passes `shout` from the parsed flag, which is `true` only when `--shout` was given, and `DEFAULTS.shout` otherwise". This presumes the parsed flag already exists.
- TASK-061's Green (tasks.md:139) and TASK-080's Green (tasks.md:164) are about the config value of `shout`, not the flag.

Meanwhile TASK-010's Green, the task that creates `parseArgs`, describes only the `--name` flag: "`parseArgs` takes only the argument list ... returns an object holding only the keys whose flags were present, and for a repeated `--name` keeps the value of the last occurrence, as the raw string" (tasks.md:73). It does not say `--shout` is recognised and it does not say what `parseArgs` returns for it.

The consequence for the build: TASK-041's Red step writes the CLI case "the binary run with `--shout --name Ada` prints `HELLO, ADA\n` on stdout, and exits 0" (tasks.md:113), and TASK-051's Red step writes "with `--format json --shout --name Ada` it prints `{"greeting": "HELLO, ADA"}\n`" (tasks.md:126). An implementer who follows TASK-010's Green literally produces a `parseArgs` that treats `--shout` as an unknown flag, so both of those Red tests fail with a usage error and exit 2 instead of the expected greeting. The implementer has to decide on their own that `--shout` belongs in TASK-010, TASK-021 or TASK-041, and there is no unit-level test of `parseArgs(['--shout'])` anywhere in the plan to pin the shape of the parsed object (the only `shout` unit test is `resolveGreeting({ lang: 'en', name: 'Ada', shout: true })` at tasks.md:113, which bypasses the parser).

Fix: name the owner. The smallest change is to add one sentence to TASK-010's Green step: "`parseArgs` recognises `--shout` as a flag that takes no value and returns `{ shout: true }` when it is given, and the key is absent otherwise", and add the matching unit assertion to TASK-010's Red step, `parseArgs(['--shout'])` returns `{ shout: true }` and `parseArgs([])` returns `{}` (already there). If the flag is instead meant to be added later, the alternative is to give it its own unit and list REQ-015 on it, since REQ-015 ("When `--shout` is given, then the whole greeting, including the name, is upper-cased in both text and JSON output") is currently traced to TASK-041 and TASK-051, which consume the parsed flag but do not produce it.

## Part C: review-2 P2 findings

All ten P2 findings of review-2 (F05 to F14) were closed in review-3 and were re-verified as still closed in this round: the five units are `**Guard → Green:**` with a one-line reason each (tasks.md:152, :164, :165, :177, :178), the `depends:` lines name Phase 3 where it is needed (tasks.md:106, :119, :171), TASK-081 uses a dedicated parent temp directory and cleans it up (tasks.md:165), the Decisions row names `test/greet.test.js` as the one repo-root exception (tasks.md:41), REQ-010 lists TASK-051 (tasks.md:192), TASK-081's Files column names `src/options.js` (tasks.md:165), TASK-021's Green wording distinguishes flag position from value position (tasks.md:87), `parseArgs(['--times', '03'])` is written in TASK-030's Red step (tasks.md:99), Review focus item 2 names TASK-080 (tasks.md:60), and TASK-091 no longer claims to be the only failing test in the suite (tasks.md:178). No new P2 is reported, per the recheck rules.

## Coverage check

All 35 REQ and SEC ids in the spec are referenced by at least one task and by the traceability table, and all 31 TEST ids are referenced by at least one task. Both sets were compared mechanically against the spec and match exactly.

Every phase holds at most 2 tasks, within `MAX_UNIT_TASKS=2`. Every task's Files column names each file its Red, Green and code-review steps touch. The `depends:` graph matches the real dependencies.

The one gap found this round is the unassigned `--shout` parsing (F16). It is not a missing traceability row, it is a behaviour REQ-015 and TEST-013 depend on that no task's Green step produces.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
top:
- No task's Green step makes `parseArgs` recognise `--shout` and return `{ shout: true }`, so TASK-041's and TASK-051's `--shout` Red tests have no code that builds them (F16)
report: plans/greet-options/reports/tasks/review-4.md
