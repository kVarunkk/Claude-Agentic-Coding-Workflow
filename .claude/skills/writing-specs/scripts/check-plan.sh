#!/usr/bin/env bash
# Mechanical checks for a plans/<feature>/ folder:
#   1. every id is declared once (spec bullets, task/goal rows)
#   2. every REQ and SEC id in the spec is referenced by the tasks file (ranges like REQ-011 – REQ-016 count)
#   3. every referenced id is declared somewhere
#   4. no template placeholders or TODO/TBD left
# Usage: check-plan.sh plans/<feature>     Exit code 1 on failures (1–2), 0 otherwise.
set -u
dir="${1:?usage: check-plan.sh plans/<feature>}"
spec=$(ls "$dir"/*-spec.md 2>/dev/null | head -1)
tasks=$(ls "$dir"/*-tasks.md 2>/dev/null | head -1)
[ -n "$spec" ] || { echo "FAIL: no *-spec.md in $dir"; exit 1; }
[ -n "$tasks" ] || { echo "FAIL: no *-tasks.md in $dir"; exit 1; }

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

spec_decl=$(grep -oE "^[[:space:]]*- \*\*($P)-[0-9]+" "$spec" | grep -oE "($P)-[0-9]+")
task_decl=$( { grep -oE "^\| *(TASK|GOAL)-[0-9]+ *\|" "$tasks"; grep -oE "^[[:space:]]*- \*\*GOAL-[0-9]+" "$tasks"; } | grep -oE "(TASK|GOAL)-[0-9]+")

dups=$(printf '%s\n%s\n' "$spec_decl" "$task_decl" | grep -v '^$' | sort | uniq -d)
if [ -n "$dups" ]; then
  echo "FAIL: ids declared more than once:"; echo "$dups" | sed 's/^/  /'; fail=1
fi

task_refs=$(refs "$tasks" | sort -u)
missing=$(echo "$spec_decl" | grep -E "^(REQ|SEC)-" | sort -u | comm -23 - <(echo "$task_refs"))
if [ -n "$missing" ]; then
  echo "FAIL: REQ/SEC ids with no task:"; echo "$missing" | sed 's/^/  /'; fail=1
fi

declared=$(printf '%s\n%s\n' "$spec_decl" "$task_decl" | grep -v '^$' | sort -u)
undeclared=$( { refs "$spec"; refs "$tasks"; } | sort -u | comm -23 - <(echo "$declared"))
if [ -n "$undeclared" ]; then
  echo "WARN: ids referenced but never declared:"; echo "$undeclared" | sed 's/^/  /'; warn=1
fi

ph=$(grep -nE "TBD|TODO|<YYYY-MM-DD>|<feature>|<one sentence|<area>|<repo or team>" "$spec" "$tasks")
if [ -n "$ph" ]; then
  echo "WARN: placeholders or TODO/TBD left:"; echo "$ph" | sed 's/^/  /'; warn=1
fi

nreq=$(echo "$spec_decl" | grep -cE "^(REQ|SEC)-")
ntask=$(echo "$task_decl" | grep -c "^TASK-")
echo "Checked $(basename "$spec") + $(basename "$tasks"): $nreq REQ/SEC ids, $ntask tasks."
[ $fail -eq 0 ] && [ $warn -eq 0 ] && echo "OK"
exit $fail
