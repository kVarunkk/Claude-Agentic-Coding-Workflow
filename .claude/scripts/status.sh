#!/usr/bin/env bash
# status.sh <plan-dir>
# Prints where /build-feature should resume:
#   brief: missing|written|approved
#   spec: missing|written|approved
#   tasks: missing|written|approved
#   afk: on|off                approvals/afk exists (user chose AFK at the tasks gate)
#   gate: <N>|none             first phase whose tasks are all done but whose phase end is not finished:
#                              approvals/phase-<N> missing, or in AFK mode the tag <feature>-phase-<N> missing
#   uncommitted: <unit>|none   the unit open at HEAD is fully ticked in the working tree (built, not committed)
#   next: <next-unit.sh line>|none
#   final: approved|open
# Exit 1 when the tasks file exists but does not parse.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: status.sh <plan-dir>}"
plan="${plan%/}"
feature=$(basename "$plan")
state() { # glob approval
  if ! ls "$plan"/$1 >/dev/null 2>&1; then echo missing
  elif [ -f "$plan/approvals/$2" ]; then echo approved
  else echo written; fi
}
b=$(state 'feature-*-brief.md' brief)
s=$(state 'feature-*-spec.md' spec)
t=$(state 'feature-*-tasks.md' tasks)
afk=off; [ -f "$plan/approvals/afk" ] && afk=on
final=open; [ -f "$plan/approvals/final" ] && final=approved
echo "brief: $b"
echo "spec: $s"
echo "tasks: $t"
echo "afk: $afk"
gate=none; next=none; unc=none
if [ "$t" != missing ]; then
  tasks=$(tasks_file "$plan") || exit 1
  parsed=$(parse_tasks "$tasks") || exit 1
  # One line per phase in file order: "<phase> <1 if all its tasks are done, else 0>".
  phases=$(printf '%s\n' "$parsed" | awk -F'\t' '
    $1 == "unit" { if (!($3 in seen)) { seen[$3] = 1; order[++n] = $3 } }
    $1 == "task" { ph = $2; sub(/[a-z]$/, "", ph); if ($4 == "open") popen[ph] = 1 }
    END { for (i = 1; i <= n; i++) print order[i], ((order[i] in popen) ? 0 : 1) }')
  while read -r p complete; do
    [ "$complete" = 1 ] || break
    if [ "$afk" = on ]; then
      git -C "$plan" rev-parse -q --verify "refs/tags/$feature-phase-$p" >/dev/null 2>&1 && continue
    else
      [ -f "$plan/approvals/phase-$p" ] && continue
    fi
    gate=$p; break
  done <<< "$phases"
  next=$(bash "$PIPELINE_SCRIPTS/next-unit.sh" "$plan") || exit 1
  [ -n "$next" ] || next=none
  if committed=$(next_unit_at "$plan" HEAD 2>/dev/null) && [ -n "$committed" ]; then
    cu="${committed%%:*}"
    open_in_cu=$(printf '%s\n' "$parsed" | awk -F'\t' -v u="$cu" '$1 == "task" && $2 == u && $4 == "open"' | wc -l)
    [ "$open_in_cu" -eq 0 ] && unc="$cu"
  fi
fi
echo "gate: $gate"
echo "uncommitted: $unc"
echo "next: $next"
echo "final: $final"
