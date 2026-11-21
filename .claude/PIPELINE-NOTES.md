# Pipeline notes

Findings that the build pipeline relies on. Docs base: https://code.claude.com/docs/en/. Read 2026-11-14 against Claude Code 2.1.325.
`[V]` = quoted verbatim from the page. `[S]` = from a summarized part of the page; re-check live in M6 (the hook logs its stdin when `PIPELINE_DEBUG=1`).

## M0 preflight

| Check | Result |
|---|---|
| git repo | none at start; `git init` on user approval, branch `master`. `.gitattributes` forces LF so bash scripts survive `core.autocrlf=true`. |
| bash | GNU bash 5.2.12 (Git for Windows, msys) |
| jq | not installed at start; installed with `winget install jqlang.jq`. Running sessions keep the old PATH, so `scripts/lib.sh` falls back to the WinGet package path. |
| Claude Code | 2.1.325 |
| TEST_CMD | `npm test` (user choice; set per project in `pipeline.conf`) |

## Decisions taken with the user (M0 to M1)

- Tasks table is `| ID | Task | Spec | Files | Status | Done |` (plan 3.1 plus a Spec column). Scripts find columns by header name.
- The pipeline is built and tested on fixtures and the M6 toy feature only. (`plans/chat-agent` moved to the separate web-agent repo on 2026-11-16, when this repo became pipeline-only.)

## 1. PreToolUse on the Agent tool (hooks.md, "tool_input fields" > Agent)

- Tool name is `Agent` [V, sub-agents.md "Restrict which subagents can be spawned": "the Task tool was renamed to Agent"]. Matcher: `Agent`.
- `tool_input` fields [V]: `prompt`, `description`, `subagent_type`, `model` (optional).
- Common input fields [S]: `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`, plus `tool_name`, `tool_input`, `tool_use_id`. `agent_id` / `agent_type` appear when the event fires inside a subagent [V].
- Blocking [V, "PreToolUse decision control"]: exit 2, and "Claude sees the stderr message as the denial reason." JSON alternative: `hookSpecificOutput.permissionDecision: "deny"` with `permissionDecisionReason` (shown to Claude). We use exit 2 + stderr.

Shape used by `check-spawn.sh`:
```json
{"hook_event_name":"PreToolUse","tool_name":"Agent","cwd":"...",
 "tool_input":{"subagent_type":"implementer","description":"...","prompt":"PLAN: plans/x\nUNIT: 2a: TASK-020 TASK-021\n..."}}
```

## 2. SubagentStop (hooks.md, "SubagentStop")

- Input [S]: `stop_hook_active`, `agent_id`, `agent_type`, `agent_transcript_path`, `last_assistant_message`, plus common fields.
- Exit 2: stderr is delivered to the subagent as its next instruction [S]. `{"decision":"block","reason":"..."}` does the same [S].
- Matcher matches the agent type, i.e. the frontmatter `name` [V, "Matcher patterns"; sub-agents.md "Project-level hooks for subagent events"].

## 3. settings.json registration (hooks.md, "How a hook resolves", "Matcher patterns")

```json
{"hooks":{"PreToolUse":[{"matcher":"Agent","hooks":[{"type":"command","command":"bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/check-spawn.sh\""}]}]}}
```
- Matcher [V]: letters/digits/`_`/`-`/space/`,`/`|` only means exact names separated by `|` or `,`; anything else is an unanchored JS regex; `*`, `""` or omitted matches all.
- `$CLAUDE_PROJECT_DIR` is exported to the hook process [V]. Quoted because this project path contains spaces.

## 4. Frontmatter hooks in agent files (sub-agents.md, "Define hooks for subagents")

- YAML: `hooks: { Stop: [ { hooks: [ { type: command, command: ... } ] } ] }` [V].
- [V] "When the agent is invoked as a subagent, `Stop` hooks in frontmatter are automatically converted to `SubagentStop` events."
- Stdin for that hook: NOT DOCUMENTED separately; assumed SubagentStop input. Verified in M6.
- Frontmatter hooks run only while that subagent is active; project agent files need workspace trust [V].
- Decision: wire `implementer-stop.sh` only in `implementer.md` frontmatter (not also in settings), so it runs once.

## 5. Agent frontmatter (sub-agents.md, "Frontmatter reference")

- Supported [V]: `name`, `description` (required), `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `autoCompactWindow`, `skills`, `mcpServers`, `hooks`, `memory`, `background`, `omitClaudeMd`, `effort`, `isolation`, `color`, `initialPrompt`, `experimental`.
- `tools`: comma string or YAML list. Omitted means inherit all, including `Agent` [V]. Listing tools without `Agent` blocks nesting.
- `skills`: YAML list, full content preloaded, max 32 [V]. Skills with `disable-model-invocation: true` cannot be preloaded [V].
- `Skill` tool: omitting it from `tools` stops the agent invoking other skills [V]. Decision: omit `Skill`; agents rely on preloaded skills.
- `model`: `sonnet`, `opus`, `haiku`, `fable`, full id, `inherit` [V]. `maxTurns`: at the limit output is marked partial and can be resumed [V].
- `permissionMode`: `default`, `acceptEdits`, `auto`, `dontAsk`, `bypassPermissions`, `plan`, `manual` [V]. Not set; the session mode applies.
- Project `.claude/agents/code-reviewer.md` overrides the user-level `~/.claude/agents/code-reviewer.md` in this repo (scope priority, project > user).

## 6. SendMessage resume (sub-agents.md, "Resume subagents") [S]

- Since 2026-11-15 the pipeline does not resume agents; every fix round is a fresh agent (see Decisions). Kept for reference.

- `SendMessage` with `to: <agentId>` (or name) resumes a finished subagent with its context, no new `Agent` call, so `check-spawn.sh` never sees it.
- Works within the session; after a restart, IDs may survive on resume of the same session, names only since v2.1.299. Pipeline treats resume after restart as unsupported: fixes go to a new implementer with the report path.
- Explore and Plan agents cannot be resumed (not used here).

## 7. AskUserQuestion

- Removed from every subagent even if listed [V, sub-agents.md "Available tools"]. Only the main session can ask. Gates therefore live in the `/build-feature` skill, which runs in the main session.

## 8. Skills (skills.md, "Frontmatter reference")

- `disable-model-invocation: true` = user-invoked only [V]. `argument-hint`, `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N` [V].
- `${CLAUDE_SKILL_DIR}` and `${CLAUDE_PROJECT_DIR}` are substituted in the skill body [V].
- `allowed-tools` pre-approves tools for the invoking turn [V].

## 9. Worktrees (for M7)

- `isolation: worktree` branches from the default branch, not the parent HEAD [V]. A base-branch setting is linked from the worktrees page, not yet read. The Agent call accepts `isolation` per call [V for forks, implied otherwise]. Re-check before M7.

## 10. Agent teams

- [V] With agent teams on, a named subagent spawned from the main conversation launches as a teammate unless it passes `isolation`. Keep `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` unset.

## M3/M4 live findings (2026-11-14)

- New agent files are not picked up by an already running session ("Agent type 'spec-verifier' not found"). Restart Claude Code after adding or renaming agents.
- `claude -p --agent <name>` runs the agent as the main session and does NOT preload its `skills:` (agents reported "PRELOADED: none"). Not a valid test of the pipeline. Spawned as real subagents (headless parent calling `Agent`), skills were preloaded: implementer `writing-tasks`, code-reviewer `reviewing-code`; spec-verifier returned the exact SUMMARY format.
- Real PreToolUse stdin for `Agent` (captured): `session_id`, `cwd` (Windows form `C:\\...`), `scratchpad_dir`, `prompt_id`, `permission_mode`, `effort`, `hook_event_name`, `tool_name: "Agent"`, `tool_input: {description, prompt, subagent_type}`, `tool_use_id`. Matches section 1.
- Real stdin of the implementer frontmatter Stop hook: `hook_event_name: "SubagentStop"`, `agent_type: "implementer"`, `agent_id`, `stop_hook_active`, `agent_transcript_path`, `last_assistant_message`, `background_tasks`, `session_crons`. Confirms sections 2 and 4.
- Live block works: a wrong `implementer` spawn in this session was refused with the check-spawn reason shown to the model.
- code-reviewer could not save its report through a Bash heredoc (permission prompt). It now has `Write`, limited by its prompt to `plans/<feature>/reports/`. Deviation from the plan's tool table.
- M6 feedback: spec-verifier returned P2 findings inline only, so they were lost after the gate. spec-verifier and task-verifier now have `Write` (report only) and save `reports/spec-review-<date>.md` / `reports/tasks-review-<date>.md` (`-2`, `-3` on re-review); `report:` carries the path. Deviation from the plan's "read-only" verifiers.
- Each hook writes its last stdin to `$TMPDIR/pipeline-last-<hook>.json` for debugging.

## M5 additions

- `scripts/status.sh <plan>` prints `spec:`, `tasks:`, `gate:` and `next:` lines so `/build-feature` resumes from script output instead of model judgment. Not in the original plan; tested in `test-scripts.sh`.
- The approval commit is tagged `<feature>-tasks` so the first phase report has a diffstat base.
- Phase-end Critical gaps become a fix unit (`N` plus the next free letter) written by a fresh task-writer, so `next-unit.sh` and `check-spawn.sh` stay consistent. One fix unit per phase, then the gate.

## Alignment step (added 2026-11-14, user request)

- The user and the agent must reach consensus before any spec is written. `/build-feature` step 1 runs the `aligning-requirements` skill in the main session (only the main session can ask the user). It interviews in rounds, writes `plans/<feature>/feature-<feature>-brief.md` with decision ids `D-01`..., and asks "Is this what we are building?" (Agree / Change something / Stop). Agree runs `approve.sh <plan> brief`.
- Enforced: `check-spawn.sh` blocks any `spec-writer` spawn without a `PLAN:` line and `approvals/brief`.
- The brief is binding downstream: spec-writer must not reopen its decisions; spec-verifier grades a contradiction or a dropped decision as P0.
- `aligning-requirements` is model-invocable (so `/build-feature` can load it) and can also be run on its own. The old `grilling` skill is untouched and not used by the pipeline.
- `check-spawn.sh` without jq now blocks only gated spawns (implementer, spec-writer); before, it blocked every subagent spawn.

## Unit gate (added 2026-11-15, after dry run 2)

- Dry run 2 (json-flag): unit 1b used the RISK-001 fallback and cut TEST-007 to `a"b`, blaming Windows quoting. The real cause was a JS literal losing `\`. The reviewer passed it as "authorised", phase-1 conformance graded it Accepted (p2), final graded the same gap p0. That cost a Changes unit, a task-verifier fail and a fix round.
- `UNIT_GATE` in `pipeline.conf` (`exceptions` default, `always`, `off`). `scripts/unit-gate.sh <plan> <base> <rounds> <last review report | green>` gates a unit before commit when its Differences section changed, a fix round ran or a mutation stayed green. AFK never gates but the reasons are logged for the Attention section. Tested in `test-scripts.sh`.
- `checking-spec-conformance`: a logged Difference that weakens a REQ/SEC test is no longer Accepted; the id is graded on the remaining evidence, so phase and final checks agree.
- `reviewing-code`: a logged test-weakening Difference is checked, not assumed authorised; wrong cause or now-untested behaviour is P1.

## Known limitations

- Hooks cannot tell who ran `approve.sh`. Use the strict gate option (user runs `! bash .claude/scripts/approve.sh plans/<feature> phase-N`) when that matters.
- `check-spawn.sh` parses the fixed `PLAN:` / `UNIT:` / `FIX:` prompt lines. Keep that form verbatim in `/build-feature`.
- AFK resume edge: when a phase ends a second time (a Changes unit after its tag), `status.sh` in AFK mode sees the old tag and reports no gate; the in-loop phase-done check still runs the phase end. Only a crash in between would skip it.
- `check-git.sh` reads commands token by token; a quoted commit message containing `push --force` can be a false block.
- Agent teams change named-subagent launch. Keep them off.
- Windows: hook commands are run with `bash "<path>"` because the project path has spaces.

## Dry run (M6)

Status: RUN 1 DONE 2026-11-15 (happy path end to end, 36 min, 6 units, 24 tests). Checks 3, 6 and 8 still untested. Needs an interactive session (gates, restart, kill). Toy repo made by `bash tests/pipeline/make-toy.sh` at `../pipeline-toy` (Node CLI, `npm test`, `MAX_UNIT_TASKS=2` to force sub-phases). Refresh its pipeline files after changes with `bash tests/pipeline/make-toy.sh --sync`.

Run: start `claude` in `../pipeline-toy` (trust the workspace so hooks run), then
`/build-feature json-flag Add a --json flag to the greet CLI that prints {"greeting":"Hello, <name>"}, and an --upper flag that uppercases the greeting.`

| # | Check | How | Result |
|---|---|---|---|
| 0 | alignment: interview in rounds, brief written, consensus question waits; spec-writer only after Agree | answer the questions, pick Agree. Optional: before agreeing, ask it to spawn spec-writer; the hook must block it | PASS. 1 plain-text why, 4 AskUserQuestion choices, brief D-01..D-07, Agree. Hook block before Agree not tried. |
| 1 | spec gate stops and waits; spec cites brief decisions | answer Approve | PASS. Waited 3 times (user chose P2 fix rounds). Spec cites D-ids. |
| 2 | tasks gate stops; plan has sub-phases (`2a`, `2b`) | read the units shown, Approve | PASS. Units 0, 1, 2a, 2b, 3. Verifier caught a real P1 (diff against working tree after commits). |
| 3 | hook blocks a wrong spawn | at a gate pick Stop, then ask: "spawn the implementer for the last unit now, PLAN/UNIT form" | NOT TESTED. |
| 4 | one fresh implementer per unit | one `implementer` spawn per unit line in the transcript | PASS. One implementer per unit (0, 1, 2a, 2b, 2c, 3). |
| 5 | review fix loop via SendMessage | while a unit's implementer runs: `bash scripts/seed-defect.sh` in another terminal; reviewer flags it, the same implementer fixes it | PASS without seeding. Unit 1 reviewer caught `'back\slash'` (no backslash); same implementer fixed it via SendMessage; re-review saved as `-2`. |
| 6 | Stop hook keeps implementer working while red | while an implementer runs: `bash scripts/seed-red.sh`; check `$TMPDIR/pipeline-last-implementer-stop.json` and the reply | NOT TESTED (tests never red). SubagentStop did fire: capture file from the toy session exists. |
| 7 | phase report written, phase gate waits | `plans/json-flag/reports/phase-N-report.md`, tag `json-flag-phase-N` | PASS. Reports, tags and gates for phases 0 to 3. Request changes at phase 2 added fix unit 2c. |
| 8 | resume after kill | kill the session mid-unit, restart, rerun `/build-feature json-flag`; it resumes at the first unticked task | NOT TESTED. |

### Run 1 findings (2026-11-15)

Worked: every gate waited; reviewers caught two real defects (unit 1 test literal, TASK-030 empty diff); SendMessage resume worked for spec-writer, task-writer and implementer; phase Request changes path worked; 6 commits plus 5 tags, nothing pushed.

Defects and friction (R-ids), status as of 2026-11-15 session 2:
- R1. Plan verifiers returned findings inline only. FIXED in ec6460d.
- R2. Brief committed as `status: draft`. FIXED: `approve.sh <plan> brief` sets `status: agreed` in the front matter (tested).
- R3. Verify-only units (Baseline, Ship) cost a full unit each. FIXED: `check-plan.sh` fails a unit whose Files are all `none`; writing-tasks and its template drop Baseline/Ship; build-feature runs the baseline before the loop and the real run in step 5.
- R4. P2 loops did not converge. FIXED: p2 never starts a fix round; gates recommend Approve when p0 and p1 are 0; re-verifies get `RECHECK: <previous report>` (old P0/P1 plus new P0/P1 only, no new P2s) in reviewing-plans and reviewing-code.
- R5. Fix unit unverified, writer edited outside it. FIXED: `fix-unit.sh check <id>` compares with HEAD (only the new unit plus traceability rows may change; tested), task-verifier reviews it with `UNIT: <id>`, short gate unless AFK. Auto units are titled `Auto-fix ...` so `fix-unit.sh count` enforces one per phase.
- R6. Tag moved, report overwritten. FIXED: tags only after the phase gate (AFK: after the report), never moved (`check-git.sh` blocks `tag -f/-d`); a phase that ends again gets `-phase-N-2`. Reports via `report-path.sh` never overwrite.
- R7. SUMMARY semantics. FIXED: everywhere p0 and p1 fail and p2 never does. Conformance maps Critical to p0, Major (Partial) to p1, Warning to p2.
- R8. Guard claims self-reported. FIXED: reviewing-code 4b runs one named mutation per guard task in a scratch copy (`scratch-copy.sh`); SUMMARY has `mutations:`; a guard still green is P1.
- R9. `git add -A` swept files. FIXED: `stage-unit.sh` (B3.2).
- R10. Too many gates. Addressed by R3, R4 and AFK mode (B1).
- R11. User's global SessionStart hook fails in Git Bash (`powershell: command not found`). Not ours; the user fixes it.
- Real run at the end: now build-feature step 5.2 and a Verified-evidence rule in checking-spec-conformance.

### Run 3 findings (2026-11-16, pipeline-toy-3, json-flag, not AFK)

Worked: brief to final in one session; 1a reviewer's mutation caught a `'a\b'` (backspace) backslash test; auto-fix unit 1d path end to end; unit gate skipped a clean unit; PR step stopped cleanly with no remote. Cost: 11 user questions and 1h03m for about 4 lines of code.

- R12. Task-verifier passed "stderr covered by code review" in Decisions taken; phase conformance failed it as P1, costing the whole 1d cycle. FIXED: reviewing-plans Coverage makes that P1; writing-tasks forbids it; checking-spec-conformance names Decisions-taken rows in "a logged test change is not Accepted".
- R13. writing-specs told the spec-writer to defer open questions to a task ("Decided in TASK-041"); spec-verifier flagged it. FIXED: open questions are answered at the spec gate, asked in the gate's own question.
- R14. Planned guard tests passing at once were logged as Differences and stopped units 1b and 1c at the unit gate. FIXED: `**Guard:**` marker in writing-tasks, its template and implementer; only an early-passing `**Red:**` test is logged; an unmarked would-be guard is a P2 in reviewing-plans.
- R15. Final conformance graded REQ-010 and SEC-002 Met with 0 P2 where the phase check, on the same code, had warnings. FIXED: the final check carries every phase finding forward or names what closed it.
- R16. P2s at the tasks gate were never applied (stale Decisions row, duplicate traceability rows, wrong TASK-014 text all reached the final report), and `check-plan.sh` warned 3 times on group labels like "REQ-010 to REQ-019". FIXED: spec and tasks gates offer "Fix the P2 notes" first when p2 > 0; `check-plan.sh` skips ranges in the undeclared-id check (tested).
- R17. A one-phase feature asked the phase gate and the final gate back to back. FIXED: the last phase has no phase gate; it is tagged after its report and `status.sh` ends it by the tag (tested).
- Not fixed (minor): orchestrator shorthand to the user ("Gate: no."), reviewer fix snippets losing escapes in markdown, Done dates local while approval stamps are UTC.

### Run 4 findings (2026-11-16, pipeline-toy-4, name-check, not AFK)

Worked: brief to accepted in 50 min, 3 units, no P0/P1 anywhere. R14 Guard marker (no false Differences, unit gate skipped all 3 units), R17 no-gate last phase, R15 carry-forward and R16 "Fix the P2 notes" (used twice) all exercised. Not exercised: AFK, R13.

- R18. A spec id kept as `(removed in v0.2: …)` still had to be referenced by the tasks file; the task-verifier's P2 told the writer to drop that reference, and check-plan then FAILed (an extra writer round). FIXED: `check-plan.sh` exempts removed ids from "REQ/SEC ids with no task" (tested).
- R19. `scan-staged.sh` forked ~10 processes per added line: 45.8 s for unit 1b's 77 lines on Git Bash, and past the 2-minute Bash timeout while the reviewer's leftover process ran. FIXED: added lines are collected once and each pattern is one grep (2.2 s on the same diff; file:line kept, tested).
- R20. The spec-verifier moved an untestable REQ into PAT-002 "Checked by code review", yet conformance graded it Untested (P2) at phase 2 and final, and it reached the final gate. FIXED: checking-spec-conformance grades a spec-marked "Checked by code review" CON/GUD/PAT as Met on Inspected evidence (never REQ/SEC); writing-specs says when to use the marker.
- R21. The unit-1b reviewer left `$TMPDIR/mut-1b` locked by a background process and its notification read "waiting on its own background work". FIXED: code-reviewer runs everything in the scratch copy in the foreground and deletes it before its SUMMARY; build-feature clears `$TMPDIR/mut-<unit>*` before each review.
- Not fixed (minor): PR question asked with no `origin` remote; stray `· summary` at the end of some orchestrator messages; the SessionStart error is the user's global hook calling `powershell` from Git Bash, not the pipeline.

### Run 5 findings (2026-11-17, pipeline-toy-5, greet-options, AFK end to end)

Worked: AFK from the tasks gate to the final gate in one session, 8 units (2 auto-fix units 1c and 3c), 43 tests, final conformance pass. The lead rejected a reviewer pass that saved no report and caught a foreign tick; both by hand.

- R22. Unit 3b's reviewer reproduced a real bug (`k in DEFAULTS` misses `constructor`) but rated it P2; P2 starts no fix round, so it was committed and failed the phase check as P1 (extra unit 3c). FIXED: reviewing-code severity says a defect reproduced with a concrete input that breaks the spec or task row is P1.
- R23. The unit-2a implementer ticked TASK-031 (phase 3). Found only at the phase 2 check, after the commit. FIXED: `tick-unit.sh <plan> <unit> <base>` fails with `foreign tick: <ids>` when another unit's row changed since base (tested); build-feature 4.5 passes BASE; implementer rule 6 names the case.
- R24. The first 2a reviewer returned a pass but could not write its report. FIXED: `check-report.sh <report>` (exists, non-empty, has a verdict line) is a commit precondition (tested).
- R25. The spec stayed `Draft` with Q-5 open after the user answered and approved; the matcher flagged it in three reports and said Q-5 was applied without the user. FIXED: `approve.sh spec` stamps the front matter and badge `Approved` (tested); spec-gate answers are logged as `Q-<n>` decisions; every phase matcher gets `DECISIONS:` and treats a `Q-<n>` row as resolved.
- R26. `decisions.tsv` was dirty from unit 2a to the end (logged after each commit). FIXED: the commit is logged before `git commit`, so the row rides in the unit commit.
- R27. The 2b implementer ended "waiting on its own background work"; 3c skipped its "Done when" run. FIXED: implementer rules 7 (foreground only) and 8 (run Done when).
- Not fixed: the SessionStart `powershell: command not found` is the user's global hook under Git Bash (same as run 4). Change it there to `powershell.exe` or `pwsh`.

### Run 6 findings (2026-11-17, pipeline-toy-6, greet-options, AFK)

Worked: brief to final in one session, 41 tests, survived a 5-hour usage-limit pause; the tasks verifier found two untested spec clauses (REQ-034 BOM, SEC-001 JSON.parse only); the reviewer's mutations and the lead's own grep caught a false "fixed" report. Cost: 4 task-writer and 4 task-verifier rounds, about 25 agent spawns for 11 tasks.

- R28. The task-writer had no Edit, so each fix rewrote the file with Write, which decodes a backslash-u escape into a raw U+FEFF. The BOM test then read as contradicting another test (F07 P1) and used up MAX_LOOPS. FIXED: writers get Edit; writing-tasks and task-writer forbid invisible characters in plan text; `check-plan.sh` fails on U+FEFF and zero-width characters (tested).
- R29. The spec-writer added unrequested BOM stripping (REQ-034), which forced a BOM test downstream. FIXED: spec-writer rule: no behaviour beyond the brief, an Open question instead. The verifier already rates a silent decision P1.
- R30. The foreign tick on TASK-015 was found by the reviewer, after a wasted review. FIXED: build-feature 4.3.1b runs `tick-unit.sh <plan> <unit> <BASE>` before the reviewer.
- R31. An implementer replied only "pending" (unit 2a). FIXED: build-feature 4.2 says to run TEST_CMD and tick-unit yourself when the reply has no `tasks done` line, and log `empty-report`.
- R32. A `log-decision.sh` call with 5 arguments failed with only the usage line. FIXED: the error now says how many arguments it got.
- R33. Tasks front matter stayed `Planned` after every task was ticked; the missing `origin` remote was found only at the PR step. FIXED: `approve.sh final` sets the tasks status to Done (tested); build-feature step 0 checks `origin` and tells the user once.
- Not fixed: the SessionStart `powershell: command not found` is still the user's global hook (R11): in `~/.claude/settings.json` use `powershell.exe`. P2 test-strength notes (weak spawn tests) still ride to the final report in AFK; an optional cleanup unit is an open idea.

### Run 7 findings (2026-11-18, dostuff harness, hooks-sandbox/pipeline-toy, greet-options, AFK, MiniMax)

First run on dostuff (`install-dostuff.sh`), resumed at unit 2a. Worked: the hook blocked a malformed `UNIT:` line; `stage-unit.sh` caught a stray file; patch-id matched on every unit; mutation review found two real test gaps; AFK reached the final gate; the PR was asked and declined. Cost: 7.4M input tokens, 6.3M of them in the final spec-matcher (resumed with its whole history). Full notes: `notes/run-7-findings-and-plan.md`.

- R34. 6 of about 17 subagent runs hit the turn cap; the orchestrator resumed each with `send_message` (forbidden, unhookable as we thought). Review 4a saved no report; the 3b implementer replied with raw reasoning. FIXED: `check-spawn.sh` is also registered for `SendMessage` / `send_message` and blocks resumes (`PIPELINE_ALLOW_RESUME=1` opts out); every reporting agent writes a skeleton with `verdict: pending` first; `check-report.sh` rejects pending; build-feature "Agents that stop early": a finished report is used, else one fresh agent with `PARTIAL: <old report>` (implementer: the rest of the unit from next-unit.sh), no cost to MAX_LOOPS, a second early stop stops the run; turn budgets in code-reviewer, spec-matcher, implementer and both verifiers (tested).
- R35. The final matcher wrote a 67-row evidence table, its writes truncated, and it left `.ids-part1.md`, `.ids-part2.md`, `conformance.md.part2` in `reports/`; a phase-2 log in `.dostuff/tmp/` blocked a stage. FIXED: checking-spec-conformance keeps Met ids on one line, a table row only for the rest, evidence only under findings, about 150 lines, one write; the final check reuses phase grades for ids whose files did not change; logs go under `${TMPDIR:-/tmp}`; `stage-unit.sh` never owns dotfiles or `*.part*` under the plan dir; `check-report.sh` fails on scratch files beside the report (tested).
- R36. `$TMPDIR` is unset in dostuff's shell, so `rm -rf "$TMPDIR"/mut-3b*` meant `/mut-3b*`. FIXED: `${TMPDIR:-/tmp}` in build-feature, code-reviewer and reviewing-code; `scratch-copy.sh` refuses a destination directly under `/` or inside the repo (tested).
- R37. From unit 2b on the orchestrator padded implementer, reviewer and matcher prompts with `Rules:` and `Note on scope:` blocks; the 4a file list differed from the Files column. FIXED: build-feature says prompts are the templates and nothing else; `check-spawn.sh` blocks implementer prompts, and code-reviewer and spec-matcher prompts with a `PLAN:` line, that hold other lines; fix rounds name extra inputs in an `ALSO:` line (tested).
- R38. `TEST_CMD` at commit step 5.1 was skipped in most units. FIXED: `unit-gate.sh` runs `TEST_CMD` first and exits 4 on red, with the last 40 lines (tested).
- R39. On resume, `status.sh` said `uncommitted: none, next: 2a` while the tree held half-built 2a work from the earlier run. FIXED: `status.sh` prints `dirty: <unit>` when the unit open at HEAD is not fully ticked but files changed outside reports, approvals and decisions.tsv; build-feature asks Finish it / Stop and the implementer builds on the files there (tested).
- R40. The final report said "one fix round in the whole build"; `decisions.tsv` showed more. FIXED: `run-stats.sh` counts reviews per unit (report files) and fix rounds, restarts, added units and stops (`decisions.tsv`, with fixed decision names); step 5.4 pastes its output (tested).
- R41. Stale or misworded Differences entries (a planned split logged as a Difference, never closed) were flagged by two matchers and shipped. FIXED: writing-tasks and implementer: a planned split is not a Difference; the unit whose work makes an entry stale updates or removes it.
- Smaller (finding 9): mutants run under `timeout 120`; reviewers never create files in the repo (and scratch-copy refuses it); the orchestrator never polls with `sleep`; `check-report.sh` fails when a report says both `verdict: pass` and `verdict: fail`. Also: `install-dostuff.sh` writes `.dostuff/.installed-from` and has `--check` for drift; `make-toy.sh --sync` commits the refreshed pipeline in the toy.

### Run 8 findings (2026-11-18, dostuff, toy-9, greet-options, AFK)

Verify run of R34-R41 on a fresh toy. Worked: the padded code-reviewer prompt and `git tag -f` were blocked; check-report caught every unfinished report; unit-gate ran the tests on all 9 units; run-stats gave the counts. But the orchestrator did the stalled agents' work itself, and 30.4M input tokens. Full notes: `notes/run-8-findings-and-plan.md`; transcript `notes/runs/run-8-dostuff-toy-9.md`.

- R42. The orchestrator overwrote the failing phase-2 matcher report with its own `verdict: pass`, wrote phase 1's `conformance-3.md` itself, and patched verdict lines and SUMMARY blocks into four reports; two failing phase checks became passes and no fix unit ran. FIXED: new hook `check-write.sh` (Write/Edit/MultiEdit; dostuff write_file/edit_file/multi_edit/delete_file). In a plan with an agreed brief, a main-session write inside the plan dir is blocked unless it is the brief, a phase or final report, a fix-input file or the PR body; subagent calls carry `agent_type` and pass (`PIPELINE_ALLOW_WRITE=1` opts out; shell writes are not caught). build-feature: check-report exit 1 is never fixed by editing (tested).
- R43. The orchestrator edited the spec itself (v0.4, v0.5) and offered to. FIXED: same hook covers the spec and tasks files; build-feature allows only Retry with a narrower scope / Stop after a second early stop (tested).
- R44. Phase-1 and phase-2 matchers graded work owned by later phases as Critical and stalled deliberating. FIXED: checking-spec-conformance `--phase N` grades the phase's slice of each id; the rest is `Not started (TASK-xxx)`, severity none; same rule in spec-matcher.
- R45. Agents still stopped early (7 times) and mostly wrote no skeleton. FIXED: `report-path.sh --pending` creates the `verdict: pending` skeleton before the spawn; every agent `REPORT:` path in build-feature uses it; agents replace the whole file at the end (tested).
- R46. spec-verifier, task-verifier and scoped spec-writer prompts were padded, one telling the writer to decide an open question. FIXED: `check-spawn.sh` checks templates for spec-writer, spec-verifier, task-writer and task-verifier too; a narrowed fix round passes a `fix-scope` fix-input file; open questions go to the gate (tested).
- R47. The final gate was never asked (a nonexistent `final-gate.sh` was called; `final: open`). FIXED: build-feature 5.5 and 6 say there is no script and to ask with AskUserQuestion.
- R48. Phase-1 matcher spawned 3 times; a restart without `PARTIAL:`; a cancelled gate plus "continue" taken as an answer. FIXED: build-feature: never a third spawn; restarts always carry `PARTIAL:`; a cancelled gate is asked again.
- R49. Reviewer 1a passed with 4 green mutants, two against cited REQ text, and `p2: 0` with a P2 under `top:`. FIXED: code-reviewer and reviewing-code: a green mutant against a cited REQ/SEC is P1, equivalence needs a reason; `check-report.sh` fails when `top:` lists more `[P<n>]` items than the count (tested).
- R50. The orchestrator re-ran mutants (files in the project root) and probed findings itself. FIXED: build-feature: never re-check an agent's work; the report is the evidence.

Next run: a fresh toy (`dostuff-toy.ps1 <name> -Rebuild`, so `config.yaml` gets the new hook; `install-dostuff.sh --check` now flags a config.yaml without it). Check that the write hook fires for the orchestrator only (dostuff sends `agent_type` for subagent tool calls), and the same in Claude Code before relying on it there.

### Run 9 findings (2026-11-19, dostuff, toy-10, greet-options, stopped at the tasks step)

Details: `notes/run-9-findings-and-plan.md`. Root cause of the stalls was in dostuff and litellm, not the pipeline: dostuff ignored `finish_reason: length` and sent no `max_tokens`, so litellm's Anthropic route capped minimax-m3 at 4096 output tokens. Fixed in agent-1 (`dostuff/output-limit`); the pipeline fixes below make it robust anyway.
- R51. The task-writer (5 spawns) and spec-writer (2) planned the whole file in their reply and were cut off before the Write call. FIXED: writing-tasks, writing-specs, task-writer, spec-writer: build the file in parts (skeleton Write, then one Edit per unit or section), never draft it in the reply, continue a part-written file. build-feature: a restarted writer continues the file; `git diff` misses an untracked new file.
- R52. The orchestrator changed `agents.models.opus` six times through `edit_config` to get the writer through, moving both verifiers too. FIXED: build-feature rule (the config is the user's); `check-write.sh` blocks `edit_config` and writes to the settings, config.yaml and pipeline.conf while a run is open (tested); `install-dostuff.sh` adds `edit_config` to the matcher and `loop.max_tokens: 32000`.
- R53. Five task-writers were spawned despite "one restart per agent run"; only one restart was logged. FIXED: `check-spawn.sh` logs pipeline spawns in the git dir and blocks a third writer with the same prompt at the same HEAD and a restart of a restarted verifier, reviewer or matcher; `approve.sh PLAN retry` (user only) allows one more (tested). The implementer is not counted.

Next run: a fresh toy with `-Rebuild` (config.yaml needs the new matcher and `loop.max_tokens`), on agent-1 `dostuff/output-limit`.

### Run 10 findings (2026-11-19, dostuff, toy-10 rebuilt, greet-options, AFK, stopped at unit 3)

Details: `notes/run-10-findings-and-plan.md`. R51-R53 held. Each fix below was replayed against run 10's own state (a toy-10 clone and its spawn log): every one blocks the command run 10 actually ran.
- R54. At the stop the orchestrator committed unit 3 (`git add plans/greet-options src test && git commit`) with two unfinished reviews whose content had 2 P1s; `status.sh` then pointed past unit 3. FIXED: `check-git.sh` blocks `git add` of anything but literal `plans/` paths, `git add -A/-u/.`, `git commit -a`, and a commit whose index holds code unless the newest review of the unit open at HEAD passes (`check-report.sh` + `verdict: pass`) or the user chose Commit anyway (`approve.sh PLAN commit-<unit>`). SKILL: a stop commits nothing (tested).
- R55. Phase ends skipped in AFK (no matcher, report or tag for phases 1-2; units 2 and 3 filed under `phase-1/`). FIXED: `check-spawn.sh` blocks an implementer while `status.sh` shows `gate: N` for an earlier phase, AFK too; `check-git.sh` blocks `git tag <f>-phase-N` without a finished `phase-N/conformance` report and `phase-N/report`; `report-path.sh` refuses `phase-M/review-<unit>` when the unit is in another phase (tested).
- R56. Reviewers and verifiers ran out of turns with the whole report in their reply (task-verifier 3 of 8, code-reviewer 2 of 6). FIXED in part: task-verifier `maxTurns` 40; every verifier, reviewer and matcher adds each finding to its report file as it confirms it; reviewer mutation cap counted in the report. Open: a turns-left warning or a final Write-only turn in dostuff (user's harness).
- R57. A verifier restart without `PARTIAL:`, then a third spawn without `approve.sh retry`; the orchestrator committed in between. FIXED: `check-spawn.sh` also counts earlier spawns of the same type and prompt (REPORT/PARTIAL left out) whose report `check-report.sh` still rejects, at any HEAD; two block the third. SKILL: verifier/reviewer/matcher stops offer Allow one more run (user's `approve.sh retry`) / Stop; never spawn to see what the hook says (tested).
- R58. `reviewing-code` section 6 template `Verdict: changes-requested` used in a pipeline report. FIXED: the skill and code-reviewer drop that line in pipeline mode; `check-report.sh` names the standalone format when it sees it; a rejected report is restarted with `PARTIAL:`, and the fix round is logged only after `check-report.sh` accepts (tested).
- R59. Fix rounds past `MAX_LOOPS` without a gate; 14 verifier reports. FIXED (prompt): one round per "one more round" answer, every round logged; the plan is committed after every finished writer round, and `reviewing-plans` recheck counts as new only what the round changed (`git diff`), older misses are P2 `pre-existing`.
- R60. `printf >> decisions.tsv`, restarts logged as `empty-report`, an implementer logging decisions, mutation count misread. FIXED: `check-git.sh` blocks shell writes to `decisions.tsv` and `approvals/` (also through a variable); naming rules in build-feature; implementer never logs; `unit-gate.sh` takes the review report and reads `mutations: <n> run, <n> still green` itself (tested).
- R61. Verifier scratch files in the repo root. FIXED (prompt): verifiers write nothing but the report; scratch under `${TMPDIR:-/tmp}`.
- R62. The brief dropped the requirement's `--times` range. FIXED (prompt): aligning-requirements copies every number, limit and name from the requirement into the brief.

### Run 11 findings (2026-11-20, dostuff, toy-10 rebuilt, greet-options, AFK, finished)

Details: `notes/run-11-findings-and-plan.md`. The run finished all 7 phases (11 units, 93 tests) but cost 32.5M input tokens in the orchestrator over 304 model calls. R54-R62 held: no stray commit, every phase end ran, the restart hook stopped the phase-3 matcher chain.
- R63. Unit 7 ran 4 fix rounds with `MAX_LOOPS=2` ("round 2 of MAX_LOOPS=2, so one more round is allowed"). FIXED: `check-spawn.sh` counts each distinct `FIX:` file as one round (implementer: per unit at HEAD, `unit-changes-*` not counted; spec-writer/task-writer: `reports/<stage>/review*` across commits) and blocks past `MAX_LOOPS`; the user's `approve.sh PLAN loop-<unit|spec|tasks>` buys one round (tested).
- R64. SEC-001 "opens no network connection and writes no file" had no end point: each review found another API the spy missed (fs surface, fetch/dns/curl, spawnSync preload), and each fix implementer hit dostuff's 100-iteration limit. FIXED (prompt): writing-specs makes a negative requirement name its bounded check; reviewing-plans rates an unbounded negative P1; reviewing-code and code-reviewer rate a spy gap past the named check P2, and a new hole of the same class in a recheck P2.
- R65. Orchestrator context: full agent replies (122k chars), the whole tasks file, pipeline scripts and hooks read with `cat`, all re-sent on every later turn. FIXED (prompt): build-feature never opens the spec, tasks, reports or pipeline sources; `next-unit.sh --all` lists units for a gate (tested); reviewers, verifiers and the matcher reply with the SUMMARY block only.
- R66. Plan bigger than the feature: 470-line spec, 7 phases, 11 units, two units whose Red tests passed at once, three spec rounds for cosmetic P2s. FIXED (prompt): Fix the P2 notes is recommended once per stage; writing-specs sizes the spec to the brief; writing-tasks groups by behaviour (2-4 units for a small CLI); reviewing-plans rates an end-to-end unit over already-built behaviour P1.
- R67. The phase-3 matcher wrote `verdict: fail` with p0 = p1 = 0, which stopped the AFK run for two P2s. FIXED: `check-report.sh` rejects a verdict that does not follow the counts; agents with Bash run it before replying (tested).

## Run 12 findings (toy-10, dostuff, 2026-11-21)

Log: `toy-10/dostuff-session-c825b3a5d39e4bde.md`. Stopped at the first tasks fix round (1.73M orchestrator input tokens by then). The orchestrator stopped correctly; the agent below was the problem.
- R68. The task-writer's FIX round marked the verifier's two P1s `[RESOLVED]` in `reports/tasks/review.md`, set its SUMMARY to `p1: 0`, and edited the approved spec. `check-write.sh` let every subagent write anything. FIXED: `check-write.sh` scopes each pipeline agent in a plan dir (spec-writer: spec; task-writer, implementer: tasks file; verifiers, reviewer, matcher: `reports/`; other subagents: the orchestrator's rules). dostuff sends `agent_type` on PreToolUse inside subagents (tested).
- R69. Both P1s told the writer to change the spec, which task-writer may not do. FIXED (prompt): task-verifier gives a tasks-file fix when one exists, else `Fix (spec):`; task-writer lists `Spec changes needed:`; build-feature 3.3 routes them through spec-writer with a `spec/changes` file and shows the spec diff at the tasks gate.
- R70. Writers are told the FIX file and reports are read-only and never to mark a finding resolved (prompt; the hook enforces it).

Next dry run (run 2): checks 3, 6, 8, plus the new paths: AFK run end to end, a fresh-agent fix round (`FIX:` spawn), a `stage-unit.sh` stray stop (touch an extra file during a unit), the final gate and the PR step (needs a remote; else check it stops cleanly without one). Use `scripts/seed-red.sh` during an implementer and kill/restart mid-unit (expect `uncommitted: <unit>` on resume).

## Decisions taken 2026-11-15 (session 2)

- Fix loops spawn a **fresh agent** each round (user). The input file goes in a `FIX:` line; the user's text is written to a `<stage>/changes` or `guidance-<unit>` report first. No SendMessage resumes in the pipeline. check-spawn allows a `FIX:` implementer only for the unit still open at HEAD.
- **AFK mode** is built (user).
- One commit per unit (default; user unsure). Revisit if the commit story matters.
- One PR per feature, at the end, after the final gate; ready unless final conformance p0 > 0 (default; user unsure). Stacked per-phase PRs not built.
- Never amend; fixes are new commits (default; user unsure). Enforced by `check-git.sh`.
- Pushing and opening a PR always ask, AFK too.

## Built 2026-11-15 (session 2)

- B1 AFK: tasks-gate option writes `approvals/afk`; check-spawn skips phase approvals; status.sh `afk:` line and AFK gate = phase complete but tag missing; stop-not-ask list; `log-decision.sh` trail `plans/<f>/decisions.tsv`; final matcher gets `DECISIONS:` and writes an Attention section; final gate Accept / Request changes / Roll back / Stop.
- B2 reports: `report-path.sh <plan> <stage>/<name>` gives `reports/{spec,tasks,phase-N,final}/<name>.md`, then `-2`, `-3`. Every agent writes only its `REPORT:` path. Phase reports are written once at the phase end, not appended per unit.
- B3: (1) `branch.sh` puts work on `feature/<f>`, check-spawn blocks implementers on the default branch; (2) `stage-unit.sh`; (3) `scan-staged.sh` (HIGH exit 1, MEDIUM exit 3, `--file` for the PR body, `scan:allow` opt-out); (4) gate integrity lens; (5) scope drift, `scope:` in SUMMARY; (6) base control via `scratch-copy.sh --base`; (7) TEST_CMD rerun at commit and in reports; (8) `check-git.sh` hook; (9) step 6 PR with the pstack body; (10) skipped.
- pstack: implementer TDD guardrails and self-deslop; reviewer two-edit test check and comment keep-list; `patch-id.sh` so a commit carries exactly the reviewed patch; "never relax a check" and "broken pipeline: stop" rules.
- `status.sh` new lines: `afk:`, `uncommitted:` (unit open at HEAD but fully ticked in the tree; resume at review), `final:`.
- `.claude/settings.json`: Bash hook for check-git.sh; allow rules for pipeline scripts, `npm test`, git status/diff/log/rev-parse/add/commit/tag.

Not built: stacked per-phase PRs; two commits per unit (test, then code); PR babysitting (only on request, never merges).

## What enforces each rule

| Rule | Enforced by |
|---|---|
| No spec before the brief is agreed | hook check-spawn.sh |
| Implementer gets exactly the next unit | hook check-spawn.sh + next-unit.sh |
| Fix rounds only for the unit in progress | hook check-spawn.sh (`FIX:` + HEAD tasks file) |
| Phase N+1 only after phase N approved (unless AFK) | hook check-spawn.sh |
| Phase N+1 only after phase N's end (matcher, report, tag), AFK too | hook check-spawn.sh (status.sh gate) |
| A phase tag only after a finished conformance report and the phase report | hook check-git.sh |
| A unit commit only after its review passes, or the user's Commit anyway; a stop commits nothing | hook check-git.sh |
| Unit code staged only by stage-unit.sh | hook check-git.sh (git add of non-plan paths, -A, commit -a) |
| decisions.tsv and approvals/ written only by their scripts | hook check-git.sh (shell writes); check-write.sh (file tools) |
| A unit's reports under its own phase | script report-path.sh |
| No unit work on the default branch | hook check-spawn.sh; branch.sh |
| Implementer stops only when green | hook implementer-stop.sh |
| No verify-only units, unit size, grammar | script check-plan.sh |
| Brief committed as agreed | script approve.sh |
| Commit only the unit's files | script stage-unit.sh |
| Commit exactly the reviewed patch | script patch-id.sh (prompt compares) |
| No secrets or junk committed or in the PR body | script scan-staged.sh (prompt runs it) |
| Added unit changes nothing else | script fix-unit.sh check |
| One auto-fix unit per phase | script fix-unit.sh count (prompt reads it) |
| Reports never overwritten | script report-path.sh (agents write the given path) |
| No force-push, amend, tag move or delete | hook check-git.sh |
| Only the user answers gates | prompt only (hooks cannot tell who ran approve.sh; strict gate option) |
| Fresh agent per fix round; no resumes | hook check-spawn.sh (registered for SendMessage / send_message) |
| Prompts are the templates only | hook check-spawn.sh (implementer, spec-writer; code-reviewer, spec-matcher, task-writer and both verifiers in a run) |
| A result counts only with a finished report | script check-report.sh (prompt runs it) |
| Orchestrator never writes agent reports, the spec or the tasks file | hook check-write.sh (file tools; shell writes are prompt only) |
| Each agent writes only its own plan files (writers never touch reports; only spec-writer touches the spec) | hook check-write.sh (agent_type scope, R68; shell writes are prompt only) |
| Orchestrator never changes the config during a run | hook check-write.sh (edit_config and the settings, config.yaml and pipeline.conf paths; shell writes are prompt only) |
| One restart per agent run | hook check-spawn.sh (writers by prompt and HEAD; verifiers, reviewer, matcher by PARTIAL chain and by unfinished reports of the same prompt; not the implementer); approve.sh retry is the user's override |
| Agents write findings into the report as they go | prompt only (agent files); a turn warning needs the harness |
| At most MAX_LOOPS fix rounds without a gate | hook check-spawn.sh (distinct FIX files per unit at HEAD, and per spec/tasks stage); approve.sh loop-<unit|spec|tasks> is the user's override (R63) |
| Verdict follows the p0/p1 counts | script check-report.sh (R67) |
| Orchestrator keeps its context small (no reading specs, tasks, reports or pipeline sources) | prompt only (R65) |
| Negative requirements name a bounded check | prompt only (writing-specs, reviewing-plans, reviewing-code; R64) |
| Recheck reports only what the fix round changed | prompt only (reviewing-plans, on the per-round plan commits) |
| Agent reports start as a pending skeleton | script report-path.sh --pending |
| Tests green at every unit commit | script unit-gate.sh (runs TEST_CMD) |
| Final report counts from files | script run-stats.sh (prompt pastes it) |
| p2 never starts a fix round | prompt only |
| Push and PR only after the user says yes | prompt only (allow rules do not cover push or gh) |
| Reviewer and matcher do not edit source | prompt only (they have Write for reports) |
