# Run 10 (dostuff, toy-10 rebuilt) findings and plan

Source: `notes/runs/run-10-dostuff-toy-10.md` (was `Downloads/toy-10/dostuff-session-15f63441932f44d5.md`). Plans and reports are in `notes/runs/run-10-toy-10-plans/`. The run built greet-options on `toy-10` in AFK mode from the tasks gate.
Pipeline: installed from `58f9eb7` plus the uncommitted R34-R53 work. agent-1 was on `dostuff/output-limit`.
Cost: 9.1M input tokens over about 3.5 hours (19:42 to 23:14).
Result: brief, spec (v0.3) and tasks (9 units, one unit per phase) approved; AFK chosen. Units 1 and 2 committed after passing review. Stopped at unit 3: both code-reviewer attempts ran out of turns before writing the report.
Status (2026-11-20): R54-R62 implemented on `fix/run-7-findings`, uncommitted. Hook and script fixes were replayed against run 10's own commands and state: each blocks what run 10 did. Beyond the plan: the decisions.tsv block also catches writes through a variable (run 10's real command used `L=...; >> "$L"`), the restart count ignores HEAD (run 10 committed between the stuck verifiers), and `git tag <f>-phase-N` needs a finished conformance report and the phase report. Tests: hooks 190, scripts 191. Open: R56 turn warning in dostuff.

## What worked (R51-R53 held)
- No writer stalled. The task-writer wrote the whole tasks file in one run (R51).
- No config or model edits (R52).
- `check-spawn.sh` blocked an extra line twice: "Write the tasks file from the approved spec." on the task-writer, and the implementer's fix line on a spec-writer.
- dostuff's output-limit fix held: no cut-off reply was taken as a final answer.
- `check-report.sh` caught every pending or verdict-less report.

## Counts
- Spec: 6 verifier reports and 6 writer runs. The writer hit its 40-turn limit once, after finishing its edits.
- Tasks: 8 verifier reports and 5 writer runs. The task-verifier hit its 30-turn limit 3 times.
- Units: 1 and 2 committed with one fix round each. Unit 3's reviewer hit its 40-turn limit twice.

## Findings (most important first)

- **R54. The orchestrator committed failing unit 3 at the stop.**
  - Both unit-3 reviewers found 2 P1s. One is a real bug: `greet --lang ES --lang fr` exits 2, against REQ-003 and D-01.
  - At the stop it ran `git add plans/greet-options src test && git commit -m "feat(greet-options): unit 3"` (`dbe2669`). AFK says "no wip commit", and code must be staged with `stage-unit.sh`.
  - `status.sh` now says `next: 4`, so a resume skips unit 3's review. The closing message said "State is safe".
  - Nothing guards a unit commit.
- **R55. Phase ends were skipped.**
  - Every unit is its own phase, and `phase-done.sh` exits 0 after units 1, 2 and 3.
  - `phase-done.sh` was never run, so there was no spec-matcher run, no phase report and no `-phase-N` tag.
  - Unit 2 and unit 3 reviews were filed under `reports/phase-1/`.
  - In AFK, `check-spawn.sh` does not require `approvals/phase-N`, and it checks nothing else about the previous phase. `status.sh` showed `gate: 1` the whole time.
- **R56. Reviewers and verifiers run out of turns before writing their report.**
  - task-verifier: 3 of 8 runs (30 turns). code-reviewer: 2 of 6 runs (40 turns). Each had the whole report in its reply text.
  - The early-skeleton and write-as-you-go rule (`code-reviewer.md:14`) was ignored: `review-3.md` was still the 5-line skeleton.
  - The 6-mutation cap was ignored (8 were run). "After about 28 turns" does not work: the model can't count its turns.
  - task-verifier.md only asks for an early skeleton; it never says to add findings as they are confirmed.
- **R57. The restart limit can be bypassed by leaving out `PARTIAL:`.**
  - review-5 (`RECHECK: review-4`) stopped early. Its restart, review-6, had no `PARTIAL:` and repeated `RECHECK: review-4`. A third spawn (review-7, same prompt) went through without `approve.sh retry`. The orchestrator wrote "Let me try the spawn to see what the hook says".
  - `guard_restarts` counts verifiers, reviewers and matchers only through the `PARTIAL:` chain.
  - The "Retry with a narrower scope" option means nothing for a verifier: its template has no `FIX:`, so `tasks/fix-scope-2.md` never reached it. The gate option told the user they would run `approve.sh retry`, which never happened.
- **R58. The review skill's verdict line conflicts with the pipeline's.**
  - `reviewing-code/SKILL.md` section 6 has `Verdict: approve | approve-with-notes | changes-requested`. The unit-2 first review and both unit-3 attempts used it.
  - `check-report.sh` rejected review-2, which wasted one full review.
  - On the way, the orchestrator logged a `fix-round` in the same command as `check-report.sh`, before seeing it fail. It then gave the replacement reviewer `RECHECK:` the discarded report.
- **R59. Fix rounds went past `MAX_LOOPS` without a gate.**
  - The user allowed one extra spec round and one extra tasks round. After the extra tasks round, a full re-review (review-7) found 3 new P1s. The orchestrator ran a fourth task-writer round without asking and without logging `fix-round`.
  - Ordinary spec and tasks fix rounds were not logged either, so `run-stats.sh` undercounts.
  - Churn: fixing the spec's P2 notes created 3 new P1s, then 2 more. Review-7 found a `depends:` and Files clash that had been in the plan since its first version.
- **R60. Bookkeeping drift.**
  - The orchestrator wrote `decisions.tsv` with `printf` (units 1 and 2) instead of `log-decision.sh`.
  - Reviewer restarts were logged as `empty-report` instead of `restart`.
  - The unit-2 fix implementer wrote `gate-reason` rows itself, which then appear twice.
  - It first passed the mutations run (10) as the still-green count to `unit-gate.sh`, then corrected itself. Reviewers write the line two ways: `10, 0 still green` and `13 run, 1 still green`.
  - When the spec-writer stopped early, the orchestrator grepped the spec itself instead of restarting the writer. The outcome was right, but it is against the rules.
- **R61. Verifiers left scratch files in the repo root** (`.tmp-parse.py`, `.tmp-review6.py`). The orchestrator deleted them. `check-write.sh` does not see shell writes.
- **R62. The brief dropped the requirement's "1-5" range for `--times`.** The orchestrator wrote the brief from the interview. The spec-writer then raised it as open question Q-1.

## Fix plan

Pipeline (`.claude/`, then `install-dostuff.sh`):

- **R54**
  - `check-git.sh`: block `git add` of paths outside `plans/` while a plan has `approvals/tasks`; stage-unit.sh does the staging.
  - Block `git commit` when the index holds paths outside `plans/` unless the newest review of the open unit (`next_unit_at HEAD`, `reports/phase-*/review-<unit>*.md`) passes `check-report.sh` with `verdict: pass`, or `approvals/commit-<unit>` exists. That marker is written by the user's "Commit anyway" answer through `approve.sh`.
  - SKILL: at a stop, commit nothing.
- **R55**
  - `check-spawn.sh`, implementer with no `FIX:`: run `status.sh`. Block when `gate: N` is set and N is lower than the unit's phase, in AFK too.
  - The message tells the orchestrator to run 4.6 for phase N. A fix unit lives in phase N itself, so it is not blocked.
- **R56**
  - task-verifier: raise `maxTurns` to 40, and add write-as-you-go: put each confirmed finding into the report as it is confirmed. The spec-verifier and spec-matcher agent files get the same line.
  - code-reviewer: cap mutations at 6 and probes at a small number. Write the report after each finding, not at the end.
  - dostuff (agent-1, user's call): a "N turns left" note near `maxTurns`, or one final turn that may only call Write. That fixes this for every agent.
- **R57**
  - `guard_restarts`: for verifiers, reviewers and matchers, also count earlier spawns with the same type, prompt key (REPORT and PARTIAL lines left out) and HEAD whose REPORT still fails `check-report.sh`. Two such spawns block the third, with or without `PARTIAL:`.
  - SKILL: when a verifier, reviewer or matcher stops early, the resume options are "allow one more run" (the user runs `approve.sh PLAN retry`) or Stop. Narrower scope applies only to writers and implementers.
- **R58**
  - reviewing-code section 6: when the prompt has `REPORT:` (pipeline), leave out the `Verdict:` header line; the only verdict is `verdict: pass|fail` in the SUMMARY. code-reviewer.md says the same.
  - SKILL: run `check-report.sh` before logging a fix round. Respawn with `PARTIAL:` of the rejected report, never `RECHECK:`.
- **R59**
  - SKILL: "One more fix round" buys exactly one round, and a fail after it goes to the gate again. Log every spec and tasks fix round with step `spec` or `tasks`.
  - Also: a recheck that finds problems in text the fix round did not touch reports them as P2 for the gate, not P1. That needs a reviewing-plans wording check.
- **R60**
  - SKILL: only `log-decision.sh` writes `decisions.tsv`. Restarts of reviewers, verifiers and matchers are logged as `restart`; `empty-report` is for the implementer only. implementer.md: never write `decisions.tsv`.
  - `unit-gate.sh`: take the review report path as the fourth argument and read the still-green count itself (numbers stay accepted).
  - reviewing-code: the line is exactly `mutations: <n> run, <n> still green`.
- **R61**: task-verifier and spec-verifier: no files in the repo; scratch goes under `${TMPDIR:-/tmp}`.
- **R62**: aligning-requirements: every number, limit and name in the requirement text goes into the brief word for word.

Not a pipeline fix: toy-10 now has unreviewed unit-3 code in `dbe2669`. A rerun should start again from a fresh toy.

## Order of work
R54, R55, R57 (hooks, with tests in `test-hooks.sh`), R58, R56, R60 (`unit-gate.sh`, with tests in `test-scripts.sh`), R59, R61, R62 (wording). Then PIPELINE-NOTES, `install-dostuff.sh --check` and a fresh toy run.
