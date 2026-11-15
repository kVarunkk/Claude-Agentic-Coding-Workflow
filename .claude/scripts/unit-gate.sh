#!/usr/bin/env bash
# unit-gate.sh <plan-dir> <base> <fix-rounds> <mutations-still-green>
# Decides whether a reviewed unit stops for the user before its commit (UNIT_GATE in pipeline.conf).
# Prints one "reason: ..." line per exception found, then "gate: yes" or "gate: no".
#   Exceptions: the "## Differences from the spec" section changed since <base> (new lines are
#   printed), a fix round ran (<fix-rounds> > 0), a mutation stayed green (<mutations-still-green> > 0).
#   UNIT_GATE=exceptions  gate when there is at least one reason (default)
#   UNIT_GATE=always      gate every unit
#   UNIT_GATE=off         never gate
#   AFK mode (approvals/afk) never gates; the reasons are still printed so they can be logged.
# Exit 0 with a decision; exit 1 on errors (message on stderr).
set -u -o pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
usage="usage: unit-gate.sh <plan-dir> <base> <fix-rounds> <mutations-still-green>"
plan="${1:?$usage}"; base="${2:?$usage}"; rounds="${3:?$usage}"; green="${4:?$usage}"
load_conf
UNIT_GATE="${UNIT_GATE:-exceptions}"
case "$UNIT_GATE" in exceptions|always|off) ;; *) echo "UNIT_GATE must be exceptions, always or off, got: $UNIT_GATE" >&2; exit 1 ;; esac
for n in "$rounds" "$green"; do
  printf '%s' "$n" | grep -qE '^[0-9]+$' || { echo "$usage" >&2; exit 1; }
done
tasks=$(tasks_file "$plan") || exit 1

# The Differences section of a tasks file on stdin, without its heading and blank lines.
diff_section() {
  tr -d '\r' | awk '/^## /{ on = ($0 ~ /^## Differences from the spec/); next } on && NF'
}
old=$(git -C "$(dirname "$tasks")" show "$base:./$(basename "$tasks")" 2>/dev/null | diff_section) \
  || { echo "cannot read the tasks file at $base" >&2; exit 1; }
new=$(diff_section < "$tasks")

reasons=0
if [ "$old" != "$new" ]; then
  added=$(printf '%s\n' "$new" | grep -vxF -f <(printf '%s\n' "$old") | grep -vx 'None yet\.')
  if [ -n "$added" ]; then
    printf '%s\n' "$added" | while IFS= read -r l; do printf 'reason: difference logged: %s\n' "$l"; done
  else
    echo "reason: Differences section edited"
  fi
  reasons=1
fi
[ "$rounds" -gt 0 ] && { echo "reason: $rounds fix round(s) ran"; reasons=1; }
[ "$green" -gt 0 ] && { echo "reason: $green mutation(s) stayed green"; reasons=1; }

if [ -f "$plan/approvals/afk" ] || [ "$UNIT_GATE" = off ]; then echo "gate: no"
elif [ "$UNIT_GATE" = always ] || [ "$reasons" -eq 1 ]; then echo "gate: yes"
else echo "gate: no"; fi
