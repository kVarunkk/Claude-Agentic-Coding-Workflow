#!/usr/bin/env bash
# scratch-copy.sh <dest> [--base <rev>]
# Makes a throwaway copy of the repo for probes and mutation checks, so the real tree is never edited.
# Default: the working tree as it is now (tracked and untracked files, not ignored ones).
# --base <rev>: the tree at <rev> instead (e.g. BASE, to show a new test fails without the change).
# node_modules is linked in when present. <dest> must not exist. Remove it with rm -rf when done.
set -u
dest="${1:?usage: scratch-copy.sh <dest> [--base <rev>]}"
[ -e "$dest" ] && { echo "$dest exists" >&2; exit 1; }
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo" >&2; exit 1; }
mkdir -p "$dest" || exit 1
if [ "${2:-}" = "--base" ]; then
  rev="${3:?--base needs a revision}"
  git -C "$root" archive --format=tar "$rev" | tar -xf - -C "$dest" || exit 1
else
  ( cd "$root" && git ls-files -co --exclude-standard -z |
      while IFS= read -r -d '' p; do [ -e "$p" ] && printf '%s\0' "$p"; done |
      tar --null -T - -cf - ) | tar -xf - -C "$dest" || exit 1
fi
[ -d "$root/node_modules" ] && [ ! -e "$dest/node_modules" ] && ln -s "$root/node_modules" "$dest/node_modules" 2>/dev/null
printf '%s\n' "$dest"
