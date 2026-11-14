#!/usr/bin/env bash
# next-unit.sh <plan-dir>
# Prints the first unit (file order) that has an open task, as "<unit-id>: TASK-a TASK-b",
# listing only its open tasks. Prints nothing when every task is done.
# Exit 0 on success, 1 on a missing file or a grammar error.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: next-unit.sh <plan-dir>}"
tasks=$(tasks_file "$plan") || exit 1
parsed=$(parse_tasks "$tasks") || exit 1
printf '%s\n' "$parsed" | awk -F'\t' '
  $1 == "task" && $4 == "open" {
    if (u == "") u = $2
    if ($2 == u) ids = ids " " $3
  }
  END { if (u != "") print u ":" ids }'
