#!/usr/bin/env bash
# phase-done.sh <plan-dir> <unit-id>
# Exit 0 when <unit-id> is the last unit of its numeric phase (3b after 3a, or a plain 3)
# and every task in that phase is done. Exit 1 otherwise, or on errors (message on stderr).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: phase-done.sh <plan-dir> <unit-id>}"
unit="${2:?usage: phase-done.sh <plan-dir> <unit-id>}"
tasks=$(tasks_file "$plan") || exit 1
parsed=$(parse_tasks "$tasks") || exit 1
printf '%s\n' "$parsed" | awk -F'\t' -v want="$unit" '
  $1 == "unit" { ph[$2] = $3; last[$3] = $2; if ($2 == want) found = 1 }
  $1 == "task" && $4 == "open" { open[ph[$2]] = 1 }
  END {
    if (!found) { print "unknown unit: " want > "/dev/stderr"; exit 1 }
    p = ph[want]
    exit (last[p] == want && !(p in open)) ? 0 : 1
  }'
