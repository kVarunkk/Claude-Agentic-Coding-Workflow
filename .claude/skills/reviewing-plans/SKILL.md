---
name: reviewing-plans
description: Reviews a feature spec, or a tasks file against its spec, in plans/<feature>/. Runs a self-review and a challenge pass, checks that every spec requirement maps to a task, checks unit size and the tasks grammar with check-plan.sh, and ends with a SUMMARY block. Use to verify a spec or tasks file before the user approves it.
argument-hint: "spec|tasks plans/<feature>"
---

# Reviewing plans

Target: **$ARGUMENTS**. Mode `spec` reviews `feature-<feature>-spec.md`. Mode `tasks` reviews `feature-<feature>-tasks.md` against the spec.

Do not edit the plan files. Report findings; the writer fixes them. The only file you write is your report.

**Narrower modes** (from the pipeline prompt):
- `RECHECK: <previous report>`: a fix round ran. Check only (a) each P0 and P1 finding of that report, marked `fixed` or `open`, and (b) new P0 or P1 problems the fix introduced. A problem is "introduced" only if it sits in text the fix round changed: see what changed with `git diff <commit of the previous review's round> -- <file>` (build-feature commits the plan after each writer round; `git log --oneline -- <file>` lists them). A problem in unchanged text that the earlier reviews missed is reported as a P2 note marked `pre-existing`, not a P1, unless it is a P0; the gate shows it to the user. Report no new P2s otherwise; carry the old P2s over unchanged. Do not rerun the full design and challenge passes. This makes fix rounds converge (R59).
- `UNIT: <id>` (tasks mode): review only that added unit: its tasks against the findings it was added for, the spec ids it cites, its Files, `depends:` and size, and the script output. Do not re-review the rest of the file.

## 1. Load

- Read the spec in full. In `tasks` mode, read the tasks file in full too.
- Read `feature-<feature>-brief.md` if it exists. It holds what the user agreed.
- Read the code the plan names (paths, modules, test setup) enough to check the plan's claims about it.

## 2. Mechanical checks (tasks mode)

Run from the repo root: `bash .claude/scripts/check-plan.sh plans/<feature>`. Every `FAIL` line is a P0 finding. Every `WARN` line is a P2 finding. Quote the line.

## 3. Self-review

0. **Brief (spec mode).** Every brief decision, scope line, out-of-scope line and constraint is honoured. A spec line that contradicts the brief, or drops a brief decision, is P0. Behaviour the brief marks out of scope is P0. A decision the spec took that the brief never covered and that changes what gets built, without an Open question, is P1.
1. **Testable.** Every REQ and SEC id is one statement with an exact value, and you can picture its test. A negative id ("no network connection", "writes no file", "never evaluated") with no bounded check named in it (a static import ban, a spy on named calls) is **P1** in spec mode: no test can prove it in full, so the code review chases it round after round (R64).
2. **Coverage (tasks mode).** Every REQ and SEC id maps to a task whose Task text actually builds it, and every task maps to a spec id. The script checks ids; you check meaning. Every part of each REQ and SEC id also has a test that will check it. A Decisions-taken row or Task cell that leaves part of a REQ or SEC id to code review, reading the code or manual checking, with no test, is **P1**: the conformance check grades that part Untested or Partial (`checking-spec-conformance`, "A logged test change is not Accepted"), so the plan must grade it the same way now.
3. **Task scan (tasks mode).** Every Task cell allows one reasonable implementation and names its tests. No "handle edge cases". A test that will pass as soon as it is written (earlier code already gives the behaviour) must be marked `**Guard:**`, not `**Red:**`; an unmarked one is P2.
4. **Unit size and order (tasks mode).** No unit above `MAX_UNIT_TASKS` (`.claude/pipeline.conf`). Each unit ends green and runnable. `depends:` matches real dependencies.
5. **Files (tasks mode).** Each task's Files column names every file it must touch, tests included. Units that share the same `depends:` set must list disjoint files.
6. **Names.** Files, functions, types, constants and routes are spelled the same in both files and across tasks.
7. **Proportion.** The plan fits the behaviour asked for. Flag shared infrastructure with one consumer and unrequested scope. In tasks mode, a unit whose `**Red:**` tests would all pass given the earlier units' Green steps (an end-to-end layer over behaviour already built and tested at the unit seam) is **P1**: fold those tests into the unit that builds the behaviour. Run 11 had two such units out of 11 (R66).
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

## 6. Report and reply

Save the report to the `REPORT:` path from your prompt. Without one, use `plans/<feature>/reports/<mode>/review.md`, with suffix `-2`, `-3` if that file exists; never overwrite a report. It holds the target, the date, every finding, and the SUMMARY block. List findings as `F01 [P1] <file>:<line> <problem>. Fix: <smallest change>.` In recheck mode, list the previous findings first with `fixed` or `open`.

Reply with the same findings, then end with this block and nothing after it:

```
SUMMARY
verdict: pass|fail
p0: <n>
p1: <n>
p2: <n>
top:
- <one line per top finding, max 5>
report: <the report path>
```

`verdict` is `fail` when p0 or p1 is above 0. P2s never fail a verdict; they are notes for the user.
