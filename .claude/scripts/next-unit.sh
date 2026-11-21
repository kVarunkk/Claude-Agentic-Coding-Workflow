#!/usr/bin/env bash
# next-unit.sh [--all] <plan-dir>
# Prints the first unit (file order) that has an open task, as "<unit-id>: TASK-a TASK-b",
# listing only its open tasks. Prints nothing when every task is done.
# --all prints every unit, one line each, as "<unit-id>: TASK-a TASK-b (done|open|<n>/<m> done)", so the
# orchestrator can show the units at a gate without reading the tasks file into its context (R65).
# Exit 0 on success, 1 on a missing file or a grammar error.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
all=0
[ "${1:-}" = --all ] && { all=1; shift; }
plan="${1:?usage: next-unit.sh [--all] <plan-dir>}"
tasks=$(tasks_file "$plan") || exit 1
parsed=$(parse_tasks "$tasks") || exit 1
if [ "$all" = 1 ]; then
  printf '%s\n' "$parsed" | awk -F'\t' '
    $1 == "unit" { order[++n] = $2 }
    $1 == "task" { ids[$2] = ids[$2] " " $3; m[$2]++; if ($4 == "done") d[$2]++ }
    END { for (i = 1; i <= n; i++) { u = order[i]; s = (d[u] + 0 == m[u]) ? "done" : (d[u] + 0 == 0 ? "open" : d[u] + 0 "/" m[u] " done"); print u ":" ids[u] " (" s ")" } }'
  exit 0
fi
printf '%s\n' "$parsed" | next_unit_of
