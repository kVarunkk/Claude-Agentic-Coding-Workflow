#!/usr/bin/env bash
# run-stats.sh <plan-dir>
# Counts for the final report, from files only (decisions.tsv and reports/), never from memory:
#   unit <id>: reviews <n>, fix rounds <n>, restarts <n>, committed yes|no
#   units: <n> committed of <n>
#   fix rounds: <n>   restarts: <n>   added units: <n>   stops: <n>   empty reports: <n>   gate reasons: <n>
# A review is a reports/phase-*/review-<id>[-k].md file. The other counts are decisions.tsv rows by decision:
# commit, fix-round, restart, add-unit, stop, empty-report, gate-reason (step unit-<id> for per-unit rows).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: run-stats.sh <plan-dir>}"; plan="${plan%/}"
tasks=$(tasks_file "$plan") || exit 1
units=$(parse_tasks "$tasks" | awk -F'\t' '$1 == "unit" { print $2 }') || exit 1
dec="$plan/decisions.tsv"
rows() { # decision [step]: number of decisions.tsv rows
  [ -f "$dec" ] || { echo 0; return; }
  tr -d '\r' < "$dec" | awk -F'\t' -v d="$1" -v s="${2-}" 'NR > 1 && $3 == d && (s == "" || $2 == s) { n++ } END { print n + 0 }'
}
total=0; done_units=0
for u in $units; do
  total=$((total + 1))
  n=$(ls "$plan"/reports/phase-*/review-"$u".md "$plan"/reports/phase-*/review-"$u"-[0-9]*.md 2>/dev/null | wc -l | tr -d ' ')
  c=no; [ "$(rows commit "unit-$u")" -gt 0 ] && { c=yes; done_units=$((done_units + 1)); }
  echo "unit $u: reviews $n, fix rounds $(rows fix-round "unit-$u"), restarts $(rows restart "unit-$u"), committed $c"
done
echo "units: $done_units committed of $total"
echo "fix rounds: $(rows fix-round)   restarts: $(rows restart)   added units: $(rows add-unit)   stops: $(rows stop)   empty reports: $(rows empty-report)   gate reasons: $(rows gate-reason)"
