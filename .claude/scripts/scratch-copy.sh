#!/usr/bin/env bash
# scratch-copy.sh <dest> [--base <rev>]
# Makes a throwaway copy of the repo for probes and mutation checks, so the real tree is never edited.
# Default: the working tree as it is now (tracked and untracked files, not ignored ones).
# --base <rev>: the tree at <rev> instead (e.g. BASE, to show a new test fails without the change).
# node_modules is linked in when present. <dest> must not exist. Remove it with rm -rf when done.
# <dest> must be outside the repo and not directly under / (an unset TMPDIR turns "$TMPDIR/mut-1a" into
# "/mut-1a"): use "${TMPDIR:-/tmp}/mut-<unit>".
set -u
dest="${1:?usage: scratch-copy.sh <dest> [--base <rev>]}"
[ -e "$dest" ] && { echo "$dest exists" >&2; exit 1; }
root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "not a git repo" >&2; exit 1; }
parent=$(cd "$(dirname "$dest")" 2>/dev/null && pwd -P) || { echo "parent of $dest does not exist" >&2; exit 1; }
[ "$parent" = "/" ] && { echo "refusing $dest: directly under / (TMPDIR unset? use \"\${TMPDIR:-/tmp}/mut-<unit>\")" >&2; exit 1; }
rootp=$(cd "$root" && pwd -P)
case "$parent/" in "$rootp"/*) echo "refusing $dest: inside the repo; scratch copies go under \${TMPDIR:-/tmp}" >&2; exit 1 ;; esac
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
