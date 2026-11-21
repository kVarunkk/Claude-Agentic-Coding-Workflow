#!/usr/bin/env bash
# tick-unit.sh <plan-dir> <unit-id> [<base>]
# Validates that every task in the unit is ticked ([x] with a date). Prints the open
# task ids and exits 1 if not. Exit 0 when fully ticked.
# With <base> (a commit), also fails when a task of another unit changed its Status or Done
# since <base>: "foreign tick: TASK-031". An implementer may tick only its own unit.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
usage="usage: tick-unit.sh <plan-dir> <unit-id> [<base>]"
plan="${1:?$usage}"
unit="${2:?$usage}"
base="${3:-}"
tasks=$(tasks_file "$plan") || exit 1
parsed=$(parse_tasks "$tasks") || exit 1
printf '%s\n' "$parsed" | awk -F'\t' -v want="$unit" '
  $1 == "unit" && $2 == want { found = 1 }
  $1 == "task" && $2 == want && ($4 == "open" || $5 == "") { open = open " " $3 }
  END {
    if (!found) { print "unknown unit: " want > "/dev/stderr"; exit 1 }
    if (open != "") { print "not ticked:" open; exit 1 }
  }' || exit 1
[ -n "$base" ] || exit 0
old=$(mktemp) || exit 1
trap 'rm -f "$old"' EXIT
git -C "$(dirname "$tasks")" show "$base:./$(basename "$tasks")" > "$old" 2>/dev/null ||
  { echo "cannot read the tasks file at $base" >&2; exit 1; }
before=$(parse_tasks "$old") || exit 1
# Tasks of other units whose state (open/done, date) differs from base.
foreign=$(
  { printf '%s\n' "$before" | sed 's/^/B\t/'; printf '%s\n' "$parsed" | sed 's/^/N\t/'; } |
  awk -F'\t' -v want="$unit" '
    $2 == "task" && $3 != want { k = $4; v = $5 "|" $6; if ($1 == "B") b[k] = v; else n[k] = v }
    END { for (k in n) if ((k in b) && b[k] != n[k]) print k }' | sort | tr '\n' ' ' | sed 's/ $//')
[ -z "$foreign" ] || { echo "foreign tick: $foreign"; exit 1; }
