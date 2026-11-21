#!/usr/bin/env bash
# status.sh <plan-dir>
# Prints where /build-feature should resume:
#   brief: missing|written|approved
#   spec: missing|written|approved
#   tasks: missing|written|approved
#   afk: on|off                approvals/afk exists (user chose AFK at the tasks gate)
#   gate: <N>|none             first phase whose tasks are all done but whose phase end is not finished:
#                              approvals/phase-<N> missing, or the tag <feature>-phase-<N> missing in AFK mode
#                              and for the last phase (it has no gate of its own: the final gate covers it)
#   uncommitted: <unit>|none   the unit open at HEAD is fully ticked in the working tree (built, not committed)
#   dirty: <unit>|none         the unit open at HEAD is not fully ticked, but files changed since HEAD outside
#                              reports/, approvals/ and decisions.tsv (an earlier run stopped mid-unit)
#   next: <next-unit.sh line>|none
#   final: approved|open
#   import: none|spec|tasks|done  the brief has "source: imported" (import-plan.sh): the reformat still due.
#                              spec: no reports/spec/import-diff*.md yet; tasks: spec approved and no
#                              reports/tasks/import-diff*.md yet; done: no reformat due now. none: not an imported plan.
# Exit 1 when the tasks file exists but does not parse.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
plan="${1:?usage: status.sh <plan-dir>}"
plan="${plan%/}"
feature=$(basename "$plan")
state() { # glob approval
  if ! ls "$plan"/$1 >/dev/null 2>&1; then echo missing
  elif [ -f "$plan/approvals/$2" ]; then echo approved
  else echo written; fi
}
b=$(state 'feature-*-brief.md' brief)
s=$(state 'feature-*-spec.md' spec)
t=$(state 'feature-*-tasks.md' tasks)
afk=off; [ -f "$plan/approvals/afk" ] && afk=on
final=open; [ -f "$plan/approvals/final" ] && final=approved
echo "brief: $b"
echo "spec: $s"
echo "tasks: $t"
echo "afk: $afk"
imp=none
brief_f=$(ls "$plan"/feature-*-brief.md 2>/dev/null | head -1)
# "source: imported" in the brief's front matter (import-plan.sh).
if [ -n "$brief_f" ] && tr -d '\r' < "$brief_f" |
    awk 'NR == 1 { if (!/^---/) exit; next } /^---/ { exit } /^source:[ \t]*imported[ \t]*$/ { f = 1 } END { exit !f }'; then
  if ! ls "$plan"/reports/spec/import-diff*.md >/dev/null 2>&1; then imp=spec
  elif [ "$s" = approved ] && ! ls "$plan"/reports/tasks/import-diff*.md >/dev/null 2>&1; then imp=tasks
  else imp=done
  fi
fi
gate=none; next=none; unc=none; dirty=none
# An imported tasks file is in the user's own shape until its reformat ran (import-diff written): do not parse it.
tasks_ready=1
[ "$imp" = none ] || ls "$plan"/reports/tasks/import-diff*.md >/dev/null 2>&1 || tasks_ready=0
if [ "$t" != missing ] && [ "$tasks_ready" = 1 ]; then
  tasks=$(tasks_file "$plan") || exit 1
  parsed=$(parse_tasks "$tasks") || exit 1
  # One line per phase in file order: "<phase> <1 if all its tasks are done, else 0>".
  phases=$(printf '%s\n' "$parsed" | awk -F'\t' '
    $1 == "unit" { if (!($3 in seen)) { seen[$3] = 1; order[++n] = $3 } }
    $1 == "task" { ph = $2; sub(/[a-z]$/, "", ph); if ($4 == "open") popen[ph] = 1 }
    END { for (i = 1; i <= n; i++) print order[i], ((order[i] in popen) ? 0 : 1) }')
  lastp=$(printf '%s\n' "$phases" | tail -1 | cut -d' ' -f1)
  while read -r p complete; do
    [ "$complete" = 1 ] || break
    if [ "$afk" = on ] || [ "$p" = "$lastp" ]; then
      git -C "$plan" rev-parse -q --verify "refs/tags/$feature-phase-$p" >/dev/null 2>&1 && continue
    else
      [ -f "$plan/approvals/phase-$p" ] && continue
    fi
    gate=$p; break
  done <<< "$phases"
  next=$(bash "$PIPELINE_SCRIPTS/next-unit.sh" "$plan") || exit 1
  [ -n "$next" ] || next=none
  if committed=$(next_unit_at "$plan" HEAD 2>/dev/null) && [ -n "$committed" ]; then
    cu="${committed%%:*}"
    open_in_cu=$(printf '%s\n' "$parsed" | awk -F'\t' -v u="$cu" '$1 == "task" && $2 == u && $4 == "open"' | wc -l)
    if [ "$open_in_cu" -eq 0 ]; then
      unc="$cu"
    else
      # Half-built: the unit is not fully ticked, but the tree holds uncommitted work (an earlier run stopped
      # mid-unit). Reports, approvals and decisions.tsv are pipeline bookkeeping, not unit work.
      prefix=$(git -C "$plan" rev-parse --show-prefix 2>/dev/null); prefix="${prefix%/}"
      work=$(git -C "$plan" -c core.quotePath=false status --porcelain=v1 -uall 2>/dev/null | cut -c4- |
        grep -vE "^$prefix/(reports/|approvals/|decisions\.tsv$)")
      [ -n "$work" ] && dirty="$cu"
    fi
  fi
fi
echo "gate: $gate"
echo "uncommitted: $unc"
echo "dirty: $dirty"
echo "next: $next"
echo "final: $final"
echo "import: $imp"
