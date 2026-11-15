# Claude Code build pipeline

`/build-feature` builds a feature end to end with specialist Claude Code subagents. It interviews you until you agree on a brief, then writes a spec and a test-first task plan. Each unit gets a fresh implementer, a code review with mutation checks, and a commit. Each phase is checked against the spec and waits for your approval at a gate. In AFK mode it runs to the end and you review once.

```
/build-feature (main session, orchestrator)
 ├─ aligning-requirements  → plans/<f>/feature-<f>-brief.md      gate: Agree
 ├─ spec-writer → spec-verifier                                    gate: spec
 ├─ task-writer → task-verifier                                    gate: tasks (or AFK)
 ├─ per unit: implementer → code-reviewer → stage, scan, commit    gate: on exceptions
 ├─ per phase: spec-matcher → phase report + tag                   gate: phase
 └─ final: spec-matcher → final gate → optional PR (asks first)
```

Hooks enforce the order: no spec before the brief is agreed, the implementer only gets the next open unit, the next phase waits for approval, implementers can't stop while tests are red, and there are no force-pushes, amends or tag rewrites. `.claude/PIPELINE-NOTES.md` has the full rule table and the design history.

## Requirements

| | |
|---|---|
| Claude Code | recent version with subagents, hooks and skills (developed on 2.1.325) |
| bash | 3.2+ (macOS default is fine). On Windows, use the bash that comes with Git for Windows |
| git | 2.28+ |
| jq | required for full hook enforcement. Without it, `check-git.sh` allows everything and `check-spawn.sh` blocks only gated spawns |
| A test command | whatever your project uses (`npm test`, `pytest`, `go test ./...`), set in `pipeline.conf` |

Install jq: `brew install jq` (macOS), `sudo apt install jq` (Debian/Ubuntu), `winget install jqlang.jq` (Windows).

The pipeline is plain bash, awk, git and jq, and avoids GNU-only flags. CI runs the test suites on Linux, macOS and Windows.

## Install into a project

```bash
git clone <this repo> claude-build-pipeline
bash claude-build-pipeline/install.sh /path/to/your-project
```

This copies the agents, hooks, scripts and pipeline skills into `your-project/.claude/`. Your existing agents, hooks and skills stay, and an existing `settings.json` or `pipeline.conf` is never overwritten. If you already have a `settings.json`, merge the `hooks` and `permissions` blocks from this repo's `.claude/settings.json` by hand. Re-run the script to update.

Then:

1. Edit `.claude/pipeline.conf`:
   ```bash
   TEST_CMD="npm test"      # your test command
   MAX_UNIT_TASKS=5         # tasks per unit before the planner must split it
   MAX_LOOPS=2              # review/fix rounds per unit before it stops for you
   UNIT_GATE=exceptions     # exceptions | always | off
   ```
2. Make sure `.sh` files stay LF on Windows: add `*.sh text eol=lf` to `.gitattributes`.
3. Restart Claude Code in the project and trust the workspace. Hooks and project agents need trust, and a running session doesn't pick up new agents.
4. Run:
   ```
   /build-feature <feature-name> <what you want built>
   ```

All state lives in `plans/<feature>/` and git, so after a stop or crash you can resume with `/build-feature <feature-name>`.

## Repo layout

```
.claude/
  agents/       spec-writer, spec-verifier, task-writer, task-verifier, implementer, code-reviewer, spec-matcher
  hooks/        check-spawn.sh (Agent), check-git.sh (Bash), implementer-stop.sh (implementer Stop)
  scripts/      deterministic helpers the orchestrator and hooks call (status, next unit, staging, scanning, ...)
  skills/       build-feature plus the skills the agents preload
  settings.json hook registration and allow rules
  pipeline.conf per-project settings
tests/pipeline/ script and hook tests, fixtures, make-toy.sh (toy repo for dry runs)
notes/          design notes (orchestration, plugin layout)
install.sh      copy the pipeline into another project
```

## Tests

```bash
bash tests/pipeline/test-scripts.sh
bash tests/pipeline/test-hooks.sh
```

For an end-to-end dry run, run `bash tests/pipeline/make-toy.sh` to create a tiny Node CLI repo next to this one. Then follow the dry-run table in `.claude/PIPELINE-NOTES.md`.

## Known limitations

- Some rules are enforced only by the prompt, not by a hook. These include "only the user answers gates", "fresh agent per fix round", and "push and PR only after a yes". See the rule table in `PIPELINE-NOTES.md`.
- Keep Claude Code agent teams off (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` unset). They change how named subagents launch.
- Tested end to end on Windows only so far. On macOS and Linux, only the CI unit tests have run.
