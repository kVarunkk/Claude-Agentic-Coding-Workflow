# tasks/review-3.md

Target: `plans/greet-options/feature-greet-options-tasks.md` (v0.1), reviewed against `plans/greet-options/feature-greet-options-spec.md` (v0.3) and `plans/greet-options/feature-greet-options-brief.md`.

Date: 2026-11-19

Mode: `tasks`, RECHECK of `plans/greet-options/reports/tasks/review-2.md`. This round checks (a) each P0 and P1 finding of review-2, marked `fixed` or `open`, and (b) new P0 or P1 problems the fix round introduced. The ten P2 findings of review-2 are carried over unchanged and are not re-litigated here.

## Mechanical checks

`bash .dostuff/scripts/check-plan.sh plans/greet-options` → exit 0, no FAIL, no WARN.

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 35 REQ/SEC ids, 18 tasks.
OK
```

## Part A: review-2 P0 and P1 findings

### F01 [P1] tasks.md:72 (TASK-010) REQ-003 tested only for `--name` — **fixed**

TASK-010's Red step now writes all four repeated-flag cases: `parseArgs(['--name', 'Bob', '--name', 'Ada'])` returns `{ name: 'Ada' }`; `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }`; `parseArgs(['--lang', 'es', '--lang', 'fr'])` returns `{ lang: 'fr' }`; `parseArgs(['--format', 'json', '--format', 'text'])` returns `{ format: 'text' }`. REQ-003 is now covered for all four flags.

The fix introduced a new defect, reported below as F15.

### F02 [P1] tasks.md:86 (TASK-021) TEST-016's `--shout=true` case never written — **fixed**

TASK-021's Red step now writes `parseArgs(['--'])`, `parseArgs(['-n'])`, `parseArgs(['-x'])` and `parseArgs(['--shout=true'])` all throwing `UsageError`, plus the CLI case "the binary run with `--shout=true` has empty stdout, exactly one usage line on stderr and exit code 2". All three halves of spec TEST-016 (`:359`) are now written.

### F03 [P1] tasks.md:85 (TASK-020) TEST-028's CLI half never written — **fixed**

TASK-020's Red step now writes, in `test/cli.test.js`: "the binary with `--name -x` prints `Hello, -x\n` on stdout, nothing on stderr and exits 0, so a value starting with a single dash is an ordinary value". Both halves of spec TEST-028 (`:371`) are now written.

### F04 [P1] tasks.md:85, :51 (TASK-020, Decisions table) Plan decides nothing about a repeated `--name` ending empty, nor about `--name=--foo` — **fixed**

A new Decisions row was added at tasks.md:51 ("When a flag value is validated, and the `--`-prefix rule"), stating that the value of the last occurrence is the one validated (`parseArgs(['--name', 'Ada', '--name', ''])` raises `UsageError`) and that the `--`-prefix rule applies to the equals form too (`parseArgs(['--name=--foo'])` raises `UsageError`). Both assertions were written into TASK-020's Red step at tasks.md:85. TASK-020's Green step was also updated to say "in the space form and in the equals form alike".

## Part B: new P0 and P1 problems introduced by the fix round

### F15 [P1] tasks.md:72 (TASK-010) TASK-010's new `--times` assertion requires a value conversion its Green step never introduces, and the two readings of it break TASK-030

TASK-010's Red step now demands `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }`, that is the **number** 4. But TASK-010's Green step (tasks.md:72) says only that `parseArgs` "takes only the argument list, never reads `process.argv`, returns an object holding only the keys whose flags were present, and treats the last occurrence of a repeated flag as the value". It says nothing about converting a `--times` value to a number; the conversion is introduced later, by TASK-030's Green step ("converts it with `Number`"). The two readings of TASK-010 both break something:

- If TASK-010 stores the raw string, its own new assertion fails. I confirmed this with a prototype built to TASK-010's Green text only: `assert.deepStrictEqual(parseArgs(['--times','3','--times','4']), {times: 4})` fails with "Expected values to be strictly deep-equal", because the parsed value is the string `'4'`.
- If TASK-010 converts with `Number` to make the assertion pass, TASK-030's Red step becomes partly a false Red. TASK-030's first assertion is `parseArgs(['--times', '3'])` returns `{ times: 3 }`, which that implementation already satisfies, so the unit is labelled `**Red:**` while its first Red step already passes. The same applies to TASK-031's first assertion `parseArgs(['--lang', 'es'])` returns `{ lang: 'es' }`.

The `--lang` and `--format` repeated-flag cases are less acute (their expected values happen to equal the raw strings), but the plan still has no statement saying that TASK-010 stores `--lang` and `--format` values unvalidated, which TASK-031's Green ("`parseArgs` matches the `--lang` value against the keys of `LANGS`") presents as its own work.

This is the same class of defect review-2 raised as F04: a choice the implementer would otherwise have to guess, not written down. The fix round moved the assertion, but did not move the decision with it.

Fix: pick one and write it down. The smallest change is to move the `--times`, `--lang` and `--format` repeated-flag cases out of TASK-010 and into the units that own those flags' semantics, since TASK-030 and TASK-031 already write `parseArgs(['--times', '3'])`, `parseArgs(['--lang', 'es'])` and `parseArgs(['--format', 'json'])` as their first Red assertions: add to TASK-030's Red step `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }` with no error, and to TASK-031's Red step `parseArgs(['--lang', 'es', '--lang', 'fr'])` returns `{ lang: 'fr' }` and `parseArgs(['--format', 'json', '--format', 'text'])` returns `{ format: 'text' }`, both with no error; leave only the `--name` repeated case in TASK-010; add REQ-003 to TASK-030's and TASK-031's Spec columns. TASK-010 keeps REQ-003, so the traceability row for REQ-003 becomes `TASK-010, TASK-030, TASK-031`. The alternative, keeping the cases in TASK-010, is to add one sentence to TASK-010's Green step saying that a `--times` value is converted with `Number` and that `--lang` and `--format` values are stored as given without a membership check, and to relabel the matching TASK-030 and TASK-031 assertions as `**Guard:**` with the reason.

## Part C: review-2 P2 findings, carried over unchanged

F05 (five units marked `**Red:**` whose tests already pass), F06 (`depends:` lines understate the Phase 3 dependency), F07 (TASK-081 writes `greet.config.json` into the shared system temp directory), F08 (the Decisions row's claim that the repo directory is never a test working directory), F09 (REQ-010 does not list TASK-051), F10 (TASK-081's Files column omits `src/options.js`), F11 (TASK-021's Green wording reads as a contradiction of TASK-020), F12 (the `times` grammar Decisions row states an untested behaviour), F13 (Review focus item 2 names TASK-070 for the config `shout` case), F14 (TASK-091 asserts the seeded test is the only failing test in the suite).

The fix round addressed every one of these. The ten P2 findings are therefore closed, but they are recorded here as carried over per the recheck rules, and the writer should confirm each against the file:

- F05 fixed: TASK-071, TASK-080, TASK-081, TASK-090 and TASK-091 are now `**Guard → Green:**` with a one-line reason each (tasks.md:151, :163, :164, :176, :177). All other 13 units remain `**Red → Green:**`, verified by scanning every task row.
- F06 fixed: Phase 4 is `depends: 1, 3` (:105), Phase 5 is `depends: 3, 4` (:118), Phase 9 is `depends: 3, 5, 7` (:170).
- F07 fixed: TASK-081 now creates a dedicated parent with `fs.mkdtempSync(path.join(os.tmpdir(), 'greet-parent-'))`, puts the config there, creates the child working directory inside that parent, and removes both in the same cleanup (:164).
- F08 fixed: the Decisions row (:41) now names `test/greet.test.js` as the one exception and says what happens if the repo root holds a config file.
- F09 fixed: the traceability row reads `| REQ-010 | TASK-050, TASK-051 |` (:192).
- F10 fixed: TASK-081's Files column is `src/config.js, src/options.js, bin/greet.js, test/cli.test.js` (:164).
- F11 fixed: TASK-021's Green now reads "a single-dash argument that is not consumed as a preceding flag's value is an unknown flag, while a single-dash argument in value position is an ordinary value (TASK-020)" (:86).
- F12 fixed: `parseArgs(['--times', '03'])` returns `{ times: 3 }` is now written in TASK-030's Red step (:98).
- F13 fixed: Review focus item 2 now reads "Test in TASK-080." (:59).
- F14 fixed: TASK-091's Green now says "the seeded trimming test in `test/zz-seeded.test.js` still fails, because REQ-017 and D-16 forbid trimming", with the "only failing test in the suite" clause gone (:177).

## Coverage check

All 35 REQ and SEC ids in the spec are referenced by at least one task and by the traceability table; all 31 TEST ids are referenced by at least one task. Both sets were compared mechanically against the spec and match exactly, with no id on one side only.

Every phase holds at most 2 tasks, within `MAX_UNIT_TASKS=2` from `.dostuff/pipeline.conf`. Every task's Files column names each file its Red, Green and code-review steps touch.

The one gap found this round is inside a cited requirement, not a missing row: REQ-003's four-flag coverage now exists, but the `--times` half of it lands in a unit whose Green step does not build it (F15).

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
top:
- TASK-010's new `--times` repeated-flag assertion needs a number conversion its Green step never introduces, and either reading of it breaks TASK-030 (F15)
report: plans/greet-options/reports/tasks/review-3.md