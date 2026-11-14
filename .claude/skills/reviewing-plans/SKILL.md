---
name: reviewing-plans
description: Reviews a feature spec, or a tasks file against its spec, in plans/<feature>/. Runs a self-review and a challenge pass, checks that every spec requirement maps to a task, checks unit size and the tasks grammar with check-plan.sh, and ends with a SUMMARY block. Use to verify a spec or tasks file before the user approves it.
argument-hint: "spec|tasks plans/<feature>"
---

# Reviewing plans

Target: **$ARGUMENTS**. Mode `spec` reviews `feature-<feature>-spec.md`. Mode `tasks` reviews `feature-<feature>-tasks.md` against the spec.

You are read-only. Do not edit the plan files. Report findings; the writer fixes them.

## 1. Load

- Read the spec in full. In `tasks` mode, read the tasks file in full too.
- Read `feature-<feature>-brief.md` if it exists. It holds what the user agreed.
- Read the code the plan names (paths, modules, test setup) enough to check the plan's claims about it.

## 2. Mechanical checks (tasks mode)

Run from the repo root: `bash .claude/scripts/check-plan.sh plans/<feature>`. Every `FAIL` line is a P0 finding. Every `WARN` line is a P2 finding. Quote the line.

## 3. Self-review

0. **Brief (spec mode).** Every brief decision, scope line, out-of-scope line and constraint is honoured. A spec line that contradicts the brief, or drops a brief decision, is P0. Behaviour the brief marks out of scope is P0. A decision the spec took that the brief never covered and that changes what gets built, without an Open question, is P1.
1. **Testable.** Every REQ and SEC id is one statement with an exact value, and you can picture its test.
2. **Coverage (tasks mode).** Every REQ and SEC id maps to a task whose Task text actually builds it, and every task maps to a spec id. The script checks ids; you check meaning.
3. **Task scan (tasks mode).** Every Task cell allows one reasonable implementation and names its tests. No "handle edge cases".
4. **Unit size and order (tasks mode).** No unit above `MAX_UNIT_TASKS` (`.claude/pipeline.conf`). Each unit ends green and runnable. `depends:` matches real dependencies.
5. **Files (tasks mode).** Each task's Files column names every file it must touch, tests included. Units that share the same `depends:` set must list disjoint files.
6. **Names.** Files, functions, types, constants and routes are spelled the same in both files and across tasks.
7. **Proportion.** The plan fits the behaviour asked for. Flag shared infrastructure with one consumer and unrequested scope.
8. **No placeholders** (`<…>`, TODO, TBD) outside Open questions.

## 4. Challenge pass

When the spec has a data model, an API contract or 3+ modules, run two more passes. If you can spawn read-only subagents, run them in parallel; otherwise do them yourself, one after the other.

- **Design review.** Architectural fit, module boundaries, the data model, API contracts, and whether the task order respects the dependencies.
- **Critical challenge.** Assumptions, missing cases (empty, huge, concurrent, timeout, malformed), scope creep, unproven requirements, simpler alternatives.

Keep at most five findings from each, with evidence.

## 5. Verify and grade

Re-read the exact plan lines for each finding and drop what does not hold up.

- **P0**: the plan cannot be built as written: a FAIL from the script, a requirement with no task, a contradiction, a missing contract.
- **P1**: will likely produce wrong code: an ambiguous requirement, a task that decides nothing, a wrong dependency, a missing edge case that hurts users.
- **P2**: cost or clarity: naming drift, a WARN from the script, proportion.

## 6. Reply

List findings as `F01 [P1] <file>:<line> <problem>. Fix: <smallest change>.` Then end with this block and nothing after it:

```
SUMMARY
verdict: pass|fail
p0: <n>
p1: <n>
p2: <n>
top:
- <one line per top finding, max 5>
report: inline
```

`verdict` is `fail` when p0 or p1 is above 0.
