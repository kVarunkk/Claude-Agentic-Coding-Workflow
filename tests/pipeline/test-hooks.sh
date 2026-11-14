#!/usr/bin/env bash
# Tests for .claude/hooks/*. Run from anywhere: bash tests/pipeline/test-hooks.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
H="$ROOT/.claude/hooks"
FX="$ROOT/tests/pipeline/fixtures"
. "$ROOT/tests/pipeline/assert.sh"
. "$ROOT/.claude/scripts/lib.sh"
find_jq || exit 1
export PIPELINE_CONF=/dev/null MAX_LOOPS=2

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export TMPDIR="$TMP/tmp"; mkdir -p "$TMPDIR"
PROJ="$TMP/proj"
mkplan() { # feature sed-script
  mkdir -p "$PROJ/plans/$1"; cp "$FX/valid/feature-demo-spec.md" "$PROJ/plans/$1/"
  sed "$2" "$FX/valid/feature-demo-tasks.md" > "$PROJ/plans/$1/feature-demo-tasks.md"
}
approve() { for n in "${@:2}"; do bash "$ROOT/.claude/scripts/approve.sh" "$PROJ/plans/$1" "$n" >/dev/null; done; }
mkplan demo ""                                                   # next unit: 2a: TASK-021
mkplan fresh 's/| \[x\] | 2026-11-14 |$/| [ ] | |/'             # next unit: 1: TASK-010 TASK-011
mkplan zero 's/## Phase 1:/## Phase 0:/; s/depends: 1/depends: 0/' # phase before 2 is 0
mkplan done 's/| \[ \] | |$/| [x] | 2026-11-14 |/'              # nothing left
approve demo spec tasks phase-1
approve fresh spec tasks
approve zero spec tasks
approve done spec tasks phase-1 phase-2

# ---- check-spawn.sh ----
spawn_json() { # subagent_type prompt
  "$JQ" -n --arg t "$1" --arg p "$2" --arg cwd "$PROJ" \
    '{hook_event_name:"PreToolUse",tool_name:"Agent",cwd:$cwd,tool_input:{subagent_type:$t,description:"x",prompt:$p}}'
}
spawn() { spawn_json "$1" "$2" | CLAUDE_PROJECT_DIR="$PROJ" bash "$H/check-spawn.sh" 2>"$TMP/err"; echo $?; }
P() { printf 'PLAN: plans/%s\nUNIT: %s\nImplement only these tasks.' "$1" "$2"; }

eq  "spawn: non-implementer allowed"              0 "$(spawn code-reviewer "anything")"
eq  "spawn: correct unit allowed"                 0 "$(spawn implementer "$(P demo '2a: TASK-021')")"
eq  "spawn: first unit needs no phase approval"   0 "$(spawn implementer "$(P fresh '1: TASK-010 TASK-011')")"
eq  "spawn: task order does not matter"           0 "$(spawn implementer "$(P fresh '1: TASK-011 TASK-010')")"
eq  "spawn: wrong unit blocked"                   2 "$(spawn implementer "$(P demo '2b: TASK-022 TASK-023')")"
has "spawn: block names the expected unit"        'expected "UNIT: 2a: TASK-021"' "$(cat "$TMP/err")"
eq  "spawn: extra task id blocked"                2 "$(spawn implementer "$(P demo '2a: TASK-021 TASK-022')")"
eq  "spawn: subset of the unit blocked"           2 "$(spawn implementer "$(P fresh '1: TASK-010')")"
eq  "spawn: missing PLAN/UNIT lines blocked"      2 "$(spawn implementer "Implement 2a: TASK-021 of plans/demo")"
eq  "spawn: plan path outside plans/ blocked"     2 "$(spawn implementer "$(P '../etc' '2a: TASK-021')")"
eq  "spawn: unknown plan blocked"                 2 "$(spawn implementer "$(P nope '1: TASK-010')")"
eq  "spawn: all done blocked"                     2 "$(spawn implementer "$(P done '3: TASK-030')")"
eq  "spawn: implementer via JSON without cwd env" 0 "$(spawn_json implementer "$(P demo '2a: TASK-021')" | env -u CLAUDE_PROJECT_DIR bash "$H/check-spawn.sh" 2>/dev/null; echo $?)"

rm "$PROJ/plans/demo/approvals/phase-1"
eq  "spawn: missing previous phase approval blocked" 2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
has "spawn: block names the missing phase"          "phase 1 is not approved" "$(cat "$TMP/err")"
approve demo phase-1
rm "$PROJ/plans/demo/approvals/tasks"
eq  "spawn: missing tasks approval blocked"      2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
approve demo tasks
rm "$PROJ/plans/demo/approvals/spec"
eq  "spawn: missing spec approval blocked"       2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
approve demo spec
eq  "spawn: approvals restored allowed again"    0 "$(spawn implementer "$(P demo '2a: TASK-021')")"

# Zero-based phases: the phase before 2 is 0.
eq  "spawn: phase-0 approval missing blocked"    2 "$(spawn implementer "$(P zero '2a: TASK-021')")"
approve zero phase-0
eq  "spawn: phase-0 approved allowed"            0 "$(spawn implementer "$(P zero '2a: TASK-021')")"

# ---- check-spawn.sh: spec-writer needs an agreed brief ----
mkdir -p "$PROJ/plans/newfeat"
SW='PLAN: plans/newfeat
Feature: newfeat. Brief: plans/newfeat/feature-newfeat-brief.md.'
eq  "spec-writer: no brief approval blocked"     2 "$(spawn spec-writer "$SW")"
has "spec-writer: block names the brief"         "brief is not agreed" "$(cat "$TMP/err")"
eq  "spec-writer: missing PLAN line blocked"     2 "$(spawn spec-writer "Write a spec for newfeat")"
approve newfeat brief
eq  "spec-writer: agreed brief allowed"          0 "$(spawn spec-writer "$SW")"
eq  "spec-writer: does not need a UNIT line"     0 "$(spawn spec-writer "$SW")"
eq  "spawn: no jq still lets other agents through" 0 "$(spawn_json Explore x | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-spawn.sh" 2>/dev/null; echo $?)"
eq  "spawn: no jq blocks a gated spawn"          2 "$(spawn_json implementer x | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-spawn.sh" 2>/dev/null; echo $?)"

# ---- implementer-stop.sh ----
stop() { # TEST_CMD agent_type agent_id
  "$JQ" -n --arg t "$2" --arg id "$3" '{hook_event_name:"SubagentStop",stop_hook_active:false,agent_type:$t,agent_id:$id}' |
    TEST_CMD="$1" CLAUDE_PROJECT_DIR="$PROJ" bash "$H/implementer-stop.sh" 2>"$TMP/err"; echo $?
}
eq  "stop: green tests allow stop"          0 "$(stop true implementer a1)"
eq  "stop: red tests block (1)"             2 "$(stop 'echo boom-output; false' implementer a2)"
has "stop: block shows the failing output"  "boom-output" "$(cat "$TMP/err")"
eq  "stop: red tests block (2)"             2 "$(stop false implementer a2)"
eq  "stop: after MAX_LOOPS blocks, allow"   0 "$(stop false implementer a2)"
eq  "stop: counter reset after release"     2 "$(stop false implementer a2)"
eq  "stop: green resets the counter"        0 "$(stop true implementer a2)"
eq  "stop: red again starts at block 1"     2 "$(stop false implementer a2)"
has "stop: block count restarted"           "Block 1 of 2" "$(cat "$TMP/err")"
eq  "stop: other agent types ignored"       0 "$(stop false code-reviewer a3)"
eq  "stop: counters are per agent"          2 "$(stop false implementer a4)"
eq  "stop: empty TEST_CMD allows stop"      0 "$(PIPELINE_CONF=/dev/null stop '' implementer a5)"

done_tests
