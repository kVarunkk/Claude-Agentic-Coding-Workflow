# Review: unit 3a (TASK-303, TASK-304)

Date: 2026-11-20
Mode: tasks, `UNIT: 3a`
Target: `plans/greet-options/feature-greet-options-tasks.md`, Phase 3a (lines 127-138)
Base: `7623912` (feat(greet-options): unit 3) plus the uncommitted working-tree diff
Reviewed: `git diff plans/greet-options/feature-greet-options-tasks.md` (unit 3a block + 2 traceability rows)

Findings: P0 0 · P1 1 · P2 4

## Mechanical checks

`bash .dostuff/scripts/check-plan.sh plans/greet-options` -> `OK` (50 REQ/SEC ids, 19 tasks).
No FAIL lines, no WARN lines. Unit 3a has 2 tasks, at the `MAX_UNIT_TASKS=2` limit
(`.dostuff/pipeline.conf`). `depends: 3` matches the real dependency: phase 3 owns
`loadConfig`/`mergeOptions` and is ticked `[x]`.

## Findings

F01 [P1] `plans/greet-options/feature-greet-options-tasks.md:225` REQ-065 has two clauses and
only one is covered by a test. The spec (`feature-greet-options-spec.md:82`) reads "The config
file is read once per process run **and is not re-read when a flag overrides one of its keys**".
TASK-304 tests only the first clause (one `loadConfig` call reads the file once). The second
clause is stated in TASK-304's Green as an instruction ("keep `mergeOptions(config, flags)` free
of any file access, so the config is not re-read when a flag overrides one of its keys") and in
TASK-601's Red as an output assertion (`greet --name Bob` in the fixture directory prints
`Hola, Bob\n`), neither of which can fail if the config were read twice. The traceability row
`REQ-065 | TASK-301, TASK-304, TASK-601` therefore claims coverage for a clause that stays
inspection-only, and the phase-3 conformance report that this unit exists to close
(`plans/greet-options/reports/phase-3/conformance.md`, REQ-065 Major) grades exactly that clause
as Partial for want of a failing-capable assertion.
Fix: in TASK-304, extend the read-count test to the second clause: with the same counting stub
installed, call `mergeOptions(loadConfig(fixture('good-format')), { name: 'Flag' })` and assert the
counter does not rise during the merge (still `1`), so a second read of the config during the
merge is red. Name the fixture and the assertion in the Red text so the test is unambiguous.

F02 [P2] `plans/greet-options/feature-greet-options-tasks.md:135` TASK-303 is marked `**Red:**` but
its behaviour already exists. `src/greet.js:160` already rejects every non-object top level with
`parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)`, and the phase-3
conformance report confirms the probe: `"hello"`, `42`, `true` and `false` each throw
`UsageError` with reason `invalid greet.config.json`. The three new fixtures will therefore pass
the moment they are written, so the instruction "confirm each new case fails for the right
reason" cannot be satisfied and the implementer will hit a red step that never turns red.
Fix: relabel TASK-303 `**Guard:**` and say so in the task text, the way TASK-205 and TASK-206 do
("these cases already pass once ... , so they guard the ... rule rather than add new behaviour").

F03 [P2] `plans/greet-options/feature-greet-options-tasks.md:136` TASK-304 is marked `**Red:**` but
its behaviour already exists too. A probe against the current `src/greet.js` shows exactly `1`
read for one `loadConfig` call, which is what the conformance report recorded. The instruction
"confirm it fails for the right reason, that is the counter is `2` or more once the code is
broken" is self-contradictory: the code is not broken, so the counter is `1` and the test is green
on the first write.
Fix: relabel TASK-304 `**Guard:**` and drop the "confirm it fails" wording, replacing it with
"this test passes as soon as it is written because `loadConfig` already reads the file once; it
guards that rule against a later change".

F04 [P2] `plans/greet-options/feature-greet-options-tasks.md:135` TASK-303 cites `TEST-006`, but
that spec id does not describe the new cases. `feature-greet-options-spec.md:422` enumerates
TEST-006 as "a fixture with invalid JSON, on a fixture whose top level is an array, on a fixture
whose top level is `null`, ..." and the spec's own fixture list (`feature-greet-options-spec.md:388`)
does not name a string, number or boolean top level either. The shapes are named in the requirement
text (`feature-greet-options-spec.md:254`) and in Q-5 (`:464`), so the behaviour is in the spec, but
the unit-test id the task cites does not cover it and the plan records no Difference for the
widening.
Fix: cite `REQ-066` plus the spec lines that name the shapes (`spec:254`, `Q-5`) in TASK-303's Spec
cell, and add a Differences entry saying the TEST-006 fixture list is widened with three
top-level shapes that the requirement text names but the TEST id did not enumerate. The same
Difference should note the three new fixture directories, which sit outside the Decisions row's
list of fixture case names.

F05 [P2] `plans/greet-options/feature-greet-options-tasks.md:136` TASK-304's counting stub counts
every `fs.readFileSync` call, not the config file's. The Red text says "counts how many times the
config file is read", but the stub as described wraps `fs.readFileSync` wholesale, so the count
would also include a read of any other file inside the same call, and the test would still be
green if `loadConfig` read a different file and never the config.
Fix: count only the calls whose path ends with `greet.config.json`, and assert the returned
config as well (`loadConfig(fixture('good-format'))` returns `{ format: 'json' }`), so the counter
of `1` is tied to the config file and not to any read.

## Notes (not findings)

- The unit is well proportioned: 2 tasks, test-only in practice, no source change expected, and
  it closes a real, evidence-backed gap. The REQ-066 half is genuinely valuable: the conformance
  report's mutation that narrows the top-level check to array+null stays green today, and the
  three new fixtures make it red.
- `depends: 3` is right, and no other unit shares that dependency set, so there is no
  same-depends file collision on `test/greet.test.js`.
- The traceability edits are limited to the two rows the new tasks touch (REQ-065, REQ-066), which
  is the right scope.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 4
top:
- F01 REQ-065's second clause ("not re-read when a flag overrides one of its keys") has no failing-capable test in any task
- F02 TASK-303 is labelled Red but the top-level check already rejects string, number and boolean
- F03 TASK-304 is labelled Red but loadConfig already reads the config exactly once
- F04 TASK-303 cites TEST-006, whose spec text does not name the string, number or boolean top levels
- F05 TASK-304's stub counts every fs.readFileSync call, not the config file's read
report: plans/greet-options/reports/phase-3/fix-unit-review.md
