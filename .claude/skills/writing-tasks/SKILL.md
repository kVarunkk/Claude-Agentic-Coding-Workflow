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
- [ ] 3. Write the tasks file from templates/tasks.md, in parts (see "Writing the file in parts" below).
- [ ] 4. Run `bash .claude/scripts/check-plan.sh plans/<feature>` from the repo root. Fix every FAIL and WARN.
- [ ] 5. Hand over: the path, the units in order, and anything the spec left open that you decided.
```

## Writing the file in parts

A model reply has an output cap. A reply cut off before its tool call loses everything in it, and an agent that plans the whole file in its reply runs out before it writes anything. So the file is the only place the plan goes:

1. Plan the units in short notes only: one line per unit (id, title, spec ids). No task rows, tables or test cases in the reply.
2. Create the file with one Write: front matter, Introduction, Decisions, Review focus, and every unit's heading, `depends:` line and GOAL bullet, with no tables yet.
3. Add each unit's table and **Done when:** line with one Edit per unit, in order.
4. Add the traceability table and Differences with a last Edit.

If the file already exists when you start (an earlier writer stopped part-way), read it and continue from the first unit that has no table. Don't start over.

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
- **Phases** start at 1. Add a Phase 0 only when the repo lacks something the tasks need (a test runner, a scaffold), and then it builds that. Each unit has a `GOAL-<id>` bullet, a task table and a checkable **Done when:** line. Each unit leaves the build green and ends in something runnable.
- **No verify-only units.** Every unit has a task that changes a file (`check-plan.sh` fails otherwise). The pipeline runs the baseline tests before the first unit and the full suite, a real run and the conformance check at the end, so there is no "Baseline", "Verify" or "Ship" unit. Docs go in the task that adds the behaviour they describe. A **Manual** task sits in the unit whose code it checks.
- **Added units.** At a phase end the pipeline may ask for one unit `## Phase <N><letter>: Auto-fix <title>` (from a conformance report) or `Changes <title>` (from the user's text). Add only that section after phase N's last unit, plus traceability rows for its tasks. `fix-unit.sh check` fails if anything else changed.
- **As few units as the spec needs.** A unit costs an implementer, a reviewer and often a fix round; a phase adds a conformance check. Group by behaviour, not by layer: the CLI-level test for a flag belongs in the unit that adds the flag, not in a later "end-to-end" unit whose tests would pass at once. A small CLI feature is two to four units (R66).
- **Tasks are vertical slices.** Each task is one behaviour through every layer it needs (schema, logic, route, UI, tests), not one layer at a time. Additive work comes first and removals come last. A task is the smallest unit that has its own test cycle and could be accepted or rejected on its own.
- **Red → Green → Refactor in every task.** The Task cell names the tests first, with the spec's exact values (`**Red:** … **Tests:** …`). Then it says what to build (`**Green:** …`): the file, the exact signature and the values.
- **Guard tests.** A test that will pass as soon as it is written, because earlier code already gives the behaviour, is listed under `**Guard:** …` instead of `**Red:**`, with one line on which earlier code makes it pass. A guard still has to fail when that behaviour breaks; the code reviewer proves it with a mutation. A task with only guard tests and no Green still needs a file it changes (the test file).
- **Decisions taken never leave a REQ or SEC id untested.** "Covered by code review" or "checked by reading the code" for part of a REQ or SEC id fails conformance later; write the test instead.
- **No invisible characters in the plan.** Never write U+FEFF, a zero-width or any other invisible character into the file: a reader sees `withConfig('{}')` and the test seems to contradict another. Describe it in words and build it in test code (`String.fromCharCode(0xFEFF)`).
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
- Log each deviation under `## Differences from the spec` as it happens, one bullet per entry: `- TASK-021 (REQ-015): <what differs and why>.` Touching a file outside the task's Files column is a deviation. So is a `**Red:**` test that passes before its code is written: log it with the reason. A `**Guard:**` test that passes at once is planned, so don't log it (logging it stops the unit for the user for no reason).
- When a decision changes the spec, say so under Differences; the spec is updated through `writing-specs`.
- A planned split is not a Difference: when the tasks file itself spreads a spec id over several units, the later unit finishing it is the plan. Don't log "REQ-049 partly done; rest in 4b".
- Keep entries true. The unit whose work makes an earlier entry stale (the split it describes is now closed, or the code changed) updates or removes that entry in the same unit. A matcher flagging a stale entry is a P2 that the next unit, or the final gate, fixes; it doesn't ship unchanged.
- Move the status badge through `Planned` (blue) → `In progress` (yellow) → `Completed` (brightgreen).
