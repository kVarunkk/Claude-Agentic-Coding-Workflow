#!/usr/bin/env bash
# PreToolUse hook, matcher "Write|Edit|MultiEdit" (dostuff: write_file|edit_file|multi_edit|delete_file).
# In a pipeline run (plans/<feature>/approvals/brief exists), the orchestrator, i.e. the main session, may write
# inside plans/<feature>/ only the files build-feature gives it:
#   feature-<feature>-brief.md                      step 1
#   reports/<stage>/report*.md                      phase and final reports
#   reports/<stage>/{changes,unit-changes-*,guidance-*,tests-*,stray-*,fix-unit-check,fix-scope,pr-body}*.md
#                                                   fix-input files and the PR body
# Everything else there belongs to an agent: the spec (spec-writer), the tasks file (task-writer, implementer),
# every review, verification and conformance report (the agent named in its REPORT: line). Blocking these
# stops the orchestrator from finishing, patching or overwriting an agent's report or editing the spec itself.
# R52: while a run is open (a plan with approvals/brief and no approvals/final), the orchestrator also does not
# change the harness config or pipeline.conf (models, limits, hooks, permissions): dostuff's edit_config, or a
# write to .claude/settings*.json, .claude/pipeline.conf, .dostuff/config.yaml or .dostuff/pipeline.conf.
# Calls made inside a subagent carry "agent_type" in the hook input (Claude Code and dostuff both send it).
# R68 (run 12: a task-writer FIX round marked the verifier's findings [RESOLVED], set p1 to 0 in the report's
# SUMMARY and edited the approved spec): inside a plan dir, each pipeline agent writes only its own files:
#   spec-writer   the spec
#   task-writer   the tasks file
#   implementer   the tasks file (ticks, Differences)
#   spec-verifier, task-verifier, code-reviewer, spec-matcher   files under reports/
# Any other subagent type gets the orchestrator's rules. Outside plan dirs subagents are not checked, and the
# config rule (R52) is the orchestrator's only.
# Not covered: writes through the shell (sed -i, >); build-feature forbids those in prose.
# PIPELINE_ALLOW_WRITE=1 turns the hook off (for editing a plan by hand outside a run).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/../scripts/lib.sh"
input=$(cat)
[ "${PIPELINE_ALLOW_WRITE:-}" = 1 ] && exit 0
if ! find_jq; then
  # Without jq: allow, unless this is plainly a main-session write to a plan's report, spec or tasks file,
  # or a writer agent's write to a report (R68).
  if printf '%s' "$input" | grep -q '"agent_type"'; then
    printf '%s' "$input" | grep -qE '"agent_type" *: *"(spec-writer|task-writer|implementer)"' || exit 0
    printf '%s' "$input" | grep -qE 'plans[/\\]+[a-z0-9-]+[/\\]+reports[/\\]' || exit 0
    echo "check-write: jq not found; a writer agent does not write a plan's reports" >&2; exit 2
  fi
  printf '%s' "$input" | grep -qE '"tool_name" *: *"edit_config"' && { echo "check-write: jq not found; cannot verify a config edit" >&2; exit 2; }
  printf '%s' "$input" | grep -qE 'plans[/\\]+[a-z0-9-]+[/\\]+(reports[/\\]|feature-[a-z0-9-]+-(spec|tasks)\.md)' || exit 0
  echo "check-write: jq not found; cannot verify a write inside a plan dir" >&2; exit 2
fi

agent=$(printf '%s' "$input" | "$JQ" -r '.agent_type // empty' | tr -d '\r')
tool=$(printf '%s' "$input" | "$JQ" -r '.tool_name // empty' | tr -d '\r')
path=$(printf '%s' "$input" | "$JQ" -r '.tool_input.file_path // .tool_input.path // empty' | tr -d '\r')

root="${CLAUDE_PROJECT_DIR:-}"
[ -n "$root" ] || root=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty' | tr -d '\r')

run_open() { # a plan whose brief is agreed and whose final report is not accepted yet
  local dir="$root" b
  command -v cygpath >/dev/null 2>&1 && [ -n "$dir" ] && dir=$(cygpath -u "$dir")
  [ -n "$dir" ] && cd "$dir" 2>/dev/null || return 1
  for b in plans/*/approvals/brief; do
    [ -f "$b" ] && [ ! -f "${b%/brief}/final" ] && return 0
  done
  return 1
}
config_blocked() {
  echo "Blocked $1: the harness config and pipeline.conf (models, limits, hooks, permissions) are the user's while a build-feature run is open. When an agent fails on its model, stop and tell the user which agent and model; they change the config themselves." >&2
  exit 2
}
if [ "$tool" = edit_config ]; then
  [ -n "$agent" ] && exit 0
  run_open && config_blocked "edit_config"
  exit 0
fi
[ -n "$path" ] || exit 0

# Compare in one spelling: forward slashes, /c/... as C:/..., lower case (Windows paths are case-blind).
canon() {
  local x
  x=$(printf '%s' "$1" | tr '\\' '/')
  # Git Bash: /tmp/x and C:\Users\...\Temp\x name the same folder; cygpath -m gives both as C:/....
  case "$x" in /*|[A-Za-z]:*) command -v cygpath >/dev/null 2>&1 && x=$(cygpath -m "$x" 2>/dev/null || printf '%s' "$x") ;; esac
  printf '%s' "$x" | sed -E 's#^/([a-zA-Z])/#\1:/#; s#/+#/#g; s#^\./##; s#/\./#/#g' | tr 'A-Z' 'a-z'
}
p=$(canon "$path"); r=$(canon "$root"); r="${r%/}"
case "$p" in
  /*|[a-z]:/*) [ -n "$r" ] || exit 0
               case "$p" in "$r"/*) rel="${p#"$r"/}" ;; *) exit 0 ;; esac ;;
  *) rel="$p" ;;
esac

case "$rel" in
  .claude/settings.json|.claude/settings.local.json|.claude/pipeline.conf|.dostuff/config.yaml|.dostuff/pipeline.conf)
    [ -n "$agent" ] && exit 0
    run_open && config_blocked "write to $rel"
    exit 0 ;;
  plans/*/*) ;;
  *) exit 0 ;;
esac
feature="${rel#plans/}"; feature="${feature%%/*}"
inner="${rel#plans/"$feature"/}"
# Only during a pipeline run. Real case of the plan dir: lower-cased paths still resolve on Windows.
dir="$root"
command -v cygpath >/dev/null 2>&1 && [ -n "$dir" ] && dir=$(cygpath -u "$dir")
[ -n "$dir" ] && cd "$dir" 2>/dev/null
[ -f "plans/$feature/approvals/brief" ] || exit 0

# R68: each pipeline agent writes only its own files in the plan dir.
agent_blocked() {
  echo "Blocked $agent write to $rel: $1 Leave the file as it is and say in your final message what should change there; the orchestrator routes it." >&2
  exit 2
}
case "$agent" in
  spec-writer)
    [ "$inner" = "feature-$feature-spec.md" ] && exit 0
    agent_blocked "spec-writer writes only plans/$feature/feature-$feature-spec.md. A FIX file and every report are read-only input." ;;
  task-writer|implementer)
    [ "$inner" = "feature-$feature-tasks.md" ] && exit 0
    case "$inner" in
      "feature-$feature-spec.md") agent_blocked "only spec-writer writes the spec, and it is approved. Fix what the tasks file can fix; list each change the spec still needs in your final message under \"Spec changes needed:\"." ;;
      reports/*) agent_blocked "reports are the reviewers' evidence. Never mark a finding resolved or change a SUMMARY: the next verifier rechecks your fix." ;;
    esac
    agent_blocked "$agent writes only plans/$feature/feature-$feature-tasks.md in the plan dir." ;;
  spec-verifier|task-verifier|code-reviewer|spec-matcher)
    case "$inner" in reports/*/*) exit 0 ;; esac
    agent_blocked "$agent writes only its report under plans/$feature/reports/." ;;
esac

case "$inner" in
  "feature-$feature-brief.md") exit 0 ;;
  reports/*/*)
    name="${inner##*/}"
    case "$name" in
      report.md|report-[0-9]*.md|changes*.md|unit-changes-*.md|guidance-*.md|tests-*.md|stray-*.md|fix-unit-check*.md|fix-scope*.md|pr-body*.md) exit 0 ;;
    esac
    why="it is an agent's report. An unfinished or unreadable report is never patched or rewritten: run check-report.sh; exit 1 means spawn one new agent with PARTIAL: (build-feature, Agents that stop early), or stop and tell the user." ;;
  "feature-$feature-spec.md") why="only spec-writer writes the spec. Write the change to a fix-input file (report-path.sh PLAN spec/changes or spec/fix-scope) and spawn spec-writer with FIX: that file." ;;
  "feature-$feature-tasks.md") why="only task-writer (and the implementer, for ticks and Differences) writes the tasks file. Write the change to a fix-input file (report-path.sh PLAN tasks/changes) and spawn task-writer with FIX: that file." ;;
  *) why="the orchestrator writes only the brief, fix-input files, the phase and final reports and the PR body in a plan dir." ;;
esac
echo "Blocked write to $rel: $why If the user wants this edit anyway, they make it themselves." >&2
exit 2
