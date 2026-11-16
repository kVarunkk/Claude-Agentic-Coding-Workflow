#!/usr/bin/env bash
# Mechanical checks for a plans/<feature>/ folder:
#   1. every id is declared once (spec bullets, task/goal rows)
#   2. every REQ and SEC id in the spec is referenced by the tasks file (ranges like REQ-011 – REQ-016 count);
#      an id declared as "(removed in v0.2: ...)" is exempt
#   3. every id referenced on its own is declared somewhere (ranges are skipped: "REQ-010 to REQ-019"
#      as a group label over REQ-010..REQ-012 is fine)
#   4. no template placeholders or TODO/TBD left
#   5. tasks grammar: "## Phase <id>: <title>" units, optional "depends:", one table with
#      ID | Task | Spec | Files | Status | Done, status [ ] or [x], ISO date on done rows,
#      Files filled, at most MAX_UNIT_TASKS tasks per unit, depends targets exist,
#      every unit has a task whose Files is not "none" (no verify-only units)
# Usage: check-plan.sh plans/<feature>     Exit 1 on failures (1, 2, 5), 0 otherwise.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
load_conf
dir="${1:?usage: check-plan.sh plans/<feature>}"
spec=$(ls "$dir"/feature-*-spec.md 2>/dev/null | head -1)
tasks=$(ls "$dir"/feature-*-tasks.md 2>/dev/null | head -1)
[ -n "$spec" ] || { echo "FAIL: no feature-*-spec.md in $dir"; exit 1; }
[ -n "$tasks" ] || { echo "FAIL: no feature-*-tasks.md in $dir"; exit 1; }

P='REQ|SEC|CON|GUD|PAT|ALT|DEP|TEST|RISK|ASSUMPTION|Q'
ALL="$P|TASK|GOAL"
fail=0; warn=0

# Ids referenced in a file, with ranges (A-011 – A-016, A-011 - A-016, A-011 to A-016) expanded.
refs() {
  grep -oE "\b($ALL)-[0-9]+\b" "$1"
  grep -oE "\b($ALL)-[0-9]+ *(–|—|-|to) *($ALL)-[0-9]+\b" "$1" | awk '{
    n = split($0, a, /[^A-Z0-9]+/)
    if (n < 4 || a[1] != a[n-1]) next
    w = length(a[2]); lo = a[2] + 0; hi = a[n] + 0
    if (hi < lo || hi - lo > 200) next
    for (i = lo; i <= hi; i++) printf "%s-%0" w "d\n", a[1], i
  }'
}

# Ids referenced on their own in a file: ranges are removed first, ends included.
refs_plain() {
  sed -E "s/\b($ALL)-[0-9]+ *(–|—|-|to) *($ALL)-[0-9]+\b//g" "$1" | grep -oE "\b($ALL)-[0-9]+\b"
}

spec_decl=$(grep -oE "^[[:space:]]*- \*\*($P)-[0-9]+" "$spec" | grep -oE "($P)-[0-9]+")
task_decl=$( { grep -oE "^\| *(TASK|GOAL)-[0-9]+ *\|" "$tasks"; grep -oE "^[[:space:]]*- \*\*GOAL-[0-9]+" "$tasks"; } | grep -oE "(TASK|GOAL)-[0-9]+")

dups=$(printf '%s\n%s\n' "$spec_decl" "$task_decl" | grep -v '^$' | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "FAIL: ids declared more than once:"; echo "$dups" | sed 's/^/  /'; fail=1
fi

task_refs=$(refs "$tasks" | sort -u)
# Ids kept as "(removed in vX: ...)" stubs are declared but need no task.
removed=$(grep -E "^[[:space:]]*- \*\*($P)-[0-9]+\*\*:? *\(removed" "$spec" | grep -oE "($P)-[0-9]+" | sort -u)
missing=$(echo "$spec_decl" | grep -E "^(REQ|SEC)-" | sort -u | comm -23 - <(echo "$task_refs") | comm -23 - <(echo "$removed"))
if [ -n "$missing" ]; then
  echo "FAIL: REQ/SEC ids with no task:"; echo "$missing" | sed 's/^/  /'; fail=1
fi

declared=$(printf '%s\n%s\n' "$spec_decl" "$task_decl" | grep -v '^$' | sort -u)
undeclared=$( { refs_plain "$spec"; refs_plain "$tasks"; } | sort -u | comm -23 - <(echo "$declared"))
if [ -n "$undeclared" ]; then
  echo "WARN: ids referenced but never declared:"; echo "$undeclared" | sed 's/^/  /'; warn=1
fi

ph=$(grep -nE "TBD|TODO|<YYYY-MM-DD>|<feature>|<one sentence|<area>|<repo or team>" "$spec" "$tasks")
if [ -n "$ph" ]; then
  echo "WARN: placeholders or TODO/TBD left:"; echo "$ph" | sed 's/^/  /'; warn=1
fi

# 5. Tasks grammar.
if ! parsed=$(parse_tasks "$tasks" 2>&1); then
  echo "FAIL: tasks grammar:"; echo "$parsed" | sed 's/^/  /'; fail=1
else
  gram=$(printf '%s\n' "$parsed" | awk -F'\t' -v max="$MAX_UNIT_TASKS" '
    $1 == "unit" { u[$2] = 1; ph[$3] = 1; dep[$2] = $4; order[++n] = $2 }
    $1 == "task" {
      cnt[$2]++
      f = $6; gsub(/[` \t]/, "", f)
      if (tolower(f) != "none") code[$2] = 1
      if ($4 == "done" && $5 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]$/) print $3 ": done but Done is not an ISO date (\"" $5 "\")"
      if ($4 == "open" && $5 != "") print $3 ": open but Done is filled (\"" $5 "\")"
      if ($6 == "") print $3 ": Files is empty"
    }
    END {
      for (i = 1; i <= n; i++) {
        x = order[i]
        if (cnt[x] > max) print "unit " x ": " cnt[x] " tasks, max is " max " (split into sub-phases)"
        if (!(x in code)) print "unit " x ": no task changes a file (Files all none). Verify-only units are not allowed; the pipeline runs the baseline and the final checks itself"
        if (dep[x] == "") continue
        k = split(dep[x], d, ",")
        for (j = 1; j <= k; j++) if (!(d[j] in u) && !(d[j] in ph)) print "unit " x ": depends on unknown unit or phase \"" d[j] "\""
      }
    }')
  if [ -n "$gram" ]; then
    echo "FAIL: tasks grammar:"; echo "$gram" | sed 's/^/  /'; fail=1
  fi
fi

nreq=$(echo "$spec_decl" | grep -cE "^(REQ|SEC)-")
ntask=$(echo "$task_decl" | grep -c "^TASK-")
echo "Checked $(basename "$spec") + $(basename "$tasks"): $nreq REQ/SEC ids, $ntask tasks."
[ $fail -eq 0 ] && [ $warn -eq 0 ] && echo "OK"
exit $fail
