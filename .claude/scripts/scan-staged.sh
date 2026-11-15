#!/usr/bin/env bash
# scan-staged.sh [--file <path>]
# Scans the staged diff (added lines and added files) for secrets and junk before a commit.
# With --file, scans one file instead (for a PR body). A line containing "scan:allow" is skipped.
#   HIGH:   private keys, cloud and API tokens, .env / key files      -> exit 1 (never commit)
#   MEDIUM: password/secret/token assignments, binary or large files  -> exit 3 (ask the user)
#   clean                                                             -> exit 0
# Findings name the file, line and kind, never the secret itself.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_conf
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

scan_line() { # where text
  local r re kind
  case "$2" in *scan:allow*) return ;; esac
  for r in "${HIGH_RE[@]}"; do
    re="${r%|*}"; kind="${r##*|}"
    printf '%s' "$2" | grep -qE -- "$re" && say HIGH "$1" "looks like a $kind"
  done
  printf '%s' "$2" | grep -qiE -- "$MED_RE" && say MEDIUM "$1" "hard-coded secret-like assignment"
}

if [ "${1:-}" = "--file" ]; then
  f="${2:?usage: scan-staged.sh --file <path>}"
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
  n=0
  while IFS= read -r line || [ -n "$line" ]; do n=$((n + 1)); scan_line "$f:$n" "$line"; done < <(tr -d '\r' < "$f")
else
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo" >&2; exit 1; }
  # Added files: names and sizes.
  while IFS=$'\t' read -r add del path; do
    [ -n "$path" ] || continue
    git cat-file -e ":$path" 2>/dev/null || continue
    base=$(basename "$path")
    case "$base" in
      .env.example|.env.sample|.env.template) ;;
      .env|.env.*|*.pem|*.key|*.p12|*.pfx|id_rsa*|id_ed25519*) say HIGH "$path" "secret-bearing file type" ;;
    esac
    [ "$add" = "-" ] && say MEDIUM "$path" "binary file"
    size=$(git cat-file -s ":$path" 2>/dev/null || echo 0)
    [ "$size" -gt $((MAX_FILE_KB * 1024)) ] && say MEDIUM "$path" "large file ($((size / 1024)) KB > $MAX_FILE_KB KB)"
  done < <(git -c core.quotePath=false diff --cached --numstat --no-renames)
  # Added lines.
  file=""; n=0
  while IFS= read -r line; do
    case "$line" in
      "+++ b/"*) file="${line#+++ b/}" ;;
      "+++ "*) file="" ;;
      "@@ "*) n=$(printf '%s' "$line" | sed -E 's/^@@ -[0-9,]+ \+([0-9]+).*/\1/'); n=$((n - 1)) ;;
      "+"*) n=$((n + 1)); [ -n "$file" ] && scan_line "$file:$n" "${line#+}" ;;
    esac
  done < <(git -c core.quotePath=false diff --cached -U0 --no-color --no-renames | tr -d '\r')
fi
[ $high -eq 1 ] && exit 1
[ $med -eq 1 ] && exit 3
echo "scan: clean"
exit 0
