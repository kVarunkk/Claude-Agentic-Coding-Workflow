# Run 7 (dostuff harness, MiniMax) findings and repo plan

Source: `hooks-sandbox/pipeline-toy/dostuff-session-a5297d7021754e13.md` (greet-options, resumed at unit 2a, AFK on, ran to final approval, PR declined). The first half of the run (deepseek) was not reviewed; its transcript is optional and only matters for finding 6.
Cost: 7.4M input tokens; the final spec-matcher alone used about 6.3M.
Status (2026-11-18): R34 to R41 and finding 9 implemented on `fix/run-7-findings` (see `.claude/PIPELINE-NOTES.md`, Run 7). Repo plan items 1 to 3, 5 (`dostuff-toy.ps1`), 6 (`notes/runs/run-7-dostuff-minimax.md`) and 7 (agent-1 state logged per run) done. Item 4 (neutral source text) is partly done: the converter still renames tool names. Next: a clean dostuff run on a fresh toy.

## What worked (keep)
- Hook blocked a malformed `UNIT:` line; `stage-unit` caught a stray file; patch-id matched on every unit.
- Mutation review found two real test gaps (1b, 2a); the reviewer proved red-at-BASE for new tests.
- No check was relaxed; AFK reached the final gate; the PR was asked and declined.

## Findings (most important first)

1. **Turn-cap exhaustion.** 6 of about 17 subagent runs hit the cap (3 reviewers, 1 implementer, 2 matchers). Each time the orchestrator resumed via `send_message`, which the SKILL forbids but `check-spawn.sh` cannot see. Review 4a saved no report; the 3b implementer's final reply was raw reasoning with nothing written.
   Fix: explicit recovery rule (report on disk -> `check-report`; none -> fresh agent, no cost to `MAX_LOOPS`). Add budgets to agent files: skeleton report first, stop probing near turn 30, cap mutations. Partly MiniMax-specific (reasoning dump), partly job size.
2. **Matcher report bloat and scratch litter.** 67-row evidence table, 300 lines, `write_file` truncates. Left `.ids-part1.md`, `.ids-part2.md`, `conformance.md.part2` in `reports/` (would be committed: stage-unit owns all of PLAN). A stray `.dostuff/tmp/phase2-test.log` blocked the 3a stage.
   Fix: cap the table in the matcher (compact rows, no evidence column); scratch only under `${TMPDIR:-/tmp}`; `check-report`/`stage-unit` fail on dotfiles and `*.part*`.
3. **`$TMPDIR` unset in this harness.** `SKILL.md:117` `rm -rf "$TMPDIR"/mut-<unit>*` expands to `/mut-3b*`.
   Fix: `${TMPDIR:-/tmp}` in SKILL.md, `scratch-copy.sh`, reviewer text, reviewing-code skill.
4. **Prompt padding.** From 2b on the orchestrator added `Rules:` / `Note on scope:` blocks to implementer, reviewer and matcher prompts. `check-spawn.sh` only checks PLAN/UNIT/FIX lines. The 4a file list in the extras differed from the unit's Files column.
   Fix: hook rejects other lines, or SKILL says "nothing else". Fixing 1 to 3 removes the motive.
5. **`TEST_CMD` at commit step 5.1 mostly skipped** (run by the orchestrator in 2a and 4a only).
   Fix: `unit-gate.sh` runs `TEST_CMD` and exits 1 on red.
6. **Resume with half-built work.** `status.sh` said `uncommitted: none, next: 2a` while the tree held unticked unit-2a work from the earlier run. The SKILL only handles dirty files outside PLAN.
   Fix: `status.sh` gets a `dirty: <unit>` line; the clean-tree check compares against the next unit's Files column.
7. **Final report said "one fix round in the whole build".** `decisions.tsv` shows more (1a re-review, 1b two rounds, 2a one). Written from the orchestrator's memory after the resume.
   Fix: step 5.4 derives counts from `decisions.tsv` and the phase reports.
8. **Stale / misworded Differences entries** (TASK-040 REQ-049 stale after 4b; REQ-021 misworded) flagged twice by matchers and shipped unchanged.
   Fix: the unit that closes a planned split updates the entry; do not log planned splits as Differences.
9. **Smaller:** runaway mutation left node processes (run mutants under `timeout`); a reviewer wrote a probe file into the repo root; the orchestrator polled with `sleep` and used a wrong job id; report header "approve-with-notes" vs SUMMARY `fail` (`check-report.sh` could assert they agree; lowest value, optional).

## Repo management plan (two harnesses)
The root problem: `pipeline-toy/.dostuff` is a copy that can drift. `install-dostuff.sh` already generates it from `.claude/` (the single source) but is untracked.

1. One source of truth: only edit `claude-build-pipeline/.claude/`. Never edit the toy's `.dostuff`.
2. Commit `install-dostuff.sh`; have it write `.dostuff/.installed-from` with the source commit sha.
3. Add a drift check: `install-dostuff.sh --check` installs to a temp dir and diffs against the toy's `.dostuff`.
4. Harness differences are converter rules (path rename, `ask_user`, `send_message`, `max_iterations`, hooks block dropped), not forks. Make source text neutral where possible.
5. One clean test target per harness: `make-toy.sh` for Claude; a variant that runs `install-dostuff.sh` on a fresh toy for dostuff. Each run starts from a freshly generated toy in a disposable directory.
6. Save run transcripts under `notes/runs/` (e.g. `run-7-dostuff-minimax.md`) instead of leaving them untracked in the toy.
7. agent-1: `agent-1` is the dostuff source checkout (Python package). `hooks-sandbox` is a scratch project that runs that checkout through `PYTHONPATH=..\agent-1; python -m dostuff`: `run-local.ps1` runs it in the sandbox root, `run-toy.ps1` in `pipeline-toy/`, and `run-wt.ps1` in a hard-coded agent-1 worktree. So every run uses whatever agent-1 has checked out at that moment, uncommitted edits included. On 2026-11-18 that was branch `dostuff/subagent-capabilities-skills` on top of `2c42aba` (release 0.2.15), with 8 modified files in subagents/config/skills, which is the code that loads agents. Nothing records which agent-1 state a run used.
   Fix: `run-toy.ps1` writes agent-1's `git rev-parse HEAD` + `git status --short` into a run header, which is saved with the transcript under `notes/runs/`. For a clean verify run, point PYTHONPATH at a detached agent-1 worktree pinned to a known commit (or a `pip install dostuff==X` venv), not at the live checkout. Never edit agent-1 from this repo.

## Order of work (tomorrow)
1. Commit `install-dostuff.sh` + `.installed-from` (items 1-2). Note the working tree also has an uncommitted `tests/pipeline/make-toy.sh` change on `fix/run-6-findings` (toy-7 work).
2. Drift check and fresh-toy script (items 3, 5).
3. R34 to R41 into `.claude/` (findings 1 to 8; 9 optional), then re-install into a fresh toy.
4. Clean dostuff re-run to verify.
