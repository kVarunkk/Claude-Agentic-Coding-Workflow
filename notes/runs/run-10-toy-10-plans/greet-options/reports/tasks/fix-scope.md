# Fix scope: the one remaining P1 in plans/greet-options/reports/tasks/review-4.md

Fix only F16. Change nothing else in the tasks file.

## F16 (P1): no task's Green step makes `parseArgs` recognise `--shout`

TASK-010's Green (the task that creates `parseArgs`) describes only `--name`. TASK-021's Green and TASK-041's Green both presume the flag is already parsed, but neither introduces it. The consequence: TASK-041's and TASK-051's `--shout` CLI Red tests fail with a usage error and exit 2 instead of producing the expected greeting, and no unit test of `parseArgs(['--shout'])` pins the parsed object's shape.

Fix: name the owner of `--shout` parsing. The smallest fix, which the review itself proposes, is:
- TASK-010's Green step: state that `parseArgs` recognises `--shout` as a flag that takes no value and returns `{ shout: true }` when it is present.
- TASK-010's Red step: add `parseArgs(['--shout'])` returns `{ shout: true }` with no error.

If you prefer a dedicated unit for it, that is fine too, provided the unit owns REQ-015 and the `--shout` parsing is stated in exactly one place, and `MAX_UNIT_TASKS=2` is still respected (a new unit must still hold at most 2 tasks).

Also check that REQ-015 is cited by the task that owns the `--shout` parsing, and that the traceability table still maps every REQ/SEC id to at least one task after the change.

## Constraints

- Change nothing else in the tasks file. Do not change the spec.
- Keep every id stable. Keep every unit at most 2 tasks (`MAX_UNIT_TASKS=2`).
- The seeded `test/zz-seeded.test.js` handling stays as it is.
