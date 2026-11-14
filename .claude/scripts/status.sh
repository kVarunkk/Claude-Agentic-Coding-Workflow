#!/usr/bin/env bash
# status.sh <plan-dir>
# Prints where /build-feature should resume:
#   brief: missing|written|approved
#   spec: missing|written|approved
#   tasks: missing|written|approved
#   gate: <N>|none      first numeric phase whose tasks are all done but approvals/phase-<N> is missing
#   next: <next-unit.sh line>|none
# Exit 1 when the tasks file exists but does not parse.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: status.sh <plan-dir>}"
state() { # glob approval
  if ! ls "$plan"/$1 >/dev/null 2>&1; then echo missing
  elif [ -f "$plan/approvals/$2" ]; then echo approved
  else echo written; fi
}
b=$(state 'feature-*-brief.md' brief)
s=$(state 'feature-*-spec.md' spec)
t=$(state 'feature-*-tasks.md' tasks)
echo "brief: $b"
echo "spec: $s"
echo "tasks: $t"
gate=none; next=none
if [ "$t" != missing ]; then
  tasks=$(tasks_file "$plan") || exit 1
  parsed=$(parse_tasks "$tasks") || exit 1
  gate=$(printf '%s\n' "$parsed" | awk -F'\t' -v dir="$plan/approvals" '
    $1 == "unit" { if (!($3 in seen)) { seen[$3] = 1; order[++n] = $3 } }
    $1 == "task" { ph = $2; sub(/[a-z]$/, "", ph); if ($4 == "open") popen[ph] = 1 }
    END {
      for (i = 1; i <= n; i++) {
        p = order[i]
        if (p in popen) break
        if ((getline line < (dir "/phase-" p)) < 0) { print p; exit }
        close(dir "/phase-" p)
      }
      print "none"
    }')
  next=$(bash "$PIPELINE_SCRIPTS/next-unit.sh" "$plan") || exit 1
  [ -n "$next" ] || next=none
fi
echo "gate: $gate"
echo "next: $next"
