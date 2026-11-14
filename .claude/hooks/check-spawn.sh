#!/usr/bin/env bash
# PreToolUse hook, matcher "Agent". Blocks an implementer spawn (exit 2, reason on stderr) unless:
#   - the prompt has "PLAN: plans/<feature>" and "UNIT: <id>: TASK-..." lines,
#   - that unit and task set equal next-unit.sh output,
#   - approvals/spec and approvals/tasks exist,
#   - for a unit in a later phase than the first, approvals/phase-<previous phase> exists.
# Every other subagent type is allowed. SendMessage resumes are not Agent calls and never reach here.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
. "$SCRIPTS/lib.sh"
input=$(cat)
printf '%s\n' "$input" > "${TMPDIR:-/tmp}/pipeline-last-check-spawn.json" 2>/dev/null
find_jq || { echo "check-spawn: jq not found; cannot verify the implementer spawn" >&2; exit 2; }

block() { echo "Blocked implementer spawn: $*" >&2; exit 2; }

type=$(printf '%s' "$input" | "$JQ" -r '.tool_input.subagent_type // empty' | tr -d '\r')
[ "$type" = "implementer" ] || exit 0
prompt=$(printf '%s' "$input" | "$JQ" -r '.tool_input.prompt // empty' | tr -d '\r')

plan=$(printf '%s\n' "$prompt" | sed -n 's/^PLAN:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' | head -1)
unit_line=$(printf '%s\n' "$prompt" | sed -n 's/^UNIT:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')
[ -n "$plan" ] && [ -n "$unit_line" ] || block 'the prompt must start with "PLAN: plans/<feature>" and "UNIT: <id>: TASK-..." lines, copied from next-unit.sh.'
plan="${plan%/}"
printf '%s' "$plan" | grep -qE '^plans/[a-z0-9][a-z0-9-]*$' || block "PLAN must be plans/<feature> in kebab-case, got \"$plan\"."

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty' | tr -d '\r')
  command -v cygpath >/dev/null 2>&1 && [ -n "$root" ] && root=$(cygpath -u "$root")
fi
[ -n "$root" ] && cd "$root" 2>/dev/null || block "cannot resolve the project dir."
[ -d "$plan" ] || block "no plan dir $plan under $root."

norm() { # "<id>: TASK-b TASK-a" -> "<id>: TASK-a TASK-b"
  local id rest
  id="${1%%:*}"; rest="${1#*:}"
  printf '%s: %s' "$(echo "$id" | tr -d '[:space:]')" "$(printf '%s\n' $rest | sort -u | tr '\n' ' ' | sed 's/ $//')"
}
expected=$(bash "$SCRIPTS/next-unit.sh" "$plan" 2>&1) || block "next-unit.sh failed: $expected"
[ -n "$expected" ] || block "every task in $plan is done; there is no unit to implement."
[ "$(norm "$unit_line")" = "$(norm "$expected")" ] || block "expected \"UNIT: $expected\", got \"UNIT: $unit_line\". Pass next-unit.sh output verbatim."

[ -f "$plan/approvals/spec" ] || block "the spec is not approved ($plan/approvals/spec missing)."
[ -f "$plan/approvals/tasks" ] || block "the tasks are not approved ($plan/approvals/tasks missing)."

unit="${expected%%:*}"
phase="${unit%[a-z]}"
tasks=$(tasks_file "$plan") || block "no tasks file."
prev=$(parse_tasks "$tasks" | awk -F'\t' -v p="$phase" '$1 == "unit" && $3 + 0 < p + 0 && (!f || $3 + 0 > m + 0) { m = $3; f = 1 } END { if (f) print m }')
if [ -n "$prev" ]; then
  [ -f "$plan/approvals/phase-$prev" ] || block "phase $prev is not approved ($plan/approvals/phase-$prev missing). Gate phase $prev with the user first."
fi
exit 0
