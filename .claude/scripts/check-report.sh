#!/usr/bin/env bash
# check-report.sh <report-file>
# Exit 0 when the agent's report exists on disk, is not empty and contains a "verdict:" line.
# Run before a unit commit: a reviewer that could not write its report has not reviewed.
set -u
f="${1:?usage: check-report.sh <report-file>}"
[ -s "$f" ] || { echo "report missing or empty: $f"; exit 1; }
tr -d '\r' < "$f" | grep -qiE '^[[:space:]]*(\*\*)?verdict(\*\*)?[[:space:]]*:' ||
  { echo "report has no verdict line: $f"; exit 1; }
