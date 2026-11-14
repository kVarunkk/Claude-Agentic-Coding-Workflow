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
- Each hook writes its last stdin to `$TMPDIR/pipeline-last-<hook>.json` for debugging.

## Known limitations

- Hooks cannot tell who ran `approve.sh`. Use the strict gate option (user runs `! bash .claude/scripts/approve.sh plans/<feature> phase-N`) when that matters.
- A finished subagent can be resumed only while its ID is in the orchestrator context. After a restart, fixes go to a new implementer with the review report as input.
- `check-spawn.sh` parses the fixed `PLAN:` / `UNIT:` prompt lines. Keep that form verbatim in `/build-feature`.
- Agent teams change named-subagent launch. Keep them off.
- Windows: hook commands are run with `bash "<path>"` because the project path has spaces.
