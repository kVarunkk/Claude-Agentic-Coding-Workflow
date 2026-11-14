#!/usr/bin/env bash
# Stop hook in implementer.md frontmatter (runs as SubagentStop). Runs TEST_CMD from
# .claude/pipeline.conf. Red: exit 2 with the output tail, which goes back to the implementer.
# After MAX_LOOPS consecutive blocks for one agent it lets the agent stop, so it cannot loop forever.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../scripts/lib.sh"
load_conf
input=$(cat)
printf '%s\n' "$input" > "${TMPDIR:-/tmp}/pipeline-last-implementer-stop.json" 2>/dev/null
JQ=""; find_jq 2>/dev/null || true
field() { [ -n "$JQ" ] && printf '%s' "$input" | "$JQ" -r "$1 // empty" 2>/dev/null | tr -d '\r'; }

atype=$(field .agent_type)
[ -z "$atype" ] || [ "$atype" = "implementer" ] || exit 0
[ -n "$TEST_CMD" ] || exit 0

id=$(field .agent_id); [ -n "$id" ] || id=$(field .session_id); [ -n "$id" ] || id=unknown
id=$(printf '%s' "$id" | tr -c 'A-Za-z0-9_-' '_')
counter="${TMPDIR:-/tmp}/pipeline-stop-$id"

[ -n "${CLAUDE_PROJECT_DIR:-}" ] && cd "$CLAUDE_PROJECT_DIR"
out=$(bash -c "$TEST_CMD" 2>&1); rc=$?
if [ $rc -eq 0 ]; then rm -f "$counter"; exit 0; fi

n=$(cat "$counter" 2>/dev/null || echo 0)
if [ "$n" -ge "$MAX_LOOPS" ]; then
  rm -f "$counter"
  echo "implementer-stop: tests still red after $MAX_LOOPS blocks; letting the agent stop. Report it under open problems." >&2
  exit 0
fi
echo $((n + 1)) > "$counter"
{
  echo "Tests are red ($TEST_CMD exited $rc). Fix them before you finish; do not tick tasks whose tests fail. Block $((n + 1)) of $MAX_LOOPS."
  echo "--- last 40 lines ---"
  printf '%s\n' "$out" | tail -n 40
} >&2
exit 2
