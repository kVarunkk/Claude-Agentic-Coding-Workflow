#!/usr/bin/env bash
# import-plan.sh <plan-dir> <spec-file> <tasks-file>
# import-plan.sh --diff <plan-dir> spec|tasks
# Brings the user's own spec and tasks file into a build-feature run (/build-feature <feature> --from ...).
#
# Import: copies <spec-file> to <plan-dir>/feature-<feature>-spec.md and <tasks-file> to
#   <plan-dir>/feature-<feature>-tasks.md as they are (CR stripped), and writes a draft brief with
#   "source: imported" that makes those files the agreement. The source files are not touched. Refuses when the
#   plan dir already has a brief, spec or tasks file (an import never overwrites a plan). After the user agrees,
#   build-feature approves the brief, commits, and tags <feature>-imported: the user's text as it came in.
#   The spec-writer and task-writer then reformat the files in place, so git can show what they changed.
#
# --diff: writes reports/<stage>/import-diff.md (report-path.sh numbering) with what the reformat changed in the
#   spec or tasks file, from the tag <feature>-imported to HEAD (commit the writer's round first). Prints the
#   path, then the diffstat. status.sh reads the file's existence as "this reformat is done".
set -u
S="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
usage="usage: import-plan.sh <plan-dir> <spec-file> <tasks-file> | import-plan.sh --diff <plan-dir> spec|tasks"

if [ "${1:-}" = --diff ]; then
  plan="${2:?$usage}"; what="${3:?$usage}"; plan="${plan%/}"
  case "$what" in spec|tasks) ;; *) echo "$usage" >&2; exit 1 ;; esac
  feature=$(basename "$plan")
  file="$plan/feature-$feature-$what.md"
  [ -f "$file" ] || { echo "no $file" >&2; exit 1; }
  tag="$feature-imported"
  git rev-parse -q --verify "refs/tags/$tag" >/dev/null 2>&1 || { echo "no tag $tag: the import was not committed and tagged" >&2; exit 1; }
  if ! git diff --quiet -- "$file" 2>/dev/null || ! git diff --cached --quiet -- "$file" 2>/dev/null; then
    echo "$file has uncommitted changes: commit the writer's round first" >&2; exit 1
  fi
  out=$(bash "$S/report-path.sh" "$plan" "$what/import-diff") || exit 1
  stat=$(git diff --stat "$tag" HEAD -- "$file")
  {
    echo "# Import diff: $what"
    echo
    echo "What the reformat changed in \`$file\`, from the user's text (tag \`$tag\`) to HEAD."
    echo "Lines starting with - are the user's; lines starting with + are the writer's."
    echo
    if [ -z "$stat" ]; then
      echo "No changes: the imported file was already in the pipeline format."
    else
      echo '```'
      echo "$stat"
      echo '```'
      echo
      echo '```diff'
      git diff "$tag" HEAD -- "$file"
      echo '```'
    fi
  } > "$out"
  echo "$out"
  [ -n "$stat" ] && echo "$stat" || echo "no changes"
  exit 0
fi

plan="${1:?$usage}"; src_spec="${2:?$usage}"; src_tasks="${3:?$usage}"; plan="${plan%/}"
feature=$(basename "$plan")
printf '%s' "$plan" | grep -qE '(^|/)plans/[a-z0-9][a-z0-9-]*$' || { echo "plan dir must be plans/<feature> in kebab-case, got $plan" >&2; exit 1; }
for f in "$src_spec" "$src_tasks"; do
  [ -f "$f" ] || { echo "no such file: $f" >&2; exit 1; }
  [ -s "$f" ] || { echo "empty file: $f" >&2; exit 1; }
done
[ "$(cd "$(dirname "$src_spec")" && pwd)/$(basename "$src_spec")" != "$(cd "$(dirname "$src_tasks")" && pwd)/$(basename "$src_tasks")" ] ||
  { echo "the spec and the tasks file are the same file" >&2; exit 1; }
if ls "$plan"/feature-*-brief.md "$plan"/feature-*-spec.md "$plan"/feature-*-tasks.md >/dev/null 2>&1; then
  echo "$plan already has a brief, spec or tasks file; an import never overwrites a plan. Pick a new feature name, or move that plan away." >&2
  exit 1
fi
mkdir -p "$plan"
spec="$plan/feature-$feature-spec.md"; tasks="$plan/feature-$feature-tasks.md"; brief="$plan/feature-$feature-brief.md"
tr -d '\r' < "$src_spec" > "$spec"
tr -d '\r' < "$src_tasks" > "$tasks"
today=$(date -u +%Y-%m-%d)
cat > "$brief" <<EOF
---
feature: $feature
date: $today
status: draft
source: imported
imported_spec: $src_spec
imported_tasks: $src_tasks
---

# Brief: $feature

## Goal

Build what the user's own spec describes (see its overview). The user wrote the spec and the tasks file
before the run; this brief records that they are the agreement, in place of an interview.

## Decisions

| Id | Question | Decision | Why | By |
|---|---|---|---|---|
| D-01 | What gets built? | Exactly what the imported spec says: its requirements, examples, numbers and names are binding. | The user wrote it. | user |
| D-02 | How is the imported text changed? | Only reformatted to the pipeline format (ids, sections, the tasks grammar). Nothing is added or dropped; a gap the format exposes becomes an open question for the user. | The user reviews the reformat as a diff. | user |
| D-03 | How is the work split? | The imported tasks file's phases, order and wording, split only where a unit is over MAX_UNIT_TASKS. | The user planned it. | user |

## Left to the spec

- Nothing beyond the reformat. Every open question goes to the user at the spec gate.
EOF
echo "imported: $spec"
echo "imported: $tasks"
echo "brief: $brief (draft, source: imported)"
