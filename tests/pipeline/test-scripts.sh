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
has "next-unit --all: lists a done unit"   "1: TASK-010 TASK-011 (done)" "$(bash "$S/next-unit.sh" --all "$TMP/partial" 2>&1)"
has "next-unit --all: lists a partial unit" "2a: TASK-020 TASK-021 (1/2 done)" "$(bash "$S/next-unit.sh" --all "$TMP/partial" 2>&1)"
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

# ---- check-plan.sh: invisible characters ----
mkdir -p "$TMP/bom" && cp "$FX/valid/"* "$TMP/bom/"
printf '%b' '\0357\0273\0277' >> "$TMP/bom/feature-demo-tasks.md"
eq "check-plan: raw U+FEFF fails" 1 "$(bash "$S/check-plan.sh" "$TMP/bom" >/dev/null 2>&1; echo $?)"
has "check-plan: names invisible characters" "invisible characters" "$(bash "$S/check-plan.sh" "$TMP/bom" 2>&1)"

# ---- log-decision.sh: arity ----
has "log-decision: wrong arity names the count" "got 5 argument(s)" "$(bash "$S/log-decision.sh" "$TMP/bom" a b c d 2>&1)"

# ---- approve.sh final sets tasks status ----
mkdir -p "$TMP/fin" && cp "$FX/valid/"* "$TMP/fin/"
awk '{ print } /^goal:/ { print "status: '"'"'Planned'"'"'" }' "$FX/valid/feature-demo-tasks.md" > "$TMP/fin/feature-demo-tasks.md"
bash "$S/approve.sh" "$TMP/fin" final >/dev/null
has "approve: final marks the tasks file Done" "status: 'Done'" "$(cat "$TMP/fin/feature-demo-tasks.md")"

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
eq "approve: retry"          0 "$(ap partial retry)"
eq "approve: bad name"       1 "$(ap partial phase-2a)"
eq "approve: no plan dir"    1 "$(ap nope tasks)"
has "approve: marker holds a timestamp" "Z" "$(cat "$TMP/partial/approvals/spec")"
eq "approve: no marker for bad name" "no" "$([ -e "$TMP/partial/approvals/phase-2a" ] && echo yes || echo no)"

# ---- status.sh ----
st() { bash "$S/status.sh" "$TMP/$1" 2>&1 | tr '\n' ';'; }
mkdir -p "$TMP/st-none"
eq "status: empty plan dir"  "brief: missing;spec: missing;tasks: missing;afk: off;gate: none;uncommitted: none;dirty: none;next: none;final: open;import: none;" "$(st st-none)"
mkdir -p "$TMP/st-spec"; cp "$FX/valid/feature-demo-spec.md" "$TMP/st-spec/"
eq "status: spec written"    "brief: missing;spec: written;tasks: missing;" "$(st st-spec | grep -oE '^brief: [^;]*;spec: [^;]*;tasks: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-spec" spec >/dev/null
eq "status: spec approved"   "spec: approved;" "$(st st-spec | grep -oE 'spec: [^;]*;')"
eq "status: fresh plan, tasks written, next is unit 1" "tasks: written;afk: off;gate: none;uncommitted: none;dirty: none;next: 1: TASK-010 TASK-011;final: open;import: none;" "$(st fresh | grep -oE 'tasks: .*')"
mkplan st-gate1 ""            # phase 1 done, not approved
eq "status: phase 1 done and unapproved is a pending gate" "gate: 1;" "$(st st-gate1 | grep -o 'gate: [^;]*;')"
bash "$S/approve.sh" "$TMP/st-gate1" phase-1 >/dev/null
eq "status: gate clears after approval" "gate: none;uncommitted: none;dirty: none;next: 2a: TASK-021;" "$(st st-gate1 | grep -oE 'gate: .*next: [^;]*;')"
mkplan st-all "$(tick TASK-021);$(tick TASK-022);$(tick TASK-023);$(tick TASK-030)"
bash "$S/approve.sh" "$TMP/st-all" phase-1 >/dev/null; bash "$S/approve.sh" "$TMP/st-all" phase-2 >/dev/null
eq "status: all done, last phase unapproved" "gate: 3;uncommitted: none;dirty: none;next: none;" "$(st st-all | grep -oE 'gate: .*next: [^;]*;')"
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

# ---- check-plan.sh: id ranges used as group labels ----
mkdir -p "$TMP/range"; cp "$FX/valid/"feature-demo-*.md "$TMP/range/"
echo "Flags (REQ-001 to REQ-009) and escaping (SEC-001 – SEC-005):" >> "$TMP/range/feature-demo-spec.md"
eq  "check-plan: range label over undeclared ids is no warning" "" "$(bash "$S/check-plan.sh" "$TMP/range" 2>&1 | grep 'never declared')"
echo "See REQ-099." >> "$TMP/range/feature-demo-spec.md"
has "check-plan: a lone undeclared id still warns" "REQ-099" "$(bash "$S/check-plan.sh" "$TMP/range" 2>&1)"

# ---- check-plan.sh: removed ids need no task ----
mkdir -p "$TMP/removed"; cp "$FX/valid/"feature-demo-*.md "$TMP/removed/"
echo "- **REQ-098**: (removed in v0.2: moved to PAT-001)" >> "$TMP/removed/feature-demo-spec.md"
eq  "check-plan: a removed REQ needs no task" 0 "$(bash "$S/check-plan.sh" "$TMP/removed" >/dev/null 2>&1; echo $?)"
echo "- **REQ-097**: Still live." >> "$TMP/removed/feature-demo-spec.md"
out=$(bash "$S/check-plan.sh" "$TMP/removed" 2>&1)
has "check-plan: a live REQ with no task still fails" "REQ-097" "$out"
eq  "check-plan: the removed REQ is not listed" "" "$(printf '%s\n' "$out" | grep REQ-098)"

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
eq  "report-path: review in another phase fails" 1 "$(bash "$S/report-path.sh" "$TMP/partial" phase-1/review-2 >/dev/null 2>&1; echo $?)"
has "report-path: says which phase"    "goes under phase-2/" "$(bash "$S/report-path.sh" "$TMP/partial" phase-1/review-2 2>&1)"
eq  "report-path: fix unit review in its phase" "$TMP/partial/reports/phase-2/review-2b.md" "$(rp phase-2/review-2b)"
eq  "report-path: other phase names free" "$TMP/partial/reports/phase-1/fix-unit-review.md" "$(rp phase-1/fix-unit-review)"
PP=$(bash "$S/report-path.sh" --pending "$TMP/partial" phase-3/review-3a 2>/dev/null)
eq  "report-path: --pending prints the path"  "$TMP/partial/reports/phase-3/review-3a.md" "$PP"
has "report-path: --pending writes a skeleton" "verdict: pending" "$(cat "$PP" 2>/dev/null)"
eq  "report-path: --pending skeleton is incomplete" 1 "$(bash "$S/check-report.sh" "$PP" >/dev/null 2>&1; echo $?)"
eq  "report-path: --pending takes the name"   "$TMP/partial/reports/phase-3/review-3a-2.md" "$(rp phase-3/review-3a)"

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
g sedi "$(tick TASK-021)" plans/demo/feature-demo-tasks.md
eq  "status: 2a ticked, not committed" "uncommitted: 2a;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'uncommitted: [^;]*;')"
eq  "status: next moves on to 2b"      "next: 2b: TASK-022 TASK-023;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'next: [^;]*;')"
g git checkout -q -- plans/demo
dl() { g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'dirty: [^;]*;'; }
eq  "status: clean tree is not dirty"   "dirty: none;" "$(dl)"
echo half > "$R/src/half.ts"
eq  "status: unticked unit with work in the tree is dirty" "dirty: 2a;" "$(dl)"
eq  "status: dirty is not uncommitted"  "uncommitted: none;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'uncommitted: [^;]*;')"
rm "$R/src/half.ts"; mkdir -p "$R/plans/demo/reports/phase-1" "$R/plans/demo/approvals"
echo r > "$R/plans/demo/reports/phase-1/review-1.md"; echo x > "$R/plans/demo/decisions.tsv"
eq  "status: reports and decisions.tsv are not dirty" "dirty: none;" "$(dl)"
g sedi "$(tick TASK-021)" plans/demo/feature-demo-tasks.md
eq  "status: fully ticked is uncommitted, not dirty" "dirty: none;" "$(dl)"
g git checkout -q -- plans/demo; rm -rf "$R/plans/demo/reports" "$R/plans/demo/decisions.tsv"
bash "$S/approve.sh" "$R/plans/demo" afk >/dev/null
eq  "status: afk on"                   "afk: on;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'afk: [^;]*;')"
eq  "status: afk, phase 1 not tagged is the gate" "gate: 1;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'gate: [^;]*;')"
g git tag demo-phase-1
eq  "status: afk, tag clears the gate" "gate: none;" "$(g bash "$S/status.sh" plans/demo | tr '\n' ';' | grep -oE 'gate: [^;]*;')"
rm "$R/plans/demo/approvals/afk"

# status.sh: the last phase has no phase gate; its tag ends it, as in AFK mode (on a copy of the repo)
R3="$TMP/repo-last"; cp -r "$R" "$R3"
for t in TASK-021 TASK-022 TASK-023 TASK-030; do ( cd "$R3" && sedi "$(tick $t)" plans/demo/feature-demo-tasks.md ); done
for p in phase-1 phase-2; do bash "$S/approve.sh" "$R3/plans/demo" $p >/dev/null; done
st3() { bash "$S/status.sh" "$R3/plans/demo" | tr '\n' ';' | grep -oE 'gate: [^;]*;|next: [^;]*;' | tr -d '\n'; }
eq  "status: last phase done, not tagged is the gate" "gate: 3;next: none;" "$(st3)"
git -C "$R3" tag demo-phase-3
eq  "status: last phase tag clears the gate, no approval needed" "gate: none;next: none;" "$(st3)"

# stage-unit.sh (unit 2b owns src/name.ts, test/name.test.ts, README.md)
echo n > "$R/src/name.ts"; echo t > "$R/test/name.test.ts"; echo y >> "$R/README.md"; echo s > "$R/plans/demo/notes.md"
eq  "stage-unit: owned files staged"   0 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
eq  "stage-unit: staged set"           "README.md plans/demo/notes.md src/name.ts test/name.test.ts" "$(g git diff --cached --name-only | LC_ALL=C sort | tr '\n' ' ' | sed 's/ $//')"
g git reset -q
echo z > "$R/src/other.ts"
eq  "stage-unit: stray file blocks"    1 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
has "stage-unit: names the stray file" "src/other.ts" "$(g bash "$S/stage-unit.sh" plans/demo 2b 2>&1)"
eq  "stage-unit: nothing staged on block" "" "$(g git diff --cached --name-only)"
g sedi 's#^None yet\.$#- TASK-022 (REQ-003): also touched src/other.ts for a shared helper.#' plans/demo/feature-demo-tasks.md
eq  "stage-unit: stray logged under Differences is allowed" 0 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
eq  "stage-unit: unknown unit fails"   1 "$(g bash "$S/stage-unit.sh" plans/demo 9 >/dev/null 2>&1; echo $?)"
g git reset -q; mkdir -p "$R/plans/demo/reports/phase-2"
echo p > "$R/plans/demo/reports/phase-2/.ids-part1.md"
eq  "stage-unit: dotfile in reports blocks"  1 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
has "stage-unit: names the dotfile"          "plans/demo/reports/phase-2/.ids-part1.md" "$(g bash "$S/stage-unit.sh" plans/demo 2b 2>&1)"
rm "$R/plans/demo/reports/phase-2/.ids-part1.md"; echo p > "$R/plans/demo/reports/phase-2/conformance.md.part2"
eq  "stage-unit: .part file in reports blocks" 1 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"
rm -r "$R/plans/demo/reports"
eq  "stage-unit: restaged after cleanup"     0 "$(g bash "$S/stage-unit.sh" plans/demo 2b >/dev/null 2>&1; echo $?)"

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
printf 'a\nb %s%s scan:allow\nc\n' "ghp_" "abcdefghijklmnopqrstuvwxyz0123456789" > "$TMP/body2.md"
eq  "scan: --file honours scan:allow"  0 "$(bash "$S/scan-staged.sh" --file "$TMP/body2.md" >/dev/null 2>&1; echo $?)"
printf 'one\ntwo\nthree\nk = "%s%s"\n' "AKIA" "ABCDEFGHIJKLMNOP" > "$R/src/multi.js"; echo "x" > "$R/src/clean.js"; g git add src/multi.js src/clean.js
eq  "scan: finds a key on a later line" 1 "$(sc)"
has "scan: names the right file and line" "HIGH src/multi.js:4: looks like a AWS access key" "$(cat "$TMP/scan")"
g git reset -q; rm -f "$R/src/clean.js" "$R/src/conf.py" "$R/src/multi.js"

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
awk '{ print } /^\| REQ-001 \| TASK-011 \|$/ { print "| SEC-001 | TASK-021, TASK-024 |" }' "$T" > "$T.new" && mv "$T.new" "$T"
eq  "fix-unit: traceability rows allowed" 0 "$(fu check 2c >/dev/null; echo $?)"
sedi 's/| TASK-023 | Document flags./| TASK-023 | Document all flags./' "$T"
eq  "fix-unit: edited old unit fails"  1 "$(fu check 2c >/dev/null; echo $?)"
has "fix-unit: names the changed unit" "changed section: ## Phase 2b: Name" "$(fu check 2c)"
g git checkout -q -- plans/demo
add_unit '^## Requirement traceability' 2c
has "fix-unit: unit after phase 3 fails" "must come before ## Phase 3: Ship" "$(fu check 2c)"
g git checkout -q -- plans/demo
add_unit '^## Phase 3:' 2d
eq  "fix-unit: wrong id fails"         1 "$(fu check 2c >/dev/null; echo $?)"
g git checkout -q -- plans/demo

# tick-unit.sh with a base: only the unit's own tasks may be ticked
R4="$TMP/repo-tick"; mkdir -p "$R4/plans/demo"
cp "$FX/valid/feature-demo-spec.md" "$R4/plans/demo/"; sed "$untick_all" "$VALID" > "$R4/plans/demo/feature-demo-tasks.md"
( cd "$R4" && git init -q -b master && git add -A && git commit -qm init )
tb() { bash "$S/tick-unit.sh" "$R4/plans/demo" "$1" HEAD 2>&1; }
( cd "$R4" && sedi "$(tick TASK-022);$(tick TASK-023)" plans/demo/feature-demo-tasks.md )
eq  "tick-unit base: own unit ticked, nothing foreign" 0 "$(tb 2b >/dev/null; echo $?)"
( cd "$R4" && sedi "$(tick TASK-030)" plans/demo/feature-demo-tasks.md )
has "tick-unit base: names the foreign tick" "foreign tick: TASK-030" "$(tb 2b)"
eq  "tick-unit base: foreign tick exits 1" 1 "$(tb 2b >/dev/null; echo $?)"

# check-report.sh
printf 'x\n\nverdict: pass\n' > "$TMP/rep-ok.md"; : > "$TMP/rep-empty.md"; printf 'no summary here\n' > "$TMP/rep-bad.md"
eq  "check-report: good report"    0 "$(bash "$S/check-report.sh" "$TMP/rep-ok.md" >/dev/null; echo $?)"
eq  "check-report: missing file"   1 "$(bash "$S/check-report.sh" "$TMP/nope.md" >/dev/null; echo $?)"
eq  "check-report: empty file"     1 "$(bash "$S/check-report.sh" "$TMP/rep-empty.md" >/dev/null; echo $?)"
eq  "check-report: no verdict"     1 "$(bash "$S/check-report.sh" "$TMP/rep-bad.md" >/dev/null; echo $?)"
CR="$TMP/cr"; mkdir -p "$CR"
cr() { printf "$1" > "$CR/r.md"; bash "$S/check-report.sh" "$CR/r.md"; }
eq  "check-report: bold verdict line"        0 "$(cr '# R\n**verdict:** fail\n' >/dev/null; echo $?)"
eq  "check-report: skeleton (pending) fails" 1 "$(cr '# R\nverdict: pending\n' >/dev/null; echo $?)"
has "check-report: says incomplete"          "incomplete" "$(cr '# R\nverdict: pending\n')"
eq  "check-report: pending left beside a verdict fails" 1 "$(cr 'verdict: pending\nSUMMARY\nverdict: pass\n' >/dev/null; echo $?)"
eq  "check-report: pass and fail disagree"   1 "$(cr 'verdict: pass\nSUMMARY\nverdict: fail\n' >/dev/null; echo $?)"
# R67: the verdict follows the p0/p1 counts.
eq  "check-report: fail with p0=p1=0 rejected"  1 "$(cr 'SUMMARY\nverdict: fail\np0: 0\np1: 0\np2: 2\n' >/dev/null; echo $?)"
has "check-report: says the verdict is pass"    "verdict is pass" "$(cr 'SUMMARY\nverdict: fail\np0: 0\np1: 0\np2: 2\n')"
eq  "check-report: pass with p1=1 rejected"     1 "$(cr 'SUMMARY\nverdict: pass\np0: 0\np1: 1\np2: 0\n' >/dev/null; echo $?)"
eq  "check-report: fail with p1=1 accepted"     0 "$(cr 'SUMMARY\nverdict: fail\np0: 0\np1: 1\np2: 0\n' >/dev/null; echo $?)"
eq  "check-report: pass with p2 only accepted"  0 "$(cr 'SUMMARY\nverdict: pass\np0: 0\np1: 0\np2: 3\n' >/dev/null; echo $?)"
eq  "check-report: only a prose verdict fails" 1 "$(cr '**Verdict:** conforms with gaps\n' >/dev/null; echo $?)"
eq  "check-report: prose verdict plus SUMMARY" 0 "$(cr '**Verdict:** conforms\nSUMMARY\nverdict: pass\n' >/dev/null; echo $?)"
eq  "check-report: top: item above its count fails" 1 "$(cr 'SUMMARY\nverdict: pass\np0: 0\np1: 0\np2: 0\ntop:\n- F01 [P2] x.md:1 thing\n' >/dev/null; echo $?)"
has "check-report: names the count"           "p2: 1 listed" "$(cr 'SUMMARY\nverdict: pass\np0: 0\np1: 0\np2: 0\ntop:\n- F01 [P2] x.md:1 thing\n')"
eq  "check-report: counts covering top: pass" 0 "$(cr 'SUMMARY\nverdict: fail\np0: 0\np1: 2\np2: 1\ntop:\n- F01 [P1] a\n- F02 [P1] b\n' >/dev/null; echo $?)"
echo x > "$CR/.ids-part1.md"
eq  "check-report: scratch file beside it fails" 1 "$(cr 'verdict: pass\n' >/dev/null; echo $?)"
has "check-report: names the scratch file"   ".ids-part1.md" "$(cr 'verdict: pass\n')"
rm "$CR/.ids-part1.md"; echo x > "$CR/conformance.md.part2"
eq  "check-report: .part file beside it fails" 1 "$(cr 'verdict: pass\n' >/dev/null; echo $?)"
rm "$CR/conformance.md.part2"

# run-stats.sh (R40)
mkplan stats ""
mkdir -p "$TMP/stats/reports/phase-2" "$TMP/stats/reports/phase-1"
touch "$TMP/stats/reports/phase-2/review-2a.md" "$TMP/stats/reports/phase-2/review-2a-2.md" "$TMP/stats/reports/phase-2/review-2b.md" "$TMP/stats/reports/phase-1/review-1.md"
for r in "unit-1 commit" "unit-2a fix-round" "unit-2a restart" "unit-2a commit" "phase-2 add-unit" "unit-2b stop"; do
  bash "$S/log-decision.sh" "$TMP/stats" ${r% *} ${r#* } why ev res
done
rs=$(bash "$S/run-stats.sh" "$TMP/stats")
has "run-stats: unit 1 one review, committed" "unit 1: reviews 1, fix rounds 0, restarts 0, committed yes" "$rs"
has "run-stats: 2a reviews -2 counted, round, restart" "unit 2a: reviews 2, fix rounds 1, restarts 1, committed yes" "$rs"
has "run-stats: 2b not committed"           "unit 2b: reviews 1, fix rounds 0, restarts 0, committed no" "$rs"
has "run-stats: units line"                 "units: 2 committed of 4" "$rs"
has "run-stats: totals"                     "fix rounds: 1   restarts: 1   added units: 1   stops: 1" "$rs"
eq  "run-stats: no decisions.tsv still works" 0 "$(bash "$S/run-stats.sh" "$TMP/fresh" >/dev/null; echo $?)"

# approve.sh spec stamps the spec Approved
mkdir -p "$TMP/specap"; printf -- "---
title: Demo
status: 'Draft'
---

# Spec
" > "$TMP/specap/feature-demo-spec.md"
printf "![Status: Draft](https://img.shields.io/badge/status-Draft-lightgrey)\nstatus: Draft in the body\n" >> "$TMP/specap/feature-demo-spec.md"
bash "$S/approve.sh" "$TMP/specap" spec >/dev/null
has "approve: spec front matter Approved" "status: 'Approved'" "$(head -12 "$TMP/specap/feature-demo-spec.md")"
has "approve: spec badge Approved" "![Status: Approved](https://img.shields.io/badge/status-Approved-green)" "$(cat "$TMP/specap/feature-demo-spec.md")"
has "approve: spec body left alone" "status: Draft in the body" "$(cat "$TMP/specap/feature-demo-spec.md")"

# unit-gate.sh
ug() { g bash "$S/unit-gate.sh" plans/demo HEAD "$@" 2>&1; }
eq  "unit-gate: clean unit passes"        "gate: no" "$(ug 0 0 | tail -1)"
has "unit-gate: no TEST_CMD says not run"  "tests: not run" "$(ug 0 0)"
has "unit-gate: green TEST_CMD runs"       "tests: green (true)" "$(TEST_CMD=true ug 0 0)"
eq  "unit-gate: red TEST_CMD exits 4"      4 "$(TEST_CMD='echo boom; false' ug 0 0 >/dev/null; echo $?)"
has "unit-gate: red shows the output"      "boom" "$(TEST_CMD='echo boom; false' ug 0 0)"
eq  "unit-gate: red decides nothing"       "" "$(TEST_CMD=false ug 1 0 | grep '^gate:')"
has "unit-gate: fix round gates"          "reason: 1 fix round(s) ran" "$(ug 1 0)"
eq  "unit-gate: fix round says yes"       "gate: yes" "$(ug 1 0 | tail -1)"
has "unit-gate: green mutation gates"     "reason: 2 mutation(s) stayed green" "$(ug 0 2)"
printf 'SUMMARY\nverdict: pass\nmutations: 10 run, 0 still green\n' > "$TMP/rv0.md"
printf 'SUMMARY\nverdict: pass\nmutations: 13, 2 still green\n' > "$TMP/rv2.md"
printf 'SUMMARY\nverdict: pass\n' > "$TMP/rvnone.md"
eq  "unit-gate: report with 0 green passes" "gate: no" "$(ug 0 "$TMP/rv0.md" | tail -1)"
has "unit-gate: reads still green from the report" "reason: 2 mutation(s) stayed green" "$(ug 0 "$TMP/rv2.md")"
eq  "unit-gate: report without mutations line fails" 1 "$(ug 0 "$TMP/rvnone.md" >/dev/null; echo $?)"
echo '- TASK-021 (SEC-001): test input cut to a"b.' >> "$T"
has "unit-gate: names the new difference" 'reason: difference logged: - TASK-021 (SEC-001): test input cut to a"b.' "$(ug 0 0)"
eq  "unit-gate: difference says yes"      "gate: yes" "$(ug 0 0 | tail -1)"
eq  "unit-gate: off never gates"          "gate: no" "$(UNIT_GATE=off ug 1 0 | tail -1)"
mkdir -p "$R/plans/demo/approvals" && touch "$R/plans/demo/approvals/afk"
eq  "unit-gate: AFK never gates"          "gate: no" "$(ug 0 0 | tail -1)"
rm -f "$R/plans/demo/approvals/afk"
g git checkout -q -- plans/demo
eq  "unit-gate: always gates clean unit"  "gate: yes" "$(UNIT_GATE=always ug 0 0 | tail -1)"
eq  "unit-gate: bad mode fails"           1 "$(UNIT_GATE=sometimes ug 0 0 >/dev/null; echo $?)"
eq  "unit-gate: bad base fails"           1 "$(g bash "$S/unit-gate.sh" plans/demo nope 0 0 >/dev/null 2>&1; echo $?)"

# scratch-copy.sh
echo wip > "$R/src/wip.js"
SC="$TMP/scratch1"
eq  "scratch-copy: copies the working tree" "wip" "$(g bash "$S/scratch-copy.sh" "$SC" >/dev/null && cat "$SC/src/wip.js")"
eq  "scratch-copy: ignored dirs skipped"    "no" "$([ -d "$SC/.git" ] && echo yes || echo no)"
eq  "scratch-copy: --base has no new file"  "no" "$(g bash "$S/scratch-copy.sh" "$TMP/scratch2" --base HEAD >/dev/null && { [ -e "$TMP/scratch2/src/wip.js" ] && echo yes || echo no; })"
eq  "scratch-copy: existing dest fails"     1 "$(g bash "$S/scratch-copy.sh" "$SC" >/dev/null 2>&1; echo $?)"
eq  "scratch-copy: dest under / fails (unset TMPDIR)" 1 "$(g bash "$S/scratch-copy.sh" /mut-zz-pipeline-test >/dev/null 2>&1; echo $?)"
eq  "scratch-copy: nothing made under /"   "no" "$([ -e /mut-zz-pipeline-test ] && echo yes || echo no)"
eq  "scratch-copy: dest inside the repo fails" 1 "$(g bash "$S/scratch-copy.sh" "$R/src/mut-1a" >/dev/null 2>&1; echo $?)"
has "scratch-copy: says why"                "inside the repo" "$(g bash "$S/scratch-copy.sh" "$R/mut-1a" 2>&1)"

# ---- import-plan.sh (bring your own spec and tasks) ----
RI="$TMP/repo-import"; mkdir -p "$RI/plans" "$RI/src"
printf 'My spec\r\nThe tool prints hello.\r\n' > "$RI/src/my-spec.md"
printf 'My tasks\n1. print hello\n' > "$RI/src/my-tasks.md"
( cd "$RI" && git init -q -b master && git add -A && git commit -qm init )
gi() { ( cd "$RI" && "$@" ); }
ip() { gi bash "$S/import-plan.sh" "$@" >/dev/null 2>&1; echo $?; }
eq  "import: missing source fails"        1 "$(ip plans/imp src/nope.md src/my-tasks.md)"
eq  "import: same file twice fails"       1 "$(ip plans/imp src/my-spec.md src/my-spec.md)"
eq  "import: bad feature name fails"      1 "$(ip plans/Bad_Name src/my-spec.md src/my-tasks.md)"
eq  "import: copies the files"            0 "$(ip plans/imp src/my-spec.md src/my-tasks.md)"
eq  "import: spec copied, CR stripped"    "My spec;The tool prints hello.;" "$(tr '\n' ';' < "$RI/plans/imp/feature-imp-spec.md")"
eq  "import: tasks copied"                "My tasks;1. print hello;" "$(tr '\n' ';' < "$RI/plans/imp/feature-imp-tasks.md")"
has "import: brief is marked imported"    "source: imported" "$(cat "$RI/plans/imp/feature-imp-brief.md")"
has "import: brief is a draft"            "status: draft" "$(cat "$RI/plans/imp/feature-imp-brief.md")"
eq  "import: source files untouched"      "My spec;The tool prints hello.;" "$(tr -d '\r' < "$RI/src/my-spec.md" | tr '\n' ';')"
eq  "import: never overwrites a plan"     1 "$(ip plans/imp src/my-spec.md src/my-tasks.md)"
sti() { gi bash "$S/status.sh" plans/imp | grep '^import:'; }
eq  "status: imported plan, spec reformat due" "import: spec" "$(sti)"
eq  "status: imported brief is written"   "brief: written" "$(gi bash "$S/status.sh" plans/imp | grep '^brief:')"
eq  "import --diff: no tag fails"         1 "$(ip --diff plans/imp spec)"
gi bash "$S/approve.sh" plans/imp brief >/dev/null
has "import: approve keeps source line"   "source: imported" "$(cat "$RI/plans/imp/feature-imp-brief.md")"
gi git add plans/imp; gi git commit -qm import; gi git tag imp-imported
printf -- "---\nstatus: 'Draft'\n---\n# Spec\n- REQ-001: The tool prints hello.\n" > "$RI/plans/imp/feature-imp-spec.md"
eq  "import --diff: uncommitted change fails" 1 "$(ip --diff plans/imp spec)"
gi git add plans/imp; gi git commit -qm reformat
eq  "import --diff: bad stage fails"      1 "$(ip --diff plans/imp final)"
D=$(gi bash "$S/import-plan.sh" --diff plans/imp spec | head -1)
eq  "import --diff: report path"          "plans/imp/reports/spec/import-diff.md" "$D"
has "import --diff: holds the user's line" "-The tool prints hello." "$(cat "$RI/$D")"
has "import --diff: holds the writer's line" "+- REQ-001: The tool prints hello." "$(cat "$RI/$D")"
eq  "status: spec reformat done, spec not approved" "import: done" "$(sti)"
gi bash "$S/approve.sh" plans/imp spec >/dev/null
eq  "status: spec approved, tasks reformat due" "import: tasks" "$(sti)"
has "import --diff: unchanged tasks say so" "No changes" "$(cat "$RI/$(gi bash "$S/import-plan.sh" --diff plans/imp tasks | head -1)")"
cp "$FX/valid/feature-demo-tasks.md" "$RI/plans/imp/feature-imp-tasks.md"   # as a reformat leaves it
eq  "status: both reformats done"         "import: done" "$(sti)"
has "status: reformatted tasks are parsed" "next: 2a: TASK-021" "$(gi bash "$S/status.sh" plans/imp)"

done_tests
