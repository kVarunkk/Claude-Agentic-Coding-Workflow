#!/usr/bin/env bash
# branch.sh <plan-dir>
# Puts the work on feature/<feature>. Run from the repo root.
#   on feature/<feature>             -> "branch: feature/<feature>", exit 0
#   on the default branch            -> checks out feature/<feature> (creates it if new), exit 0
#   on another branch or detached    -> message on stderr, exit 3 (ask the user)
#   not a git repo                   -> exit 1
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: branch.sh <plan-dir>}"
plan="${plan%/}"
want="feature/$(basename "$plan")"
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }
cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || { echo "no commit yet; commit something first" >&2; exit 1; }
if [ "$cur" = "$want" ]; then echo "branch: $want"; exit 0; fi
def=$(default_branch) || def=""
if [ -n "$def" ] && [ "$cur" = "$def" ]; then
  if git show-ref --verify --quiet "refs/heads/$want"; then
    git checkout -q "$want" || exit 1
  else
    git checkout -q -b "$want" || exit 1
  fi
  echo "branch: $want (from $cur)"
  exit 0
fi
if [ "$cur" = HEAD ]; then echo "detached HEAD; check out a branch first" >&2; exit 3; fi
echo "on branch $cur, which is neither $want nor the default branch${def:+ ($def)}" >&2
exit 3
