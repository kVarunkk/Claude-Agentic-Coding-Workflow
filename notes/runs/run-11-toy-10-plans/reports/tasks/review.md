# tasks/review.md

Target: `plans/greet-options/feature-greet-options-tasks.md`
Spec: `plans/greet-options/feature-greet-options-spec.md` (v0.4)
Brief: `plans/greet-options/feature-greet-options-brief.md`
Mode: tasks
Date: 2026-11-20
Reviewer note: `depends: none` is not a valid value for the `depends:` line the check script parses (it reads the value after `depends:` as a comma-separated list of unit ids and compares each against the declared unit ids). An empty `depends:` line is the correct way to say "no dependency".

## Mechanical check

`bash .dostuff/scripts/check-plan.sh plans/greet-options`:

```
WARN: ids referenced but never declared:
  TASK-203
  TASK-204
FAIL: tasks grammar:
  unit 1: depends on unknown unit or phase "none"
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 50 REQ/SEC ids, 14 tasks.
```

Every `FAIL` is a P0.

## Findings

F01 [P0] plans/greet-options/feature-greet-options-tasks.md:66 `depends: none` makes the check script fail: `FAIL: tasks grammar: unit 1: depends on unknown unit or phase "none"`. The script parses the text after `depends:` as a comma-separated list of unit ids and checks each against the declared units; `none` is not one. Fix: delete the `depends: none` line on line 66 (an empty `depends:` value means "no dependency", and the script skips an empty value).

F02 [P0] plans/greet-options/feature-greet-options-tasks.md:170-182 The traceability table maps REQ-030, REQ-031, REQ-033, REQ-050, REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-056 and REQ-002 partly to `TASK-203` and `TASK-204`, and the "Review focus" section at line 60 names `TASK-204`, but neither task exists anywhere in the file: `grep -oE '^\| TASK-[0-9]+'` yields only TASK-101, 102, 201, 202, 301, 302, 401, 402, 501, 502, 601, 602, 701, 702. The check script reports `WARN: ids referenced but never declared: TASK-203, TASK-204`. Fix: add the two missing tasks (see F03) or delete the references and re-map the ids to the tasks that really do build them.

F03 [P1] plans/greet-options/feature-greet-options-tasks.md:86,112 No task builds the JSON branch of `renderOutput`, so REQ-052, REQ-053, REQ-054 and REQ-056 have no test that will fail if the behaviour is wrong. TASK-202's Red covers only the text branch (`renderOutput` returning the line repeated `count` times); it names TEST-009, but the spec's TEST-009 (spec line 425) asserts four things, of which two are JSON: `{"greeting":"Hello, world"}\n` and `{"greeting":"Hello, world\nHello, world"}\n`. TASK-402's Red asserts only `greet --format json` printing `{"greeting":"Hello, world"}\n` for the default name, lang and times. Nothing asserts: (a) the JSON value holds the repeated lines joined by `\n` when `times` is greater than 1 (REQ-053), (b) the JSON object has exactly the one key `greeting` in any combination of options (REQ-054), (c) the JSON value follows the shout rule, e.g. `--format json --shout` printing `{"greeting":"HELLO, ADA"}` (REQ-056). The spec's TEST-013 and TEST-014 both cover these and are listed in the tasks' Spec columns, but no Red text implements them. Fix: add a task (Phase 2, so it needs no new dependency) whose Red covers the spec's TEST-009 JSON cases and TEST-013's `--format json --shout` case, and whose Green implements `renderOutput`'s `format: 'json'` branch as `JSON.stringify({ greeting: value }) + '\n'` with `value` the single line or the lines joined by `\n`.

F04 [P1] plans/greet-options/feature-greet-options-tasks.md:151 TASK-702 contradicts TASK-301 on the same fixture. TASK-301 defines the fixture `test/fixtures/unknown-key/greet.config.json` as holding `{"name": "Ada", "unknownKey": 1}` and asserts `loadConfig` returns `{ name: 'Ada' }`. TASK-702 then asserts that a run in that fixture directory "still prints `Hola, Ada\n`". With `lang` unset the merged record uses the built-in default `en`, so the CLI prints `Hello, Ada\n`, not `Hola, Ada\n`. The two tasks cannot both be implemented. Fix: change TASK-702's expected output to `Hello, Ada\n`, or give TASK-702 its own fixture that sets `"lang": "es"` alongside the unknown key and list that fixture in TASK-702's Files column.

F05 [P1] plans/greet-options/feature-greet-options-tasks.md:73,124,125 No task tests a value-taking flag that is missing its value other than `--name`. REQ-074 (spec line 95) names `greet --times` explicitly ("a flag given without its value such as `greet --name` or `greet --times`"), and the spec's §4.1 gives the same rule for `--lang` and `--format`. The plan's Red tests cover `--name` with no value only, so a parser that special-cases `--name` and crashes or misbehaves on `--times`, `--lang` or `--format` with no value passes every test in the plan. Fix: add `--times`, `--lang` and `--format` with no value to TASK-102's Red list (expected reason `missing value for --times` and so on), and add the `--times` case to TASK-502's end-to-end stderr assertions.

F06 [P1] plans/greet-options/feature-greet-options-tasks.md:99 TASK-302 lists REQ-076 in its Spec column but has no Red test for it. REQ-076's second half is that a `shout: true` from `greet.config.json` cannot be turned off by a flag. TASK-302's Green states "A flag may only set `shout` to `true`, never to `false`, so a `shout: true` from the config stays on", but its Red only asserts `mergeOptions({ name: 'Config', lang: 'es' }, { name: 'Flag' })` and `mergeOptions({}, {})`. A `mergeOptions` that lets a flag set `shout: false`, or that drops the config's `shout`, passes the plan's tests. Fix: add to TASK-302's Red: `mergeOptions({ shout: true }, {})` returns `shout: true`, and `mergeOptions({ shout: true }, { shout: false })` still returns `shout: true`.

F07 [P1] plans/greet-options/feature-greet-options-tasks.md:98 The config `format` key has no test. TASK-301's Green requires "`format` must be `text` or `json`" and lists REQ-062, whose rule covers all five known keys, but its Red tests only `{"lang": "de"}`, `{"shout": "yes"}`, `{"name": 123}`, `{"name": ""}`, `{"times": 0}`, `{"times": "3"}` and `{"times": 2.5}`. No fixture anywhere in the plan holds a `format` key (the only JSON literals in the file are `{"name": "Ada", "lang": "es"}`, `{"name": "Ada", "unknownKey": 1}`, `{"name": 123}`, `{"name": ""}`, `{"lang": "de"}`, `{"shout": "yes"}`, `{"times": "3"}`, `{"times": 0}`, `{"times": 2.5}`, `{"times": 6}`), so an invalid config `format` is never caught and a valid config `format` is never honoured. Fix: add a `bad-format` fixture holding `{"format": "xml"}` and a Red test asserting `loadConfig` throws a `UsageError` with reason `invalid value for format: xml`; add the fixture to TASK-301's Files column.

F08 [P2] plans/greet-options/feature-greet-options-tasks.md:38 The "Decisions taken" row says `OPTION_SPECS` holds the five flags "with their kind (boolean or value), their allowed values and their reason prefixes", but TASK-101's Green (line 72) says each entry names "the flag, whether it takes a value, and its allowed values" and says nothing about reason prefixes. The two descriptions of the same constant disagree, and the reason prefixes differ per error kind (`unknown flag: `, `missing value for `, `empty value for `, `invalid value for `, `invalid flag syntax: `, `invalid argument: `), so "reason prefixes" is not a per-entry field. Fix: drop "and their reason prefixes" from the Decisions row, or spell out the reason-prefix table the entry must carry.

F09 [P2] plans/greet-options/feature-greet-options-tasks.md:38 The Decisions row cites `(GUD-003, RISK-004)` for the `OPTION_SPECS` decision. GUD-003 is about the greeting-word map, not the option list; the option list is RISK-004's mitigation (and GUD-001's "one-file layout"). The spec never names `OPTION_SPECS`, so the constant is a plan-level choice. Fix: cite `(GUD-001, RISK-004)` and note that the constant name is the implementer's choice, the way the fixture-directory names are.

F10 [P2] plans/greet-options/feature-greet-options-tasks.md:79,92,118,131,144 Units 2 and 3 share `depends: 1`, and units 5, 6 and 7 share `depends: 4`, yet every one of those units lists `src/greet.js` and `test/greet.test.js` in its Files column, so the "units that share a `depends:` set must list disjoint files" rule is broken throughout. The pipeline runs units sequentially in file order (`next-unit.sh` prints the first unit with an open task), so this does not block the build; it only removes the guarantee that two sibling units cannot conflict on the same file. Fix: leave as is if the units stay sequential, or give each unit its own source and test file so the disjointness rule holds.

## Design review

- The pipeline shape (`parseOptions` → `loadConfig` → `mergeOptions` → `buildGreeting` → `renderOutput`) matches spec §2 and §4.1 exactly, and the unit/process split matches spec §9. The task order (parse, then build, then config, then CLI, then the end-to-end contracts) respects the real dependencies: `bin/greet.js` needs `loadConfig` from Phase 3, and Phase 4 declares `depends: 1, 2, 3`.
- `MAX_UNIT_TASKS` is 2 in `.dostuff/pipeline.conf` and every unit has exactly 2 tasks, so the size rule holds.
- Every task's Files column names the fixtures its own Red text needs (checked TASK-301 against its fixture list and TASK-602 against `times-six`); no task lists a file it does not touch and no task touches a file it does not list, except that F04's fixture is shared by two tasks with contradictory expectations.
- The `Decisions taken` table settles the open questions the spec left (times digit rule, `-`-prefixed values, fixture layout, `loadConfig(cwd)` seam, upper-casing, JSON shape, exit strategy, unknown-key handling, reason wording) and each decision traces to a spec id or section.

## Critical challenge

- Ordering risk: the spec says flags are parsed first, then the config is read (spec §4.2), while REQ-069 says the whole config is validated before the merge even when a flag overrides the offending key. TASK-602's `greet --times 2` against `{"times": 6}` pins the correct behaviour (config validation wins), and TASK-602's Green says "make `loadConfig` validate the whole file before the merge". The plan is consistent here, but nothing pins the order of `parseOptions` versus `loadConfig`: a `bin/greet.js` that loads the config before parsing flags still passes every test in the plan, even though the spec §4.2 diagram pins flags first. Fix worth considering: add a Red case in TASK-602 that a bad flag and a broken config together report the flag error, which pins parse-first.
- A `greet.config.json` in the repo root would change the behaviour of the three existing tests, which run with the repo root as their working directory. The repo root has no such file today and the plan's Decisions do not mention it, and no task creates one, so the risk is only that a later contributor adds one. The spec records this as RISK-002.
- `process.exitCode` rather than `process.exit` is the right call and the plan states the reason (spec §4.2), so the truncation case the plan's "Review focus" item 4 names is covered by TASK-401's Green.
- No scope creep: the plan adds no option, no dependency, no directory under `src/` and no sixth CLI surface, and the `--help` and `--version` cases stay usage errors.

## Open items for the writer

1. F01 must be fixed for the check script to pass.
2. F02 and F03 together: the plan needs the two missing tasks (a JSON-rendering task and, if the ids stay, a count task) or a re-mapped traceability table.
3. F04 to F07 are the coverage gaps that the conformance check would grade Untested or Partial.

SUMMARY
verdict: fail
p0: 2
p1: 5
p2: 3
top:
- F01: `depends: none` on line 66 fails the plan check script; delete the line.
- F02/F03: TASK-203 and TASK-204 are referenced but never exist, so the JSON rendering branch of `renderOutput` (REQ-052, REQ-053, REQ-054, REQ-056) has no test.
- F04: TASK-702 expects `Hola, Ada` from a fixture that holds no `lang`, contradicting TASK-301; it must expect `Hello, Ada`.
- F05: no test covers `--times`, `--lang` or `--format` given without a value, though REQ-074 names `greet --times`.
- F06: REQ-076's "a config `shout: true` cannot be turned off" is in a Green note with no Red test.
- F07: the config `format` key is never exercised by any fixture or test.
report: plans/greet-options/reports/tasks/review.md
