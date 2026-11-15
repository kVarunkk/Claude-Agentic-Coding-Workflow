#!/usr/bin/env bash
# fix-unit.sh <plan-dir> id <N>       prints the id for a new unit in phase N: N plus the next free letter
# fix-unit.sh <plan-dir> count <N>    prints how many automatic fix units ("## Phase N?: Auto-fix ...") phase N has
# fix-unit.sh <plan-dir> check <id>   compares the tasks file with HEAD: the only change allowed is one new
#                                     unit <id>, placed after phase N's units and before later phases, plus
#                                     rows in "## Requirement traceability" and a new last_updated date.
#                                     Prints each violation and exits 1.
set -u
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
usage="usage: fix-unit.sh <plan-dir> id <N> | count <N> | check <unit-id>"
plan="${1:?$usage}"; cmd="${2:?$usage}"; arg="${3:?$usage}"
tasks=$(tasks_file "$plan") || exit 1

case "$cmd" in
  id)
    printf '%s' "$arg" | grep -qE '^[0-9]+$' || { echo "N must be a phase number" >&2; exit 1; }
    parsed=$(parse_tasks "$tasks") || exit 1
    printf '%s\n' "$parsed" | awk -F'\t' -v p="$arg" '
      $1 == "unit" && $3 == p { n++; l = substr($2, length(p) + 1); if (l > max) max = l }
      END {
        if (!n) { print "phase " p " has no units" > "/dev/stderr"; exit 1 }
        letters = "abcdefghijklmnopqrstuvwxyz"
        i = (max == "") ? 1 : index(letters, max) + 1
        if (i > 26) { print "phase " p " has no free letter" > "/dev/stderr"; exit 1 }
        print p substr(letters, i, 1)
      }'
    ;;
  count)
    tr -d '\r' < "$tasks" | grep -cE "^## Phase ${arg}[a-z]?: Auto-fix" || true
    ;;
  check)
    printf '%s' "$arg" | grep -qE '^[0-9]+[a-z]$' || { echo "unit id must be <N><letter>" >&2; exit 1; }
    old=$(mktemp); trap 'rm -f "$old"' EXIT
    git -C "$(dirname "$tasks")" show "HEAD:./$(basename "$tasks")" > "$old" 2>/dev/null ||
      { echo "tasks file is not committed at HEAD" >&2; exit 1; }
    tr -d '\r' < "$tasks" | awk -v want="$arg" '
      function phase_of(h,   id) { id = h; sub(/^## Phase /, "", id); sub(/:.*/, "", id); return id }
      FNR == 1 { f++; key = "(front matter and intro)"; pos = 0; keys[f, key] = 1 }
      /^## / { key = $0; pos++; keys[f, key] = 1; at[f, key] = pos; if (f == 2) seq[++ns] = key; next }
      /^[ \t]*$/ || /^---[ \t]*$/ || /^last_updated:/ { next }
      { body[f, key] = body[f, key] "\n" $0 }
      END {
        bad = 0
        for (k in keys) {
          split(k, kk, SUBSEP); if (kk[1] != 1) continue; h = kk[2]
          if (!((2, h) in keys)) { print "removed section: " h; bad = 1; continue }
          if (h ~ /^## Requirement traceability/) continue
          if (body[1, h] != body[2, h]) { print "changed section: " h; bad = 1 }
        }
        p = want; sub(/[a-z]$/, "", p)
        nnew = 0
        for (i = 1; i <= ns; i++) {
          h = seq[i]; if ((1, h) in keys) continue
          nnew++
          if (h !~ /^## Phase / || phase_of(h) != want) { print "unexpected new section: " h; bad = 1; continue }
          newpos = i
        }
        if (nnew == 0) { print "no new unit " want; bad = 1 }
        if (newpos) for (i = 1; i <= ns; i++) {
          h = seq[i]; if (h !~ /^## Phase / || i == newpos) continue
          q = phase_of(h); sub(/[a-z]$/, "", q)
          if (q + 0 == p + 0 && i > newpos) { print "unit " want " must come after " h; bad = 1 }
          if (q + 0 > p + 0 && i < newpos) { print "unit " want " must come before " h; bad = 1 }
        }
        exit bad
      }' "$old" -
    rc=$?
    [ $rc -eq 0 ] && echo "fix unit $arg: only the new unit was added"
    exit $rc
    ;;
  *) echo "$usage" >&2; exit 1 ;;
esac
