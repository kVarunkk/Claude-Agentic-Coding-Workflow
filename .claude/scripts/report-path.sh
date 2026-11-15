#!/usr/bin/env bash
# report-path.sh <plan-dir> <stage>/<name>
# Prints the next free report path <plan-dir>/reports/<stage>/<name>.md, then -2, -3, ...
# so no report is ever overwritten. Creates the stage folder.
# Stages: spec, tasks, phase-<N>, final. Name: lowercase letters, digits and dashes.
#   report-path.sh plans/x phase-2/review-2a  ->  plans/x/reports/phase-2/review-2a.md (or -2.md, ...)
set -u
usage="usage: report-path.sh <plan-dir> spec|tasks|final|phase-<N>/<name>"
plan="${1:?$usage}"; rel="${2:?$usage}"
plan="${plan%/}"
printf '%s' "$rel" | grep -qE '^(spec|tasks|final|phase-[0-9]+)/[a-z0-9][a-z0-9-]*$' ||
  { echo "bad report name: $rel ($usage)" >&2; exit 1; }
[ -d "$plan" ] || { echo "no such plan dir: $plan" >&2; exit 1; }
base="$plan/reports/$rel"
mkdir -p "$(dirname "$base")"
p="$base.md"; n=2
while [ -e "$p" ]; do p="$base-$n.md"; n=$((n + 1)); done
printf '%s\n' "$p"
