#!/usr/bin/env bash
# approve.sh <plan-dir> <name>
# Records a user approval as <plan-dir>/approvals/<name> holding a UTC timestamp.
# Names: brief, spec, tasks, phase-<N> (N = numeric phase), afk, final. Run only after the user approved.
# brief also sets "status: agreed" in the brief's front matter, so the brief is never committed as draft.
# spec likewise sets the spec's status to Approved (front matter and badge).
set -u
usage="usage: approve.sh <plan-dir> brief|spec|tasks|phase-<N>|afk|final"
plan="${1:?$usage}"
name="${2:?$usage}"
case "$name" in
  brief|spec|tasks|afk|final) ;;
  phase-[0-9]|phase-[0-9][0-9]|phase-[0-9][0-9][0-9]) ;;
  *) echo "bad approval name: $name (want brief, spec, tasks, phase-<N>, afk or final)" >&2; exit 1 ;;
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
mkdir -p "$plan/approvals"
date -u +%Y-%m-%dT%H:%M:%SZ > "$plan/approvals/$name"
echo "approved: $plan/approvals/$name"
