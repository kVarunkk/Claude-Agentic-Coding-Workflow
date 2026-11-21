#!/usr/bin/env bash
# report-path.sh [--pending] <plan-dir> <stage>/<name>
# Prints the next free report path <plan-dir>/reports/<stage>/<name>.md, then -2, -3, ...
# so no report is ever overwritten. Creates the stage folder.
# Stages: spec, tasks, phase-<N>, final. Name: lowercase letters, digits and dashes.
#   report-path.sh plans/x phase-2/review-2a  ->  plans/x/reports/phase-2/review-2a.md (or -2.md, ...)
# A unit review (review-<unit>) must sit under its unit's phase: phase-1/review-2 is refused.
# --pending: also creates the file as a skeleton with "verdict: pending", for a path handed to an agent in a
#   REPORT: line. The name is taken at once, and an agent that stops before writing anything leaves a report
#   that check-report.sh calls incomplete instead of a missing one. The agent replaces the whole file.
set -u
usage="usage: report-path.sh [--pending] <plan-dir> spec|tasks|final|phase-<N>/<name>"
pending=0
[ "${1:-}" = --pending ] && { pending=1; shift; }
plan="${1:?$usage}"; rel="${2:?$usage}"
plan="${plan%/}"
printf '%s' "$rel" | grep -qE '^(spec|tasks|final|phase-[0-9]+)/[a-z0-9][a-z0-9-]*$' ||
  { echo "bad report name: $rel ($usage)" >&2; exit 1; }
[ -d "$plan" ] || { echo "no such plan dir: $plan" >&2; exit 1; }
# A unit's review goes under its own phase: review-2a lives in phase-2 (R55).
case "$rel" in
  phase-*/review-[0-9]*)
    rn=$(printf '%s' "${rel#*/review-}" | sed -nE 's/^([0-9]+)[a-z]?$/\1/p')
    ph="${rel%%/*}"; ph="${ph#phase-}"
    if [ -n "$rn" ] && [ "$((10#$rn))" -ne "$((10#$ph))" ]; then
      echo "unit ${rel#*/review-} is in phase $rn, so its review goes under phase-$rn/, not ${rel%%/*}/" >&2; exit 1
    fi ;;
esac
base="$plan/reports/$rel"
mkdir -p "$(dirname "$base")"
p="$base.md"; n=2
while [ -e "$p" ]; do p="$base-$n.md"; n=$((n + 1)); done
if [ "$pending" = 1 ]; then
  printf '# %s\n\nverdict: pending\n\nSkeleton from report-path.sh. The agent named in the REPORT: line replaces this whole file.\n' \
    "${p#"$plan"/reports/}" > "$p" || { echo "cannot create $p" >&2; exit 1; }
fi
printf '%s\n' "$p"
