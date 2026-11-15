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
eq "approve: brief without a brief file fails" 1 "$(ap partial brief)"
printf -- '---\nfeature: demo\nstatus: draft\n---\n\n# Brief\nstatus: draft stays in the body\n' > "$TMP/partial/feature-demo-brief.md"
eq "approve: brief"          0 "$(ap partial brief)"
has "approve: brief front matter set to agreed" $'feature: demo\nstatus: agreed\n---' "$(cat "$TMP/partial/feature-demo-brief.md")"
has "approve: brief body left alone" "status: draft stays in the body" "$(cat "$TMP/partial/feature-demo-brief.md")"
printf -- '---\nfeature: demo\n---\n# Brief\n' > "$TMP/partial/feature-demo-brief.md"
ap partial brief >/dev/null
has "approve: brief without status gets one" $'feature: demo\nstatus: agreed\n---' "$(cat "$TMP/partial/feature-demo-brief.md")"
eq "approve: afk"            0 "$(ap partial afk)"
eq "approve: final"          0 "$(ap partial final)"
eq "approve: spec"           0 "$(ap partial spec)"
eq "approve: phase-2"        0 "$(ap partial phase-2)"
eq "approve: bad name"       1 "$(ap partial phase-2a)"
eq "approve: no plan dir"    1 "$(ap nope tasks)"
has "approve: marker holds a timestamp" "Z" "$(cat "$TMP/partial/approvals/spec")"
eq "approve: no marker for bad name" "no" "$([ -e "$TMP/partial/approvals/phase-2a" ] && echo yes || echo no)"

# ---- status.sh ----
st() { bash "$S/status.sh" "$TMP/$1" 2>&1 | tr '\n' ';'; }
mkdir -p "$TMP/st-none"
eq "status: empty plan dir"  "brief: missing;spec: missing;tasks: missing;afk: off;gate: none;uncommitted: none;next: none;final: open;" "$(st st-none)"
mkdir -p "$TMP/st-spec"; cp "$FX/valid/feature-demo-spec.md" "$TMP/st-spec/"
eq "status: spec written"    "brief: missing;spec: written;tasks: missing;" "$(st st-spec | grep -oE '^brief: [^;]*;spec: [^;]*;tasks: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-spec" spec >/dev/null
eq "status: spec approved"   "spec: approved;" "$(st st-spec | grep -oE 'spec: [^;]*;')"
eq "status: fresh plan, tasks written, next is unit 1" "tasks: written;afk: off;gate: none;uncommitted: none;next: 1: TASK-010 TASK-011;final: open;" "$(st fresh | grep -oE 'tasks: .*')"
mkplan st-gate1 ""            # phase 1 done, not approved
eq "status: phase 1 done and unapproved is a pending gate" "gate: 1;" "$(st st-gate1 | grep -o 'gate: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-gate1" phase-1 >/dev/null
eq "status: gate clears after approval" "gate: none;uncommitted: none;next: 2a: TASK-021;" "$(st st-gate1 | grep -oE 'gate: .*next: [^;]*;')"
mkplan st-all "$(tick TASK-021);$(tick TASK-022);$(tick TASK-023);$(tick TASK-030)"
bash "$S/approve.sh" "$TMP/st-all" phase-1 >/dev/null; bash "$S/approve.sh" "$TMP/st-all" phase-2 >/dev/null
eq "status: all done, last phase unapproved" "gate: 3;uncommitted: none;next: none;" "$(st st-all | grep -oE 'gate: .*next: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-all" final >/dev/null
eq "status: final approved" "final: approved;" "$(st st-all | grep -oE 'final: [^;]*;')"
mkdir -p "$TMP/st-brief"; echo "# Brief" > "$TMP/st-brief/feature-x-brief.md"
eq "status: brief written" "brief: written;" "$(st st-brief | grep -o '^brief: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-brief" brief >/dev/null
eq "status: brief approved" "brief: approved;" "$(st st-brief | grep -o '^brief: [^;]*;')"
eq "status: malformed exits 1" 1 "$(bash "$S/status.sh" "$TMP/malformed" >/dev/null 2>&1; echo $?)"

# ---- check-plan.sh: verify-only units ----
mkplan verify-only 's#| TASK-030 | Add `--upper`. | CON-001 | src/upper.ts, test/upper.test.ts |#| TASK-030 | Verify the suite. | CON-001 | none |#'
eq  "check-plan: verify-only unit fails"   1 "$(bash "$S/check-plan.sh" "$TMP/verify-only" >/dev/null 2>&1; echo $?)"
has "check-plan: names the verify-only unit" "unit 3: no task changes a file" "$(bash "$S/check-plan.sh" "$TMP/verify-only" 2>&1)"

# ---- report-path.sh ----
rp() { bash "$S/report-path.sh" "$TMP/partial" "$1" 2>/dev/null; }
eq  "report-path: first report"        "$TMP/partial/reports/phase-2/review-2a.md" "$(rp phase-2/review-2a)"
touch "$TMP/partial/reports/phase-2/review-2a.md"
eq  "report-path: rerun gets -2"       "$TMP/partial/reports/phase-2/review-2a-2.md" "$(rp phase-2/review-2a)"
touch "$TMP/partial/reports/phase-2/review-2a-2.md"
eq  "report-path: then -3"             "$TMP/partial/reports/phase-2/review-2a-3.md" "$(rp phase-2/review-2a)"
eq  "report-path: spec stage"          "$TMP/partial/reports/spec/review.md" "$(rp spec/review)"
eq  "report-path: bad stage fails"     1 "$(bash "$S/report-path.sh" "$TMP/partial" misc/x >/dev/null 2>&1; echo $?)"
eq  "report-path: path escape fails"   1 "$(bash "$S/report-path.sh" "$TMP/partial" spec/../x >/dev/null 2>&1; echo $?)"

# ---- log-decision.sh ----
bash "$S/log-decision.sh" "$TMP/partial" "unit 2a" "commit" "green$(printf '\t')and pass" "review.md" "abc123"
eq  "log-decision: header plus one row" 2 "$(wc -l < "$TMP/partial/decisions.tsv" | tr -d ' ')"
eq  "log-decision: six columns, tabs in fields flattened" 6 "$(tail -1 "$TMP/partial/decisions.tsv" | awk -F'\t' '{print NF}')"
eq  "log-decision: wrong arg count fails" 1 "$(bash "$S/log-decision.sh" "$TMP/partial" a b 2>/dev/null; echo $?)"

# ---- git-backed scripts: a throwaway repo ----
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
R="$TMP/repo"; mkdir -p "$R/plans/demo" "$R/src" "$R/test"
cp "$FX/valid/feature-demo-spec.md" "$R/plans/demo/"; cp "$VALID" "$R/plans/demo/feature-demo-tasks.md"
echo "x" > "$R/README.md"
( cd "$R" && git init -q -b master && git add -A && git commit -qm init )
g() { ( cd "$R" && "$@" ); }

# branch.sh
eq  "branch: from default creates feature branch" "branch: feature/demo (from master)" "$(g bash "$S/branch.sh" plans/demo 2>&1)"
eq  "branch: already on it"                       "branch: feature/demo" "$(g bash "$S/branch.sh" plans/demo 2>&1)"
g git checkout -q -b other
eq  "branch: other branch exits 3"                3 "$(g bash "$S/branch.sh" plans/demo >/dev/null 2>&1; echo $?)"
g git checkout -q master
eq  "branch: back on default checks out existing" "branch: feature/demo (from master)" "$(g bash "$S/branch.sh" plans/demo 2>&1)"

# status.sh: uncommitted unit and AFK gate
eq  "status: nothing built yet"        "uncommitted: none;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'uncommitted: [^;]*;')"
g sed -i "$(tick TASK-021)" plans/demo/feature-demo-tasks.md
eq  "status: 2a ticked, not committed" "uncommitted: 2a;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'uncommitted: [^;]*;')"
eq  "status: next moves on to 2b"      "next: 2b: TASK-022 TASK-023;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'next: [^;]*;')"
g git checkout -q -- plans/demo
bash "$S/approve.sh" "$R/plans/demo" afk >/dev/null
eq  "status: afk on"                   "afk: on;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'afk: [^;]*;')"
eq  "status: afk, phase 1 not tagged is the gate" "gate: 1;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'gate: [^;]*;')"
g git tag demo-phase-1
eq  "status: afk, tag clears the gate" "gate: none;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'gate: [^;]*;')"
rm "$R/plans/demo/approvals/afk"

# stage-unit.sh (unit 2b owns src/name.ts, test/name.test.ts, README.md)
echo n > "$R/src/name.ts"; echo t > "$R/test/name.test.ts"; echo y >> "$R/README.md"; echo s > "$R/plans/demo/notes.md"
eq  "stage-unit: owned files staged"   0 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
eq  "stage-unit: staged set"           "README.md plans/demo/notes.md src/name.ts test/name.test.ts" "$(g git diff --cached --name-only | sort | tr '\n' ' ' | sed 's/ $//')"
g git reset -q
echo z > "$R/src/other.ts"
eq  "stage-unit: stray file blocks"    1 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
has "stage-unit: names the stray file" "src/other.ts" "$(g bash "$S/stage-unit.sh" plans/demo 2b 2>&1)"
eq  "stage-unit: nothing staged on block" "" "$(g git diff --cached --name-only)"
g sed -i 's#^None yet\.$#- TASK-022 (REQ-003): also touched src/other.ts for a shared helper.#' plans/demo/feature-demo-tasks.md
eq  "stage-unit: stray logged under Differences is allowed" 0 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
eq  "stage-unit: unknown unit fails"   1 "$(g bash "$S/stage-unit.sh" plans/demo 9 >/dev/null 2>&1; echo $?)"

# patch-id.sh
pid1=$(g bash "$S/patch-id.sh" plans/demo)
mkdir -p "$R/plans/demo/reports/phase-2"; echo r > "$R/plans/demo/reports/phase-2/review-2b.md"; g git add plans/demo/reports
eq  "patch-id: reports do not change it" "$pid1" "$(g bash "$S/patch-id.sh" plans/demo)"
echo more >> "$R/src/name.ts"; g git add src/name.ts
eq  "patch-id: a code change changes it" "changed" "$([ "$(g bash "$S/patch-id.sh" plans/demo)" != "$pid1" ] && echo changed)"
g git commit -qm "unit 2b"
eq  "patch-id: nothing staged"         "empty" "$(g bash "$S/patch-id.sh" plans/demo)"

# scan-staged.sh (fake secrets built from pieces so this file holds none)
sc() { g bash "$S/scan-staged.sh" >"$TMP/scan" 2>&1; echo $?; }
echo 'const ok = 1;' > "$R/src/clean.js"; g git add src/clean.js
eq  "scan: clean diff"                 0 "$(sc)"
printf 'const k = "%s%s";\n' "AKIA" "ABCDEFGHIJKLMNOP" > "$R/src/aws.js"; g git add src/aws.js
eq  "scan: AWS key is HIGH"            1 "$(sc)"
has "scan: names file and line"        "HIGH src/aws.js:1: looks like a AWS access key" "$(cat "$TMP/scan")"
has "scan: does not print the secret"  "ok" "$(grep -q ABCDEFGHIJKLMNOP "$TMP/scan" && echo leaked || echo ok)"
g git reset -q; rm "$R/src/aws.js"
printf 'password = "%s"\n' "hunter2hunter2hunter2" > "$R/src/conf.py"; g git add src/conf.py
eq  "scan: password assignment is MEDIUM" 3 "$(sc)"
printf 'password = "%s"  # scan:allow\n' "hunter2hunter2hunter2" > "$R/src/conf.py"; g git add src/conf.py
eq  "scan: scan:allow skips the line"  0 "$(sc)"
echo "X=1" > "$R/.env"; g git add -f .env
eq  "scan: .env file is HIGH"          1 "$(sc)"
g git reset -q; rm "$R/.env"
printf 'abc\0def' > "$R/src/blob.bin"; g git add src/blob.bin
eq  "scan: binary file is MEDIUM"      3 "$(sc)"
g git reset -q; rm "$R/src/blob.bin"
printf '## Why\nship it %s%s\n' "ghp_" "abcdefghijklmnopqrstuvwxyz0123456789" > "$TMP/body.md"
eq  "scan: --file finds a token"       1 "$(bash "$S/scan-staged.sh" --file "$TMP/body.md" >/dev/null 2>&1; echo $?)"
g git reset -q; rm -f "$R/src/clean.js" "$R/src/conf.py"

# fix-unit.sh
fu() { g bash "$S/fix-unit.sh" plans/demo "$@" 2>&1; }
eq  "fix-unit: next id in phase 2"     "2c" "$(fu id 2)"
eq  "fix-unit: plain phase gets a"     "1a" "$(fu id 1)"
eq  "fix-unit: no auto-fix units yet"  "0" "$(fu count 2)"
T="$R/plans/demo/feature-demo-tasks.md"
add_unit() { # awk inserting a unit before the line matching $1
  awk -v at="$1" -v id="$2" '$0 ~ at && !d { print "## Phase " id ": Auto-fix escape\n\ndepends: 2a, 2b\n\n| ID | Task | Spec | Files | Status | Done |\n|----|------|------|-------|--------|------|\n| TASK-024 | Fix it. | SEC-001 | src/json.ts | [ ] | |\n"; d = 1 } { print }' "$T" > "$T.new" && mv "$T.new" "$T"
}
add_unit '^## Phase 3:' 2c
eq  "fix-unit: clean addition passes"  0 "$(fu check 2c >/dev/null; echo $?)"
eq  "fix-unit: counts the auto-fix unit" "1" "$(fu count 2)"
sed -i 's/^| REQ-001 | TASK-011 |$/| REQ-001 | TASK-011 |\n| SEC-001 | TASK-021, TASK-024 |/' "$T"
eq  "fix-unit: traceability rows allowed" 0 "$(fu check 2c >/dev/null; echo $?)"
sed -i 's/| TASK-023 | Document flags./| TASK-023 | Document all flags./' "$T"
eq  "fix-unit: edited old unit fails"  1 "$(fu check 2c >/dev/null; echo $?)"
has "fix-unit: names the changed unit" "changed section: ## Phase 2b: Name" "$(fu check 2c)"
g git checkout -q -- plans/demo
add_unit '^## Requirement traceability' 2c
has "fix-unit: unit after phase 3 fails" "must come before ## Phase 3: Ship" "$(fu check 2c)"
g git checkout -q -- plans/demo
add_unit '^## Phase 3:' 2d
eq  "fix-unit: wrong id fails"         1 "$(fu check 2c >/dev/null; echo $?)"
g git checkout -q -- plans/demo

# unit-gate.sh
ug() { g bash "$S/unit-gate.sh" plans/demo HEAD "$@" 2>&1; }
eq  "unit-gate: clean unit passes"        "gate: no" "$(ug 0 0)"
has "unit-gate: fix round gates"          "reason: 1 fix round(s) ran" "$(ug 1 0)"
eq  "unit-gate: fix round says yes"       "gate: yes" "$(ug 1 0 | tail -1)"
has "unit-gate: green mutation gates"     "reason: 2 mutation(s) stayed green" "$(ug 0 2)"
echo '- TASK-021 (SEC-001): test input cut to a"b.' >> "$T"
has "unit-gate: names the new difference" 'reason: difference logged: - TASK-021 (SEC-001): test input cut to a"b.' "$(ug 0 0)"
eq  "unit-gate: difference says yes"      "gate: yes" "$(ug 0 0 | tail -1)"
eq  "unit-gate: off never gates"          "gate: no" "$(UNIT_GATE=off ug 1 0 | tail -1)"
mkdir -p "$R/plans/demo/approvals" && touch "$R/plans/demo/approvals/afk"
eq  "unit-gate: AFK never gates"          "gate: no" "$(ug 0 0 | tail -1)"
rm -f "$R/plans/demo/approvals/afk"
g git checkout -q -- plans/demo
eq  "unit-gate: always gates clean unit"  "gate: yes" "$(UNIT_GATE=always ug 0 0)"
eq  "unit-gate: bad mode fails"           1 "$(UNIT_GATE=sometimes ug 0 0 >/dev/null; echo $?)"
eq  "unit-gate: bad base fails"           1 "$(g bash "$S/unit-gate.sh" plans/demo nope 0 0 >/dev/null 2>&1; echo $?)"

# scratch-copy.sh
echo wip > "$R/src/wip.js"
SC="$TMP/scratch1"
eq  "scratch-copy: copies the working tree" "wip" "$(g bash "$S/scratch-copy.sh" "$SC" >/dev/null && cat "$SC/src/wip.js")"
eq  "scratch-copy: ignored dirs skipped"    "no" "$([ -d "$SC/.git" ] && echo yes || echo no)"
eq  "scratch-copy: --base has no new file"  "no" "$(g bash "$S/scratch-copy.sh" "$TMP/scratch2" --base HEAD >/dev/null && { [ -e "$TMP/scratch2/src/wip.js" ] && echo yes || echo no; })"
eq  "scratch-copy: existing dest fails"     1 "$(g bash "$S/scratch-copy.sh" "$SC" >/dev/null 2>&1; echo $?)"

done_tests
