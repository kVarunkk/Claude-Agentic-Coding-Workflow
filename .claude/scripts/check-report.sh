#!/usr/bin/env bash
# check-report.sh <report-file>
# Exit 0 when the agent's report is finished: it exists, is not empty, has a "verdict: pass" or "verdict: fail"
# line (the SUMMARY block the agent copies into the file), no "verdict: pending" line (the skeleton
# report-path.sh --pending or the agent writes first, left behind when it ran out of turns), no pass/fail
# disagreement, and p0/p1/p2 counts no lower than the [P<n>] items its SUMMARY lists under top:.
# The report's folder must also hold no scratch files (dotfiles or *.part*), which stage-unit.sh would
# otherwise commit.
# Run before using any reviewer, verifier or matcher result: an agent that did not finish its report has not
# reviewed. Exit 1 is never fixed by editing the report: the agent is replaced (build-feature).
set -u
f="${1:?usage: check-report.sh <report-file>}"
[ -s "$f" ] || { echo "report missing or empty: $f"; exit 1; }
verdicts=$(tr -d '\r' < "$f" |
  sed -nE 's/^[[:space:]]*[*`_]*[Vv]erdict[*`_]*[[:space:]]*:[[:space:]*`_]*([A-Za-z-]+).*/\1/p' |
  tr 'A-Z' 'a-z' | sort -u)
printf '%s\n' "$verdicts" | grep -qx pending &&
  { echo "report incomplete (verdict: pending): the agent stopped before finishing: $f"; exit 1; }
pf=$(printf '%s\n' "$verdicts" | grep -xE 'pass|fail')
if [ -z "$pf" ]; then
  other=$(printf '%s\n' "$verdicts" | grep -vx '' | head -1)
  [ -n "$other" ] && { echo "report says \"verdict: $other\", which is the standalone review format; a pipeline report needs \"verdict: pass|fail\" in its SUMMARY: $f"; exit 1; }
  echo "report has no \"verdict: pass|fail\" line: $f"; exit 1
fi
[ "$(printf '%s\n' "$pf" | wc -l)" -eq 1 ] || { echo "report says both verdict: pass and verdict: fail: $f"; exit 1; }
# The SUMMARY counts must cover its top: list: a "[P2]" item under top: with "p2: 0" means a wrong count.
bad=$(tr -d '\r' < "$f" | awk '
  /^[[:space:]]*SUMMARY[[:space:]]*$/ { insum = 1; split("", c); split("", t); next }
  insum && /^[[:space:]]*p[0-2]:[[:space:]]*[0-9]+/ { k = $1; sub(":", "", k); c[k] = $2 + 0; next }
  insum && /^[[:space:]]*-/ { s = $0; while (match(s, /\[[Pp][0-2]\]/)) { k = tolower(substr(s, RSTART + 1, 2)); t[k]++; s = substr(s, RSTART + RLENGTH) } }
  END { for (k in t) if ((k in c) && t[k] > c[k]) printf "%s: %d listed under top:, count says %d\n", k, t[k], c[k] }')
[ -z "$bad" ] || { echo "SUMMARY counts disagree with its top: list ($f):"; printf '  %s\n' "$bad"; exit 1; }
# R67: the verdict follows the counts: fail when p0 or p1 is above 0, else pass. Run 11's phase-3 matcher wrote
# "verdict: fail" with p0 = p1 = 0, which stopped an AFK run for two P2 notes.
blocking=$(tr -d '\r' < "$f" | awk '
  /^[[:space:]]*SUMMARY[[:space:]]*$/ { insum = 1; a = ""; b = ""; next }
  insum && /^[[:space:]]*p0:[[:space:]]*[0-9]+/ { a = $2 + 0 }
  insum && /^[[:space:]]*p1:[[:space:]]*[0-9]+/ { b = $2 + 0 }
  END { if (a != "" && b != "") print a + b }')
if [ -n "$blocking" ]; then
  [ "$pf" = fail ] && [ "$blocking" -eq 0 ] &&
    { echo "verdict: fail with p0 = p1 = 0; the verdict is pass when no P0 or P1 is open (P2s never fail a verdict): $f"; exit 1; }
  [ "$pf" = pass ] && [ "$blocking" -gt 0 ] &&
    { echo "verdict: pass with $blocking P0/P1 finding(s) open; the verdict is fail: $f"; exit 1; }
fi
litter=$(ls -A "$(dirname "$f")" | grep -E '^\.|\.part' )
[ -z "$litter" ] || { echo "scratch files next to the report (move them to \${TMPDIR:-/tmp} or delete them):"; printf '  %s\n' $litter; exit 1; }
exit 0
