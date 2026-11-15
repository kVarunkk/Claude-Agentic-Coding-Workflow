#!/usr/bin/env bash
# PreToolUse hook, matcher "Agent". Blocks an implementer spawn (exit 2, reason on stderr) unless:
#   - the prompt has "PLAN: plans/<feature>" and "UNIT: <id>: TASK-..." lines,
#   - without a FIX line: that unit and task set equal next-unit.sh output (a new unit, or the rest of one);
#     with "FIX: plans/<feature>/reports/...": the file exists and the unit id is the unit still open at
#     HEAD (built in the working tree, not committed yet). Fix rounds get a fresh implementer this way.
#   - approvals/spec and approvals/tasks exist,
#   - for a unit in a later phase than the first, approvals/phase-<previous phase> exists,
#     unless approvals/afk exists (the user chose AFK mode at the tasks gate),
#   - in a git repo, HEAD is not on the default branch.
# Blocks a spec-writer spawn unless its prompt has a "PLAN: plans/<feature>" line and
# approvals/brief exists, i.e. the user agreed the brief first.
# Every other subagent type is allowed. SendMessage resumes are not Agent calls and never reach here.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
. "$SCRIPTS/lib.sh"
input=$(cat)
printf '%s\n' "$input" > "${TMPDIR:-/tmp}/pipeline-last-check-spawn.json" 2>/dev/null
if ! find_jq; then
  # Without jq, block only spawns that look gated; let everything else through.
  printf '%s' "$input" | grep -qE '"subagent_type" *: *"(implementer|spec-writer)"' || exit 0
  echo "check-spawn: jq not found; cannot verify this spawn" >&2; exit 2
fi

type=$(printf '%s' "$input" | "$JQ" -r '.tool_input.subagent_type // empty' | tr -d '\r')
case "$type" in implementer|spec-writer) ;; *) exit 0 ;; esac
block() { echo "Blocked $type spawn: $*" >&2; exit 2; }
prompt=$(printf '%s' "$input" | "$JQ" -r '.tool_input.prompt // empty' | tr -d '\r')

plan=$(printf '%s\n' "$prompt" | sed -n 's/^PLAN:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' | head -1)
[ -n "$plan" ] || block 'the prompt must have a "PLAN: plans/<feature>" line.'
plan="${plan%/}"
printf '%s' "$plan" | grep -qE '^plans/[a-z0-9][a-z0-9-]*$' || block "PLAN must be plans/<feature> in kebab-case, got \"$plan\"."

root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty' | tr -d '\r')
  command -v cygpath >/dev/null 2>&1 && [ -n "$root" ] && root=$(cygpath -u "$root")
fi
[ -n "$root" ] && cd "$root" 2>/dev/null || block "cannot resolve the project dir."
[ -d "$plan" ] || block "no plan dir $plan under $root."

if [ "$type" = "spec-writer" ]; then
  [ -f "$plan/approvals/brief" ] || block "the brief is not agreed ($plan/approvals/brief missing). Align with the user first (aligning-requirements)."
  exit 0
fi

unit_line=$(printf '%s\n' "$prompt" | sed -n 's/^UNIT:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')
[ -n "$unit_line" ] || block 'the prompt must have a "UNIT: <id>: TASK-..." line, copied from next-unit.sh.'
fix=$(printf '%s\n' "$prompt" | sed -n 's/^FIX:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')

norm() { # "<id>: TASK-b TASK-a" -> "<id>: TASK-a TASK-b"
  local id rest
  id="${1%%:*}"; rest="${1#*:}"
  printf '%s: %s' "$(echo "$id" | tr -d '[:space:]')" "$(printf '%s\n' $rest | sort -u | tr '\n' ' ' | sed 's/ $//')"
}
uid=$(printf '%s' "${unit_line%%:*}" | tr -d '[:space:]')

if [ -n "$fix" ]; then
  case "$fix" in "$plan"/reports/*) ;; *) block "FIX must name a file under $plan/reports/, got \"$fix\"." ;; esac
  case "$fix" in *..*) block "FIX path must not contain \"..\"." ;; esac
  [ -f "$fix" ] || block "FIX file $fix does not exist."
  expected=$(next_unit_at "$plan" HEAD 2>/dev/null) || block "cannot read the tasks file committed at HEAD; a fix round needs the approved tasks committed."
  [ -n "$expected" ] || block "no unit is open at HEAD; there is nothing in progress to fix."
  [ "$uid" = "${expected%%:*}" ] || block "a fix round is only for the unit in progress (${expected%%:*}), got $uid."
else
  expected=$(bash "$SCRIPTS/next-unit.sh" "$plan" 2>&1) || block "next-unit.sh failed: $expected"
  [ -n "$expected" ] || block "every task in $plan is done; there is no unit to implement."
  [ "$(norm "$unit_line")" = "$(norm "$expected")" ] || block "expected \"UNIT: $expected\", got \"UNIT: $unit_line\". Pass next-unit.sh output verbatim."
fi

[ -f "$plan/approvals/spec" ] || block "the spec is not approved ($plan/approvals/spec missing)."
[ -f "$plan/approvals/tasks" ] || block "the tasks are not approved ($plan/approvals/tasks missing)."

unit="${expected%%:*}"
phase="${unit%[a-z]}"
tasks=$(tasks_file "$plan") || block "no tasks file."
prev=$(parse_tasks "$tasks" | awk -F'\t' -v p="$phase" '$1 == "unit" && $3 + 0 < p + 0 && (!f || $3 + 0 > m + 0) { m = $3; f = 1 } END { if (f) print m }')
if [ -n "$prev" ] && [ ! -f "$plan/approvals/afk" ]; then
  [ -f "$plan/approvals/phase-$prev" ] || block "phase $prev is not approved ($plan/approvals/phase-$prev missing). Gate phase $prev with the user first."
fi

if git rev-parse --git-dir >/dev/null 2>&1; then
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  def=$(default_branch 2>/dev/null) || def=""
  [ -n "$def" ] && [ "$cur" = "$def" ] && block "HEAD is on the default branch $def. Run bash .claude/scripts/branch.sh $plan first."
fi
exit 0
