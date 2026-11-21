---
name: build-feature
description: Builds a feature end to end with specialist subagents. Agree a brief with the user, then spec, tasks, one implementer per unit with code review, phase checks against the spec, user approval gates (or AFK mode with one review at the end), and an optional PR. Run as /build-feature <feature> [requirement], or /build-feature <feature> --from <spec-file> <tasks-file> to build from the user's own spec and tasks.
disable-model-invocation: true
argument-hint: "<feature> [requirement text | --from <spec-file> <tasks-file>]"
allowed-tools: Bash(bash .claude/scripts/*) Bash(git status *) Bash(git diff *) Bash(git rev-parse *) Bash(git log *) Bash(git add *) Bash(git commit *) Bash(git tag *)
---

# Build feature

Arguments: **$ARGUMENTS**. The first word is `<feature>` (kebab-case). The rest, if any, is the requirement, or `--from <spec-file> <tasks-file>`: the user brings their own spec and tasks (step 1, Import). `PLAN` below means `plans/<feature>`. `S` means `bash .claude/scripts`.

You orchestrate. Subagents write the spec, tasks, code and every review, verification and conformance report. You write only the brief (step 1), the fix-input files, the phase and final reports, and the PR body. You never write or edit an agent's report, the spec or the tasks file, not even one line of a report an agent left unfinished: a hook blocks it, and the shell is no way around it.

## Rules

- Nothing is written before the user agrees the brief. A hook blocks `spec-writer` until `PLAN/approvals/brief` exists.
- **Fresh agent every round.** Never resume any agent with `SendMessage` (a hook blocks it). A fix round is a new agent whose prompt names its input file in a `FIX:` line. When the input is the user's text, first write it to a file from `S/report-path.sh PLAN <stage>/changes` and pass that. An agent that stops early is replaced, not resumed: see **Agents that stop early**.
- **Prompts are the templates below, nothing else.** No added rules, notes, scope reminders, finding summaries or file lists: the agent files hold the rules, the tasks file holds the Files column, and a `FIX:` file holds what to fix. A hook blocks every pipeline agent's prompt with extra lines. To narrow a fix round, write the chosen findings to a fix-input file (`S/report-path.sh PLAN <stage>/fix-scope`) and pass that as `FIX:`. If an agent keeps getting something wrong, tell the user; don't patch it in the prompt.
- **Reports.** Every report path comes from `S/report-path.sh PLAN <stage>/<name>`. A path for an agent's `REPORT:` line comes from `S/report-path.sh --pending PLAN <stage>/<name>`, which also creates the `verdict: pending` skeleton the agent replaces. Re-runs get `-2`, `-3`; nothing is overwritten. Stages: `spec`, `tasks`, `phase-<N>`, `final`.
- **Keep your context small.** You run the whole feature in one session and every turn re-sends everything you have read, so each file you open is paid for again on every later turn (run 11: 304 turns, 32M input tokens). Never open the spec, the tasks file, an agent's report, the agent files, or a pipeline script or hook (`cat`, `Read`, `grep` into them): the scripts print what you need. Units come from `S/next-unit.sh PLAN` (all of them, for a gate: `S/next-unit.sh --all PLAN`), state from `S/status.sh PLAN`, a report's verdict from its SUMMARY. When a script or hook blocks you, its message is the whole answer; do not read its source to find out why. Run independent checks in one shell call.
- Read only the SUMMARY block of a reviewer, verifier or matcher reply. Open the full report only when escalating to the user. Never re-check an agent's work yourself: no probes, mutants, test scripts or regrading of your own. The report is the evidence, and a verdict you disagree with goes to the user, not into a report you write.
- **Severity.** `verdict: fail` (p0 or p1 above 0) starts a fix round. p2 never starts a fix round on its own. At a gate where p0 and p1 are 0, Approve is the first option, marked "(Recommended)", and the P2s are listed as notes. Exception: at the spec and tasks gates with p2 above 0, **Fix the P2 notes** comes first, marked "(Recommended)", the first time that gate is reached: later agents read these files, so stale rows and wrong text there cost more later than one writer round now. After one P2 round has run for that stage, Approve is recommended again and the remaining P2s are notes: each P2 round costs a writer and a verifier, and run 11 spent three spec rounds on cosmetic notes (R66).
- Never answer a gate yourself. Run `approve.sh` only right after the user picked that option in this session. A gate question the user cancelled or left unanswered is asked again; "continue" is not an answer to it.
- Pass script output verbatim. Never alter, split or reorder a unit.
- Report each step to the user in one line (`unit 2a: implementer done, review pass, committed abc123`).
- Read `TEST_CMD`, `MAX_LOOPS` and `UNIT_GATE` from `.claude/pipeline.conf`.
- Every gate uses `AskUserQuestion`. Stop ends the run; all state is in files, so a later `/build-feature <feature>` resumes.
- Strict gate option: the user may run `! bash .claude/scripts/approve.sh plans/<feature> <name>` themselves and then tell you to continue. Check the marker exists before moving on.
- **Git.** Work only on `feature/<feature>` (step 0). Stage only with `S/stage-unit.sh` or `git add plans/<feature>` (a literal path), never `git add -A`, `git add .` or code paths, and never `git commit -a` (a hook blocks these). A commit that carries code needs a passing review of the unit open at HEAD, or the user's Commit anyway (`approve.sh PLAN commit-<unit>`); a hook blocks any other. Never force-push, amend, or move or delete a tag (a hook blocks these). Commit messages are `type(scope): subject`, no trailing period, no em dashes. Push and open PRs only after the user says yes, in AFK mode too.
- **Never relax a check to pass it.** Do not edit the spec, the tests or the checks to get green. A failing check is fixed in code or raised to the user.
- **Decision trail.** Log every commit, fix round (spec, tasks and unit rounds alike, including a round the user allowed past `MAX_LOOPS`), restart, added unit, skipped step and stop with `S/log-decision.sh PLAN <step> <decision> <why> <evidence> <result>`. Only that script writes `decisions.tsv`: no `printf >>`, no `tee` (a hook blocks shell writes to it and to `approvals/`). Log a fix round only after `check-report.sh` accepted the report that starts it.
- If a pipeline script or hook is broken, stop and tell the user. Do not work around it.
- **The config is the user's.** Never change the harness settings (models and their aliases, limits, hooks, permissions) or `.claude/pipeline.conf` during a run, not even to get a failing agent through: a hook blocks it. When an agent fails on its model, stop and tell the user which agent and model.
- Run scripts and tests in the foreground and wait for them. Never poll with `sleep` or check on background jobs.
- **Decision names** in `log-decision.sh` (`S/run-stats.sh` counts them): `commit`, `fix-round`, `restart`, `add-unit`, `skip`, `stop`, `empty-report`, `gate-reason`, `Q-<n>`. Per-unit rows use step `unit-<id>`; spec and tasks rows use step `spec` or `tasks`. `restart` is a new agent for one that stopped early (any type); `empty-report` is only an implementer whose work was done although its reply was not.

## Agents that stop early

An agent stopped early when its reply has no SUMMARY block (reviewer, verifier, matcher), no `tasks done` line (implementer) or no summary of what it wrote (spec-writer, task-writer), or the harness says it hit its turn or iteration limit. Every `REPORT:` file starts as the `verdict: pending` skeleton from `report-path.sh --pending`, so the files tell you what happened:

- **Reviewer, verifier or matcher.** Run `S/check-report.sh <its REPORT>`. Exit 0: the report is finished; read the SUMMARY from the file and go on. Exit 1 (missing, pending, no verdict, counts that disagree): the report does not count, even if the reply had a SUMMARY. Never edit it to pass. Spawn one new agent of the same type with the same prompt (every line, `RECHECK:` included), a new `REPORT:` from `report-path.sh --pending`, and `PARTIAL: <the old report>`. Log decision `restart`. The same holds for a report `check-report.sh` rejected for its format (for example `Verdict: changes-requested`): the replacement gets `PARTIAL:`, never `RECHECK:`, because a rejected report is no review to recheck.
- **Spec-writer or task-writer.** Spawn one new writer with the same prompt; it continues the file if the first one started it. Log `restart`. Do not grep the file to decide the writer finished after all: the verifier is the check, and only a finished writer's file is committed (2.3). (A new file is untracked: `git status --short -- <its file>` shows it, `git diff` does not.)
- **Implementer.** Run `TEST_CMD` and `S/tick-unit.sh PLAN <unit-id>`. Both pass: the unit is built; log `empty-report` and go to 4.3. Otherwise spawn a new implementer with the same prompt, its `UNIT:` line taken fresh from `S/next-unit.sh PLAN` (the rest of the unit; the hook checks it) on a first build, or the same `FIX:` line in a fix round. Log `restart`.

A restart does not count toward `MAX_LOOPS`. One restart per agent run: when the new agent stops early too, the job is too big for one agent. Stop and tell the user which agent and report (AFK too); never spawn a third agent, never switch its model and never do the agent's work yourself. A hook blocks the third spawn (it counts unfinished reports of the same prompt, with or without `PARTIAL:`); the user can allow one more with `! bash .claude/scripts/approve.sh PLAN retry`. Ask with these options only, and spawn nothing until the answer allows it:
- Writer or implementer: **Retry with a narrower scope** (the user picks the findings; write them to `S/report-path.sh PLAN <stage>/fix-scope` and spawn the same template with `FIX:` that file) / **Stop**.
- Verifier, reviewer or matcher (their templates have no `FIX:`, so there is no narrower scope): **Allow one more run** (the user runs `! bash .claude/scripts/approve.sh PLAN retry` and says continue; check `PLAN/approvals/retry` exists before the spawn) / **Stop**.
Never spawn to "see what the hook says".

## AFK mode

The user turns it on only at the tasks gate ("Approve and run to the end"), which writes `PLAN/approvals/afk`. In AFK mode:

- No phase gates, no unit gates and no gate for added units. The hook allows the next phase without `approvals/phase-N`. Everything else still runs: reviews, fix rounds, phase checks, one automatic fix unit per phase, phase reports and tags.
- **Stop, don't ask**, when: a unit is still red or still `verdict: fail` after `MAX_LOOPS` rounds; a hook blocks a spawn; `stage-unit.sh` or `scan-staged.sh` refuses; a phase still fails its conformance check after its fix unit; a script fails. Leave the working tree as it is: commit nothing, not even "so it is not lost" (no `wip` or unit commit; the staged change is safe, and `status.sh` resumes at the review). A hook blocks a code commit without a passing review. Log the stop, then end with one short paragraph: what stopped, the report path, what you need.
- On resume after a stop, ask the question that stopped the run as a normal gate, then carry on in AFK mode.
- The run needs no permission prompts: tell the user once, at the tasks gate, that the session should be in auto or accept-edits mode.
- The user reviews everything once, at the final gate (step 5).

## 0. Resume

1. Run `S/branch.sh PLAN`. Exit 0: go on. Exit 3 (another branch): ask Continue on this branch / Stop. Exit 1: show the error and stop.
2. Run `git remote get-url origin`. None: tell the user once that step 6 (PR) will not be possible, and carry on.
3. Run `S/status.sh PLAN`. Start at the first line that applies; never redo approved work:

| Status | Go to |
|---|---|
| `brief: missing` or `brief: written` | 1 |
| `import: spec` | 2.1 (reformat) |
| `import: tasks` | 3.1 (reformat) |
| `spec: missing` | 2.1 |
| `spec: written` | 2.2 |
| `tasks: missing` | 3.1 |
| `tasks: written` | 3.2 |
| `uncommitted: <unit>` | 4.3 for that unit, `BASE` = HEAD |
| `dirty: <unit>` | An earlier run stopped mid-unit. Show `git status --short` and ask Finish it / Stop (AFK too: this is a resume). Finish it: 4 for that unit, `BASE` = HEAD; the implementer builds on the files there. To discard the work instead, the user runs `! git stash -u` and reruns `/build-feature <feature>` |
| `gate: N` | 4.6 for phase N |
| `next: <unit>` | 4 |
| `next: none`, `final: open` | 5 |
| `final: approved` | 6 |

## 1. Align

**Import.** With `--from <spec-file> <tasks-file>`, or `brief: written` on a brief with `source: imported`, there is no interview; the user's files are the agreement:

1. `brief: missing`: run `S/import-plan.sh PLAN <spec-file> <tasks-file>`. Exit 1: show the error and stop. It copies both files into `PLAN` unchanged and writes a draft brief with `source: imported`.
2. Ask with `AskUserQuestion`: "Build from these files? They are reformatted to the pipeline format next, and you see the diff at the spec and tasks gates." Show the two copied paths. Options: **Agree** / **Stop**. Agree: `S/approve.sh PLAN brief`, then `git add PLAN && git commit -m "docs(<feature>): import spec and tasks"` and `git tag <feature>-imported` (the user's text as it came in; every import diff starts there). Go to 2.1.

Otherwise, reach consensus with the user on what gets built. Invoke the `aligning-requirements` skill with `<feature> <requirement>` and follow it in this session. It interviews the user, writes `PLAN/feature-<feature>-brief.md`, and ends with the consensus question.

- No requirement given: ask for it in plain text first.
- `brief: written` on resume: show the brief and go straight to its consensus question; reopen the interview only for what the user wants changed.
- Decisions this conversation already settled count. Record them in the brief instead of asking again.
- Move on only when `PLAN/approvals/brief` exists (`approve.sh` also sets the brief to `status: agreed`). Commit: `git add PLAN && git commit -m "docs(<feature>): brief agreed"`.

## 2. Spec

1. **Write.** Spawn `spec-writer`:
   ```
   PLAN: plans/<feature>
   Brief: plans/<feature>/feature-<feature>-brief.md (agreed with the user; its decisions are binding)
   Write the spec.
   ```
   **Imported plan** (`import: spec`): the last line is `Reformat the imported spec.` instead. After it finishes: `git add PLAN && git commit -m "docs(<feature>): spec reformatted"`, then `S/import-plan.sh --diff PLAN spec` (it prints the diff report path and the diffstat), and `git add PLAN && git commit -m "docs(<feature>): spec import diff"`. Then 2.2.
2. **Verify.** `R=$(S/report-path.sh --pending PLAN spec/review)`. Spawn `spec-verifier` with exactly:
   ```
   spec plans/<feature>
   REPORT: <R>
   ```
   On a recheck add `RECHECK: <previous review>`; on a restart add `PARTIAL: <unfinished report>`.
3. **Fix loop.** After every spec-writer run that finished (first write, fix round, changes), commit the plan before verifying: `git add plans/<feature> && git commit -m "docs(<feature>): spec round <n>"`, so a recheck can diff what the round changed. While `verdict: fail`, at most `MAX_LOOPS` rounds: spawn a new `spec-writer` with the same PLAN and Brief lines plus `FIX: <R>` and "Fix only the P0 and P1 findings in that file." Then a new `spec-verifier` with a new `REPORT:` and `RECHECK: <R>`. Still failing: show the remaining `top:` lines at the gate. A gate answer "one more fix round" buys exactly one round: run `S/approve.sh PLAN loop-spec` (`loop-tasks` at 3.3), because a hook counts the rounds and blocks a writer FIX round past `MAX_LOOPS` without that marker (R63). Still failing after it, ask again. Log every round as `fix-round` (step `spec`). An open question in the spec is the user's: it goes to the gate, never into a fix prompt for the writer to decide.
4. **Gate.** Show the spec path, the report path, on an imported plan the import diff report and its diffstat (what the writer changed in the user's text, including every later fix round: `git diff <feature>-imported HEAD -- <spec>`), its open questions, any place it departs from the brief, and the P2 notes. Ask each open question in the same `AskUserQuestion` call; the answers go into the change file. Options: Approve / Request changes / Stop, with **Fix the P2 notes** first when p2 is above 0 (as Request changes, the change file listing those P2s and the open-question answers; the gate comes again after the recheck). Log each answer to an open question with `log-decision.sh` (step `spec-gate`, decision `Q-<n>`). Approve: `S/approve.sh PLAN spec` (it stamps the spec `Approved`). Request changes: write the user's text to `S/report-path.sh PLAN spec/changes`, spawn a new spec-writer with the PLAN line, `FIX:` that file and "Apply the changes in that file.", then go to 2.2 with `RECHECK:` the last review. If the change contradicts a brief decision, update the brief first (step 1, Change something).

## 3. Tasks

1. **Write.** Spawn `task-writer`: `PLAN: plans/<feature>. Write the tasks file from the approved spec.`
   **Imported plan** (`import: tasks`): spawn it with `PLAN: plans/<feature>. Reformat the imported tasks file.` instead. After it finishes: `git add PLAN && git commit -m "docs(<feature>): tasks reformatted"`, `S/import-plan.sh --diff PLAN tasks`, `git add PLAN && git commit -m "docs(<feature>): tasks import diff"`. Then 3.2.
2. **Verify.** Run `S/check-plan.sh PLAN` yourself. `R=$(S/report-path.sh --pending PLAN tasks/review)`. Spawn `task-verifier` with exactly a `tasks plans/<feature>` line and `REPORT: <R>` (plus `RECHECK:` or `PARTIAL:` as in 2.2).
3. **Fix loop.** As 2.3 (commit after every finished writer run: `docs(<feature>): tasks round <n>`; one round per "one more round" answer; log each), with a new task-writer (`PLAN:` line, `FIX: <R>`) and a new task-verifier. A FAIL from check-plan counts as p0. When the task-writer's reply has `Spec changes needed:` lines (R69), before the recheck: copy those lines to `C=$(S/report-path.sh PLAN spec/changes)`, spawn a new spec-writer with the PLAN line, `FIX: <C>` and "Apply the changes in that file.", and commit (`docs(<feature>): spec change from tasks review`). The task-verifier recheck covers both files; at the gate, say the spec changed after its approval and show `git diff --stat $(git log -1 --format=%h -- PLAN/approvals/spec) HEAD -- <spec>`.
4. **Gate.** Show the units in order with their task ids (`S/next-unit.sh --all PLAN`), the report path and the P2 notes. On an imported plan also show the tasks import diff report and its diffstat, and the units the writer split and tasks it added (from its reply). Options:
   - **Fix the P2 notes** (only when p2 is above 0, then first and recommended): as Request changes, with the P2 lines from the review as the change file. The gate comes again after the recheck. `AskUserQuestion` takes four options, so in this case Request changes is the free-text answer ("Other"): say so in the question.
   - **Approve**: `S/approve.sh PLAN tasks`. Phases are gated one by one, except the last (4.6.4).
   - **Approve and run to the end (AFK)**: `S/approve.sh PLAN tasks` and `S/approve.sh PLAN afk`. No more gates until the final review; the run stops on its own if something fails. Say that the session should be in auto or accept-edits mode.
   - **Request changes**: as 2.4, with the task-writer and `tasks/changes`.
   - **Stop.**

   On either approval: `git add PLAN && git commit -m "docs(<feature>): spec and tasks approved"` and `git tag <feature>-tasks`.

## 4. Unit loop

Before the first unit:
- **Baseline.** Run `TEST_CMD`. Red: show the tail and ask Continue anyway / Stop (AFK: stop). This replaces any baseline unit.
- **Clean tree.** Run `git status --porcelain`. Anything outside `PLAN` that is uncommitted would block every unit commit: show it and ask the user to commit or stash it, then Stop. Skip this when step 0 found `dirty: <unit>` and the user chose Finish it.

Repeat until `next-unit.sh` prints nothing:

1. `UNIT=$(S/next-unit.sh PLAN)`, `BASE=$(git rev-parse HEAD)`, `N` = the unit id without its letter: unit 3 is phase 3, its reports go under `phase-3/` (`report-path.sh` refuses a review filed under another phase).
2. Spawn `implementer` with exactly this prompt (a hook checks it):
   ```
   PLAN: plans/<feature>
   UNIT: <UNIT verbatim>
   Implement only these tasks.
   ```
   If the hook blocks the spawn, show the reason to the user and stop. Do not retry with a different unit.
   If the reply has no `tasks done` line (for example just "pending", or raw reasoning), do not trust it: follow **Agents that stop early**.
3. **Stage and review.**
   1. `S/stage-unit.sh PLAN <unit-id>`. Exit 1 (files outside the unit): write its output to `S/report-path.sh PLAN phase-N/stray-<unit-id>` and treat it as a failed review (4.4).
   1b. `S/tick-unit.sh PLAN <unit-id> <BASE>` now, before any review. `foreign tick: ...` goes to the fix loop (4.4) with that output as the FIX file, without spawning a reviewer.
   2. `PID=$(S/patch-id.sh PLAN)`. `R=$(S/report-path.sh --pending PLAN phase-N/review-<unit-id>)`. Run `rm -rf "${TMPDIR:-/tmp}"/mut-<unit-id>*` so a scratch copy left by an earlier reviewer cannot block this one (`scratch-copy.sh` refuses an existing folder).
   3. Spawn `code-reviewer`:
      ```
      PLAN: plans/<feature>
      UNIT: <UNIT verbatim>
      BASE: <BASE>
      REPORT: <R>
      Review the staged change (git diff --cached BASE).
      ```
      On a re-review add `RECHECK: <previous review report>`.
4. **Fix loop.** Run `TEST_CMD`. If it is red, `verdict: fail` or `scope: drift`, at most `MAX_LOOPS` rounds:
   1. Red: write the last 40 lines to `S/report-path.sh PLAN phase-N/tests-<unit-id>`.
   2. Spawn a new `implementer`:
      ```
      PLAN: plans/<feature>
      UNIT: <UNIT verbatim, as in step 2>
      FIX: <the review, stray or tests file>
      ALSO: <other files of this round, space separated; omit the line when there are none>
      Fix only the P0 and P1 findings, the drift and the failing tests named there.
      ```
      Log decision `fix-round` (step `unit-<id>`).
   3. Back to 4.3 (stage, new PID, new reviewer with `RECHECK:`).

   Still failing after `MAX_LOOPS` rounds: ask with the remaining findings and the report path: Commit anyway / Give guidance / Stop (AFK: stop). Commit anyway: `S/approve.sh PLAN commit-<unit-id>`, then 4.5 (the commit hook needs that marker). Give guidance: `S/approve.sh PLAN loop-<unit-id>`, write the user's text to `S/report-path.sh PLAN phase-N/guidance-<unit-id>`, spawn a new implementer with `FIX:` that file, then 4.3. The hook counts each distinct `FIX:` file of the unit as one round and blocks the implementer past `MAX_LOOPS` rounds; the marker buys exactly one more (R63). Count rounds by that rule, not in your head: "round 2 of MAX_LOOPS=2, so one more is allowed" is wrong, the gate comes now.
5. **Commit.** All of these, in order:
   1. (No separate test run: `unit-gate.sh` in 5.5 runs `TEST_CMD`.)
   2. `S/tick-unit.sh PLAN <unit-id> <BASE>` exits 0. `foreign tick: ...` means the implementer ticked another unit's task: unlike a stray file it is not a Difference; treat it as a failed review (4.4) with that output as the FIX file, and have the implementer reset the row.
   2b. `S/check-report.sh <the last review report>` exits 0. A reviewer that did not finish its report has not reviewed: discard its verdict and follow **Agents that stop early**.
   3. `S/stage-unit.sh PLAN <unit-id>` (adds the reports), then `S/patch-id.sh PLAN` equals the `PID` of the last review. Different: the code changed after the review; go back to 4.3.
   4. `S/scan-staged.sh`. Exit 1: show the findings and stop; never commit a secret. Exit 3: ask Commit anyway / Stop (AFK: stop).
   5. **Unit gate.** `S/unit-gate.sh PLAN <BASE> <fix rounds run for this unit> <the last review report>` (it reads the still-green count from the report's `mutations:` line). It runs `TEST_CMD` first. Exit 4 (tests red): write its output to `S/report-path.sh PLAN phase-N/tests-<unit-id>` and go to the fix loop (4.4) with that file. Exit 1: stop. Log every `reason:` line with `log-decision.sh` (step `unit-<id>`, decision `gate-reason`), AFK too, so the final Attention section sees them. On `gate: yes`, show the reasons, the last review report and `git diff --cached --stat BASE`, then ask Commit / Request changes / Stop. A logged Difference that weakens or drops a spec test comes first in the question.
      - Commit: go on.
      - Request changes: write the user's text to `S/report-path.sh PLAN phase-N/unit-changes-<unit-id>`, spawn a new implementer with `FIX:` that file, then 4.3. This round does not count toward `MAX_LOOPS`.
      - Stop: leave the change staged; on resume `uncommitted: <unit>` re-reviews it and this gate runs again.
   6. Log the commit first (`log-decision.sh`, step `unit-<id>`, decision `commit`, evidence the review report path, result `committing`), then `git add PLAN && git commit -m "feat(<feature>): unit <unit-id>"`. Logging after the commit would leave `decisions.tsv` dirty for the next implementer; the sha is in `git log`.
6. **Phase end.** Run `S/phase-done.sh PLAN <unit-id>` after every unit commit, AFK too. If it exits 0 (or step 0 sent you here with `gate: N`), do all of the following before the next unit; a hook blocks the next phase's implementer while `status.sh` shows `gate: N`:
   1. `C=$(S/report-path.sh --pending PLAN phase-N/conformance)`. Spawn `spec-matcher`: `PLAN: plans/<feature> --phase N`, `REPORT: <C>` and `DECISIONS: plans/<feature>/decisions.tsv` (so it knows what the user already decided; it adds its Attention section only in AFK mode).
   2. **Automatic fix unit.** The phase verdict is the matcher's report as `check-report.sh` accepts it; you never regrade it. If you think the matcher graded later-phase work, say so in the phase report, but the fix unit still runs. If `verdict: fail` and `S/fix-unit.sh PLAN count N` prints 0:
      1. `ID=$(S/fix-unit.sh PLAN id N)`. Spawn a new `task-writer`: `PLAN: plans/<feature>. Add one unit "## Phase <ID>: Auto-fix <short title>" for the P0 and P1 gaps in <C>, placed after phase N's last unit, depending on phase N's units, at most MAX_UNIT_TASKS tasks. Add traceability rows for its tasks. Change nothing else.`
      2. Run `S/check-plan.sh PLAN` and `S/fix-unit.sh PLAN check <ID>`. A FAIL: one new task-writer round with `FIX:` that output written to `S/report-path.sh PLAN phase-N/fix-unit-check`; still failing: stop.
      3. `T=$(S/report-path.sh --pending PLAN phase-N/fix-unit-review)`. Spawn `task-verifier`: `tasks plans/<feature>`, `UNIT: <ID>`, `REPORT: <T>`. `verdict: fail`: one fix round as 3.3.
      4. Not AFK: show the new unit's tasks and ask Approve / Request changes / Stop. AFK: log it (decision `add-unit`) and go on.
      5. `git add PLAN && git commit -m "docs(<feature>): add unit <ID>"`. Back to the loop; the fix unit runs next.

      A second `verdict: fail` for the same phase goes to the gate as is (AFK: stop).
   3. **Phase report.** `P=$(S/report-path.sh PLAN phase-N/report)`. Write: phase N's units with their commit shas (`git log --oneline <previous tag>..HEAD`), each unit's last review report and verdict, the `Differences from the spec` entries for phase N's tasks, the matcher SUMMARY, the `TEST_CMD` command and result (run now), and `git diff --stat <previous tag>..HEAD`. The previous tag is `<feature>-phase-<previous N>`, or `<feature>-tasks`. Commit it: `git add PLAN && git commit -m "docs(<feature>): phase N report"`.
   4. **Gate** (not AFK, and not the last phase). Show the report path and the one-line results. Approve / Request changes / Stop.

      **Last phase** (`S/next-unit.sh PLAN` prints nothing): no phase gate, since the final gate comes next and covers the same work. `git tag <feature>-phase-N` right after the report and go to 5. `status.sh` treats the last phase as ended by its tag, so a resume goes to 5 too.
      - Approve: `S/approve.sh PLAN phase-N`, then `git tag <feature>-phase-N`.
      - Request changes: write the user's text to `S/report-path.sh PLAN phase-N/changes`. Add a unit as in 4.6.2, titled `Changes <short title>` instead of `Auto-fix`, from that file. Then continue the loop; the phase end and its gate come again.

      AFK: no gate. `git tag <feature>-phase-N` right after the report, and go on.

   A tag is set once and never moved. When a phase ends a second time (changes after its gate), tag `<feature>-phase-N-2`, then `-3`. The previous tag for a diffstat is the newest tag of the previous phase.

## 5. Final

1. Run `TEST_CMD`. Red: stop (not AFK: show it and ask).
2. **Run it for real.** Tests alone are not enough. Run the feature's entry point once with the spec's own example (the CLI command, the request, the script) and keep the command and its output. If the spec names no runnable example, say so.
3. `F=$(S/report-path.sh --pending PLAN final/conformance)`. Spawn `spec-matcher`: `PLAN: plans/<feature>` and `REPORT: <F>` and `DECISIONS: plans/<feature>/decisions.tsv` (in AFK mode it adds an Attention section).
4. `FR=$(S/report-path.sh PLAN final/report)`. Write: units and commits, links to every phase report, the final conformance SUMMARY, the real run (command and output), every finding still open (p0, p1, P2 notes), and in AFK mode the matcher's Attention section. Every count (reviews, fix rounds, restarts, added units, stops) is the output of `S/run-stats.sh PLAN`, pasted as is; never count from memory, which a resume or a long run loses. Commit it. The phase and final reports are yours, not an agent's: they get no SUMMARY block, and `check-report.sh` is not run on them.
5. **Final gate.** There is no script for it: show the report path and the summary, then ask with `AskUserQuestion` (AFK too; this is the one review AFK keeps). `status.sh` says `final: open` until the user picks Accept. Options:
   - **Accept**: `S/approve.sh PLAN final` (it sets the tasks file status to Done), commit the marker and the tasks file, go to 6.
   - **Request changes**: write the text to `S/report-path.sh PLAN final/changes`, add a `Changes` unit to the last phase as in 4.6.2, and go back to 4. AFK stays on.
   - **Roll back to a phase tag**: list the `<feature>-phase-*` tags. The user runs `! git reset --hard <tag>` themselves; then rerun `/build-feature <feature>`.
   - **Stop.**

## 6. Pull request

Ask with `AskUserQuestion`: **Push and open a PR** / **Not now**. Always ask, AFK mode included. Not now: end with the branch name.

1. No `origin` remote, or `gh` is missing or not logged in: say so and end.
2. Write the body to `S/report-path.sh PLAN final/pr-body`: under 40 lines, these headings in order, empty ones dropped:
   - `## Why`: opens with the user's goal from the brief (imported plan: from the spec's overview).
   - `## What changed`: behaviour, not files.
   - `## Scope`: what is in and what is out (always present).
   - `## Tradeoffs`: the Differences from the spec, in one line each.
   - `## Blast Radius`: what else this can break.
   - `## Verification`: `TEST_CMD` and its result, the real-run command and output, the conformance verdict.

   Link the reports (`plans/<feature>/reports/...`); keep shas, verdict tables and long lists there, not in the body. Use `Closes #<n>` only when the brief names an issue and the final conformance has `verdict: pass`, else `Refs #<n>`.
3. `S/scan-staged.sh --file <body>` must exit 0. Otherwise show the findings and stop.
4. `git push -u origin feature/<feature>`. If `gh pr view` finds a PR for the branch, `gh pr edit --body-file <body>`; else `gh pr create --base <default branch> --title "feat(<feature>): <subject>" --body-file <body>`. Open it ready; add `--draft` only when the final conformance still has p0 above 0.
5. Show the PR URL. Never merge it.
