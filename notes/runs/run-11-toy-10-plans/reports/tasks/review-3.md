# tasks/review-3.md

Target: `plans/greet-options/feature-greet-options-tasks.md`
Spec: `plans/greet-options/feature-greet-options-spec.md` (v0.4)
Brief: `plans/greet-options/feature-greet-options-brief.md`
Mode: tasks (RECHECK)
Date: 2026-11-20
Previous report: `plans/greet-options/reports/tasks/review-2.md`
Fix round: commit `2fb7a56` (docs(greet-options): tasks round 3)

Scope of this round: check each P0 and P1 finding of the previous report as `fixed` or `open`, and report new P0 or P1 problems the fix round introduced. New P2s are not reported except where the fix round created them; the old P2s are carried over unchanged.

## Mechanical check

`bash .dostuff/scripts/check-plan.sh plans/greet-options`:

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 50 REQ/SEC ids, 15 tasks.
OK
```

Exit 0. No FAIL, no WARN. The task count dropped from 16 to 15 because TASK-203 was folded into TASK-202.

## Previous findings

F01 [P0] `depends: none` fails the check script. **fixed** (carried from round 2, still fixed).

F02 [P0] `TASK-203` and `TASK-204` referenced but never declared. **fixed** (carried from round 2, still fixed). Both ids are gone or declared: `grep -n 'TASK-203'` over the tasks and spec files returns nothing, and the 15 declared task rows are TASK-101, 102, 201, 202, 204, 301, 302, 401, 402, 501, 502, 601, 602, 701, 702. Every `TASK-nnn` referenced in the file is one of those 15 and every declared task appears in the traceability table, so the id set is closed in both directions.

F03 [P1] No task builds the JSON branch of `renderOutput`. **fixed** (carried from round 2, still fixed). TASK-204 remains the JSON unit and is unchanged in substance.

F04 [P1] TASK-702 contradicts TASK-301 on the `unknown-key` fixture. **fixed** (carried from round 2, still fixed).

F05 [P1] No test covers a value-taking flag given without its value other than `--name`. **fixed** (carried from round 2, still fixed).

F06 [P1] TASK-302 lists REQ-076 with no Red test for the config `shout: true` case. **fixed** (carried from round 2, still fixed).

F07 [P1] The config `format` key has no test. **fixed** (carried from round 2, still fixed).

F08 [P2] The Decisions row's "and their reason prefixes" disagrees with TASK-101's Green. **fixed**. Line 38 now reads "...with their kind (boolean or value) and their allowed values." The clause "and their reason prefixes" is gone, so the row now agrees with TASK-101's Green, which describes `OPTION_SPECS` entries as naming "the flag, whether it takes a value, and its allowed values". The row was rewritten by the fix round (`git diff 0b474a9 2fb7a56`, line 38).

F09 [P2] The Decisions row cites GUD-003 for the `OPTION_SPECS` decision. **fixed**. Line 38 now cites `(RISK-004, GUD-001)`. That matches the spec: GUD-001 is "All logic lives in `src/greet.js` as plain exported functions, matching the existing one-file layout" and RISK-004's mitigation is "the option list lives in one place in `src/greet.js` (GUD-001)". GUD-003 is the greeting-word map, which no longer appears in the row.

F10 [P2] Units sharing a `depends:` set list overlapping Files. **fixed**. Every task's Files cell now names the specific addition instead of the bare path, so sibling units no longer list an identical Files set. Phase 2a lists `src/greet.js (adds buildGreeting)` and `src/greet.js (adds renderOutput)`; Phase 2b lists `src/greet.js (adds the json branch to renderOutput)`; Phase 3 lists `src/greet.js (adds loadConfig)` and `src/greet.js (adds mergeOptions)`; Phase 4 lists `bin/greet.js (replaces the ad-hoc --name lookup with the pipeline)` and `src/greet.js (adds formatUsage), bin/greet.js (adds the try/catch and the usage-error path)`. The change was made by the fix round across all 15 task rows.

F11 [P2] TASK-203's two Red cases already pass once TASK-202's Green is in place. **fixed**. TASK-203 was deleted and its two cases were folded into TASK-202 as an explicit `**Guard:**` block (line 84): "**Guard:** add unit tests ... that the repeat count is exact in the text format, so `renderOutput({ ...DEFAULT_OPTIONS, times: 3 }, { line: 'Hello, world', count: 3 })` returns `Hello, world\nHello, world\nHello, world\n` ... These two cases already pass once the Green above is in place, because the Green repeats `greeting.line` `greeting.count` times and appends a single trailing `\n`, so they guard that behaviour rather than add new behaviour." The label now matches the writing-tasks rule, and the traceability table was updated in step: REQ-030 is `TASK-202, TASK-401`, REQ-031 is `TASK-202, TASK-204`, REQ-033 is `TASK-202, TASK-401` (previously REQ-030 `TASK-202, TASK-203, TASK-401` and REQ-033 `TASK-203, TASK-401`). REQ-033 still has both a unit test (TASK-202's Guard compares the `times: 1` render against the `DEFAULT_OPTIONS` render) and a route test (TASK-401 asserts `greet --times 1` prints the same bytes as `greet` with no arguments), so nothing lost its test.

## New findings

No new P0 or P1 problems were found in the text the fix round changed.

Checks run over the changed text:

- The unit and phase graph stays valid after the fold. `parse_tasks` maps unit `2a` and unit `2b` both to phase `2`, so Phase 4's `depends: 1, 2, 3` still resolves (the check script's grammar pass confirms it). `phase-done.sh` sets `last[2]` to the last unit seen in phase 2, which is `2b`, so phase 2 completes only after 2b. `next-unit.sh` picks the first unit in file order with an open task, so 2a runs before 2b; `depends:` is not used to reorder the run, so the `depends: 1` on Phase 2b is a validation statement rather than a scheduling one. This is consistent with the runner and was already noted in round 2.
- `MAX_UNIT_TASKS` is 2 and every unit still has at most two tasks after the fold (Phase 2a has TASK-201 and TASK-202, Phase 2b has TASK-204 alone).
- Traceability is complete and closed: all 50 spec REQ/SEC ids appear in the traceability table, and every task id referenced in the table is declared. No dangling `TASK-203` remains in either the tasks file or the spec.
- The fixture inventory is consistent. The Decisions row (line 42) names 18 fixture directories, and the union of the Files columns names exactly the same 18. Each task's own Red cases map to fixtures in its own Files column: TASK-301 lists `no-config`, `empty-config`, `unknown-key`, `invalid-json`, `top-level-array`, `top-level-null`, `bad-lang`, `bad-shout`, `bad-format`, `good-format`, `name-number`, `name-empty`, `times-zero`, `times-string`, `times-fraction`; TASK-602 lists `bad-lang`, `name-empty`, `name-number`, `top-level-array`, `times-six`; TASK-601 lists `name-ada-lang-es` and `parent-has-config`; TASK-702 lists `unknown-key`.
- The plan's claims about the code still hold. `src/greet.js` is the one-file module with `greet(name)` and `module.exports = { greet }` (as TASK-101's Green requires); `bin/greet.js` still does the ad-hoc `--name` lookup that TASK-401 replaces; `test/greet.test.js` has the three existing tests named in TASK-401; `package.json` runs `npm test` as `node --test`.
- The spec's contract for `renderOutput(options, greeting)` and `buildGreeting(options)` matches the task text: the text branch repeats `greeting.count` times each followed by `\n` (REQ-050, REQ-031), the json branch returns `JSON.stringify({ greeting: value }) + '\n'` with the one key `greeting` (REQ-051 to REQ-056), and `buildGreeting` returns `{ line, count }` with `count` being `options.times` (REQ-030).

One carried-forward observation is unchanged and is not re-reported: the plan's own unit tests are the conformance evidence for the spec ids, so REQ-050 appearing on both TASK-202 and TASK-204 is correct (TASK-204 pins the text branch stays as it is while adding the json branch), and the duplicate JSON assertions between TASK-204 (unit) and TASK-402 (route) are the intended unit-plus-route pairing the spec's TEST-009 and TEST-013 ask for.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
top:
- All four P2 findings from review-2 (F08, F09, F10, F11) are fixed by commit `2fb7a56`; no P0 or P1 findings were open, and none were introduced.
- F11 fixed: TASK-203 was deleted and its two cases folded into TASK-202 as an explicit `**Guard:**` block that states they already pass once the Green is in place.
- F08 and F09 fixed: the Decisions row no longer mentions "reason prefixes" and now cites `(RISK-004, GUD-001)` instead of GUD-003.
- F10 fixed: every task's Files cell now names the specific addition, so sibling units sharing a `depends:` set no longer list identical Files.
- The check script exits 0 with no FAIL and no WARN: 50 REQ/SEC ids, 15 tasks, all ids traced and closed.
report: plans/greet-options/reports/tasks/review-3.md
