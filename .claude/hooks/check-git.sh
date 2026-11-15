#!/usr/bin/env bash
# PreToolUse hook, matcher "Bash". Blocks history-rewriting git commands (exit 2, reason on stderr):
#   git push with --force / --force-with-lease / -f / +refspec, git push --delete or :ref,
#   git commit --amend, git tag -f / --force / -d / --delete.
# If one is really needed, the user runs it with "! <command>". Without jq it allows everything.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../scripts/lib.sh"
input=$(cat)
find_jq 2>/dev/null || exit 0
cmd=$(printf '%s' "$input" | "$JQ" -r '.tool_input.command // empty' | tr -d '\r')
[ -n "$cmd" ] || exit 0

# One git invocation per segment; the subcommand is the first word after "git" and its global options.
reason=$(printf '%s\n' "$cmd" | tr ';&|\n' '\n\n\n\n' | awk '
  {
    n = split($0, t, /[ \t]+/); g = 0
    for (i = 1; i <= n; i++) if (t[i] == "git" || t[i] ~ /\/git(\.exe)?$/) { g = i; break }
    if (!g) next
    i = g + 1
    while (i <= n && t[i] ~ /^-/) { if (t[i] == "-C" || t[i] == "-c") i++; i++ }
    sub_ = t[i]; flags = ""
    for (j = i + 1; j <= n; j++) flags = flags " " t[j]
    flags = flags " "
    if (sub_ == "push") {
      if (flags ~ / --force(-with-lease)?[= ]/ || flags ~ / -[A-Za-z]*f[A-Za-z]* / || flags ~ / \+[^ ]/) { print "force push rewrites shared history"; exit }
      if (flags ~ / --delete / || flags ~ / -d / || flags ~ / :[^ ]/) { print "deleting a remote ref"; exit }
    }
    if (sub_ == "commit" && flags ~ / --amend /) { print "--amend rewrites a commit; make a new commit instead"; exit }
    if (sub_ == "tag" && (flags ~ / -[A-Za-z]*[fd][A-Za-z]* / || flags ~ / --(force|delete) /)) { print "tags are never moved or deleted; use a new suffix (-2)"; exit }
  }')
[ -z "$reason" ] && exit 0
echo "Blocked git command: $reason. If the user wants it anyway, they run it themselves with \"! <command>\"." >&2
exit 2
