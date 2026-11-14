---
name: build-feature
description: Builds a feature end to end with specialist subagents. Spec, tasks, then one implementer per unit with code review, phase checks against the spec, and user approval gates. Run as /build-feature <feature> [requirement].
disable-model-invocation: true
argument-hint: "<feature> [requirement text]"
allowed-tools: Bash(bash .claude/scripts/status.sh *) Bash(bash .claude/scripts/next-unit.sh *) Bash(bash .claude/scripts/phase-done.sh *) Bash(bash .claude/scripts/tick-unit.sh *) Bash(bash .claude/scripts/check-plan.sh *) Bash(git status *) Bash(git diff *) Bash(git rev-parse *) Bash(git log *)
---

# Build feature

Arguments: **$ARGUMENTS**. The first word is `<feature>` (kebab-case). The rest, if any, is the requirement. `PLAN` below means `plans/<feature>`.

You orchestrate. Subagents do the work. You never write code, specs or tasks yourself.

## Rules

- Read only the SUMMARY block of a reviewer, verifier or matcher reply. Open the full report only when escalating to the user.
- Never answer a gate yourself. Run `approve.sh` only right after the user picked Approve in this session.
- Pass script output verbatim. Never alter, split or reorder a unit.
- Report each step to the user in one line (`unit 2a: implementer done, review pass, committed abc123`).
- Read `TEST_CMD` and `MAX_LOOPS` from `.claude/pipeline.conf`.
- Every gate uses `AskUserQuestion` with options Approve / Request changes / Stop. Stop ends the run; all state is in files, so a later `/build-feature <feature>` resumes.
- Strict gate option: the user may instead run `! bash .claude/scripts/approve.sh plans/<feature> <name>` themselves and then pick Stop or tell you to continue. Then the model never writes the marker. Check the marker exists before moving on.

## 0. Resume

Run `bash .claude/scripts/status.sh PLAN`. Start at the first line that applies; never redo approved work:

| Status | Go to |
|---|---|
| `spec: missing` | 1, write |
| `spec: written` | 1, verify |
| `tasks: missing` | 2, write |
| `tasks: written` | 2, verify |
| `gate: N` | 3.6 for phase N |
| `next: <unit>` | 3 |
| `next: none` | 4 |

If no requirement was given and the spec is missing, ask the user for it. If this conversation already settled decisions (for example a /grilling), pass them on.

## 1. Spec

1. **Write.** Spawn `spec-writer`: `Feature: <feature>. PLAN: plans/<feature>. Requirement: <text>. Decisions already made: <list or none>.`
2. **Verify.** Spawn `spec-verifier`: `spec plans/<feature>`.
3. **Fix loop.** If the SUMMARY has p0 or p1 above 0: `SendMessage` the same spec-writer with the `top:` lines, then verify again with a new spec-verifier. At most `MAX_LOOPS` rounds. If the writer's ID is gone (new session), spawn a new spec-writer with the findings. Still failing: show the user the remaining `top:` lines at the gate.
4. **Gate.** Show the spec path, key decisions and open questions. Approve: `bash .claude/scripts/approve.sh PLAN spec`. Request changes: resume the spec-writer with the user's text, then go to 2.

## 2. Tasks

1. **Write.** Spawn `task-writer`: `PLAN: plans/<feature>. Write the tasks file from the approved spec.`
2. **Verify.** Run `bash .claude/scripts/check-plan.sh PLAN` yourself, then spawn `task-verifier`: `tasks plans/<feature>`.
3. **Fix loop.** Same as 1.3, with the task-writer and task-verifier. A FAIL from check-plan counts as p0.
4. **Gate.** Show the units in order with their task ids. Approve: `approve.sh PLAN tasks`, then commit the plan: `git add PLAN && git commit -m "docs(<feature>): spec and tasks approved"` and `git tag <feature>-tasks`.

## 3. Unit loop

Before the first unit, run `git status --porcelain`. If anything outside `PLAN` is uncommitted, show it and ask: Keep and continue / Stop. Unit commits would include it.

Repeat until `next-unit.sh` prints nothing:

1. `UNIT=$(bash .claude/scripts/next-unit.sh PLAN)` and `BASE=$(git rev-parse HEAD)`.
2. Spawn `implementer` with exactly this prompt (a hook checks it):
   ```
   PLAN: plans/<feature>
   UNIT: <UNIT verbatim>
   Implement only these tasks.
   ```
   If the hook blocks the spawn, show the reason to the user and stop. Do not retry with a different unit.
3. Spawn `code-reviewer`:
   ```
   PLAN: plans/<feature>
   UNIT: <UNIT verbatim>
   BASE: <BASE>
   FILES: <files changed, from the implementer's reply>
   Review `git diff BASE` plus untracked files for this unit.
   ```
4. **Fix loop.** Run `TEST_CMD`. If tests are red or the SUMMARY has p0 or p1 above 0: `SendMessage` the same implementer with the failing test tail and the `top:` lines, then spawn a new code-reviewer (same prompt, same BASE). At most `MAX_LOOPS` rounds. Then ask the user with the remaining findings and the report path: Commit anyway / Give guidance (resume the implementer with their text) / Stop.
5. **Commit.** Only with `TEST_CMD` green and `tick-unit.sh PLAN <unit-id>` exiting 0: `git add -A && git commit -m "feat(<feature>): unit <unit-id>"`. Append to `PLAN/reports/phase-N-report.md` (N = unit id without its letter): the unit line, the commit sha, and the reviewer SUMMARY block.
6. **Phase end.** If `bash .claude/scripts/phase-done.sh PLAN <unit-id>` exits 0 (or step 0 sent you here with `gate: N`):
   1. Spawn `spec-matcher`: `PLAN: plans/<feature> --phase N`.
   2. If its SUMMARY has p0 above 0 (Critical gaps) and this phase has not had a fix unit yet: spawn a new `task-writer`: `PLAN: plans/<feature>. Add one fix unit for phase N from <report path>: id N plus the next free letter, placed after phase N's last unit, depends on phase N's units, at most MAX_UNIT_TASKS tasks. Change nothing else.` Run `check-plan.sh`, commit the tasks file, and go back to the loop (the fix unit runs next). A second Critical result goes to the gate as is.
   3. Finish `PLAN/reports/phase-N-report.md`: ticked tasks of phase N, the `Differences from the spec` entries, the matcher SUMMARY, the `TEST_CMD` result, and `git diff --stat <previous tag>..HEAD` (previous tag: `<feature>-phase-<previous N>`, or `<feature>-tasks`). Commit it and `git tag <feature>-phase-N`.
   4. **Gate.** Show the report path and the one-line results. Approve: `approve.sh PLAN phase-N`. Request changes: spawn a new task-writer to add a unit for phase N from the user's text (as in 6.2), then continue the loop; the gate comes again at the phase end.

## 4. Final

Spawn `spec-matcher`: `PLAN: plans/<feature>` (whole feature). Then give the user a short summary: units built, commits, open Critical items, and links to `PLAN/reports/`.
