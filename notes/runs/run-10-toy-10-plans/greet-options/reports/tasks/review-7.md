# tasks/review-7.md

Target: `plans/greet-options/feature-greet-options-tasks.md` (v0.1), reviewed against `plans/greet-options/feature-greet-options-spec.md` (v0.3) and `plans/greet-options/feature-greet-options-brief.md`.

Date: 2026-11-19

Mode: `tasks`, RECHECK of `plans/greet-options/reports/tasks/review-4.md`. This round checks (a) each P0 and P1 finding of review-4, marked `fixed` or `open`, and (b) new P0 or P1 problems the fix round introduced. The ten P2 findings of review-2 were closed in review-3 and are not re-litigated here.

Note on the report series: `review-5.md` and `review-6.md` are still `verdict: pending` skeletons, so review-4 is the last completed review and the current file state is what this round re-checks. The narrow scope in `plans/greet-options/reports/tasks/fix-scope-2.md` was used as a hint list but the full recheck rules of the skill were applied, since the prompt names review-4 as the RECHECK target.

## Mechanical checks

`bash .dostuff/scripts/check-plan.sh plans/greet-options` → exit 0, no FAIL, no WARN.

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 35 REQ/SEC ids, 18 tasks.
OK
```

Id coverage was re-verified mechanically against the spec: all 35 REQ/SEC ids and all 31 TEST ids in the spec appear in the tasks file, and no id appears on only one side. Every TEST id appears in at least one task's Tests column. Every phase holds at most 2 tasks (`MAX_UNIT_TASKS=2` in `.dostuff/pipeline.conf`).

The script does not compare the traceability table against the tasks' Spec columns, so the drift in F17 below is invisible to it.

## Part A: review-4 P0 and P1 findings

### F15 [P1] tasks.md:72 (TASK-010) TASK-010's new `--times` assertion required a value conversion its Green step never introduced — **fixed** (carried, confirmed still closed)

review-4 already recorded this as fixed. I re-verified it: the repeated-flag cases live in the units that own each value's semantics. TASK-030's Red writes `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }` (tasks.md:99) and its Green introduces the `Number` conversion, so the Red is genuine. TASK-031's Red writes `parseArgs(['--lang', 'es', '--lang', 'fr'])` returns `{ lang: 'fr' }` and `parseArgs(['--format', 'json', '--format', 'text'])` returns `{ format: 'text' }` (tasks.md:100), and its Green introduces the membership check. TASK-010's Green says the `--times`, `--lang` and `--format` values "are read as raw strings, without the conversion and the membership check that TASK-030 and TASK-031 add" (tasks.md:73). No unit contains a Red that passes before its own code exists. Still closed.

### F16 [P1] tasks.md:73, :87, :113 No task's Green step makes `parseArgs` recognise `--shout` and return `{ shout: true }` — **fixed**

The fix is complete and lands in the right place.

- TASK-010's Red step now asserts it: "`parseArgs(['--shout'])` returns `{ shout: true }` with no error, because `--shout` is a flag that takes no value and its presence sets `shout` to `true`" (tasks.md:73).
- TASK-010's Green step now states it: "`parseArgs` recognises `--shout` as a long flag that takes no value: when it is present the returned object holds `shout: true`, and when it is absent the key is absent from the object, as with every other flag (REQ-015). This task owns the parsing of `--shout`; the upper-casing it causes is built in TASK-041" (tasks.md:73).
- REQ-015 is in TASK-010's Spec column (tasks.md:73).
- The ownership is written down, not left to the implementer, so TASK-041's Red step (the binary run with `--shout --name Ada` prints `HELLO, ADA\n`, tasks.md:113) now has a named owner for the parsed flag.

Both readings review-4 warned about are closed: `parseArgs` recognises `--shout`, and the shape of the parsed object is pinned by a unit assertion in the unit that builds it.

## Part B: new P0 and P1 problems

### F17 [P1] tasks.md:112, :125, :126 No task's Green step puts `times` or `format` into the settings object, so TASK-050's and TASK-051's CLI Red tests have no code path

This is the `times` and `format` wiring gap. It was not caught by review-2, review-3 or review-4, and it is not a regression of the fix round, but it is a P1: the plan cannot be built as written without the implementer guessing.

`render(settings)` reads `settings.times` and `settings.format` (spec.md §4.1: "In `text` format: the greeting repeated `settings.times` times"; "In `json` format: the line `{"greeting": "<repeated greeting>"}`"). The spec names `mergeSettings` as the producer of the settings object, but `mergeSettings` is built in TASK-061 (Phase 6) and only reaches `bin/greet.js` in TASK-070 (Phase 7). Phases 5 and 6 therefore need a temporary producer inside `bin/greet.js`, and that producer is only partly specified.

What the tasks actually say:

- TASK-040's Green step (tasks.md:112) is the task that creates the settings object in `bin/greet.js`: "`bin/greet.js` builds the settings from the parsed flags and `DEFAULTS` (name, lang) and prints `resolveGreeting(settings)` instead of `greet(name)`; the name and the language are read from the flags when the key is present and from `DEFAULTS` otherwise." It names two keys, `name` and `lang`.
- TASK-041's Green step (tasks.md:113) adds a third: "`bin/greet.js` passes `shout` from the parsed flag, which is `true` only when `--shout` was given, and `DEFAULTS.shout` otherwise."
- TASK-050's Green step (tasks.md:125) says only: "`src/options.js` gains `render(settings)`, which calls `resolveGreeting` once and returns the whole stdout payload as one string: in text format the greeting repeated `settings.times` times, each repetition followed by a newline. `bin/greet.js` writes the payload with `process.stdout.write(payload)` and stops using `console.log`." It never says where `settings.times` comes from.
- TASK-051's Green step (tasks.md:126) says only how the json line is built. It never says where `settings.format` comes from.

The Red steps that need the missing wiring:

- TASK-050's Red step (tasks.md:125): "the binary run with `--name Ada --times 3` prints three identical lines `Hello, Ada` on stdout and exits 0; the binary run with `--name Ada --times 2 --lang es` prints `Hola, Ada` on two lines."
- TASK-051's Red step (tasks.md:126): "the binary run with `--format json --name Ada` prints `{"greeting": "Hello, Ada"}\n` and exits 0; with `--name Ada --format json --times 2` it prints one line that `JSON.parse` reads back as an object whose `greeting` value is `Hello, Ada` and `Hello, Ada` joined by a newline".

An implementer who follows TASK-040's Green literally builds a settings object with `name`, `lang` and (from TASK-041) `shout`, and no `times` and no `format`. TASK-050's CLI Red then prints one line, not three, because `settings.times` is `undefined`; TASK-051's CLI Red prints the text greeting, not the JSON line, because `settings.format` is `undefined`. Both units fail to go green on the plan's own instructions.

The one place a rule covers this is the Decisions row (tasks.md:48): "Phases 4 to 6 read the flag values in `bin/greet.js` and fall back to `DEFAULTS` there." That row is the right home for the rule, but it contradicts the more specific TASK-040 wording ("`DEFAULTS` (name, lang)"), and neither TASK-050 nor TASK-051 points back to it. A reader has to choose between the narrow task text and the general decisions row.

Fix: state the wiring where the settings object is built and where each key is added. The smallest change is to widen TASK-040's Green step to name all five keys, for example "`bin/greet.js` builds the settings from the parsed flags and `DEFAULTS` (name, lang, shout, times, format)", and to add one clause to TASK-050's Green step, "`bin/greet.js` puts the parsed `times` into the settings, falling back to `DEFAULTS.times`, so `render` repeats the greeting that many times", and to add the matching clause to TASK-051's Green step for `format`. Alternatively, give `times` and `format` their own owner task between TASK-040 and TASK-050.

### F18 [P1] tasks.md:139 The whitespace-only config name fallback has a rule but no test, so REQ-034 and TEST-005 are partly untested

This is a coverage gap the earlier reviews missed, and it is the kind the conformance check will grade as Untested.

REQ-034 requires: "a `name` that is not a non-empty string, or **a `name` that holds only whitespace**, a `shout` that is not a boolean, a `times` that is not a whole number in 1 to 5, a `lang` or `format` that is not a string, or a `lang` or `format` whose trimmed, lower-cased string value is not one of the allowed values, then that single value falls back to its built-in default and the other config values still apply."

The spec's TEST-005 lists the same case as one that must be tested: "a config `name` of only whitespace" (spec.md:348). Spec §3 repeats the rule: "The one exception is a name that holds only whitespace: that is not a valid name, so it falls back to the default `world` (D-12, REQ-034)" (spec.md:175).

The rule is stated in TASK-061's Green step (tasks.md:139): "The config `name` is valid when it is a non-empty string that is not only whitespace, and is used verbatim." But it appears in no Red step anywhere in the file. I checked every Red step for the words "whitespace" and for a whitespace-only name literal: the only hit for "only whitespace" in the whole file is TASK-061's Green step, and no task's Red step contains the case.

TASK-061's Red step (tasks.md:139) covers every other branch of the rule: "a config `name` of `''` resolves to `world`; a config `name` of `'  Ada  '` resolves to `'  Ada  '`, untrimmed; a config `name` of `42` or of `true` resolves to `world`; a config `shout` of `'true'` or of `'false'` resolves to `false`; a config `times` of `0`, of `6`, of `2.5` or of `'2'` resolves to `1`; a config `lang` of `42` or of `true` resolves to `en`; a config `format` of `42` resolves to `text`; a config `lang` of `'de'` resolves to `en`; a config `format` of `'xml'` resolves to `text`". The whitespace-only name is the single missing branch.

The gap is not cosmetic, because the case is easy to get wrong: `'  Ada  '` is valid and kept verbatim, while `'   '` is invalid and falls back to `world`, so the two differ only in whether the string is entirely whitespace. TASK-061's Red step already has the neighbouring case, so the fix is one assertion.

Fix: add one case to TASK-061's Red step, for example "a config `name` of `'   '` (only whitespace) resolves to `world`", or add a CLI case to TASK-071's Red step, for example "run in a directory holding `{"name": "   "}` it prints `Hello, world\n`".

### F19 [P1] tasks.md:86, :99 Two units with the same `depends:` set list the same files, so they cannot run as siblings

Phase 2 (`depends: 1`, tasks.md:80) and Phase 3 (`depends: 1`, tasks.md:93) have identical `depends:` sets, and their Files columns overlap on two files:

- Phase 2: TASK-020 lists `src/options.js, test/options.test.js, test/cli.test.js` (tasks.md:86); TASK-021 lists the same three (tasks.md:87).
- Phase 3: TASK-030 lists `src/options.js, test/options.test.js` (tasks.md:99); TASK-031 lists the same two (tasks.md:100).

The skill's rule is that "Units that share the same `depends:` set must list disjoint files". Phase 2 and Phase 3 share `src/options.js` and `test/options.test.js`, so two units that the dependency graph allows to run in parallel would both write the parser module and both append to the same unit test file. The plan is also wrong on the substance: TASK-020's Red step asserts `parseArgs(['--name', '--shout'])` throws `UsageError` and TASK-021's Red step asserts `parseArgs(['--shout=true'])` throws `UsageError`, so TASK-021 depends on TASK-020's rule that a `--`-prefixed value is a missing value (TASK-021's Green step says so explicitly: "a single-dash argument in value position is an ordinary value (TASK-020)"), but nothing in the graph says Phase 2's two tasks, or Phase 3's two tasks, are ordered against each other.

The current runner picks the first unit in file order with an open task, so the build does not break today. The declared graph is still wrong, and the file overlap is exactly the condition the rule exists to catch.

Fix: give the units a real order, for example Phase 2 `depends: 1` and Phase 3 `depends: 1, 2`, which also matches the fact that TASK-031's `--format` and `--lang` membership check and TASK-030's `--times` conversion both sit on the same `parseArgs` that TASK-020 and TASK-021 shape. Alternatively, split the shared files so that the two phases touch disjoint files.

## Part C: traceability table drift against the tasks' Spec columns

The traceability table and the tasks' Spec columns disagree on three REQ ids. The check-plan script does not compare the two, so this is invisible to it. These are drift, not missing coverage: every id has an owner either way, so I grade them P2.

- **REQ-005** — table (tasks.md:190) reads `| REQ-005 | TASK-020, TASK-090 |`, but TASK-090's Spec column (tasks.md:177) is `REQ-023, REQ-024`. TASK-090 is the newline-name task; it never asserts a missing flag value, so TASK-090 does not build REQ-005. Fix: drop TASK-090 from the REQ-005 row.
- **REQ-010** — table (tasks.md:193) reads `| REQ-010 | TASK-050, TASK-051 |`, but TASK-051's Spec column (tasks.md:126) is `REQ-015, REQ-022, REQ-023, D-03`. TASK-051 does build REQ-010's JSON half (its Red step writes "`render` with `format: 'json'` and `times: 2` returns `{"greeting": "Hello, Ada\nHello, Ada"}\n`"), so the table is right and the Spec column is short. Fix: add REQ-010 to TASK-051's Spec column. (This is the same drift review-3's F09 half-fixed: only the table row was changed.)
- **REQ-015** — table (tasks.md:198) reads `| REQ-015 | TASK-010, TASK-041, TASK-051 |`, but TASK-080's Spec column (tasks.md:164) is `REQ-015, REQ-031, RISK-005`. TASK-080's Red step asserts the JSON half of REQ-015 ("run in the same directory with `--name Ada --format json` it prints `{"greeting": "HELLO, ADA"}\n`"), so the table is short. Fix: add TASK-080 to the REQ-015 row.

## Coverage check

All 35 REQ and SEC ids in the spec are referenced by at least one task and by the traceability table, and all 31 TEST ids are referenced by at least one task. Both sets were compared mechanically against the spec and match exactly. Every TEST id appears in at least one task's Tests column.

Every phase holds at most 2 tasks, within `MAX_UNIT_TASKS=2`. Every task's Files column names each file its Red, Green and code-review steps touch. The `depends:` graph is correct in substance, except for the Phase 2 and Phase 3 overlap in F19.

Two parts of requirements are untested: the whitespace-only config name (F18), and, as recorded in Part C, the traceability rows for REQ-005, REQ-010 and REQ-015 name owners that the Spec columns do not agree with.

SUMMARY
verdict: fail
p0: 0
p1: 3
p2: 3
top:
- No task's Green step puts `times` or `format` into the settings object, so TASK-050's and TASK-051's CLI Red tests have no code path (F17)
- The whitespace-only config name fallback has a rule in TASK-061's Green but no test, leaving REQ-034 and TEST-005 partly untested (F18)
- Phase 2 and Phase 3 share the `depends: 1` set and list the same files, so they cannot run as siblings (F19)
report: plans/greet-options/reports/tasks/review-7.md
