#!/usr/bin/env bash
# stage-unit.sh <plan-dir> <unit-id>
# Stages exactly what the unit owns, instead of "git add -A". Run from the repo root.
# Owned: the files in the unit's Files column (an entry ending in "/" owns that folder), anything
# under <plan-dir>, and any path named under "## Differences from the spec" in the tasks file.
# Never owned: a dotfile, dot-folder or ".part" name under <plan-dir> (scratch an agent left in reports/).
# If another file changed, it lists those files, stages nothing and exits 1.
# Exit 1 also when nothing changed at all.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: stage-unit.sh <plan-dir> <unit-id>}"
unit="${2:?usage: stage-unit.sh <plan-dir> <unit-id>}"
plan="${plan%/}"
[ -z "$(git rev-parse --show-prefix 2>/dev/null)" ] && git rev-parse --git-dir >/dev/null 2>&1 ||
  { echo "run from the repo root" >&2; exit 1; }
tasks=$(tasks_file "$plan") || exit 1
parsed=$(parse_tasks "$tasks") || exit 1
printf '%s\n' "$parsed" | awk -F'\t' -v u="$unit" '$1 == "unit" && $2 == u { f = 1 } END { exit !f }' ||
  { echo "unknown unit: $unit" >&2; exit 1; }

owned=$(printf '%s\n' "$parsed" | awk -F'\t' -v u="$unit" '$1 == "task" && $2 == u { print $6 }' |
  tr ',' '\n' | tr -d '`\r' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s#^\./##' |
  grep -vix 'none' | grep -v '^$' | sort -u)
diffs=$(tr -d '\r' < "$tasks" | awk '/^## Differences from the spec/ { on = 1; next } on && /^## / { on = 0 } on')

is_owned() {
  local p="$1" o
  # Under the plan dir, scratch files (dotfiles, *.part*) are not owned: agents leave them in reports/.
  case "$p" in "$plan"/*) case "/${p#"$plan"/}" in */.*|*.part*) return 1 ;; esac; return 0 ;; esac
  while IFS= read -r o; do
    [ -n "$o" ] || continue
    [ "$p" = "$o" ] && return 0
    case "$o" in */) case "$p" in "$o"*) return 0 ;; esac ;; esac
  done <<< "$owned"
  [ -n "$diffs" ] && printf '%s\n' "$diffs" | grep -qF -- "$p" && return 0
  return 1
}

stage=(); stray=()
while IFS= read -r -d '' entry; do
  xy="${entry:0:2}"; p="${entry:3}"
  paths=("$p")
  case "$xy" in R*|C*) IFS= read -r -d '' old; paths+=("$old") ;; esac
  for q in "${paths[@]}"; do
    if is_owned "$q"; then stage+=("$q"); else stray+=("$q"); fi
  done
done < <(git -c core.quotePath=false status --porcelain=v1 -z -uall)

if [ ${#stray[@]} -gt 0 ]; then
  echo "unit $unit: changed files outside its Files column and not logged under Differences:"
  printf '  %s\n' "${stray[@]}"
  echo "nothing staged"
  exit 1
fi
[ ${#stage[@]} -gt 0 ] || { echo "unit $unit: nothing changed"; exit 1; }
GIT_LITERAL_PATHSPECS=1 git add -A -- "${stage[@]}" || exit 1
echo "staged ${#stage[@]} path(s) for unit $unit"
