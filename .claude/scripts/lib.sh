# Shared helpers for the build pipeline scripts. Source it; do not run it.
#
# parse_tasks <tasks.md> prints one record per line, tab separated:
#   unit <unit-id> <phase-number> <depends, comma separated or empty>
#   task <unit-id> <task-id> <open|done> <done-date> <files>
# Records come in file order. Grammar errors go to stderr; return code 1.

PIPELINE_SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

load_conf() {
  local conf="${PIPELINE_CONF:-$PIPELINE_SCRIPTS/../pipeline.conf}"
  local keep_max="${MAX_UNIT_TASKS-}" keep_loops="${MAX_LOOPS-}" keep_test="${TEST_CMD-}"
  # shellcheck disable=SC1090
  [ -f "$conf" ] && . "$conf"
  # Values already in the environment win over the file.
  [ -n "$keep_max" ] && MAX_UNIT_TASKS="$keep_max"
  [ -n "$keep_loops" ] && MAX_LOOPS="$keep_loops"
  [ -n "$keep_test" ] && TEST_CMD="$keep_test"
  MAX_UNIT_TASKS="${MAX_UNIT_TASKS:-5}"
  MAX_LOOPS="${MAX_LOOPS:-2}"
  TEST_CMD="${TEST_CMD-}"
}

# jq may be installed but not yet on PATH in a running session (WinGet).
find_jq() {
  if command -v jq >/dev/null 2>&1; then JQ=jq; return 0; fi
  local c
  for c in "${LOCALAPPDATA:-}"/Microsoft/WinGet/Packages/jqlang.jq_*/jq.exe \
           "${LOCALAPPDATA:-}"/Microsoft/WinGet/Links/jq.exe; do
    [ -x "$c" ] && { JQ="$c"; return 0; }
  done
  echo "jq not found" >&2
  return 1
}

# tasks_file <plan-dir>: the single feature-*-tasks.md in the plan dir.
tasks_file() {
  local dir="${1:?plan dir required}" f n
  n=$(ls "$dir"/feature-*-tasks.md 2>/dev/null | wc -l)
  if [ "$n" -ne 1 ]; then
    echo "expected one feature-*-tasks.md in $dir, found $n" >&2
    return 1
  fi
  f=$(ls "$dir"/feature-*-tasks.md)
  printf '%s\n' "$f"
}

parse_tasks() {
  local file="${1:?tasks file required}"
  [ -f "$file" ] || { echo "no such file: $file" >&2; return 1; }
  tr -d '\r' < "$file" | awk -F'\t' -v FILENAME_="$file" '
    function err(msg) { printf "%s:%d: %s\n", FILENAME_, NR, msg > "/dev/stderr"; bad = 1 }
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function close_unit() {
      if (unit == "") return
      if (!hdr) err("unit " unit ": no task table")
      else if (rows == 0) err("unit " unit ": table has no task rows")
    }
    # Split a markdown table row into cells[1..n]; \| is a literal pipe.
    function split_row(line,   s, n, i) {
      s = line
      gsub(/\\\|/, "\001", s)
      sub(/^[ \t]*\|/, "", s); sub(/\|[ \t]*$/, "", s)
      n = split(s, cells, "|")
      for (i = 1; i <= n; i++) { gsub(/\001/, "|", cells[i]); cells[i] = trim(cells[i]) }
      return n
    }
    BEGIN { unit = ""; bad = 0 }
    /^## / {
      close_unit()
      unit = ""; hdr = 0; rows = 0; ended = 0
      if ($0 !~ /^## Phase /) next
      line = $0; sub(/^## Phase /, "", line)
      if (index(line, ":") == 0) { err("phase heading needs \"## Phase <id>: <title>\""); next }
      id = trim(substr(line, 1, index(line, ":") - 1))
      if (id !~ /^[0-9]+[a-z]?$/) { err("bad unit id \"" id "\" (want 1, 2, 3a, 3b)"); next }
      if (id in seen) { err("unit " id " declared twice"); next }
      seen[id] = 1; unit = id
      phase = id; sub(/[a-z]$/, "", phase)
      deps[unit] = ""
      order[++nunits] = unit; uphase[unit] = phase
      next
    }
    unit == "" { next }
    /^depends:/ {
      if (hdr) { err("unit " unit ": depends: must come before the table"); next }
      d = $0; sub(/^depends:[ \t]*/, "", d); gsub(/[ \t]*,[ \t]*|[ \t]+/, ",", d); sub(/,$/, "", d)
      deps[unit] = d
      next
    }
    /^[ \t]*\|/ {
      if (ended) { err("unit " unit ": second table in one unit"); next }
      n = split_row($0)
      if (!hdr) {
        for (k in col) delete col[k]
        for (i = 1; i <= n; i++) col[cells[i]] = i
        ncols = n
        need = "ID Task Spec Files Status Done"; split(need, nd, " ")
        miss = ""
        for (i = 1; i <= 6; i++) if (!(nd[i] in col)) miss = miss " " nd[i]
        if (miss != "") { err("unit " unit ": table header missing column(s):" miss); unit = ""; next }
        hdr = 1; sep = 0
        next
      }
      if (!sep) { sep = 1; if ($0 ~ /^[ \t]*\|[ \t:|-]+\|?[ \t]*$/) next }
      if (n != ncols) { err("unit " unit ": row has " n " cells, header has " ncols); next }
      tid = cells[col["ID"]]
      if (tid !~ /^TASK-[0-9]+$/) { err("unit " unit ": bad task id \"" tid "\""); next }
      st = cells[col["Status"]]
      if (st == "[ ]") s = "open"
      else if (st == "[x]") s = "done"
      else { err(tid ": status must be [ ] or [x], got \"" st "\""); next }
      rows++
      out[++nout] = "task\t" unit "\t" tid "\t" s "\t" cells[col["Done"]] "\t" cells[col["Files"]]
      next
    }
    hdr && NF > 0 { ended = 1 }
    END {
      close_unit()
      if (nunits == 0) err("no \"## Phase <id>: <title>\" units found")
      if (bad) exit 1
      # Units first, then tasks, both in file order.
      for (i = 1; i <= nunits; i++) { u = order[i]; print "unit\t" u "\t" uphase[u] "\t" deps[u] }
      for (i = 1; i <= nout; i++) print out[i]
    }
  '
}
