# tasks/review-2.md

Target: `plans/greet-options/feature-greet-options-tasks.md`
Spec: `plans/greet-options/feature-greet-options-spec.md` (v0.4)
Brief: `plans/greet-options/feature-greet-options-brief.md`
Mode: tasks (RECHECK)
Date: 2026-11-20
Previous report: `plans/greet-options/reports/tasks/review.md`
Fix round: commit `0b474a9` (docs(greet-options): tasks round 2)

Scope of this round: check each P0 and P1 finding of the previous report as `fixed` or `open`, and report new P0 or P1 problems the fix round introduced. New P2s are not reported except where the fix round created them; the old P2s are carried over unchanged.

## Mechanical check

`bash .dostuff/scripts/check-plan.sh plans/greet-options`:

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 50 REQ/SEC ids, 16 tasks.
OK
```

Exit 0. No FAIL, no WARN. The previous FAIL (`depends on unknown unit or phase "none"`) and the previous WARN (`ids referenced but never declared: TASK-203, TASK-204`) are both gone.

## Previous findings

F01 [P0] `depends: none` fails the check script. **fixed**. The `depends: none` line was deleted from Phase 1 (line 66 in the old file). `parse_tasks` now emits `unit 1 1 ` with an empty dependency list, and the script's check skips an empty value.

F02 [P0] `TASK-203` and `TASK-204` referenced but never declared. **fixed**. Both tasks now exist in the new Phase 2b (lines 96 and 97). The traceability table (lines 168-219) now maps every id to tasks that exist, and `grep -oE '^\| TASK-[0-9]+'` yields TASK-101, 102, 201, 202, 203, 204, 301, 302, 401, 402, 501, 502, 601, 602, 701, 702 (16 tasks, matching the script's count).

F03 [P1] No task builds the JSON branch of `renderOutput`. **fixed**. The new TASK-204 (line 97) covers REQ-051 through REQ-056 with Red tests for the single-line JSON value, the joined repeated value, the shout rule, and the exactly-one-key rule, and a Green that implements `format: 'json'` as `JSON.stringify({ greeting: value }) + '\n'`. TASK-402 (line 123) also gained the end-to-end JSON Red cases, so REQ-052 to REQ-056 now have both a unit and a route test.

F04 [P1] TASK-702 contradicts TASK-301 on the `unknown-key` fixture. **fixed**. TASK-702 now expects `Hello, Ada\n` (line 162), which matches the built-in default `lang: 'en'` from TASK-101.

F05 [P1] No test covers a value-taking flag given without its value other than `--name`. **fixed**. TASK-102's Red now asserts `parseOptions(['--times'])`, `parseOptions(['--lang'])` and `parseOptions(['--format'])` each throw the matching `missing value for --<flag>` reason, and its Green says "every flag that takes a value reports the same missing-value error when the value is absent, so no flag is special-cased" (line 71). TASK-502 gained the end-to-end `greet --times`, `greet --lang` and `greet --format` stderr lines (line 136).

F06 [P1] TASK-302 lists REQ-076 with no Red test for the config `shout: true` case. **fixed**. TASK-302's Red now asserts `mergeOptions({ shout: true }, {})` returns `shout: true` and `mergeOptions({ shout: true }, { shout: false })` still returns `shout: true`, plus `mergeOptions({}, { shout: true })` returns `shout: true` (line 110).

F07 [P1] The config `format` key has no test. **fixed**. TASK-301's Red now asserts `loadConfig` throws for `{"format": "xml"}` and returns `{ format: 'json' }` for a fixture holding `{"format": "json"}`, and the Green names the reason `invalid value for format: xml` (line 109). The `bad-format` and `good-format` fixtures are listed in the Decisions row (line 42) and in TASK-301's Files column.

F08 [P2] The Decisions row's "and their reason prefixes" disagrees with TASK-101's Green. **open (pre-existing)**. Line 38 is unchanged by the fix round, so this is carried over as a pre-existing note.

F09 [P2] The Decisions row cites GUD-003 for the `OPTION_SPECS` decision. **open (pre-existing)**. Line 38 is unchanged by the fix round. GUD-003 is the greeting-word map; the option list is RISK-004's mitigation with GUD-001's one-file layout behind it.

F10 [P2] Units sharing a `depends:` set list overlapping Files. **open (pre-existing, not reported again)**. The new Phase 2b shares `depends: 1` with Phase 2a and Phase 3 and lists the same `src/greet.js` and `test/greet.test.js`, so the same observation now also covers 2b. The runner (`next-unit.sh` via `next_unit_of`) works in file order, so this does not block the build.

## New findings

F11 [P2] plans/greet-options/feature-greet-options-tasks.md:96 TASK-203 is a whole task of guard tests labelled `**Red:**`. Both of its Red cases already hold once TASK-202's Green is in place. TASK-202's Green says "For `format: 'text'` return the line repeated `greeting.count` times, each followed by `\n`", and TASK-202's Green even spells out the exact bytes "`--times 3` with the defaults prints `Hello, world\nHello, world\nHello, world\n`". TASK-203's first Red case is `renderOutput({ ...DEFAULT_OPTIONS, times: 3 }, { line: 'Hello, world', count: 3 })` returning `Hello, world\nHello, world\nHello, world\n`, and its second is `times: 1` returning `Hello, world\n`. Both are exactly what TASK-202's implementation produces, and TASK-203's own Green ("repeating `greeting.line` `greeting.count` times and joining the repeats with `\n`, then append a single trailing `\n`") is an equivalent restatement of TASK-202's. Under the writing-tasks rule a test that passes as soon as it is written belongs under `**Guard:**`, and the implementer would otherwise have to log TASK-203 as a Difference under the spec. Fix: relabel TASK-203's two cases as `**Guard:**` with a line saying TASK-202's Green already makes them pass, and move any genuinely new behaviour TASK-203 was meant to add (there is none today) out, or fold TASK-203 into TASK-202 and keep the phase at two tasks.

No new P0 or P1 problems were found in the text the fix round changed. The unit and phase graph stays valid after the split: `parse_tasks` maps unit `2a` and unit `2b` both to phase `2`, so Phase 4's `depends: 1, 2, 3` still resolves, `phase-done.sh` treats `2b` as the last unit of phase 2, and `next-unit.sh` runs units in file order so `2b` completes before Phase 3 and Phase 4. `MAX_UNIT_TASKS` is 2 and every unit still has exactly two tasks.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
top:
- All seven P0 and P1 findings from the previous round are fixed; the check script now exits 0 with no FAIL and no WARN.
- F11 (P2, new): TASK-203's two Red cases already pass once TASK-202's Green is in place, so they should be labelled `**Guard:**` rather than `**Red:**`.
- F08 and F09 (P2, pre-existing, unchanged text): the Decisions row still says "and their reason prefixes" and still cites GUD-003.
report: plans/greet-options/reports/tasks/review-2.md
