#!/usr/bin/env bash
# scan-staged.sh [--file <path>]
# Scans the staged diff (added lines and added files) for secrets and junk before a commit.
# With --file, scans one file instead (for a PR body). A line containing "scan:allow" is skipped.
#   HIGH:   private keys, cloud and API tokens, .env / key files      -> exit 1 (never commit)
#   MEDIUM: password/secret/token assignments, binary or large files  -> exit 3 (ask the user)
#   clean                                                             -> exit 0
# Findings name the file, line and kind, never the secret itself.
# Added lines are collected once and each pattern is one grep over all of them (a grep per line
# was ~0.6 s per line on Git Bash for Windows).
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_conf
export LC_ALL=C
high=0; med=0
say() { echo "$1 $2: $3"; [ "$1" = HIGH ] && high=1 || med=1; }

HIGH_RE=(
  'AKIA[0-9A-Z]{16}|AWS access key'
  '-----BEGIN [A-Z ]*PRIVATE KEY-----|private key'
  'gh[pousr]_[A-Za-z0-9]{36}|GitHub token'
  'github_pat_[A-Za-z0-9_]{22,}|GitHub token'
  'sk-ant-[A-Za-z0-9_-]{20,}|Anthropic API key'
  'sk-(proj-)?[A-Za-z0-9]{32,}|OpenAI-style API key'
  'xox[abprs]-[A-Za-z0-9-]{10,}|Slack token'
  'AIza[0-9A-Za-z_-]{35}|Google API key'
)
MED_RE='(api[_-]?key|secret|token|passw(or)?d)["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]]{12,}["'"'"']'

work=$(mktemp -d) || exit 1
trap 'rm -rf "$work"' EXIT
tx="$work/text"; lc="$work/loc"   # line k of tx is the text found at location line k of lc
: > "$tx"; : > "$lc"

# Locations (file:line) of the collected lines matching an ERE. $2: extra grep flags.
hits() {
  local idx
  idx=$(grep -a -n $2 -E -- "$1" "$tx" | cut -d: -f1)
  [ -n "$idx" ] || return 0
  printf '%s\n' "$idx" | awk 'NR == FNR { w[$1]; next } FNR in w' - "$lc"
}

if [ "${1:-}" = "--file" ]; then
  f="${2:?usage: scan-staged.sh --file <path>}"
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
  tr -d '\r' < "$f" | awk -v tx="$tx" -v lc="$lc" -v F="$f" \
    'index($0, "scan:allow") == 0 { print > tx; print F ":" NR > lc }'
else
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }
  # Added files: names and sizes.
  while IFS=$'\t' read -r add del path; do
    [ -n "$path" ] || continue
    git cat-file -e ":$path" 2>/dev/null || continue
    base=${path##*/}
    case "$base" in
      .env.example|.env.sample|.env.template) ;;
      .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*) say HIGH "$path" "secret-bearing file type" ;;
    esac
    [ "$add" = "-" ] && say MEDIUM "$path" "binary file"
    size=$(git cat-file -s ":$path" 2>/dev/null || echo 0)
    [ "$size" -gt $((MAX_FILE_KB * 1024)) ] && say MEDIUM "$path" "large file ($((size / 1024)) KB > $MAX_FILE_KB KB)"
  done < <(git -c core.quotePath=false diff --cached --numstat --no-renames)
  # Added lines.
  git -c core.quotePath=false diff --cached -U0 --no-color --no-renames | tr -d '\r' |
    awk -v tx="$tx" -v lc="$lc" '
      /^\+\+\+ b\// { file = substr($0, 7); next }
      /^\+\+\+ /    { file = ""; next }
      /^@@ /        { s = $0; sub(/^@@ -[0-9,]+ \+/, "", s); sub(/[^0-9].*$/, "", s); n = s - 1; next }
      /^\+/         { n++; if (file != "" && index($0, "scan:allow") == 0) { print substr($0, 2) > tx; print file ":" n > lc } }'
fi

for r in "${HIGH_RE[@]}"; do
  re="${r%|*}"; kind="${r##*|}"
  while IFS= read -r at; do [ -n "$at" ] && say HIGH "$at" "looks like a $kind"; done < <(hits "$re" "")
done
while IFS= read -r at; do [ -n "$at" ] && say MEDIUM "$at" "hard-coded secret-like assignment"; done < <(hits "$MED_RE" "-i")

[ $high -eq 1 ] && exit 1
[ $med -eq 1 ] && exit 3
echo "scan: clean"
exit 0
