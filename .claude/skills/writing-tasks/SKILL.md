---
name: writing-tasks
description: Writes or updates the test-first task plan plans/<feature>/feature-<feature>-tasks.md from an existing spec, split into phases and sub-phases that the build pipeline runs one at a time. Also holds the rules for ticking tasks and logging Differences during implementation. Use after a spec is written or changed, when the user asks for a task breakdown, or while implementing tasks from a plans/ tasks file.
---

# Writing tasks

The tasks file says how to build the spec, test-first, in order. Template: [templates/tasks.md](templates/tasks.md). Scripts parse it, so the grammar below is exact.

## Workflow

```
- [ ] 1. Read plans/<feature>/feature-<feature>-spec.md in full. If the tasks file exists, update it; don't start over.
- [ ] 2. Read the code the tasks touch and the test setup.
- [ ] 3. Write the tasks file from templates/tasks.md.
- [ ] 4. Run `bash .claude/scripts/check-plan.sh plans/<feature>` from the repo root. Fix every FAIL and WARN.
- [ ] 5. Hand over: the path, the units in order, and anything the spec left open that you decided.
```

## Grammar (parsed by scripts)

```
## Phase 2a: <title>
depends: 1
| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-020 | Add X | REQ-014 | src/x.ts, test/x.test.ts | [ ] | |
| TASK-021 | Add Y | REQ-015 | src/y.ts | [x] | 2026-11-14 |
```

- A **unit** is one `## Phase <id>: <title>` heading and its one table. Ids: `0`, `1`, `2`, `2a`, `2b`. Numeric prefix = phase. `2a` and `2b` together are phase 2.
- At most `MAX_UNIT_TASKS` (in `.claude/pipeline.conf`, default 5) tasks per unit. A bigger phase becomes sub-phases `Na`, `Nb`, … Split where a sub-phase still ends green and testable.
- `depends:` (optional) comes before the table: comma-separated unit ids or phase numbers. Sub-phases that don't depend on each other list the same dependency, not each other.
- Columns exactly `ID | Task | Spec | Files | Status | Done`. Status is `[ ]` or `[x]`. Done is empty, or the ISO date once ticked. Write `\|` for a literal pipe in a cell.
- **Files** lists every file the task creates or changes, tests included, comma-separated (`none` for none). The implementer may not touch other files without logging why.
- Other `##` sections (Decisions, Review focus, traceability, Differences) are not units and may sit before or after the phases.

## Content rules

- **Decisions taken** comes first: every choice the spec left open that an implementer would otherwise stop and ask about.
- **Review focus** comes next. List the ~5 inputs or failure modes the spec implies that are most likely to hurt a real user, most likely first. For each line, add its test to the task that owns the code.
- **Phases** start at 0 (scaffold and test infrastructure). Each unit has a `GOAL-<id>` bullet, a task table and a checkable **Done when:** line. Each unit leaves the build green and ends in something runnable.
- **Tasks are vertical slices.** Each task is one behaviour through every layer it needs (schema, logic, route, UI, tests), not one layer at a time. Additive work comes first and removals come last. A task is the smallest unit that has its own test cycle and could be accepted or rejected on its own.
- **Red → Green → Refactor in every task.** The Task cell names the tests first, with the spec's exact values (`**Red:** … **Tests:** …`). Then it says what to build (`**Green:** …`): the file, the exact signature and the values.
- **One name per thing.** When a later task uses something an earlier task makes, both use the same name (function, type, route), and so does the spec.
- **Every task decides something.** "Handle edge cases", "add validation" and "write tests" decide nothing: name the cases and the tests instead. Include a function body only when the signature and tests leave the algorithm open.
- A new field or entity lists every layer it crosses (schema, migration, query, API type, client type, UI, validation) in the same task.
- Mark **Manual** tasks (real keys, a human, a browser) and say what to record from them.
- Task ids are `TASK-<phase><n>`, unique in the file. The **Spec** column maps each task to spec ids.
- The **traceability** table covers every REQ and SEC id. Ranges like `REQ-011 – REQ-016` are fine.
- End with `## Differences from the spec` set to "None yet."

## During implementation

- Work one test at a time: red, green, then the next test. Refactor with the tests green.
- When a task's tests pass, change its Status to `[x]` and put today's ISO date in Done. Tick only your own tasks.
- Log each deviation under `## Differences from the spec` as it happens, one bullet per entry: `- TASK-021 (REQ-015): <what differs and why>.` Touching a file outside the task's Files column is a deviation.
- When a decision changes the spec, say so under Differences; the spec is updated through `writing-specs`.
- Move the status badge through `Planned` (blue) → `In progress` (yellow) → `Completed` (brightgreen).
