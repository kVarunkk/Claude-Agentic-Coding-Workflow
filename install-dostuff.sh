#!/usr/bin/env bash
# install-dostuff.sh <target-project-dir>
# install-dostuff.sh --check <target-project-dir>
# Installs the build pipeline for dostuff instead of Claude Code: the same agents, skills, scripts and hooks as
# install.sh, copied under <target>/.dostuff/ and converted from this repo's .claude/ files (which stay the single
# source; nothing here edits them).
#
#   agents   -> .dostuff/agents/   maxTurns: becomes max_iterations:, the frontmatter hooks: block is dropped
#                                  (dostuff reads agent hooks from config, see the SubagentStop entry below)
#   skills   -> .dostuff/skills/
#   scripts  -> .dostuff/scripts/  hooks -> .dostuff/hooks/  pipeline.conf -> .dostuff/pipeline.conf
#   text     .claude/ paths become .dostuff/ ; AskUserQuestion -> ask_user ; SendMessage -> send_message
#   hooks    .dostuff/config.yaml gets the hooks under dostuff's tool names (agent, send_message, bash_command,
#            write_file|edit_file|multi_edit|delete_file|edit_config, SubagentStop with matcher implementer)
#            and loop.max_tokens (dostuff otherwise sends no output cap). An existing
#            config.yaml is never overwritten: the block is
#            printed for you to merge, like install.sh does with settings.json.
# Re-run to update: pipeline files are replaced, the project's other agents, hooks and skills are left alone.
# Writes .dostuff/.installed-from: this repo's commit and whether .claude/ had uncommitted changes.
# --check: installs into a temp dir and compares the pipeline files (agents, hooks, scripts, the pipeline skills)
#   with the target's .dostuff/. Exit 0 when they match, 1 with the differing paths when the target has drifted
#   from .claude/ (someone edited the copy, or .claude/ changed since the install). config.yaml and
#   pipeline.conf are the project's own and are not compared, except that every pipeline hook must be named in
#   config.yaml.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK=0; [ "${1:-}" = "--check" ] && { CHECK=1; shift; }
T="${1:?usage: install-dostuff.sh [--check] <target-project-dir>}"
[ -d "$T" ] || { echo "no such directory: $T" >&2; exit 1; }
T="$(cd "$T" && pwd)"
[ "$T" = "$ROOT" ] && { echo "target is this repo" >&2; exit 1; }
D="$T/.dostuff"
CONFIG_HOOKS="pipeline-check-spawn pipeline-check-resume pipeline-check-write pipeline-check-git pipeline-implementer-stop"
if [ $CHECK -eq 1 ]; then
  [ -d "$D" ] || { echo "no .dostuff in $T" >&2; exit 1; }
  W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
  bash "${BASH_SOURCE[0]}" "$W" >/dev/null 2>&1 || { echo "install into a temp dir failed" >&2; exit 1; }
  drift=0
  for p in agents hooks scripts $(for s in build-feature aligning-requirements writing-specs writing-tasks reviewing-plans reviewing-code checking-spec-conformance; do echo "skills/$s"; done); do
    if [ "${p%%/*}" = agents ]; then  # only the pipeline's agents; the project may have its own
      for f in "$W/.dostuff/agents"/*.md; do
        cmp -s "$f" "$D/agents/$(basename "$f")" || { echo "differs: .dostuff/agents/$(basename "$f")"; drift=1; }
      done
      continue
    fi
    out=$(diff -rq "$W/.dostuff/$p" "$D/$p" 2>&1) || {
      out=$(printf '%s\n' "$out" | sed -e "s#^Files .* and $T/\(.*\) differ\$#differs: \1#" \
        -e "s#^Only in $W/\([^:]*\): #missing in the target: \1/#" -e "s#^Only in $T/\([^:]*\): #note, the project's own file: \1/#")
      printf '%s\n' "$out"
      printf '%s\n' "$out" | grep -qv '^note' && drift=1; }
  done
  # config.yaml is the project's own, but a pipeline hook missing from it means that check never runs.
  for h in $CONFIG_HOOKS; do
    grep -q "name: $h," "$D/config.yaml" 2>/dev/null || { echo "missing in .dostuff/config.yaml: hook $h (merge the block install-dostuff.sh prints)"; drift=1; }
  done
  [ -f "$D/.installed-from" ] && sed 's/^/installed from: /' "$D/.installed-from" | head -2
  echo "repo now:       commit $(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  [ $drift -eq 0 ] && { echo "in sync: $D matches .claude/"; exit 0; }
  echo "drift: rerun install-dostuff.sh (or make-toy.sh --dostuff --sync) to bring $D back to .claude/"
  exit 1
fi
SKILLS="build-feature aligning-requirements writing-specs writing-tasks reviewing-plans reviewing-code checking-spec-conformance"

command -v git >/dev/null || echo "warning: git not found; the pipeline needs it" >&2
command -v jq >/dev/null || echo "warning: jq not found; the hooks need it (check-spawn blocks gated spawns without it)" >&2

# Paths and tool names in the pipeline's own text, in the order they matter.
convert() { sed -i -e 's#\.claude/#.dostuff/#g' -e 's/AskUserQuestion/ask_user/g' -e 's/SendMessage/send_message/g' "$@"; }

mkdir -p "$D/agents" "$D/hooks" "$D/scripts" "$D/skills"

cp -r "$ROOT/.claude/scripts/." "$D/scripts/"
cp -r "$ROOT/.claude/hooks/." "$D/hooks/"
convert "$D"/scripts/*.sh "$D"/hooks/*.sh

for f in "$ROOT"/.claude/agents/*.md; do
  out="$D/agents/$(basename "$f")"
  # Inside the frontmatter only: drop the hooks: block (it is config in dostuff), rename maxTurns.
  awk '
    /^---[ \t\r]*$/ { fm++; print; next }
    fm == 1 && /^hooks:/ { skip = 1; next }
    fm == 1 && skip && /^[ \t]/ { next }
    { skip = 0; if (fm == 1) sub(/^maxTurns:/, "max_iterations:"); print }
  ' "$f" > "$out"
  convert "$out"
done

for s in $SKILLS; do
  rm -rf "$D/skills/$s"
  cp -r "$ROOT/.claude/skills/$s" "$D/skills/"
  find "$D/skills/$s" -name '*.md' -exec sed -i -e 's#\.claude/#.dostuff/#g' -e 's/AskUserQuestion/ask_user/g' -e 's/SendMessage/send_message/g' {} +
done

if [ -e "$D/pipeline.conf" ]; then
  echo "kept existing .dostuff/pipeline.conf"
else
  cp "$ROOT/.claude/pipeline.conf" "$D/"
  echo "wrote .dostuff/pipeline.conf; set TEST_CMD to this project's test command"
fi

CONFIG_BLOCK='# Pipeline hooks (install-dostuff.sh). Project hooks run only after you trust them (dostuff asks once).
agents:
  models:               # the agent files say opus / sonnet; point them at models you have, or leave inherit
    opus: inherit
    sonnet: inherit
loop:
  max_tokens: 32000     # output-token cap per model call; without it litellm sends 4096 for a model it does not know on the Anthropic route (minimax-m3, qwen3.8-max).
                        # Keep it under the output limit of every model above (models.dev, limit.output)
hooks:
  PreToolUse:
    - matcher: agent            # blocks a gated implementer / spec-writer spawn
      hooks:
        - { type: command, name: pipeline-check-spawn, command: "bash .dostuff/hooks/check-spawn.sh" }
    - matcher: send_message     # blocks resuming a pipeline agent (fresh agent every round)
      hooks:
        - { type: command, name: pipeline-check-resume, command: "bash .dostuff/hooks/check-spawn.sh" }
    - matcher: write_file|edit_file|multi_edit|delete_file|edit_config   # the orchestrator never writes agent reports, the spec, the tasks file or the config
      hooks:
        - { type: command, name: pipeline-check-write, command: "bash .dostuff/hooks/check-write.sh" }
    - matcher: bash_command     # blocks force-push, --amend and tag moves
      hooks:
        - { type: command, name: pipeline-check-git, command: "bash .dostuff/hooks/check-git.sh" }
  SubagentStop:
    - matcher: implementer      # the implementer cannot finish while TEST_CMD is red
      hooks:
        - { type: command, name: pipeline-implementer-stop, command: "bash .dostuff/hooks/implementer-stop.sh" }'

if [ -e "$D/config.yaml" ]; then
  echo "kept existing .dostuff/config.yaml; merge this by hand (hooks: and agents: keys may already exist there):"
  printf '%s\n' "$CONFIG_BLOCK"
else
  printf '%s\n' "$CONFIG_BLOCK" > "$D/config.yaml"
  echo "wrote .dostuff/config.yaml"
fi
sha=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null || echo unknown)
dirty=no; [ -n "$(git -C "$ROOT" status --porcelain -- .claude 2>/dev/null)" ] && dirty=yes
printf 'commit: %s\nclaude-dir-uncommitted: %s\nsource: %s\ninstalled: %s\n' "$sha" "$dirty" "$ROOT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "$D/.installed-from"
grep -q 'eol=lf' "$T/.gitattributes" 2>/dev/null || echo "tip: add '*.sh text eol=lf' to $T/.gitattributes so Windows checkouts keep LF"
echo "installed into $D; start dostuff there, trust the project hooks, then run /build-feature <feature>"
