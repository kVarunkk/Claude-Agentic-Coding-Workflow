#!/usr/bin/env bash
# tick-unit.sh <plan-dir> <unit-id>
# v1: validates that every task in the unit is ticked ([x] with a date). Prints the open
# task ids and exits 1 if not. Exit 0 when fully ticked. (M7 moves ticking here.)
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: tick-unit.sh <plan-dir> <unit-id>}"
unit="${2:?usage: tick-unit.sh <plan-dir> <unit-id>}"
tasks=$(tasks_file "$plan") || exit 1
parsed=$(parse_tasks "$tasks") || exit 1
printf '%s\n' "$parsed" | awk -F'\t' -v want="$unit" '
  $1 == "unit" && $2 == want { found = 1 }
  $1 == "task" && $2 == want && ($4 == "open" || $5 == "") { open = open " " $3 }
  END {
    if (!found) { print "unknown unit: " want > "/dev/stderr"; exit 1 }
    if (open != "") { print "not ticked:" open; exit 1 }
  }'
