#!/usr/bin/env bash
# PreToolUse hook, matcher "Agent". Blocks an implementer spawn (exit 2, reason on stderr) unless:
#   - the prompt has "PLAN: plans/<feature>" and "UNIT: <id>: TASK-..." lines,
#   - without a FIX line: that unit and task set equal next-unit.sh output (a new unit, or the rest of one);
#     with "FIX: plans/<feature>/reports/...": the file exists and the unit id is the unit still open at
#     HEAD (built in the working tree, not committed yet). Fix rounds get a fresh implementer this way.
#   - approvals/spec and approvals/tasks exist,
#   - for a unit in a later phase than the first, approvals/phase-<previous phase> exists,
#     unless approvals/afk exists (the user chose AFK mode at the tasks gate),
#   - no earlier phase is waiting for its phase end: status.sh "gate: N" with N below the unit's phase blocks,
#     AFK too (R55),
#   - in a git repo, HEAD is not on the default branch.
# Blocks a spec-writer spawn unless its prompt has a "PLAN: plans/<feature>" line and
# approvals/brief exists, i.e. the user agreed the brief first (for an imported plan: agreed to the import).
# Pipeline spawns are blocked when the prompt holds lines beyond the build-feature template (PLAN:, UNIT:, BASE:,
# REPORT:, FIX:, ... and the fixed instruction lines): implementer and spec-writer always; code-reviewer,
# spec-matcher and task-writer when the prompt has a PLAN: line; spec-verifier and task-verifier when it has a
# "spec plans/..." or "tasks plans/..." line. Without those lines they are not in a pipeline run and take any prompt.
# Every other subagent type is allowed.
# One restart per agent run (R53): every allowed pipeline spawn of a writer, verifier, reviewer or matcher is
# logged in the git dir (pipeline-spawns.tsv: time, type, prompt key, HEAD, REPORT, PARTIAL). Blocked:
#   - spec-writer or task-writer with the same prompt as two earlier spawns at the same HEAD,
#   - a verifier, reviewer or matcher whose PARTIAL: report was written by an agent that was itself a restart,
#   - a verifier, reviewer or matcher when two earlier spawns of its type with the same prompt (REPORT: and
#     PARTIAL: lines left out), at any HEAD, left reports that check-report.sh still rejects (R57: a restart
#     that leaves out PARTIAL: is still counted, and a commit in between does not reset the count).
# The user allows one more with "approve.sh <plan> retry"; the hook removes that marker when it uses it.
# The implementer is not counted here: its restart prompt changes as tasks get ticked.
# MAX_LOOPS (R63; run 11 ran 4 unit fix rounds with MAX_LOOPS=2 because the orchestrator miscounted). Each distinct
# FIX file is one fix round; a restart with the same FIX: line is not a new round. Blocked past MAX_LOOPS rounds:
#   - an implementer FIX round for the unit open at HEAD (rounds counted at this HEAD; a unit-changes-<unit> file,
#     the user's Request changes at the unit gate, is not counted),
#   - a spec-writer FIX round from reports/spec/review*, a task-writer FIX round from reports/tasks/review*
#     (changes and fix-scope files are the user's own text and are not counted).
# The user allows one more round with "approve.sh <plan> loop-<unit>|loop-spec|loop-tasks"; the hook uses it up.
# Also registered for SendMessage (Claude Code) / send_message (dostuff): resuming an agent is blocked
# (fresh agent every round), unless PIPELINE_ALLOW_RESUME=1.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
. "$SCRIPTS/lib.sh"
input=$(cat)
printf '%s\n' "$input" > "${TMPDIR:-/tmp}/pipeline-last-check-spawn.json" 2>/dev/null
RESUME_MSG='pipeline agents are never resumed (build-feature: fresh agent every round). An agent that ran out of turns: check its REPORT with check-report.sh; unfinished -> spawn a new agent of the same type with PARTIAL: <its report> (implementer: next-unit.sh output, or FIX:). Set PIPELINE_ALLOW_RESUME=1 to allow resumes outside a pipeline run.'
resume_blocked() { [ "${PIPELINE_ALLOW_RESUME:-}" = 1 ] && exit 0; echo "Blocked $1: $RESUME_MSG" >&2; exit 2; }
if ! find_jq; then
  # Without jq, block only spawns that look gated, and resumes; let everything else through.
  printf '%s' "$input" | grep -qE '"tool_name" *: *"(SendMessage|send_message)"' && resume_blocked "resume"
  printf '%s' "$input" | grep -qE '"subagent_type" *: *"(implementer|spec-writer|code-reviewer|spec-matcher)"' || exit 0
  echo "check-spawn: jq not found; cannot verify this spawn" >&2; exit 2
fi

tool=$(printf '%s' "$input" | "$JQ" -r '.tool_name // empty' | tr -d '\r')
case "$tool" in SendMessage|send_message) resume_blocked "$tool" ;; esac

type=$(printf '%s' "$input" | "$JQ" -r '.tool_input.subagent_type // empty' | tr -d '\r')
case "$type" in implementer|spec-writer|code-reviewer|spec-matcher|task-writer|spec-verifier|task-verifier) ;; *) exit 0 ;; esac
block() { echo "Blocked $type spawn: $*" >&2; exit 2; }
prompt=$(printf '%s' "$input" | "$JQ" -r '.tool_input.prompt // empty' | tr -d '\r')

resolve_root() {
  root="${CLAUDE_PROJECT_DIR:-}"
  if [ -z "$root" ]; then
    root=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty' | tr -d '\r')
    command -v cygpath >/dev/null 2>&1 && [ -n "$root" ] && root=$(cygpath -u "$root")
  fi
}
line_value() { printf '%s\n' "$prompt" | sed -n "s/^[[:space:]]*$1:[[:space:]]*//p" | head -1 | sed 's/[[:space:]]*$//; s#^\./##'; }
guard_restarts() { # R53; returns to the caller when the spawn may go ahead, after logging it
  local plan log head key rep par n prev why=""
  resolve_root
  [ -n "$root" ] && cd "$root" 2>/dev/null || return 0
  plan=$(printf '%s\n' "$prompt" | sed -nE 's/^[[:space:]]*(PLAN:[[:space:]]*|spec |tasks )(plans\/[a-z0-9][a-z0-9-]*).*/\2/p' | head -1)
  [ -n "$plan" ] && [ -d "$plan" ] || return 0
  log=$(git rev-parse --git-path pipeline-spawns.tsv 2>/dev/null) || return 0
  head=$(git rev-parse -q --verify HEAD 2>/dev/null) || head=none
  key=$(printf '%s\n' "$prompt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | grep -vE '^(REPORT|PARTIAL):' | cksum | cut -d' ' -f1)
  rep=$(line_value REPORT); par=$(line_value PARTIAL)
  case "$type" in
    spec-writer|task-writer)
      n=$(awk -F'\t' -v t="$type" -v k="$key" -v h="$head" '$2 == t && $3 == k && $4 == h' "$log" 2>/dev/null | wc -l | tr -d ' ')
      [ "${n:-0}" -ge 2 ] && why="two $type agents with this prompt already ran at this commit and the job is still not done." ;;
    *)
      if [ -n "$par" ]; then
        prev=$(awk -F'\t' -v r="$par" '$5 == r { p = $6 } END { print p }' "$log" 2>/dev/null)
        [ -n "$prev" ] && why="$par was written by an agent that was already a restart (its PARTIAL: was $prev)."
      fi
      # R57: a restart without PARTIAL: is still a restart. Earlier spawns with this prompt whose report is still
      # unfinished count, however the new prompt is worded and whatever was committed in between (run 10 committed
      # the plan between the second and third stuck task-verifier).
      if [ -z "$why" ]; then
        local stuck
        stuck=$(awk -F'\t' -v t="$type" -v k="$key" '$2 == t && $3 == k && $5 != "" { print $5 }' "$log" 2>/dev/null |
          while IFS= read -r r; do bash "$SCRIPTS/check-report.sh" "$r" >/dev/null 2>&1 || printf '%s ' "$r"; done)
        n=$(printf '%s' "$stuck" | wc -w | tr -d ' ')
        [ "${n:-0}" -ge 2 ] && why="two $type agents with this prompt already stopped without a finished report (${stuck% })."
      fi ;;
  esac
  if [ -n "$why" ]; then
    if [ -f "$plan/approvals/retry" ]; then
      rm -f "$plan/approvals/retry"
    else
      block "$why One restart per agent run (build-feature, Agents that stop early): stop and tell the user which agent stopped early and what its last reply said. Do not change the model, the config or the prompt to get past this. The user can allow one more try with: bash .claude/scripts/approve.sh $plan retry"
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$type" "$key" "$head" "$rep" "$par" >> "$log" 2>/dev/null
  return 0
}
guard_loops() { # R63: <kind> <name> <fix file> <head or "any">; returns when the round may go ahead, after logging it
  local kind="$1" name="$2" fx="$3" h="$4" key log seen n marker
  key="$plan/$name"
  load_conf
  log=$(git rev-parse --git-path pipeline-spawns.tsv 2>/dev/null) || return 0
  seen=$(awk -F'\t' -v t="$kind" -v k="$key" -v h="$h" -v f="$fx" '$2 == t && $3 == k && (h == "any" || $4 == h) && $5 == f' "$log" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${seen:-0}" -eq 0 ]; then
    n=$(awk -F'\t' -v t="$kind" -v k="$key" -v h="$h" '$2 == t && $3 == k && (h == "any" || $4 == h) { print $5 }' "$log" 2>/dev/null | sort -u | wc -l | tr -d ' ')
    marker="$plan/approvals/loop-$name"
    if [ "${n:-0}" -ge "$MAX_LOOPS" ]; then
      if [ -f "$marker" ]; then
        rm -f "$marker"
      else
        block "$n fix rounds already ran for $name (MAX_LOOPS=$MAX_LOOPS). Do not start another: ask the user at the MAX_LOOPS gate (build-feature 4.4: Commit anyway / Give guidance / Stop; spec and tasks: the gate with the remaining findings). AFK: stop. The user allows one more round with: bash .claude/scripts/approve.sh $plan loop-$name"
      fi
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$kind" "$key" "$h" "$fx" "" >> "$log" 2>/dev/null
  return 0
}
writer_loops() { # spec-writer / task-writer FIX rounds from a review
  local fx stage p
  fx=$(line_value FIX)
  [ -n "$fx" ] || return 0
  p=$(printf '%s\n' "$prompt" | sed -nE 's/^[[:space:]]*PLAN:[[:space:]]*(plans\/[a-z0-9][a-z0-9-]*).*/\1/p' | head -1)
  [ -n "$p" ] || return 0
  case "$type" in spec-writer) stage=spec ;; *) stage=tasks ;; esac
  case "$fx" in "$p/reports/$stage/review"*) ;; *) return 0 ;; esac
  resolve_root
  [ -n "$root" ] && cd "$root" 2>/dev/null || return 0
  [ -d "$p" ] || return 0
  plan="$p"; guard_loops "$type-fix" "$stage" "$fx" any
}
allow() { case "$type" in spec-writer|task-writer) writer_loops ;; esac; guard_restarts; exit 0; }

# The prompt is the SKILL's template and nothing else: extra rules or file lists in a prompt override the
# agent file and the unit's Files column. Blank lines and code fences are fine.
only_lines() { # extended regex of allowed lines
  local extra
  extra=$(printf '%s\n' "$prompt" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' | grep -v '^```' | grep -vE "$1" | head -3)
  [ -z "$extra" ] || block "the prompt may hold only the template lines from build-feature; remove: $(printf '%s' "$extra" | tr '\n' '|')"
}
case "$type" in # outside a pipeline run these agents take any prompt
  code-reviewer|spec-matcher|task-writer) printf '%s\n' "$prompt" | grep -qE '^[[:space:]]*PLAN:' || exit 0 ;;
  spec-verifier) printf '%s\n' "$prompt" | grep -qE '^[[:space:]]*spec plans/' || exit 0 ;;
  task-verifier) printf '%s\n' "$prompt" | grep -qE '^[[:space:]]*tasks plans/' || exit 0 ;;
esac
FIXLINES='^Fix only the P0 and P1 findings in that file\.$|^Apply the changes in that file\.$'
case "$type" in
  implementer)   only_lines '^(PLAN|UNIT|FIX|ALSO):|^Implement only these tasks\.$|^Fix only the P0 and P1 findings, the drift and the failing tests named there\.$' ;;
  code-reviewer) only_lines '^(PLAN|UNIT|BASE|REPORT|RECHECK|PARTIAL):|^Review the staged change \(git diff --cached BASE\)\.$'; allow ;;
  spec-matcher)  only_lines '^(PLAN|REPORT|DECISIONS|PARTIAL):'; allow ;;
  spec-verifier) only_lines '^spec plans/[a-z0-9-]+/?$|^(REPORT|RECHECK|PARTIAL):'; allow ;;
  task-verifier) only_lines '^tasks plans/[a-z0-9-]+/?$|^(UNIT|REPORT|RECHECK|PARTIAL):'; allow ;;
  task-writer)   only_lines "^PLAN: plans/[a-z0-9-]+/?\$|^FIX:|$FIXLINES|^PLAN: plans/[a-z0-9-]+\\. (Write the tasks file from the approved spec\\.|Reformat the imported tasks file\\.|Add one unit \"## Phase .* Change nothing else\\.)\$"; allow ;;
  spec-writer)   only_lines "^(PLAN|Brief|FIX):|^Write the spec\\.\$|^Reformat the imported spec\\.\$|$FIXLINES" ;;
esac

plan=$(printf '%s\n' "$prompt" | sed -n 's/^PLAN:[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' | head -1)
[ -n "$plan" ] || block 'the prompt must have a "PLAN: plans/<feature>" line.'
plan="${plan%/}"
printf '%s' "$plan" | grep -qE '^plans/[a-z0-9][a-z0-9-]*$' || block "PLAN must be plans/<feature> in kebab-case, got \"$plan\"."

resolve_root
[ -n "$root" ] && cd "$root" 2>/dev/null || block "cannot resolve the project dir."
[ -d "$plan" ] || block "no plan dir $plan under $root."

if [ "$type" = "spec-writer" ]; then
  [ -f "$plan/approvals/brief" ] || block "the brief is not agreed ($plan/approvals/brief missing). Align with the user first (aligning-requirements)."
  allow
fi

unit_line=$(printf '%s\n' "$prompt" | sed -n 's/^UNIT:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')
[ -n "$unit_line" ] || block 'the prompt must have a "UNIT: <id>: TASK-..." line, copied from next-unit.sh.'
fix=$(printf '%s\n' "$prompt" | sed -n 's/^FIX:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*$//')

norm() { # "<id>: TASK-b TASK-a" -> "<id>: TASK-a TASK-b"
  local id rest
  id="${1%%:*}"; rest="${1#*:}"
  printf '%s: %s' "$(echo "$id" | tr -d '[:space:]')" "$(printf '%s\n' $rest | sort -u | tr '\n' ' ' | sed 's/ $//')"
}
uid=$(printf '%s' "${unit_line%%:*}" | tr -d '[:space:]')

if [ -n "$fix" ]; then
  case "$fix" in "$plan"/reports/*) ;; *) block "FIX must name a file under $plan/reports/, got \"$fix\"." ;; esac
  case "$fix" in *..*) block "FIX path must not contain \"..\"." ;; esac
  [ -f "$fix" ] || block "FIX file $fix does not exist."
  expected=$(next_unit_at "$plan" HEAD 2>/dev/null) || block "cannot read the tasks file committed at HEAD; a fix round needs the approved tasks committed."
  [ -n "$expected" ] || block "no unit is open at HEAD; there is nothing in progress to fix."
  [ "$uid" = "${expected%%:*}" ] || block "a fix round is only for the unit in progress (${expected%%:*}), got $uid."
else
  expected=$(bash "$SCRIPTS/next-unit.sh" "$plan" 2>&1) || block "next-unit.sh failed: $expected"
  [ -n "$expected" ] || block "every task in $plan is done; there is no unit to implement."
  [ "$(norm "$unit_line")" = "$(norm "$expected")" ] || block "expected \"UNIT: $expected\", got \"UNIT: $unit_line\". Pass next-unit.sh output verbatim."
fi

[ -f "$plan/approvals/spec" ] || block "the spec is not approved ($plan/approvals/spec missing)."
[ -f "$plan/approvals/tasks" ] || block "the tasks are not approved ($plan/approvals/tasks missing)."

unit="${expected%%:*}"
phase="${unit%[a-z]}"
tasks=$(tasks_file "$plan") || block "no tasks file."
prev=$(parse_tasks "$tasks" | awk -F'\t' -v p="$phase" '$1 == "unit" && $3 + 0 < p + 0 && (!f || $3 + 0 > m + 0) { m = $3; f = 1 } END { if (f) print m }')
if [ -n "$prev" ] && [ ! -f "$plan/approvals/afk" ]; then
  [ -f "$plan/approvals/phase-$prev" ] || block "phase $prev is not approved ($plan/approvals/phase-$prev missing). Gate phase $prev with the user first."
fi
# R55: AFK too, an earlier phase must have ended (matcher, phase report, tag) before a later phase starts.
gate=$(bash "$SCRIPTS/status.sh" "$plan" 2>/dev/null | sed -n 's/^gate: //p')
case "$gate" in
  ''|none) ;;
  *) if [ "$gate" -lt "$phase" ] 2>/dev/null; then
       block "phase $gate has not ended: status.sh says gate: $gate. Run the phase end first (build-feature 4.6: spec-matcher, phase report, git tag $(basename "$plan")-phase-$gate), AFK too."
     fi ;;
esac

if git rev-parse --git-dir >/dev/null 2>&1; then
  cur=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  def=$(default_branch 2>/dev/null) || def=""
  [ -n "$def" ] && [ "$cur" = "$def" ] && block "HEAD is on the default branch $def. Run bash .claude/scripts/branch.sh $plan first."
fi
# R63: MAX_LOOPS for unit fix rounds. Every fix round of one unit runs at the same HEAD (nothing is committed
# until the unit passes), so rounds are counted per unit at this HEAD.
if [ -n "$fix" ]; then
  case "$fix" in
    */unit-changes-*) ;;
    *) guard_loops implementer-fix "$unit" "$fix" "$(git rev-parse -q --verify HEAD 2>/dev/null || echo none)" ;;
  esac
fi
exit 0
