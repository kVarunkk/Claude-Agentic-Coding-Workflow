#!/usr/bin/env bash
# install.sh <target-project-dir>
# Copies the build pipeline (agents, hooks, scripts, skills) into another project's .claude/.
# Re-run to update: pipeline files are replaced, the project's other agents, hooks and skills are left
# alone, and settings.json and pipeline.conf are never overwritten.
set -eu
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
T="${1:?usage: install.sh <target-project-dir>}"
[ -d "$T" ] || { echo "no such directory: $T" >&2; exit 1; }
T="$(cd "$T" && pwd)"
[ "$T" = "$ROOT" ] && { echo "target is this repo" >&2; exit 1; }

command -v git >/dev/null || echo "warning: git not found; the pipeline needs it" >&2
command -v jq >/dev/null || echo "warning: jq not found; hooks degrade without it (see README)" >&2

mkdir -p "$T/.claude/skills"
# Merge copy: the project's own agents and hooks stay; files with our names are replaced.
for d in agents hooks scripts; do
  mkdir -p "$T/.claude/$d"
  cp -r "$ROOT/.claude/$d/." "$T/.claude/$d/"
done
for s in build-feature aligning-requirements writing-specs writing-tasks reviewing-plans reviewing-code checking-spec-conformance; do
  rm -rf "$T/.claude/skills/$s"
  cp -r "$ROOT/.claude/skills/$s" "$T/.claude/skills/"
done

if [ -e "$T/.claude/settings.json" ]; then
  echo "kept existing .claude/settings.json; merge the hooks and permissions from $ROOT/.claude/settings.json by hand"
else
  cp "$ROOT/.claude/settings.json" "$T/.claude/"
fi
if [ -e "$T/.claude/pipeline.conf" ]; then
  echo "kept existing .claude/pipeline.conf"
else
  cp "$ROOT/.claude/pipeline.conf" "$T/.claude/"
  echo "wrote .claude/pipeline.conf; set TEST_CMD to this project's test command"
fi
grep -q 'eol=lf' "$T/.gitattributes" 2>/dev/null || echo "tip: add '*.sh text eol=lf' to $T/.gitattributes so Windows checkouts keep LF"
echo "installed into $T/.claude; restart Claude Code there, trust the workspace, then run /build-feature <feature>"
