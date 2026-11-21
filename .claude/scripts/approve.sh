#!/usr/bin/env bash
# approve.sh <plan-dir> <name>
# Records a user approval as <plan-dir>/approvals/<name> holding a UTC timestamp.
# Names: brief, spec, tasks, phase-<N> (N = numeric phase), afk, final, retry, commit-<unit>, loop-<unit>,
# loop-spec, loop-tasks. Run only after the user approved.
# loop-<unit|spec|tasks> is the user's "one more fix round" past MAX_LOOPS (Give guidance at the unit gate, one
# more round at the spec or tasks gate); check-spawn.sh uses it up on that round (R63).
# commit-<unit> is the user's "Commit anyway" for a unit whose review still fails after MAX_LOOPS rounds:
# check-git.sh then lets that unit's code be committed.
# retry lets check-spawn.sh allow one more spawn of an agent that already stopped early twice with the same
# prompt; the hook removes the marker when it uses it.
# brief also sets "status: agreed" in the brief's front matter, so the brief is never committed as draft.
# spec likewise sets the spec's status to Approved (front matter and badge).
# final sets the tasks file status to Done (front matter and badge).
set -u
usage="usage: approve.sh <plan-dir> brief|spec|tasks|phase-<N>|afk|final|retry|commit-<unit>|loop-<unit|spec|tasks>"
plan="${1:?$usage}"
name="${2:?$usage}"
case "$name" in
  brief|spec|tasks|afk|final|retry) ;;
  phase-[0-9]|phase-[0-9][0-9]|phase-[0-9][0-9][0-9]) ;;
  commit-[0-9]|commit-[0-9][a-z]|commit-[0-9][0-9]|commit-[0-9][0-9][a-z]) ;;
  loop-spec|loop-tasks|loop-[0-9]|loop-[0-9][a-z]|loop-[0-9][0-9]|loop-[0-9][0-9][a-z]) ;;
  *) echo "bad approval name: $name (want brief, spec, tasks, phase-<N>, afk, final, retry, commit-<unit> or loop-<unit|spec|tasks>)" >&2; exit 1 ;;
esac
[ -d "$plan" ] || { echo "no such plan dir: $plan" >&2; exit 1; }
if [ "$name" = brief ]; then
  brief=$(ls "$plan"/feature-*-brief.md 2>/dev/null | head -1)
  [ -n "$brief" ] || { echo "no feature-*-brief.md in $plan" >&2; exit 1; }
  tmp=$(mktemp)
  tr -d '\r' < "$brief" | awk '
    NR == 1 && /^---[ \t]*$/ { fm = 1; print; next }
    fm && /^---[ \t]*$/ { fm = 0; if (!done) print "status: agreed"; print; next }
    fm && /^status:/ { print "status: agreed"; done = 1; next }
    { print }' > "$tmp" && mv "$tmp" "$brief"
fi
if [ "$name" = spec ]; then
  spec=$(ls "$plan"/feature-*-spec.md 2>/dev/null | head -1)
  if [ -n "$spec" ]; then
    tmp=$(mktemp)
    tr -d '\r' < "$spec" | awk '
      NR == 1 && /^---[ \t]*$/ { fm = 1; print; next }
      fm && /^---[ \t]*$/ { fm = 0; print; next }
      fm && !done && /^status:/ { print "status: '"'"'Approved'"'"'"; done = 1; next }
      /^!\[Status: Draft\]/ { sub(/Draft/, "Approved"); sub(/lightgrey/, "green"); sub(/status-Draft/, "status-Approved") }
      { print }' > "$tmp" && mv "$tmp" "$spec"
  fi
fi
if [ "$name" = final ]; then
  tf=$(ls "$plan"/feature-*-tasks.md 2>/dev/null | head -1)
  if [ -n "$tf" ]; then
    tmp=$(mktemp)
    tr -d '\r' < "$tf" | awk '
      NR == 1 && /^---[ 	]*$/ { fm = 1; print; next }
      fm && /^---[ 	]*$/ { fm = 0; print; next }
      fm && !done && /^status:/ { print "status: '"'"'Done'"'"'"; done = 1; next }
      /^!\[Status: [A-Za-z]+\]/ { sub(/Status: [A-Za-z]+/, "Status: Done"); sub(/status-[A-Za-z]+-[a-z]+/, "status-Done-green") }
      { print }' > "$tmp" && mv "$tmp" "$tf"
  fi
fi
mkdir -p "$plan/approvals"
date -u +%Y-%m-%dT%H:%M:%SZ > "$plan/approvals/$name"
echo "approved: $plan/approvals/$name"
