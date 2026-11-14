#!/usr/bin/env bash
# Tests for .claude/scripts/*. Run from anywhere: bash tests/pipeline/test-scripts.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/.claude/scripts"
FX="$ROOT/tests/pipeline/fixtures"
export PIPELINE_CONF=/dev/null MAX_UNIT_TASKS=5
. "$ROOT/tests/pipeline/assert.sh"

# ---- check-plan.sh ----
check() { bash "$S/check-plan.sh" "$FX/$1" >/dev/null 2>&1; echo $?; }
eq "check-plan: valid passes"            0 "$(check valid)"
eq "check-plan: oversized unit fails"    1 "$(check oversized)"
eq "check-plan: bad unit id fails"       1 "$(check bad-id)"
eq "check-plan: missing column fails"    1 "$(check missing-column)"
eq "check-plan: bad status fails"        1 "$(check bad-status)"
eq "check-plan: unknown depends fails"   1 "$(check bad-depends)"
eq "check-plan: non-ISO done date fails" 1 "$(check bad-date)"
has "check-plan: oversized names the unit" "unit 2a: 6 tasks" "$(bash "$S/check-plan.sh" "$FX/oversized" 2>&1)"
eq "check-plan: MAX_UNIT_TASKS=6 lets oversized pass" 0 "$(MAX_UNIT_TASKS=6 bash "$S/check-plan.sh" "$FX/oversized" >/dev/null 2>&1; echo $?)"

# ---- scenario plans built from the valid fixture ----
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
VALID="$FX/valid/feature-demo-tasks.md"
mkplan() { # name sed-script
  mkdir -p "$TMP/$1"; cp "$FX/valid/feature-demo-spec.md" "$TMP/$1/"
  sed "$2" "$VALID" > "$TMP/$1/feature-demo-tasks.md"
}
tick() { echo "s/\\(| $1 |.*\\)| \\[ \\] | |\$/\\1| [x] | 2026-11-14 |/"; }
untick_all='s/| \[x\] | 2026-11-14 |$/| [ ] | |/'
mkplan fresh "$untick_all"
mkplan partial ""
mkplan sub2b "$(tick TASK-021)"
mkplan sub2b-part "$(tick TASK-021);$(tick TASK-022)"
mkplan phase2-done "$(tick TASK-021);$(tick TASK-022);$(tick TASK-023)"
mkplan all-done "$(tick TASK-021);$(tick TASK-022);$(tick TASK-023);$(tick TASK-030)"
mkplan malformed 's/| TASK-022 | Add `--name`. | REQ-003 | src\/name.ts, test\/name.test.ts | \[ \] | |/| TASK-022 | Add `--name`. | REQ-003 | [ ] | |/'
mkdir -p "$TMP/empty"

# ---- next-unit.sh ----
nu() { bash "$S/next-unit.sh" "$TMP/$1" 2>/dev/null; }
eq "next-unit: fresh plan picks first unit, all its tasks" "1: TASK-010 TASK-011" "$(nu fresh)"
eq "next-unit: partial unit lists only open tasks"         "2a: TASK-021"         "$(nu partial)"
eq "next-unit: after 2a done, moves to sub-phase 2b"       "2b: TASK-022 TASK-023" "$(nu sub2b)"
eq "next-unit: 2b partly done lists the rest"              "2b: TASK-023"         "$(nu sub2b-part)"
eq "next-unit: phase 2 done moves to phase 3"              "3: TASK-030"          "$(nu phase2-done)"
eq "next-unit: all done prints nothing"                    ""                     "$(nu all-done)"
eq "next-unit: all done exits 0"                           0 "$(nu all-done >/dev/null; echo $?)"
eq "next-unit: malformed row exits 1"                      1 "$(nu malformed >/dev/null; echo $?)"
eq "next-unit: missing tasks file exits 1"                 1 "$(nu empty >/dev/null; echo $?)"

# ---- phase-done.sh ----
pd() { bash "$S/phase-done.sh" "$TMP/$1" "$2" >/dev/null 2>&1; echo $?; }
eq "phase-done: phase 1 done, single unit"           0 "$(pd partial 1)"
eq "phase-done: 2a is not the last sub-phase"        1 "$(pd sub2b 2a)"
eq "phase-done: 2b last sub-phase but open tasks"    1 "$(pd sub2b-part 2b)"
eq "phase-done: 2b last sub-phase, phase 2 complete" 0 "$(pd phase2-done 2b)"
eq "phase-done: 2a never ends the phase even when 2 is done" 1 "$(pd phase2-done 2a)"
eq "phase-done: unknown unit exits 1"                1 "$(pd partial 9z)"
eq "phase-done: malformed exits 1"                   1 "$(pd malformed 1)"

# ---- tick-unit.sh ----
tu() { bash "$S/tick-unit.sh" "$TMP/$1" "$2" 2>&1; }
eq "tick-unit: fully ticked unit exits 0"  0 "$(tu partial 1 >/dev/null; echo $?)"
eq "tick-unit: partly ticked unit exits 1" 1 "$(tu partial 2a >/dev/null; echo $?)"
has "tick-unit: names the open tasks" "not ticked: TASK-021" "$(tu partial 2a)"
eq "tick-unit: unknown unit exits 1"       1 "$(tu partial 7 >/dev/null; echo $?)"

# ---- approve.sh ----
ap() { bash "$S/approve.sh" "$TMP/$1" "$2" >/dev/null 2>&1; echo $?; }
eq "approve: spec"           0 "$(ap partial spec)"
eq "approve: phase-2"        0 "$(ap partial phase-2)"
eq "approve: bad name"       1 "$(ap partial phase-2a)"
eq "approve: no plan dir"    1 "$(ap nope tasks)"
has "approve: marker holds a timestamp" "Z" "$(cat "$TMP/partial/approvals/spec")"
eq "approve: no marker for bad name" "no" "$([ -e "$TMP/partial/approvals/phase-2a" ] && echo yes || echo no)"

# ---- status.sh ----
st() { bash "$S/status.sh" "$TMP/$1" 2>&1 | tr '\n' ';'; }
mkdir -p "$TMP/st-none"
eq "status: empty plan dir"  "spec: missing;tasks: missing;gate: none;next: none;" "$(st st-none)"
mkdir -p "$TMP/st-spec"; cp "$FX/valid/feature-demo-spec.md" "$TMP/st-spec/"
eq "status: spec written"    "spec: written;tasks: missing;gate: none;next: none;" "$(st st-spec)"
bash "$S/approve.sh" "$TMP/st-spec" spec >/dev/null
eq "status: spec approved"   "spec: approved;tasks: missing;gate: none;next: none;" "$(st st-spec)"
eq "status: fresh plan, tasks written, next is unit 1" "spec: written;tasks: written;gate: none;next: 1: TASK-010 TASK-011;" "$(st fresh)"
mkplan st-gate1 ""            # phase 1 done, not approved
eq "status: phase 1 done and unapproved is a pending gate" "gate: 1;" "$(st st-gate1 | grep -o 'gate: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-gate1" phase-1 >/dev/null
eq "status: gate clears after approval" "gate: none;next: 2a: TASK-021;" "$(st st-gate1 | grep -o 'gate: .*')"
mkplan st-all "$(tick TASK-021);$(tick TASK-022);$(tick TASK-023);$(tick TASK-030)"
bash "$S/approve.sh" "$TMP/st-all" phase-1 >/dev/null; bash "$S/approve.sh" "$TMP/st-all" phase-2 >/dev/null
eq "status: all done, last phase unapproved" "gate: 3;next: none;" "$(st st-all | grep -o 'gate: .*')"
eq "status: malformed exits 1" 1 "$(bash "$S/status.sh" "$TMP/malformed" >/dev/null 2>&1; echo $?)"

done_tests
