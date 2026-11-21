# Run 11 (dostuff, toy-10 rebuilt) findings and plan

Source: `notes/runs/run-11-dostuff-toy-10.md` (was `Downloads/toy-10/dostuff-session-6e49bdc610fc488e.md`). Plans and reports are in `notes/runs/run-11-toy-10-plans/`, the spawn log in `notes/runs/run-11-pipeline-spawns.tsv`.
Pipeline: R34-R62, uncommitted on `fix/run-7-findings`. The session started at the tasks gate (brief and spec were approved in an earlier session) and ran in AFK.
Result: finished. 7 phases, 11 units (2 auto-fix units), 93 tests, 218 lines of `src/greet.js` and 915 lines of tests.
Cost: 32.5M input tokens and 53k output tokens in the orchestrator session. It used up the user's weekly opencode go quota.
Status (2026-11-21): R63-R67 implemented on `fix/run-7-findings`, uncommitted. Tests: hooks 211, scripts 222.

## Where the tokens went

The orchestrator made about 304 model calls. Each call re-sends the whole session, which grew to about 160k tokens. Estimated re-send cost by source:

| Source | Chars | Re-sent tokens |
|---|---|---|
| Agent replies (full reports, not just the SUMMARY) | 122k | ~4.6M |
| Other bash output (git log/diff, greps over spec and tasks) | 110k | ~4.4M |
| The whole tasks file, read once early | 29k | ~2.3M |
| The skill prompt | | ~2.2M |
| Pipeline scripts and hooks read with `cat` | 19k | ~1.1M |

Unit 7 started when the context was about 136k tokens. Its 48 calls cost about 7M, more than a fifth of the run.

## Counts

- 66 agent spawn calls (some were blocked by the hook): 19 implementer, 18 code-reviewer, 13 spec-matcher, 11 task-writer, 5 task-verifier.
- Fix rounds: units 1, 3, 4 and 5 had 1 each. Unit 7 had 4.
- Matcher stops: phases 2, 3 (twice) and 4. Phase 3 needed `approve.sh retry`.
- Implementer iteration limit (100) hit 3 times, all in unit 7 fix rounds. `empty-report` saved each one.

## Findings

- **R63. MAX_LOOPS exceeded.** `MAX_LOOPS=2`, but unit 7 ran 4 fix rounds before the gate. The orchestrator wrote "This is fix round 2 of MAX_LOOPS=2, so one more round is allowed" (log line 9971). This is the same failure as R59, which was fixed in the prompt only.
- **R64. A negative requirement with no end point.** SEC-001: "The CLI reads no secrets, opens no network connection and writes no file." Each recheck found a new hole in the test spy:
  - the fs spy covered only part of fs;
  - the network spy missed `fetch`, `node:dns` and a spawned `curl`;
  - three `spawnSync` runs skipped the spy preload.

  Each one is a true P1 under "a green mutation that breaks a cited SEC is P1", and the list never ends. Unit 7 took 13:48 to 17:07 UTC.
- **R65. Orchestrator context.** Agent replies carried the full report. The orchestrator read the tasks file in full, and used `cat` on `stage-unit.sh`, `unit-gate.sh`, `check-spawn.sh` and `check-write.sh` to learn how they work.
- **R66. The plan was bigger than the feature.**
  - The brief has 5 flags and a config file. The spec has 470 lines; the tasks file has 270 lines, 7 phases and 11 units.
  - The spec went through 5 rounds, and rounds 3-5 closed only "cosmetic P2 notes".
  - In units 5 and 6, every Red test passed as soon as it was written: an end-to-end layer over behaviour that earlier units already built and tested.
  - The "Fix the P2 notes (Recommended)" option at the spec and tasks gates kept the loop going.
- **R67. Verdict and counts disagree.** The phase-3 matcher wrote `verdict: fail` with p0 = p1 = 0. That counted as a second phase fail, so AFK stopped for two P2 Warnings. The matcher even noticed this in its own reply.

## Fixes

- **R63 (hook).** `check-spawn.sh` counts each distinct `FIX:` file as one round:
  - implementer rounds per unit at HEAD; `unit-changes-*` files (the user's Request changes) are not counted;
  - spec-writer rounds from `reports/spec/review*`, task-writer rounds from `reports/tasks/review*`, across commits; `changes` and `fix-scope` files are not counted.

  A restart with the same `FIX:` is not a new round. Past `MAX_LOOPS` the spawn is blocked until the user runs `approve.sh PLAN loop-<unit|spec|tasks>`, which buys exactly one round. The build-feature skill names the marker at the Give guidance and "one more round" answers.
- **R64 (prompt).**
  - writing-specs: a negative requirement names its bounded check (a static import ban, a spy on named calls), and nothing past that check is in scope.
  - reviewing-plans: an unbounded negative is P1 in spec mode.
  - reviewing-code and code-reviewer: a spy gap past the named check is P2. Adding new forbidden code is not a mutation. A new hole of the same class in a recheck is P2.
- **R65.**
  - build-feature: never open the spec, tasks, reports or pipeline sources; a block message is the whole answer; run independent checks in one shell call.
  - `next-unit.sh --all` lists every unit and its state for the tasks gate (tested).
  - code-reviewer, spec-matcher, spec-verifier and task-verifier reply with the SUMMARY block only.
- **R66 (prompt).**
  - Fix the P2 notes is recommended only the first time a stage's gate is reached.
  - writing-specs: size the spec to the brief.
  - writing-tasks: as few units as the spec needs, grouped by behaviour (2-4 for a small CLI).
  - reviewing-plans: a unit whose Red tests would all pass given earlier units is P1.
- **R67 (script).** `check-report.sh` rejects `fail` with p0 = p1 = 0, and `pass` with p0 + p1 above 0. code-reviewer, spec-matcher and task-verifier run `check-report.sh` on their report before replying (tested).

## Still open

- **An orchestrator script to cut calls.** A script for the whole 4.5 commit sequence would save about 6 calls per unit. It is not done: a `git commit` inside a script slips past `check-git.sh`, which only sees the `bash <script>` command line.
- **Matcher early stops** (phases 2, 3 and 4). The cause is not clear from the log. The shorter replies and the verdict check may help. Watch it in run 12.
- **The implementer's 100-iteration limit in fix rounds.** R64 should remove the harness-chasing that caused it.
- **Compaction did not help.** dostuff has auto compaction, set to `auto_compact_threshold: 20` (percent of the window) in `~/.dostuff/config.yaml`. The model was `opencode-go/minimax-m3`. If its window is 1M, the threshold is 200k, and the orchestrator's estimated peak of about 160k never reached it. The log shows no compaction, and the ~107k average per call fits that. `prompt_caching` covers Claude models only, so every re-sent token was paid in full.
  - For the pipeline, set the threshold by tokens, not percent. About 60-80k suits a 1M window: 6-8%, or set `context_window`. Use `/compact auto <N>` for one session.
  - Compaction drops what the orchestrator read earlier. The pipeline is built for that: all state is in files and `status.sh` resumes. So a low threshold costs little.
  - To check: the window litellm reports for minimax-m3, and whether the session header's token count includes the subagents.

## Next

Rebuild toy-10 (`dostuff-toy.ps1 -Rebuild`) and run a smaller feature in AFK. Compare its token count with this run's 32.5M.
