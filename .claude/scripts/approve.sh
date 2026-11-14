#!/usr/bin/env bash
# approve.sh <plan-dir> <name>
# Records a user approval as <plan-dir>/approvals/<name> holding a UTC timestamp.
# Names: brief, spec, tasks, phase-<N> (N = numeric phase). Run only after the user approved.
set -u
plan="${1:?usage: approve.sh <plan-dir> brief|spec|tasks|phase-<N>}"
name="${2:?usage: approve.sh <plan-dir> brief|spec|tasks|phase-<N>}"
case "$name" in
  brief|spec|tasks) ;;
  phase-[0-9]|phase-[0-9][0-9]|phase-[0-9][0-9][0-9]) ;;
  *) echo "bad approval name: $name (want brief, spec, tasks or phase-<N>)" >&2; exit 1 ;;
esac
[ -d "$plan" ] || { echo "no such plan dir: $plan" >&2; exit 1; }
mkdir -p "$plan/approvals"
date -u +%Y-%m-%dT%H:%M:%SZ > "$plan/approvals/$name"
echo "approved: $plan/approvals/$name"
