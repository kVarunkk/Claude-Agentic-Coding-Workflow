# tasks review: greet-options

- Target: `plans/greet-options/feature-greet-options-tasks.md` against `plans/greet-options/feature-greet-options-spec.md` (v0.3)
- Date: 2026-11-21
- Mode: tasks (full pass)

## Mechanical check

`bash .dostuff/scripts/check-plan.sh plans/greet-options` → OK (18 REQ/SEC ids, 11 tasks). No FAIL or WARN lines.

## Findings

F01 [P1] [RESOLVED] plans/greet-options/feature-greet-options-spec.md:61 (with tasks.md:123)
SEC-002 states it is "Checked by a static test (TEST-008)" that includes "the name value is only concatenated in buildGreeting and passed to console.log", but the actual TEST-008 (spec.md:192) and TASK-024 (tasks.md:123) assert only three things: forbidden tokens absent, `require` arguments whitelisted, and the single fs call. The name-flow part of SEC-002 (name never passed to shell/eval/filesystem and only used in the greeting) has no test, so conformance will grade that clause Untested. Fix: add to TEST-008/TASK-024 a static assertion that in `src/greet.js` `name` appears only inside `buildGreeting`, and in `bin/greet.js` the name value is passed only to `buildGreeting` (never to `fs`, `child_process` or `eval`).
  Resolution: TEST-008 (spec.md:192) and TASK-024 (tasks.md:123) now assert the name-flow clause.

F02 [P1] [RESOLVED] plans/greet-options/feature-greet-options-spec.md:52 (with spec.md:198, tasks.md:111)
REQ-032's second clause, "`--shout` and `--format` are never applied to the error path", is untested. Every usage-error case in TASK-023's Red (tasks.md:111) and TEST-015 (spec.md:198) is a single error in isolation; none combines `--shout` or a valid `--format json` with a usage error. `--format xml` (unsupported format) does not cover this clause, and the empty-stdout assertion cannot catch `--shout` upper-casing the stderr usage line. Fix: add at least `run('--shout','--nope')` and `run('--format','json','--times','0')` to TASK-023/TEST-015, asserting the exact lowercase REQ-031 line, empty stdout, and exit 2.
  Resolution: TASK-023 (tasks.md:111) and TEST-015 (spec.md:198) now include `run('--shout','--nope')` and `run('--format','json','--times','0')` asserting the exact lowercase REQ-031 line, empty stdout and exit 2.

F03 [P2] plans/greet-options/feature-greet-options-spec.md:127 (with tasks.md:74)
`formatJson(value, times)` is described as "`times` selects the value shape", but TASK-013's Green (tasks.md:74) just builds `{greeting: value}` and stringifies; `times` is an unused parameter and the caller (TASK-021) builds the array. The spec and task describe different contracts for the same function. Fix: drop the unused `times` parameter, or have `formatJson` select string vs array from `times`; make spec and task match.

F04 [P2] plans/greet-options/feature-greet-options-tasks.md:39 (with spec.md:192, tasks.md:123)
The mandated config call in the Decisions row (tasks.md:39) and TASK-022 Green (tasks.md:110) is `readFileSync(path.join(process.cwd(), 'greet.config.json'), 'utf8')`, but TEST-008 (spec.md:192) and TASK-024 (tasks.md:123) assert the call without the `, 'utf8'` argument. A strict exact-match static test would fail against the code the earlier task mandates, pushing a spurious "adjust bin/greet.js" step. Fix: include `, 'utf8'` in the asserted call string, or state explicitly that the static test tolerates the encoding argument.

F05 [P2] plans/greet-options/feature-greet-options-tasks.md:97, 110, 123
Three tasks mislabel guard tests as Red, contrary to the tasks file's own convention (tasks.md:22). TASK-020 (line 97) calls existing CLI tests "Red" when they already pass and writes no new red test; TASK-022 (line 110) folds "no config file → no-config output" into Red though that already passes because the config is not read yet; TASK-024 (line 123) labels the static security test Red though it passes as soon as it is written because TASK-020 through TASK-023 already obey the constraints. Fix: mark each as `**Guard:**` with a one-line reason, or split the genuine Red from the guard within the task.

## Notes

- `check-plan.sh` passes clean; no P0.
- The phase split (1a/1b/1c/2a/2b/2c, max 2 tasks each) is within `MAX_UNIT_TASKS=2`, `depends:` targets exist, and the traceability table covers all 18 REQ/SEC ids. Phase 1 builds the pure-function seam and Phase 2 wires it into the CLI, so no end-to-end "over-layer" unit whose Red tests would already pass.

SUMMARY
verdict: fail
p0: 0
p1: 0
p2: 3
top:
- [P2] formatJson's unused times param contradicts spec's "times selects the value shape"
- [P2] static test's fs call omits the 'utf8' the Decisions/TASK-022 mandate
- [P2] TASK-020, TASK-022, TASK-024 mislabel guard tests as Red
report: plans/greet-options/reports/tasks/review.md
