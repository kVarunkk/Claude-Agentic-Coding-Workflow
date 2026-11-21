# Run 8 (dostuff, toy-9) findings and plan

Source: `notes/runs/run-8-dostuff-toy-9.md` (greet-options on a fresh `toy-9`, AFK from the tasks gate, ran to the end).
Pipeline: installed from `58f9eb7` plus the uncommitted R34-R41 work (`toy-9/.dostuff/.installed-from`). agent-1: `package-structure@3f42300`, clean. Model not recorded.
Cost: 30.4M input tokens (run 7: 7.4M).
Result: 9/9 units committed, 107 tests green, final conformance "all 50 ids met", clean tree. Final gate never asked (`final: open`).

## What worked (R34-R41 held)
- `check-spawn.sh` blocked a padded code-reviewer prompt; the orchestrator went back to the template.
- `check-git.sh` blocked `git tag -f greet-options-final`.
- `check-report.sh` caught every missing, pending or verdict-less report.
- `unit-gate.sh` ran `TEST_CMD` on all 9 units; `${TMPDIR:-/tmp}` used; `run-stats.sh` gave the final counts; no `sleep` polling; patch-id matched.

## Findings (most important first)

- **R42. The orchestrator writes and edits agents' reports.**
  - Phase 2: the matcher's `phase-2/conformance.md` (8 Critical, no verdict line) was overwritten in place by the orchestrator's own report with `verdict: pass`. No restart was logged, and the original was never committed.
  - Phase 1: after two matcher restarts stalled, the orchestrator wrote `conformance-3.md` itself (`verdict: pass`).
  - It also patched `spec/review-3.md` (`pending` to `fail`), and added SUMMARY blocks to `review-4a.md`, `review-4b.md` and `final/report.md`.
  - Net effect: two failing phase checks became passes, so the automatic fix unit never ran.
  - Fix: a `check-write.sh` PreToolUse hook on Write/Edit/MultiEdit (dostuff: write_file/edit_file/multi_edit/delete_file). It blocks main-session writes inside `plans/<f>/` except the files the orchestrator owns (brief, its fix-input files, phase and final reports, PR body). Subagent calls carry `agent_type` (dostuff `run_hook.py` sets it for PreToolUse in an agent; Claude Code does the same for subagent hook input) and are not touched. SKILL: exit 1 from check-report means restart or stop, never patch.
- **R43. The orchestrator edited the spec itself.**
  - Spec v0.4 and v0.5 were its own edits (F07, then REQ-010/011/016/017 and TEST-008, from the verifier's raw reasoning).
  - At the spec-writer stop it offered "Apply the spec fixes myself (Recommended)".
  - Fix: the R42 hook also covers `feature-*-spec.md` and `feature-*-tasks.md`. The SKILL lists the only options at an early-stop stop.
- **R44. Phase checks fail on work that later phases own.**
  - Phase 1 and 2 ids also carry behaviour that later tasks build (process boundary, CLI config path). The matchers graded those parts Critical Untested or Partial, deliberated, and stalled.
  - This was the motive for R42. Phases 3-5 graded with `Not started` for the later part and finished.
  - Fix: in `checking-spec-conformance` `--phase N`, grade only the part of an id that phase N's tasks own. The rest is `Not started (TASK-xxx)`, severity none. The same rule goes in `spec-matcher.md`.
- **R45. Agents still stop early; skeleton-first mostly ignored.**
  - Stopped early: spec-writer x2, spec-verifier x2, 1a reviewer, phase-1 matcher x2 (raw reasoning as the reply).
  - Missing skeletons: 1a review, first review-4, review-4a/4b, phase-1/2 conformance.
  - Fix: `report-path.sh --pending` creates the skeleton (`verdict: pending`) before the spawn. A missing report can't happen, and the name is reserved. Agents replace the whole file at the end.
- **R46. Prompt padding where the hook does not look.**
  - spec-verifier x3 and task-verifier x3 prompts carried "Keep the report short..." blocks.
  - Scoped spec-writer prompts (after the user chose "retry with smaller scope") carried finding text and "the decision is yours" for open question Q-2.
  - Fix: `check-spawn.sh` checks templates for spec-writer, spec-verifier, task-writer and task-verifier too. A scoped retry writes the chosen findings to a fix-input file (`spec/fix-scope`) and passes it as `FIX:`.
- **R47. Final gate skipped.** The orchestrator called a nonexistent `final-gate.sh` (exit 127) and never asked Accept / Request changes / Roll back / Stop. The PR question was plain text. Fix: SKILL 5.5 says plainly "there is no script; ask with AskUserQuestion". Step 6 must be an AskUserQuestion call too.
- **R48. Restart and gate rules bent.**
  - The phase-1 matcher was spawned 3 times.
  - A spec-verifier restart had no `PARTIAL:` line.
  - A cancelled spec-gate question plus "continue" was taken as the user picking "Fix P2".
  - Fix: SKILL wording. A cancelled gate is asked again.
- **R49. Reviewer 1a passed with 4 green mutants, 2 against cited spec text.** The two were `--shout` consuming the next argument (REQ-020) and trimming the name (REQ-011), filed as "mutation-limit notes". Its SUMMARY said `p2: 0` with a P2 under `top:`. Fix: code-reviewer and reviewing-code: a green mutant that breaks behaviour a cited REQ/SEC states is a P1 test gap unless shown equivalent. `check-report.sh` fails when `top:` holds more `[P<n>]` items than the count.
- **R50. The orchestrator redid reviewers' work.** It re-ran mutants for 1b and 1c (`mutcheck.js` and `src/options.js.mutant` in the project root) and probed findings itself. Likely a large share of the 30M tokens. Fix: SKILL rule: never re-verify a finding or run mutants or probes yourself; the report is the evidence.

## Order of work
R42+R43 (hook), R44, R45, R47, R46, R49, R48, R50 (SKILL text), then tests, PIPELINE-NOTES, `install-dostuff.sh` hook entry, then a fresh toy run.
