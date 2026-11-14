# Multi-agent build pipeline in Claude Code

Notes on running feature work as a pipeline of specialist agents driven by one orchestrator. Not specific to any one project; this is about the tooling. Status: design notes, nothing built yet. Written 2026-11-14.

## Goal

```
orchestrator (main session)
 ├─ spec-writer        → plans/<feature>/feature-<feature>-spec.md
 ├─ spec-verifier      → checks the spec
 ├─ task-writer        → plans/<feature>/feature-<feature>-tasks.md
 ├─ task-verifier      → checks the tasks against the spec
 ├─ implementer × N    → one fresh agent per phase (or sub-phase, when a phase is too big)
 ├─ code-reviewer      → after each implementer run
 └─ spec-matcher       → code vs spec at the end of each phase
```

Each agent sees only what it needs. The orchestrator decides what runs next based on their results.

## Claude Code mechanics (from code.claude.com/docs)

Sources: `sub-agents.md`, `skills.md`, `agent-teams.md`, `headless.md`, `hooks.md` under https://code.claude.com/docs/en/.

### Custom subagents: `.claude/agents/<name>.md`

Only `name` and `description` are required. Useful frontmatter:

| Field | What it does |
|---|---|
| `tools` / `disallowedTools` | allowlist / denylist of tools (omit `tools` to inherit all) |
| `model` | `sonnet`, `opus`, `haiku`, `fable`, a full model ID, or `inherit` |
| `skills` | skills whose **full content** is injected at startup (up to 32) |
| `permissionMode` | `default`, `acceptEdits`, `auto`, `dontAsk`, `plan`, …; the main session's mode wins if it is more permissive |
| `maxTurns` | caps agentic turns; output is marked partial and the agent can be resumed |
| `hooks` | hooks scoped to this agent (`PreToolUse`, `PostToolUse`, `Stop` → becomes `SubagentStop`) |
| `isolation: worktree` | runs in a temporary git worktree branched from the **default branch** (not the current HEAD); cleaned up if unchanged |
| `background: true` | runs in the background (smaller tool set) |
| `memory` | `user` / `project` / `local` persistent memory directory for the agent |
| `effort`, `color`, `omitClaudeMd`, `initialPrompt`, `mcpServers` | as named |

Scope priority: managed settings > `--agents` flag > `.claude/agents/` > `~/.claude/agents/` > plugin agents.

### Skills and subagents

- `skills: [a, b]` preloads the full skill text into that agent.
- Skills with `disable-model-invocation: true` **cannot** be preloaded (so `/grilling` stays in the main session, which is fine: it needs a live conversation).
- Without `skills`, a subagent can still find and invoke any project/user/plugin skill through the Skill tool. Remove `Skill` from its `tools` to keep it to its own preloaded skills.
- A skill can itself run as a subagent: `context: fork` + `agent: <name>` in the skill's frontmatter. The skill body becomes the task prompt; the agent sees no conversation history.

### Spawning, nesting, resuming

- Every `Agent(...)` call creates a **new** instance with a clean context. Calling it once per phase is how you get one implementer per phase.
- A finished subagent returns an ID. `SendMessage` to that ID resumes it with its context intact (useful for "fix these review findings").
- Nesting is on by default, up to 3 levels below the main session (`CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`). Remove `Agent` from a subagent's tools to stop it spawning.
- Only the main session can stop and ask the user questions. That is why the orchestrator belongs in the main session.
- `claude --agent <name>` (or `"agent": "<name>"` in settings) runs the whole session as that agent.

### Hooks

- `PreToolUse` with matcher on the `Agent` tool runs before every spawn and can block it (exit code 2, reason shown to the model).
- `SubagentStart` / `SubagentStop` in settings, matched by agent name. `SubagentStop` exit 2 (or `decision: "block"`) keeps the subagent working, e.g. until tests pass.
- Exact input schemas: check `hooks.md` when building.

### Agent teams (experimental)

- Enabled with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- Teammates are separate Claude Code instances sharing a task list with dependencies (`~/.claude/tasks/<team>/`), messaging each other by name.
- More autonomous, higher token cost, less controlled. The `skills` field is **not** applied to teammates. While enabled, named subagents launch as teammates.

### Headless

- `claude -p "<prompt>" --agent <name>` runs one agent non-interactively.
- `--agents <json or file>` defines agents inline; `--output-format json` / `--json-schema` give parseable results; `--permission-mode` controls prompts.
- The Agent SDK (Python / TypeScript) runs the same agent loop from code.

## Proposed design

### Agent roster

| Agent | Preloaded skills | Tools |
|---|---|---|
| `spec-writer` | `writing-specs` | Read, Write, Grep, Glob, WebSearch |
| `spec-verifier` | `reviewing-plans` (to write) | read-only |
| `task-writer` | `writing-tasks` (split out of `writing-specs`) | Read, Write, Grep, Glob |
| `task-verifier` | `reviewing-plans` + `check-plan.sh` | read-only + Bash |
| `implementer` | `writing-tasks` (tick/Differences rules) | Read, Edit, Write, Bash, Grep, Glob |
| `code-reviewer` | `reviewing-code` | read-only + Bash (probes) |
| `spec-matcher` | `checking-spec-conformance` | read-only + Bash; writes only its report |

Example `.claude/agents/implementer.md`:

```markdown
---
name: implementer
description: Implements one phase or sub-phase of a plans/<feature> tasks file, test-first.
tools: Read, Edit, Write, Bash, Grep, Glob
model: sonnet
skills: [writing-tasks]
maxTurns: 80
---
You implement exactly the tasks you are given, nothing else. For each task: Red → Green → Refactor.
Tick the task row with the date when its tests pass. Log any deviation under "Differences from the spec".
Finish with: tasks done, tests run (command + result), files changed, open problems. Under 200 words.
```

### Orchestrator flow (`/build-feature <feature>`, a user-invoked skill)

```
1. Spec:  spec-writer → spec-verifier → findings? resume spec-writer (max 2 loops) → show user, wait for approval
2. Tasks: task-writer → task-verifier → same loop → show user, wait for approval
3. Until next-unit.sh reports nothing left:
     unit = next-unit.sh plans/<feature>          # e.g. "3b: TASK-034 TASK-035 TASK-036"
     implementer("Implement <unit ids> of plans/<feature>/…-tasks.md")
     code-reviewer("Review the changes from that run against <unit ids>")
     P0/P1 findings? → SendMessage the same implementer → re-review (max 2 loops)
     end of a phase? → spec-matcher --phase N
                       Critical gaps → new implementer run for them
                       else → report to user, wait for go-ahead
4. Final spec-matcher on the whole feature, then a summary.
```

## Controlling what each implementer gets

Written only in the orchestrator skill ("if a phase has > 5 tasks, split it"), the split is an instruction the model usually follows, not a guarantee. Four layers make it deterministic, each stricter than the last:

1. **The split lives in the tasks file.** The task-writer writes sub-phases (`Phase 3a`, `Phase 3b`, each with its own table) and the user approves them with the plan. The orchestrator spawns one implementer per table; it makes no judgement call.
2. **A script picks the next unit.** `next-unit.sh plans/<feature>` parses `tasks.md` and prints the first unticked phase/sub-phase and its task ids. The orchestrator passes that list verbatim.
3. **A hook enforces it.** A `PreToolUse` hook on `Agent` checks every `implementer` spawn: the task ids in the prompt must equal `next-unit.sh`'s output. Otherwise the spawn is blocked with the reason. A `Stop` hook in `implementer.md` can also refuse to let it finish while tests are red.
4. **No model in the loop.** A bash script loops over `next-unit.sh` and runs `claude -p --agent implementer …`, then reviewer, then spec-matcher. Fully code-controlled, but there are no interactive approval pauses unless the script prompts.

**Chosen direction:** 1 + 2 + 3. The split is decided in the plan and approved by the user, a script selects the unit, and a hook blocks any spawn that doesn't match. The orchestrator stays interactive.

### Other rules

- State lives in files: ticks, dates and Differences in `tasks.md`. Re-running the orchestrator resumes at the first unticked task.
- Fixes after review go to the **same** implementer via `SendMessage`, so it keeps its context.
- Parallel phases are possible with `isolation: worktree`, but need a git repo, and worktrees branch from the default branch. Run dependent phases sequentially.
- Reviewer and spec-matcher return a short structured summary (counts + verdict + top findings) so the orchestrator can decide the next step without reading full reports.

## To build

- [ ] Split `writing-specs` into `writing-specs` and `writing-tasks` (tasks rules include sub-phase tables).
- [ ] New `reviewing-plans` skill: self-review, challenge pass, `check-plan.sh`.
- [ ] Structured summary output for `reviewing-code` and `checking-spec-conformance`.
- [ ] `next-unit.sh`: parse `tasks.md`, print the next unticked unit and its task ids.
- [ ] The 7 agent files in `.claude/agents/`.
- [ ] `/build-feature` orchestrator skill.
- [ ] `PreToolUse` hook on `Agent` (spawn check) and `Stop` hook in `implementer.md` (tests green).
- [ ] Confirm hook input fields in `hooks.md` before writing the hooks.
- [ ] Try it end-to-end on a small feature before promoting anything to `~/.claude/`.
