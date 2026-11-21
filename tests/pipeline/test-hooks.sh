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
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.com GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.com
( cd "$PROJ" && git init -q -b master && git add -A && git commit -qm init && git checkout -q -b feature/demo )

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

# AFK: the previous phase approval is not needed, but its phase end is (R55: tag <feature>-phase-<N>).
rm "$PROJ/plans/demo/approvals/phase-1"
approve demo afk
eq  "spawn: afk without the phase-1 tag blocked" 2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
has "spawn: block names the phase end"           "phase 1 has not ended" "$(cat "$TMP/err")"
( cd "$PROJ" && git tag demo-phase-1 )
eq  "spawn: afk skips the phase approval"        0 "$(spawn implementer "$(P demo '2a: TASK-021')")"
rm "$PROJ/plans/demo/approvals/afk"
eq  "spawn: without afk it is needed again"      2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
approve demo phase-1

# Fix rounds: a fresh implementer for the unit still open at HEAD.
F() { printf 'PLAN: plans/%s\nUNIT: %s\nFIX: %s\nFix only the P0 and P1 findings, the drift and the failing tests named there.' "$1" "$2" "$3"; }
mkdir -p "$PROJ/plans/demo/reports/phase-2"; echo "F01" > "$PROJ/plans/demo/reports/phase-2/review-2a.md"
sedi 's/\(| TASK-021 |.*\)| \[ \] | |$/\1| [x] | 2026-11-15 |/' "$PROJ/plans/demo/feature-demo-tasks.md"
RV=plans/demo/reports/phase-2/review-2a.md
eq  "fix: unit built but uncommitted allowed"    0 "$(spawn implementer "$(F demo '2a: TASK-021' "$RV")")"
eq  "fix: plain spawn of 2a now blocked"         2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
eq  "fix: other unit blocked"                    2 "$(spawn implementer "$(F demo '2b: TASK-022 TASK-023' "$RV")")"
has "fix: block names the unit in progress"      "only for the unit in progress (2a)" "$(cat "$TMP/err")"
eq  "fix: missing FIX file blocked"              2 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/nope.md)")"
eq  "fix: FIX outside reports blocked"           2 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/feature-demo-tasks.md)")"
eq  "fix: FIX with .. blocked"                   2 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/../feature-demo-tasks.md)")"
eq  "fix: ALSO line allowed"                     0 "$(spawn implementer "$(F demo '2a: TASK-021' "$RV")
ALSO: plans/demo/reports/phase-2/tests-2a.md")"
eq  "fix: free-text padding blocked"             2 "$(spawn implementer "$(F demo '2a: TASK-021' "$RV") Also read the tests file.")"
# R63: MAX_LOOPS is counted by the hook: one round per distinct FIX file of the unit at this HEAD.
for n in 2 3 4; do echo "F01" > "$PROJ/plans/demo/reports/phase-2/review-2a-$n.md"; done
echo "x" > "$PROJ/plans/demo/reports/phase-2/unit-changes-2a.md"
eq  "loops: second fix round allowed"            0 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/review-2a-2.md)")"
eq  "loops: third fix round blocked"             2 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/review-2a-3.md)")"
has "loops: block names MAX_LOOPS and the marker" "MAX_LOOPS=2" "$(cat "$TMP/err")"
has "loops: block names approve loop-2a"         "approve.sh plans/demo loop-2a" "$(cat "$TMP/err")"
eq  "loops: restart of round 2 (same FIX) allowed" 0 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/review-2a-2.md)")"
eq  "loops: unit-changes round not counted"      0 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/unit-changes-2a.md)")"
approve demo loop-2a
eq  "loops: loop-2a marker allows one more"      0 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/review-2a-3.md)")"
eq  "loops: marker used up"                      no "$([ -e "$PROJ/plans/demo/approvals/loop-2a" ] && echo yes || echo no)"
eq  "loops: the next round is blocked again"     2 "$(spawn implementer "$(F demo '2a: TASK-021' plans/demo/reports/phase-2/review-2a-4.md)")"
( cd "$PROJ" && git checkout -q -- plans/demo/feature-demo-tasks.md )

# ---- prompt padding (R37): only the template lines ----
eq  "pad: implementer template in a code fence allowed" 0 "$(spawn implementer "$(printf '```\n%s\n```' "$(P demo '2a: TASK-021')")")"
eq  "pad: implementer with a Rules: block blocked"      2 "$(spawn implementer "$(P demo '2a: TASK-021')
Rules: touch only src/name.ts.")"
has "pad: block names the extra line"                   "remove: Rules: touch only src/name.ts." "$(cat "$TMP/err")"
CR='PLAN: plans/demo
UNIT: 2a: TASK-021
BASE: abc123
REPORT: plans/demo/reports/phase-2/review-2a.md
Review the staged change (git diff --cached BASE).'
eq  "pad: code-reviewer template allowed"               0 "$(spawn code-reviewer "$CR")"
eq  "pad: code-reviewer with RECHECK and PARTIAL allowed" 0 "$(spawn code-reviewer "$CR
RECHECK: plans/demo/reports/phase-2/review-2a.md
PARTIAL: plans/demo/reports/phase-2/review-2a-2.md")"
eq  "pad: code-reviewer with a scope note blocked"      2 "$(spawn code-reviewer "$CR
Note on scope: also check bin/greet.js.")"
eq  "pad: code-reviewer outside a pipeline run allowed" 0 "$(spawn code-reviewer "Review my uncommitted change to src/a.js.")"
SM='PLAN: plans/demo --phase 2
REPORT: plans/demo/reports/phase-2/conformance.md
DECISIONS: plans/demo/decisions.tsv'
eq  "pad: spec-matcher template allowed"                0 "$(spawn spec-matcher "$SM")"
eq  "pad: spec-matcher with extra rules blocked"        2 "$(spawn spec-matcher "$SM
Keep the report under 100 lines.")"

# ---- resumes (R34): SendMessage / send_message blocked ----
resume() { "$JQ" -n --arg t "$1" '{hook_event_name:"PreToolUse",tool_name:$t,tool_input:{to:"a1b2c3",message:"finish your report"}}' |
  CLAUDE_PROJECT_DIR="$PROJ" bash "$H/check-spawn.sh" 2>"$TMP/err"; echo $?; }
eq  "resume: SendMessage blocked"                2 "$(resume SendMessage)"
has "resume: block names the recovery"           "PARTIAL:" "$(cat "$TMP/err")"
eq  "resume: send_message (dostuff) blocked"     2 "$(resume send_message)"
eq  "resume: PIPELINE_ALLOW_RESUME=1 allows it"  0 "$(PIPELINE_ALLOW_RESUME=1 resume SendMessage)"
eq  "resume: blocked without jq too"             2 "$("$JQ" -n '{tool_name:"send_message",tool_input:{to:"x"}}' | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-spawn.sh" 2>/dev/null; echo $?)"

# Default branch.
( cd "$PROJ" && git checkout -q master )
eq  "spawn: on the default branch blocked"       2 "$(spawn implementer "$(P demo '2a: TASK-021')")"
has "spawn: block names branch.sh"               "branch.sh" "$(cat "$TMP/err")"
( cd "$PROJ" && git checkout -q feature/demo )
eq  "spawn: on the feature branch allowed"       0 "$(spawn implementer "$(P demo '2a: TASK-021')")"

# ---- check-spawn.sh: spec-writer needs an agreed brief ----
mkdir -p "$PROJ/plans/newfeat"
printf -- '---\nfeature: newfeat\nstatus: draft\n---\n# Brief\n' > "$PROJ/plans/newfeat/feature-newfeat-brief.md"
SW='PLAN: plans/newfeat
Brief: plans/newfeat/feature-newfeat-brief.md (agreed with the user; its decisions are binding)
Write the spec.'
eq  "spec-writer: no brief approval blocked"     2 "$(spawn spec-writer "$SW")"
has "spec-writer: block names the brief"         "brief is not agreed" "$(cat "$TMP/err")"
eq  "spec-writer: missing PLAN line blocked"     2 "$(spawn spec-writer "Write a spec for newfeat")"
approve newfeat brief
eq  "spec-writer: agreed brief allowed"          0 "$(spawn spec-writer "$SW")"
eq  "spec-writer: does not need a UNIT line"     0 "$(spawn spec-writer "$SW")"
# R46: writers and verifiers get the templates only.
eq  "pad: spec-writer fix round allowed"         0 "$(spawn spec-writer "PLAN: plans/newfeat
Brief: plans/newfeat/feature-newfeat-brief.md
FIX: plans/newfeat/reports/spec/fix-scope.md
Fix only the P0 and P1 findings in that file.")"
eq  "pad: spec-writer change file allowed"       0 "$(spawn spec-writer "PLAN: plans/newfeat
FIX: plans/newfeat/reports/spec/changes.md
Apply the changes in that file.")"
eq  "import: spec-writer reformat allowed"      0 "$(spawn spec-writer "PLAN: plans/newfeat
Brief: plans/newfeat/feature-newfeat-brief.md (agreed with the user; its decisions are binding)
Reformat the imported spec.")"
eq  "import: task-writer reformat allowed"      0 "$(spawn task-writer "PLAN: plans/newfeat. Reformat the imported tasks file.")"
eq  "import: task-writer reformat with extra blocked" 2 "$(spawn task-writer "PLAN: plans/newfeat. Reformat the imported tasks file.
Keep the units small.")"
eq  "pad: spec-writer with finding text blocked" 2 "$(spawn spec-writer "$SW
For the Q-2 resolution, the decision is yours to make as the spec author.")"
eq  "pad: spec-verifier template allowed"        0 "$(spawn spec-verifier "spec plans/newfeat
REPORT: plans/newfeat/reports/spec/review-2.md
RECHECK: plans/newfeat/reports/spec/review.md")"
eq  "pad: spec-verifier with extra rules blocked" 2 "$(spawn spec-verifier "spec plans/newfeat
REPORT: plans/newfeat/reports/spec/review-3.md
Keep the report short. Do not print your reasoning outside the report.")"
eq  "pad: spec-verifier outside a run allowed"   0 "$(spawn spec-verifier "Review my spec draft in docs/spec.md")"
eq  "pad: task-verifier template allowed"        0 "$(spawn task-verifier "tasks plans/newfeat
UNIT: 2c
REPORT: plans/newfeat/reports/phase-2/fix-unit-review.md")"
eq  "pad: task-verifier with extra rules blocked" 2 "$(spawn task-verifier "tasks plans/newfeat
REPORT: plans/newfeat/reports/tasks/review.md
Keep the report under 60 lines.")"
eq  "pad: task-writer write template allowed"    0 "$(spawn task-writer "PLAN: plans/newfeat. Write the tasks file from the approved spec.")"
eq  "pad: task-writer auto-fix template allowed" 0 "$(spawn task-writer 'PLAN: plans/newfeat. Add one unit "## Phase 2c: Auto-fix usage line" for the P0 and P1 gaps in plans/newfeat/reports/phase-2/conformance.md, placed after phase 2'"'"'s last unit, depending on phase 2'"'"'s units, at most 2 tasks. Add traceability rows for its tasks. Change nothing else.')"
eq  "pad: task-writer fix round allowed"         0 "$(spawn task-writer "PLAN: plans/newfeat
FIX: plans/newfeat/reports/tasks/review.md
Fix only the P0 and P1 findings in that file.")"
eq  "pad: task-writer with extra rules blocked"  2 "$(spawn task-writer "PLAN: plans/newfeat
FIX: plans/newfeat/reports/tasks/review.md
Fix only the P0 and P1 findings in that file.
F05: use a directory as the unreadable config.")"
eq  "spawn: no jq still lets other agents through" 0 "$(spawn_json Explore x | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-spawn.sh" 2>/dev/null; echo $?)"
eq  "spawn: no jq blocks a gated spawn"          2 "$(spawn_json implementer x | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-spawn.sh" 2>/dev/null; echo $?)"

# ---- check-write.sh (R42, R43): the orchestrator does not write agents' files in a plan dir ----
wr() { # tool path [agent_type]
  "$JQ" -n --arg t "$1" --arg p "$2" --arg a "${3:-}" --arg cwd "$PROJ" \
    '{hook_event_name:"PreToolUse",tool_name:$t,cwd:$cwd,tool_input:{file_path:$p,content:"x"}} + (if $a == "" then {} else {agent_type:$a,agent_id:"a1"} end)' |
    CLAUDE_PROJECT_DIR="$PROJ" bash "$H/check-write.sh" 2>"$TMP/err"; echo $?
}
NF=plans/newfeat
eq  "write: main session, agent report blocked"        2 "$(wr Write $NF/reports/phase-2/conformance.md)"
has "write: block points to the restart"               "PARTIAL:" "$(cat "$TMP/err")"
eq  "write: main session, review edit blocked"         2 "$(wr Edit $NF/reports/phase-1/review-1a.md)"
eq  "write: main session, spec blocked"                2 "$(wr Edit $NF/feature-newfeat-spec.md)"
has "write: spec block names spec-writer"              "spec-writer" "$(cat "$TMP/err")"
eq  "write: main session, tasks blocked"               2 "$(wr MultiEdit $NF/feature-newfeat-tasks.md)"
eq  "write: absolute path blocked"                     2 "$(wr Write "$PROJ/$NF/reports/spec/review-2.md")"
winp() { if command -v cygpath >/dev/null 2>&1; then cygpath -w "$1"; else printf '%s' "$1" | tr / '\'; fi; }
eq  "write: Windows-style path blocked"                2 "$(wr Write "$(winp "$PROJ/$NF/reports/spec/review.md")")"
eq  "write: backslash path blocked"                    2 "$(wr Write "$(printf '%s' "$PROJ/$NF/reports/spec/review.md" | tr / '\')")"
eq  "write: dostuff path key blocked"                  2 "$("$JQ" -n --arg cwd "$PROJ" --arg p "$NF/reports/final/conformance.md" '{tool_name:"write_file",cwd:$cwd,tool_input:{path:$p,content:"x"}}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$H/check-write.sh" 2>/dev/null; echo $?)"
eq  "write: phase report allowed"                      0 "$(wr Write $NF/reports/phase-1/report.md)"
eq  "write: phase report re-run allowed"               0 "$(wr Write $NF/reports/phase-1/report-2.md)"
eq  "write: final report allowed"                      0 "$(wr Edit $NF/reports/final/report.md)"
eq  "write: change file allowed"                       0 "$(wr Write $NF/reports/spec/changes-2.md)"
eq  "write: fix-scope file allowed"                    0 "$(wr Write $NF/reports/spec/fix-scope.md)"
eq  "write: tests and guidance files allowed"          00 "$(wr Write $NF/reports/phase-2/tests-2a.md)$(wr Write $NF/reports/phase-2/guidance-2a.md)"
eq  "write: PR body allowed"                           0 "$(wr Write $NF/reports/final/pr-body.md)"
eq  "write: brief allowed"                             0 "$(wr Edit $NF/feature-newfeat-brief.md)"
eq  "write: subagent writes its report"                0 "$(wr Write $NF/reports/phase-2/conformance.md spec-matcher)"
eq  "write: subagent writes the spec"                  0 "$(wr Edit $NF/feature-newfeat-spec.md spec-writer)"
# R68: each pipeline agent writes only its own files in a plan dir (run 12: a task-writer rewrote the review).
eq  "scope: task-writer edits the tasks file"          0 "$(wr Edit $NF/feature-newfeat-tasks.md task-writer)"
eq  "scope: task-writer edits a review blocked"        2 "$(wr Edit $NF/reports/tasks/review.md task-writer)"
has "scope: block says reports are evidence"           "evidence" "$(cat "$TMP/err")"
eq  "scope: task-writer edits the spec blocked"        2 "$(wr Edit $NF/feature-newfeat-spec.md task-writer)"
has "scope: block names Spec changes needed"           "Spec changes needed:" "$(cat "$TMP/err")"
eq  "scope: dostuff task-writer write_file blocked"    2 "$("$JQ" -n --arg cwd "$PROJ" --arg p "$NF/reports/tasks/review.md" '{tool_name:"write_file",cwd:$cwd,agent_type:"task-writer",tool_input:{path:$p,content:"x"}}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$H/check-write.sh" 2>/dev/null; echo $?)"
eq  "scope: task-writer deletes a review blocked"      2 "$("$JQ" -n --arg cwd "$PROJ" --arg p "$NF/reports/tasks/review.md" '{tool_name:"delete_file",cwd:$cwd,agent_type:"task-writer",tool_input:{path:$p}}' | CLAUDE_PROJECT_DIR="$PROJ" bash "$H/check-write.sh" 2>/dev/null; echo $?)"
eq  "scope: spec-writer edits a review blocked"        2 "$(wr Edit $NF/reports/spec/review-2.md spec-writer)"
eq  "scope: spec-writer edits the tasks file blocked"  2 "$(wr Edit $NF/feature-newfeat-tasks.md spec-writer)"
eq  "scope: implementer ticks the tasks file"          0 "$(wr Edit $NF/feature-newfeat-tasks.md implementer)"
eq  "scope: implementer edits a review blocked"        2 "$(wr Edit $NF/reports/phase-1/review-1a.md implementer)"
eq  "scope: implementer edits the spec blocked"        2 "$(wr Edit $NF/feature-newfeat-spec.md implementer)"
eq  "scope: implementer writes source"                 0 "$(wr Write src/a.js implementer)"
eq  "scope: verifier writes its report"                0 "$(wr Write $NF/reports/tasks/review-2.md task-verifier)"
eq  "scope: verifier edits the tasks file blocked"     2 "$(wr Edit $NF/feature-newfeat-tasks.md task-verifier)"
eq  "scope: reviewer edits the spec blocked"           2 "$(wr Edit $NF/feature-newfeat-spec.md code-reviewer)"
eq  "scope: other subagent gets the orchestrator rules" 2 "$(wr Write $NF/reports/tasks/review.md general-purpose)"
eq  "scope: other subagent writes the brief"           0 "$(wr Edit $NF/feature-newfeat-brief.md general-purpose)"
eq  "scope: no jq blocks a writer's report write"      2 "$("$JQ" -n --arg p "$NF/reports/tasks/review.md" '{tool_name:"Edit",agent_type:"task-writer",tool_input:{file_path:$p}}' | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-write.sh" 2>/dev/null; echo $?)"
eq  "scope: no jq lets a verifier write its report"    0 "$("$JQ" -n --arg p "$NF/reports/tasks/review.md" '{tool_name:"Write",agent_type:"task-verifier",tool_input:{file_path:$p}}' | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-write.sh" 2>/dev/null; echo $?)"
eq  "write: source files not checked"                  0 "$(wr Write src/a.js)"
eq  "write: plan without an agreed brief not checked"  0 "$(wr Write plans/fresh/reports/phase-1/review-1.md)"
eq  "write: PIPELINE_ALLOW_WRITE=1 allows"             0 "$(PIPELINE_ALLOW_WRITE=1 wr Write $NF/feature-newfeat-spec.md)"
eq  "write: no jq blocks a main-session report write"  2 "$("$JQ" -n --arg p "$NF/reports/x/review.md" '{tool_name:"Write",tool_input:{file_path:$p}}' | PATH=/usr/bin:/bin LOCALAPPDATA=/nonexistent "$(command -v bash)" "$H/check-write.sh" 2>/dev/null; echo $?)"

# ---- check-write.sh (R52): the orchestrator does not change the config while a run is open ----
cfg() { # [agent_type] [project]
  "$JQ" -n --arg a "${1:-}" --arg cwd "${2:-$PROJ}" \
    '{hook_event_name:"PreToolUse",tool_name:"edit_config",cwd:$cwd,tool_input:{old_str:"opus: inherit",new_str:"opus: x/y",scope:"project"}} + (if $a == "" then {} else {agent_type:$a,agent_id:"a1"} end)' |
    CLAUDE_PROJECT_DIR="${2:-$PROJ}" bash "$H/check-write.sh" 2>"$TMP/err"; echo $?
}
eq  "config: edit_config blocked in an open run"       2 "$(cfg)"
has "config: block says the config is the user's"      "are the user's" "$(cat "$TMP/err")"
eq  "config: settings.json write blocked"              2 "$(wr Edit .claude/settings.json)"
eq  "config: pipeline.conf write blocked"              2 "$(wr Write .claude/pipeline.conf)"
eq  "config: dostuff config.yaml write blocked"        2 "$(wr Write "$PROJ/.dostuff/config.yaml")"
eq  "config: subagent edit_config not checked"         0 "$(cfg task-writer)"
eq  "config: other dotfiles not checked"               0 "$(wr Write .claude/notes.md)"
CLOSED="$TMP/closed"; mkdir -p "$CLOSED/plans/old/approvals"; : > "$CLOSED/plans/old/approvals/brief"; : > "$CLOSED/plans/old/approvals/final"
eq  "config: edit_config allowed when every run is closed" 0 "$(cfg "" "$CLOSED")"
eq  "config: edit_config allowed with no plans"        0 "$(cfg "" "$TMP/tmp")"

# ---- check-spawn.sh (R53): one restart per agent run ----
mkdir -p "$PROJ/plans/rs/approvals" "$PROJ/plans/rs/reports/tasks"; : > "$PROJ/plans/rs/approvals/brief"
TW="PLAN: plans/rs. Write the tasks file from the approved spec."
eq  "restart: first task-writer allowed"               0 "$(spawn task-writer "$TW")"
eq  "restart: one restart allowed"                     0 "$(spawn task-writer "$TW")"
eq  "restart: third task-writer blocked"               2 "$(spawn task-writer "$TW")"
has "restart: block names the retry approval"          "approve.sh plans/rs retry" "$(cat "$TMP/err")"
bash "$ROOT/.claude/scripts/approve.sh" "$PROJ/plans/rs" retry >/dev/null
eq  "restart: retry approval allows one more"          0 "$(spawn task-writer "$TW")"
eq  "restart: retry marker is used up"                 no "$([ -e "$PROJ/plans/rs/approvals/retry" ] && echo yes || echo no)"
eq  "restart: blocked again after the retry"           2 "$(spawn task-writer "$TW")"
: > "$PROJ/plans/rs/reports/tasks/fix-scope.md"
eq  "restart: a fix-scope round is a new prompt"       0 "$(spawn task-writer "PLAN: plans/rs
FIX: plans/rs/reports/tasks/fix-scope.md
Apply the changes in that file.")"
( cd "$PROJ" && git commit -q --allow-empty -m next )
eq  "restart: a new commit starts the count again"     0 "$(spawn task-writer "$TW")"
# R63: writer FIX rounds from a review count toward MAX_LOOPS across commits; changes files do not.
mkdir -p "$PROJ/plans/rs/reports/spec"
for r in review review-2 review-3 review-4 changes; do echo F01 > "$PROJ/plans/rs/reports/spec/$r.md"; done
SW() { printf 'PLAN: plans/rs
Brief: plans/rs/feature-rs-brief.md
FIX: plans/rs/reports/spec/%s.md
Fix only the P0 and P1 findings in that file.' "$1"; }
eq  "loops: spec round 1 allowed"                0 "$(spawn spec-writer "$(SW review)")"
( cd "$PROJ" && git commit -q --allow-empty -m "spec round" )
eq  "loops: spec round 2 allowed"                0 "$(spawn spec-writer "$(SW review-2)")"
( cd "$PROJ" && git commit -q --allow-empty -m "spec round" )
eq  "loops: spec round 3 blocked"                2 "$(spawn spec-writer "$(SW review-3)")"
has "loops: block names loop-spec"               "approve.sh plans/rs loop-spec" "$(cat "$TMP/err")"
eq  "loops: user's changes file not counted"     0 "$(spawn spec-writer "PLAN: plans/rs
FIX: plans/rs/reports/spec/changes.md
Apply the changes in that file.")"
bash "$ROOT/.claude/scripts/approve.sh" "$PROJ/plans/rs" loop-spec >/dev/null
eq  "loops: loop-spec allows one more"           0 "$(spawn spec-writer "$(SW review-3)")"
eq  "loops: spec round 4 blocked again"          2 "$(spawn spec-writer "$(SW review-4)")"
for r in review review-2 review-3; do echo F01 > "$PROJ/plans/rs/reports/tasks/$r.md"; done
TWF() { printf 'PLAN: plans/rs
FIX: plans/rs/reports/tasks/%s.md
Fix only the P0 and P1 findings in that file.' "$1"; }
eq  "loops: tasks rounds 1-2 allowed"            00 "$(spawn task-writer "$(TWF review)")$(spawn task-writer "$(TWF review-2)")"
eq  "loops: tasks round 3 blocked"               2 "$(spawn task-writer "$(TWF review-3)")"
SV="spec plans/rs"
eq  "restart: verifier allowed"                        0 "$(spawn spec-verifier "$SV
REPORT: plans/rs/reports/spec/review.md")"
eq  "restart: verifier restart with PARTIAL allowed"   0 "$(spawn spec-verifier "$SV
REPORT: plans/rs/reports/spec/review-2.md
PARTIAL: plans/rs/reports/spec/review.md")"
eq  "restart: restart of a restart blocked"            2 "$(spawn spec-verifier "$SV
REPORT: plans/rs/reports/spec/review-3.md
PARTIAL: plans/rs/reports/spec/review-2.md")"
eq  "restart: next round's restart allowed"            00 "$(spawn spec-verifier "$SV
REPORT: plans/rs/reports/spec/review-4.md
RECHECK: plans/rs/reports/spec/review-2.md")$(spawn spec-verifier "$SV
REPORT: plans/rs/reports/spec/review-5.md
RECHECK: plans/rs/reports/spec/review-2.md
PARTIAL: plans/rs/reports/spec/review-4.md")"
# R57: a restart without PARTIAL: still counts; unfinished reports of the same prompt at this HEAD are counted.
TV="tasks plans/rs
RECHECK: plans/rs/reports/tasks/review-4.md"
eq  "restart: recheck verifier allowed"                0 "$(spawn task-verifier "$TV
REPORT: plans/rs/reports/tasks/review-5.md")"
eq  "restart: restart without PARTIAL allowed once"    0 "$(spawn task-verifier "$TV
REPORT: plans/rs/reports/tasks/review-6.md")"
eq  "restart: third without PARTIAL blocked"           2 "$(spawn task-verifier "$TV
REPORT: plans/rs/reports/tasks/review-7.md")"
has "restart: block lists the unfinished reports"      "review-5.md plans/rs/reports/tasks/review-6.md" "$(cat "$TMP/err")"
( cd "$PROJ" && git commit -q --allow-empty -m "docs(rs): plan committed between runs" )
eq  "restart: a commit in between does not reset it"   2 "$(spawn task-verifier "$TV
REPORT: plans/rs/reports/tasks/review-7.md")"
printf 'SUMMARY\nverdict: pass\np0: 0\np1: 0\np2: 0\n' > "$PROJ/plans/rs/reports/tasks/review-5.md"
eq  "restart: a finished report does not count"        0 "$(spawn task-verifier "$TV
REPORT: plans/rs/reports/tasks/review-8.md")"

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

# ---- check-git.sh ----
gitcmd() { "$JQ" -n --arg c "$1" '{hook_event_name:"PreToolUse",tool_name:"Bash",tool_input:{command:$c}}' |
  bash "$H/check-git.sh" 2>"$TMP/err"; echo $?; }
eq  "git: plain push allowed"               0 "$(gitcmd 'git push -u origin feature/x')"
eq  "git: push --follow-tags allowed"       0 "$(gitcmd 'git push --follow-tags')"
eq  "git: commit allowed"                   0 "$(gitcmd 'git commit -m "feat(x): unit 1"')"
eq  "git: tag allowed"                      0 "$(gitcmd 'git tag x-phase-1')"
eq  "git: annotated tag allowed"            0 "$(gitcmd 'git tag -a v1 -m "release"')"
eq  "git: non-git command allowed"          0 "$(gitcmd 'npm test -- --force')"
eq  "git: push --force blocked"             2 "$(gitcmd 'git push --force origin x')"
has "git: block says why"                   "force push" "$(cat "$TMP/err")"
eq  "git: push -f blocked"                  2 "$(gitcmd 'git push -f')"
eq  "git: push -uf blocked"                 2 "$(gitcmd 'git push -uf origin x')"
eq  "git: force-with-lease blocked"         2 "$(gitcmd 'git push --force-with-lease')"
eq  "git: +refspec blocked"                 2 "$(gitcmd 'git push origin +x')"
eq  "git: push --delete blocked"            2 "$(gitcmd 'git push origin --delete x')"
eq  "git: push :ref blocked"                2 "$(gitcmd 'git push origin :x')"
eq  "git: -C before push still checked"     2 "$(gitcmd 'git -C ../toy push --force')"
eq  "git: amend blocked"                    2 "$(gitcmd 'git add -A && git commit --amend --no-edit')"
eq  "git: tag -f blocked"                   2 "$(gitcmd 'git tag -f x-phase-2')"
eq  "git: tag -d blocked"                   2 "$(gitcmd 'git tag -d x-phase-2')"
eq  "git: second segment checked"           2 "$(gitcmd 'git status; git push --force')"

# Pipeline checks need the project dir (R54, R60).
gitp() { "$JQ" -n --arg c "$1" --arg cwd "$PROJ" '{hook_event_name:"PreToolUse",tool_name:"Bash",cwd:$cwd,tool_input:{command:$c}}' |
  env -u CLAUDE_PROJECT_DIR bash "$H/check-git.sh" 2>"$TMP/err"; echo $?; }
eq  "book: append to decisions.tsv blocked"     2 "$(gitp 'printf "a\tb\n" >> plans/demo/decisions.tsv')"
has "book: block names log-decision.sh"         "log-decision.sh" "$(cat "$TMP/err")"
eq  "book: tee into decisions.tsv blocked"      2 "$(gitp 'printf x | tee -a plans/demo/decisions.tsv')"
eq  "book: write through a variable blocked"    2 "$(gitp 'L=plans/demo/decisions.tsv && printf "a\n" >> "$L"')"
eq  "book: touch through \${VAR} blocked"       2 "$(gitp 'D=plans/demo/approvals/afk; touch "${D}"')"
eq  "book: read through a variable allowed"     0 "$(gitp 'L=plans/demo/decisions.tsv; cat "$L"')"
eq  "book: fix-input file write allowed"        0 "$(gitp 'C=$(bash s/report-path.sh plans/demo spec/changes) && cat > "$C" <<EOF')"
eq  "book: touch an approval blocked"           2 "$(gitp 'touch plans/demo/approvals/afk')"
eq  "book: rm an approval blocked"              2 "$(gitp 'cd x && rm -f plans/demo/approvals/retry')"
eq  "book: reading decisions.tsv allowed"       0 "$(gitp 'cat plans/demo/decisions.tsv; grep restart plans/demo/decisions.tsv')"
eq  "book: listing approvals allowed"           0 "$(gitp 'ls -la plans/demo/approvals/')"
eq  "book: log-decision.sh allowed"             0 "$(gitp 'bash .claude/scripts/log-decision.sh plans/demo unit-1 commit a b c')"
eq  "add: plan path allowed"                    0 "$(gitp 'git add plans/demo && git status')"
eq  "add: quoted ./plan path allowed"           0 "$(gitp 'git add "./plans/demo/x.md"')"
eq  "add: code paths blocked"                   2 "$(gitp 'git add plans/demo src test')"
has "add: block names stage-unit.sh"            "stage-unit.sh" "$(cat "$TMP/err")"
eq  "add: -A blocked"                           2 "$(gitp 'git add -A')"
eq  "add: dot blocked"                          2 "$(gitp 'git add .')"
eq  "commit: -am blocked"                       2 "$(gitp 'git commit -am "feat(demo): unit 2a"')"
eq  "commit: plans only allowed"                0 "$(gitp 'git commit -m "docs(demo): phase 1 report"')"
rm -rf "$PROJ/plans/demo/reports/phase-2"; mkdir -p "$PROJ/src" "$PROJ/plans/demo/reports/phase-2"
( cd "$PROJ" && echo 'x' > src/a.js && git add src/a.js )
UC='git add plans/demo && git commit -m "feat(demo): unit 2a"'
eq  "commit: code without a review blocked"     2 "$(gitp "$UC")"
has "commit: block says a stop commits nothing" "A stopped run commits nothing" "$(cat "$TMP/err")"
R2A="$PROJ/plans/demo/reports/phase-2"
printf 'SUMMARY\nverdict: fail\np0: 0\np1: 1\np2: 0\ntop:\n- F01 [P1] x\n' > "$R2A/review-2a.md"
eq  "commit: failing review blocked"            2 "$(gitp "$UC")"
has "commit: block names the verdict"           "says verdict: fail" "$(cat "$TMP/err")"
printf 'SUMMARY\nverdict: pass\np0: 0\np1: 0\np2: 0\n' > "$R2A/review-2a-2.md"
eq  "commit: passing newest review allowed"     0 "$(gitp "$UC")"
bash "$ROOT/.claude/scripts/report-path.sh" --pending "$PROJ/plans/demo" phase-2/review-2a >/dev/null
eq  "commit: unfinished newer review blocked"   2 "$(gitp "$UC")"
has "commit: block names the unfinished report" "review-2a-3.md, is not finished" "$(cat "$TMP/err")"
bash "$ROOT/.claude/scripts/approve.sh" "$PROJ/plans/demo" commit-2a >/dev/null
eq  "commit: user's Commit anyway allowed"      0 "$(gitp "$UC")"
rm -f "$PROJ/plans/demo/approvals/commit-2a"
( cd "$PROJ" && git reset -q src/a.js )
eq  "commit: nothing outside plans/ allowed"    0 "$(gitp "$UC")"

# A phase tag needs the phase end first (R55): a finished conformance report and the phase report.
eq  "tag: phase tag without conformance blocked" 2 "$(gitp 'git tag demo-phase-2')"
has "tag: block names the matcher"               "spec-matcher" "$(cat "$TMP/err")"
bash "$ROOT/.claude/scripts/report-path.sh" --pending "$PROJ/plans/demo" phase-2/conformance >/dev/null
eq  "tag: unfinished conformance blocked"         2 "$(gitp 'git tag demo-phase-2')"
printf 'SUMMARY\nverdict: fail\np0: 0\np1: 1\np2: 0\n' > "$PROJ/plans/demo/reports/phase-2/conformance-2.md"
eq  "tag: no phase report blocked"                2 "$(gitp 'git tag -a demo-phase-2 -m "phase 2"')"
has "tag: block names the phase report"           "no phase report" "$(cat "$TMP/err")"
echo "# Phase 2 report" > "$PROJ/plans/demo/reports/phase-2/report.md"
eq  "tag: phase end done allowed"                 0 "$(gitp 'git tag demo-phase-2')"
eq  "tag: second phase end tag checked too"       0 "$(gitp 'git tag demo-phase-2-2')"
eq  "tag: other tags allowed"                     0 "$(gitp 'git tag demo-tasks && git tag v1.0')"
eq  "tag: phase tag of a phase with no reports"   2 "$(gitp 'git tag demo-phase-3')"

done_tests
