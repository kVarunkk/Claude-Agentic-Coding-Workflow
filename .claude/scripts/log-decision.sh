#!/usr/bin/env bash
# log-decision.sh <plan-dir> <step> <decision> <why> <evidence> <result>
# Appends one row to <plan-dir>/decisions.tsv (append-only trail; header on first use).
# Tabs and newlines inside a field become spaces.
set -u
usage="usage: log-decision.sh <plan-dir> <step> <decision> <why> <evidence> <result>"
[ $# -eq 6 ] || { echo "got $# argument(s), want 6 after the plan dir (step decision why evidence result)" >&2; echo "$usage" >&2; exit 1; }
plan="${1%/}"; shift
[ -d "$plan" ] || { echo "no such plan dir: $plan" >&2; exit 1; }
f="$plan/decisions.tsv"
[ -f "$f" ] || printf 'ts\tstep\tdecision\twhy\tevidence\tresult\n' > "$f"
row=$(date -u +%Y-%m-%dT%H:%M:%SZ)
for v in "$@"; do row="$row"$'\t'"$(printf '%s' "$v" | tr '\t\r\n' '   ')"; done
printf '%s\n' "$row" >> "$f"
