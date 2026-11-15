# Packaging as a Claude Code plugin (draft)

Status: proposal, nothing built. Written 2026-11-16. Today the pipeline ships as a template (`install.sh` copies files into `.claude/`). A plugin would let people install it with `/plugin` and update it in one step. Check every point below against the plugin docs (code.claude.com/docs, "Plugins" and "Plugins reference") before building.

## Proposed layout

```
claude-build-pipeline/
  .claude-plugin/
    plugin.json            name, version, description, author
  agents/                  the 7 agent files, unchanged except hook paths
  skills/                  build-feature + the 6 preloaded skills
  hooks/
    hooks.json             PreToolUse Agent -> check-spawn.sh, Bash -> check-git.sh
    check-spawn.sh check-git.sh implementer-stop.sh
  scripts/                 unchanged
  templates/pipeline.conf  copied into the project on first run
```

## Changes needed

1. **Paths.** About 10 places point at `.claude/scripts/...` or `.claude/hooks/...` (build-feature, aligning-requirements, reviewing-code, reviewing-plans, writing-tasks, code-reviewer, task-verifier, implementer frontmatter). In a plugin they become `${CLAUDE_PLUGIN_ROOT}/scripts/...`. Check that `${CLAUDE_PLUGIN_ROOT}` is substituted in skill bodies and agent frontmatter hooks, not only in hooks.json.
2. **allowed-tools.** `Bash(bash .claude/scripts/*)` in build-feature becomes a pattern on the plugin path. The path contains the user's home and may contain spaces, so check how the matcher handles that.
3. **Permissions.** The `permissions.allow` list in `settings.json` probably can't ship in a plugin. Options: document it in the README, or have `/build-feature` print the block on first run.
4. **Config.** `pipeline.conf` stays per project at `.claude/pipeline.conf`. `lib.sh` currently looks next to the scripts (`$PIPELINE_SCRIPTS/../pipeline.conf`). Change it to `$CLAUDE_PROJECT_DIR/.claude/pipeline.conf` first, then the old location, keeping the `PIPELINE_CONF` override. If the file is missing, step 0 of build-feature copies the template and asks for `TEST_CMD`.
5. **Agent name clashes.** Plugin agents may be namespaced (`plugin:agent`). `check-spawn.sh` matches `subagent_type` exactly (`implementer`, `spec-writer`), so make it accept the namespaced form too. The `Agent` calls in build-feature need the right names.
6. **Implementer Stop hook.** It's in agent frontmatter today. Check that frontmatter hooks in plugin agents run and that `$CLAUDE_PROJECT_DIR` is still set. If not, move it to hooks.json as `SubagentStop` with matcher `implementer`.
7. **Tests.** `test-hooks.sh` and `test-scripts.sh` resolve paths from the repo root. They keep working if `scripts/` and `hooks/` move to the plugin root, after updating the `S=` and `H=` variables.

## Order

Fix 4 first. It's small and helps the template install too. Then 1, 2, 5 and 6 together on a branch, then a dry run with the toy repo installed via a local plugin marketplace.
