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

done_tests
