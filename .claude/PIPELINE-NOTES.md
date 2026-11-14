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
| TEST_CMD | `npm test` (user choice; matches chat-agent CON-005) |

## Decisions taken with the user (M0 to M1)

- Tasks table is `| ID | Task | Spec | Files | Status | Done |` (plan 3.1 plus a Spec column). Scripts find columns by header name.
- `plans/chat-agent` stays in the old format. The pipeline is built and tested on fixtures and the M6 toy feature only.

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

## Known limitations

- Hooks cannot tell who ran `approve.sh`. Use the strict gate option (user runs `! bash .claude/scripts/approve.sh plans/<feature> phase-N`) when that matters.
- A finished subagent can be resumed only while its ID is in the orchestrator context. After a restart, fixes go to a new implementer with the review report as input.
- `check-spawn.sh` parses the fixed `PLAN:` / `UNIT:` prompt lines. Keep that form verbatim in `/build-feature`.
- Agent teams change named-subagent launch. Keep them off.
- Windows: hook commands are run with `bash "<path>"` because the project path has spaces.

## Dry run (M6)

Status: RUN 1 DONE 2026-11-15 (happy path end to end, 36 min, 6 units, 24 tests). Checks 3, 6 and 8 still untested. Needs an interactive session (gates, restart, kill). Toy repo made by `bash tests/pipeline/make-toy.sh` at `../pipeline-toy` (Node CLI, `npm test`, `MAX_UNIT_TASKS=2` to force sub-phases). Refresh its pipeline files after changes with `bash tests/pipeline/make-toy.sh --sync`.

Run: start `claude` in `../pipeline-toy` (trust the workspace so hooks run), then
`/build-feature json-flag Add a --json flag to the greet CLI that prints {"greeting":"Hello, <name>"}, and an --upper flag that uppercases the greeting.`

| # | Check | How | Result |
|---|---|---|---|
| 0 | alignment: interview in rounds, brief written, consensus question waits; spec-writer only after Agree | answer the questions, pick Agree. Optional: before agreeing, ask it to spawn spec-writer; the hook must block it || PASS. 1 plain-text why, 4 AskUserQuestion choices, brief D-01..D-07, Agree. Hook block before Agree not tried. |
| 1 | spec gate stops and waits; spec cites brief decisions | answer Approve || PASS. Waited 3 times (user chose P2 fix rounds). Spec cites D-ids. |
| 2 | tasks gate stops; plan has sub-phases (`2a`, `2b`) | read the units shown, Approve || PASS. Units 0, 1, 2a, 2b, 3. Verifier caught a real P1 (diff against working tree after commits). |
| 3 | hook blocks a wrong spawn | at a gate pick Stop, then ask: "spawn the implementer for the last unit now, PLAN/UNIT form" || NOT TESTED. |
| 4 | one fresh implementer per unit | one `implementer` spawn per unit line in the transcript || PASS. One implementer per unit (0, 1, 2a, 2b, 2c, 3). |
| 5 | review fix loop via SendMessage | while a unit's implementer runs: `bash scripts/seed-defect.sh` in another terminal; reviewer flags it, the same implementer fixes it || PASS without seeding. Unit 1 reviewer caught `'back\slash'` (no backslash); same implementer fixed it via SendMessage; re-review saved as `-2`. |
| 6 | Stop hook keeps implementer working while red | while an implementer runs: `bash scripts/seed-red.sh`; check `$TMPDIR/pipeline-last-implementer-stop.json` and the reply || NOT TESTED (tests never red). SubagentStop did fire: capture file from the toy session exists. |
| 7 | phase report written, phase gate waits | `plans/json-flag/reports/phase-N-report.md`, tag `json-flag-phase-N` || PASS. Reports, tags and gates for phases 0 to 3. Request changes at phase 2 added fix unit 2c. |
| 8 | resume after kill | kill the session mid-unit, restart, rerun `/build-feature json-flag`; it resumes at the first unticked task || NOT TESTED. |

### Run 1 findings (2026-11-15)

Worked: every gate waited; reviewers caught two real defects (unit 1 test literal, TASK-030 empty diff); SendMessage resume worked for spec-writer, task-writer and implementer; phase Request changes path worked; 6 commits plus 5 tags, nothing pushed.

Defects and friction, to fix (R-ids):
- R1. Plan verifiers returned findings inline only. FIXED in ec6460d.
- R2. Brief committed with `status: draft`; the orchestrator flipped it to `agreed` after the commit (it rode along in the tasks commit). Fix: aligning-requirements sets `status: agreed` before approve.sh, or the commit step does.
- R3. Verify-only units (0 Baseline, 3 Ship) cost an implementer, a reviewer, a matcher and a gate each for no code. Fix: writing-tasks forbids units without code; the baseline is the orchestrator's pre-loop test run and the ship check is step 5.
- R4. P2 loops do not converge: each fresh spec-verifier found 3 or 4 new P2 wording notes (3 rounds). The orchestrator also recommended fixing P2s. Fix: the gate recommends Approve when p0 and p1 are 0; a re-verify after a fix round checks only the fixed findings plus new p0/p1.
- R5. Phase fix unit (2c) was added by the task-writer and built without a task-verifier or the user seeing the unit. The writer also edited traceability and decisions outside the unit despite "Change nothing else". Fix: run check-plan plus task-verifier on the new unit, and show it at a short gate (or fold into the phase gate).
- R6. `json-flag-phase-2` tag was moved (force) after the fix unit; first `conformance-phase-2.md` was overwritten. Fix: B2 numbering; tag policy (never move a tag; tag only after the phase is approved).
- R7. SUMMARY semantics differ: in reviews p1 means likely wrong code and fails the verdict; in conformance p1 means Warning (incl. "inspected only") and passes. The final report showed p1 3 with verdict pass for untestable guidelines. Fix: conformance maps Warning to p2, or adds a separate `warn:` count.
- R8. Guard and mutation claims are self-reported. Reviewers said "I did not run the mutation checks". Implementer skipped proving the backslash test can go red. Fix: reviewer reruns one named mutation per guard task (cheap), per pstack "verdict from an agent that did not write it".
- R9. Unit commits use `git add -A` and swept the untracked review report into `feat:` commits. Works, but see B3 item 2 (stage-unit.sh).
- R10. 10 user gates for a 6-unit toy feature (brief, spec x3, tasks, phase 0, 1, 2 x2, 3). Supports B1 (AFK) and R3.
- R11. User's global SessionStart hook fails in Git Bash (`powershell: command not found`). Not ours; tell the user.
- Good unplanned behaviour to keep: the orchestrator ran the real CLI at the end (`greet --name Ada --json --upper`). Make it a step (pstack "tests alone are not sufficient").

Next dry run (run 2): checks 3, 6, 8 plus R2 to R8 fixes. Use `scripts/seed-red.sh` during an implementer and kill/restart mid-unit.

## Backlog (noted 2026-11-15, pick up next session)

Nothing below is built yet. Change only this repo; resync the toy after.

### B1. AFK mode (user request, design agreed in principle, not yet approved to build)

The user approves once, then reviews only at the end of the whole feature.

- Opt in at the tasks gate: a fourth option "Approve and run to the end (AFK)". It writes `approvals/afk`. Only the user's pick there creates it.
- check-spawn.sh: with `approvals/afk`, skip the `approvals/phase-<prev>` check. All other checks stay (next unit, spec, tasks, brief).
- Phase ends still run spec-matcher, the one automatic fix unit, the phase report and the tag. No gate; continue.
- Final step: one review of all phase reports, the final conformance report and every unresolved finding. Options: Accept / Request changes / Roll back to a phase tag.
- Still stops (does not ask, just stops; the next `/build-feature` resumes): a unit still red or with p0/p1 after MAX_LOOPS; a hook block; a phase still Critical after its fix unit.
- Unattended runs need permission allow rules for TEST_CMD, git add/commit/tag and Write. Long runs may compact; state is in files.
- Tests: hook allows phase N+1 without phase-N approval when `approvals/afk` exists; status.sh reports afk.

### B2. Reports grouped by stage and phase (user request)

All of a phase's reports live in one folder. Proposed layout:

```
plans/<feature>/reports/
  spec/review.md, review-2.md            (spec-verifier)
  tasks/review.md, review-2.md           (task-verifier)
  phase-1/review-1a.md, review-1a-2.md   (code-reviewer, per unit)
  phase-1/conformance.md, conformance-2.md (spec-matcher --phase 1)
  phase-1/report.md                      (orchestrator phase report)
  final/conformance.md                   (spec-matcher, whole feature)
```

- Dates go inside each report, not in the file name. Re-runs add `-2`, `-3`; nothing is overwritten (this also fixes spec-matcher replacing its first report when a fix unit runs).
- Update: spec-verifier, task-verifier, code-reviewer, spec-matcher agents; reviewing-plans, reviewing-code, checking-spec-conformance skills; build-feature (phase report path, fix-unit report path, final links); PIPELINE-NOTES dry-run table.
- Phase of a unit = unit id without its letter (`2a` -> `phase-2`).

### B3. Commit safety and PRs (user request; ideas taken from garrytan/gstack /ship and /review)

Gaps today: units commit with `git add -A` on whatever branch is checked out (master here), nothing checks what gets staged, and there is no PR step.

Borrow from gstack, adapted to our pipeline:

1. **Feature branch.** Step 0 creates or checks out `feature/<feature>`. Refuse to run units on the default branch (gstack: "Ship from a feature branch."). Hook option: block implementer spawns when HEAD is the default branch.
2. **Stage only what the unit owns.** Replace `git add -A` with a `stage-unit.sh <plan> <unit>` script: stage the unit's Files plus `PLAN`; list any other changed file and stop. A file outside Files is allowed only if the implementer logged it under Differences. Test with fixtures.
3. **Secret and junk scan before each commit.** Scan the staged diff for keys, tokens, `.env`, large or binary files; a hit blocks the commit (gstack blocks HIGH secret hits and asks on MEDIUM).
4. **Gate integrity in code review.** Our Stop hook pushes the implementer to make tests green, so the reviewer must flag weakened gates: a test deleted, skipped or with relaxed asserts, snapshots changed without their test, lint/CI config relaxed, swallowed exceptions. Always P0/P1, never auto-fixed. Add to reviewing-code.
5. **Scope drift in code review.** Diff vs the unit's tasks: files not in Files, unrequested refactors, behaviour no task asked for. Output `Scope: clean | drift` in the SUMMARY.
6. **Regression proof.** Optional: a new test must fail at BASE and pass at HEAD (gstack "base control"). Cheap for us since we record BASE.
7. **No completion claim without fresh evidence.** Commit only after TEST_CMD ran green in this step (already true) and record the command and result in the phase report.
8. **Never force-push, never amend, never commit to the default branch.** Put it in the build-feature rules.
9. **PR at the end (new step 6).** Ask first (outward-facing). Push the branch, then `gh pr create` (update if one exists). Draft when any Critical/P0/P1 is open. Body: one-line summary, the brief's goal, Spec link, units and commits, Differences from the spec, final conformance SUMMARY, tests run, open findings, links to reports. `Closes #N` only when the final conformance has no gaps, else `Linked to #N`. Scan the body for secrets before posting.
10. Skip for now: version bumps, CHANGELOG, coverage %, deploy/canary. Revisit if a real project needs them.

#### B3 addendum: poteto's pstack (cursor/plugins, folder pstack), the user's main reference

The X article itself could not be read (x.com 402, mirrors failed). Notes are from the repo: README, `skills/poteto-mode/SKILL.md`, `playbooks/opening-a-pr.md`, `skills/principle-sequence-verifiable-units/SKILL.md`. deslop and no-comments were not read.

Take from pstack:
- **Worktree off main.** "Work from a git worktree off main. Subagents inherit it." Fits item 1 and M7. A dirty branch with unrelated work: patch it out, fresh worktree, apply.
- **One PR per phase, stacked.** "Prefer five narrow PRs to one large PR." Phase 1 PR targets main; phase 2 branches from phase 1's tip and targets it. Our phases already end green with a report and a tag, so each phase gate can open its PR. Replaces item 9's single PR (AFK mode: open them all at the end).
- **Commits tell the story.** "Each commit lands on its own and the sequence reads as an argument." Canonical shape: failing test commit, then the fix. Option: implementer commits stay one per unit (current), or split test and code into two commits per unit. Decide with the user.
- **PR body is a one-minute briefing, under ~40 lines**, headings in order, empty ones dropped: `## Why` (opens with the user's goal, from the brief), `## What changed`, `## Scope` (always), `## Tradeoffs`, `## Blast Radius`, `## Verification` (real run paths and results). SHAs, verdicts and long lists go in linked files (our `reports/`), not the body. Prefer this over gstack's long body.
- **Titles** `type(scope): subject`, no trailing period. Our commits already follow this.
- **Cleanup pass before commit / review** (deslop, no-comments): strip AI slop and needless comments from the diff. Add as a reviewer check, not a separate agent.
- **Always pause for irreversible writes**: force-push to shared branches, deploys, data deletion, messages. Pushing and opening PRs ask the user first, also in AFK mode.
- **Broken pipeline skill mid-task**: fix it separately; don't silently work around it.

Conflicts between gstack and pstack, to decide with the user:
- Draft vs ready: gstack opens a draft while findings are open; pstack opens every PR ready. Proposal: ready when the phase gate passed, draft only with open Critical/P0.
- Amending: pstack amends a just-made commit when the fix belongs in it; gstack never force-pushes. Proposal: amend only unpushed commits; never rewrite pushed history.
- pstack has no staged-file check. Keep our own `stage-unit.sh` (item 2) and the gate-integrity review (item 4) from gstack.

#### B3 addendum 2: full read of pstack (2026-11-15)

Read in full: poteto-mode SKILL.md; playbooks opening-a-pr, shipping, babysit, feature, bug-fix, refactoring, multi-phase-plan, autonomous-run, autopilot-full, autopilot-stack, orchestrate, pause-safely, session-pickup, worktree-cleanup, references/bugbot-triage; skills deslop (cursor-team-kit), no-comments + agent comment-sicko, tdd, blast-radius, correct, interrogate, swarm, figure-it-out, technical-writing, unslop, show-me-your-work; all principle-* skills; docs/harness/claude-code.md, docs/guide/06 and 07. Descriptions only: how, why, architect, arena, reflect, recall, teach, ketchup, statechart, verification-skill generators, benchmark-checklist, the perf/forensics/eval/prototype/visual-parity playbooks. Not read: automations/benny, other guide pages.

Ideas worth taking, by where they land:

Implementer (before it stops):
- deslop its own diff: drop needless comments, abnormal try/catch or defensive checks on trusted paths, casts that dodge types, deep nesting. Behaviour unchanged.
- tdd guardrails, verbatim: "Do not change tests merely to match a wrong implementation." "Do not weaken existing assertions unless the expected behavior has genuinely changed and the reason is clear." Run the new test before the code and confirm it fails for the intended reason.

Code reviewer:
- Gate integrity (from gstack) plus pstack autopilot-full step 6: anything that loosens a gate needs proof, "because the owner is the one who wants green".
- Test quality by two imagined edits (principle-test-behavior-not-implementation): break the behaviour, does the test fail? change internals only, does it still pass? Flag tests that fail either.
- Comments: keep only a non-obvious why the code cannot show (comment-sicko keep-list: license headers, external constraints, public API docs, issue links).
- Findings need evidence a run can reproduce (interrogate: "only findings proven by a run survive").
- Optional for risky units: blast-radius, "find the one fact it's safe because of" and prove it by running code.

Orchestrator commit step:
- A verdict covers a patch. Record `git diff BASE | git patch-id` at review time; commit only if the staged patch-id matches, else re-review (shipping step 3). Cheap structural check that nothing changed after review.
- Commit order tells the story: failing test, then the fix (bug-fix step 5). Optional per unit.
- Commit and PR text through technical-writing + unslop rules (we already ban em dashes; unslop also bans mid-sentence colons and filler).

PRs (extends item 9):
- One PR per phase, stacked; root targets main; open ready, not draft; body sections Why / What changed / Scope / Tradeoffs / Blast Radius / Verification, under ~40 lines; details linked to reports/.
- Babysitting a PR starts only when the user asks; it never merges. Landing is separate: only a verified contiguous run from the bottom, one PR at a time, read back the merge state.
- Green CI is not a verdict. Only an agent that did not write the code gives one (we already split implementer and reviewer).

Verification:
- "Tests alone are not sufficient verification." Spec-matcher (or a phase step) should run the real artifact, e.g. the CLI command from the spec, and paste the output.
- Verdicts are VERIFIED / NOT VERIFIED / INCONCLUSIVE; inconclusive is not a pass.

AFK mode (B1):
- Decision trail per show-me-your-work: append-only `plans/<feature>/decisions.tsv` (ts, phase, decision, why, evidence, result), one row per unit and decision; the final review ends with an "Attention" section from a reviewer that did not do the work.
- Exit condition as a checkable predicate; never relax it to declare victory (never edit the spec or tests to pass).
- Pause safely: on stop, finish or back out of the current step, commit `wip:`, write a resume note. Our status.sh already covers pickup.
- "Always pause" list: force-push, deploys, data deletion, external messages. Pushing and PRs ask the user.

Process:
- encode-lessons-in-structure and /correct: a rule enforced by a hook or script beats prose. Keep a table in PIPELINE-NOTES pairing each pipeline rule with what enforces it (hook, script, prompt only).

Tension with our design, decide with the user:
- pstack prefers fresh subagents over resuming ("Interrupt-chained resumes silently drop directives"). Our fix loops resume the same writer/implementer via SendMessage. Option: fresh agent per fix round with the consolidated brief (original prompt + findings + prior report).
- pstack does not check which files get staged; it relies on a clean worktree per task. Keep stage-unit.sh.
