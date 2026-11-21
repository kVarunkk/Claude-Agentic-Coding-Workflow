#!/usr/bin/env bash
# PreToolUse hook, matcher "Bash". Blocks (exit 2, reason on stderr):
#   Everywhere: history-rewriting git commands: git push with --force / --force-with-lease / -f / +refspec,
#     git push --delete or :ref, git commit --amend, git tag -f / --force / -d / --delete.
#   In a pipeline project (some plans/<feature>/approvals/brief exists), for the orchestrator and every agent:
#     - a shell write to plans/<f>/decisions.tsv or plans/<f>/approvals/ (redirect, tee, touch, rm, mv, cp,
#       sed -i, truncate): only log-decision.sh and approve.sh write those (R60);
#   once the tasks are approved (some plans/<feature>/approvals/tasks exists):
#     - git add of anything but literal plans/... paths, and git add -A / -u / . : unit code is staged only by
#       stage-unit.sh (R54);
#     - git commit -a / --all;
#     - git commit while the index holds files outside plans/, unless the newest review of the unit open at HEAD
#       (plans/<f>/reports/phase-*/review-<unit>[-n].md) passes check-report.sh with "verdict: pass", or the
#       user chose Commit anyway (approvals/commit-<unit>, written by approve.sh). A stopped run commits nothing.
# If one is really needed, the user runs it with "! <command>". Without jq it allows everything.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$HERE/../scripts"
. "$SCRIPTS/lib.sh"
input=$(cat)
find_jq 2>/dev/null || exit 0
cmd=$(printf '%s' "$input" | "$JQ" -r '.tool_input.command // empty' | tr -d '\r')
[ -n "$cmd" ] || exit 0
block() { echo "Blocked command: $1 If the user wants it anyway, they run it themselves with \"! <command>\"." >&2; exit 2; }

# One git invocation per segment; the subcommand is the first word after "git" and its global options.
reason=$(printf '%s\n' "$cmd" | tr ';&|\n' '\n\n\n\n' | awk '
  {
    n = split($0, t, /[ \t]+/); g = 0
    for (i = 1; i <= n; i++) if (t[i] == "git" || t[i] ~ /\/git(\.exe)?$/) { g = i; break }
    if (!g) next
    i = g + 1
    while (i <= n && t[i] ~ /^-/) { if (t[i] == "-C" || t[i] == "-c") i++; i++ }
    sub_ = t[i]; flags = ""
    for (j = i + 1; j <= n; j++) flags = flags " " t[j]
    flags = flags " "
    if (sub_ == "push") {
      if (flags ~ / --force(-with-lease)?[= ]/ || flags ~ / -[A-Za-z]*f[A-Za-z]* / || flags ~ / \+[^ ]/) { print "force push rewrites shared history"; exit }
      if (flags ~ / --delete / || flags ~ / -d / || flags ~ / :[^ ]/) { print "deleting a remote ref"; exit }
    }
    if (sub_ == "commit" && flags ~ / --amend /) { print "--amend rewrites a commit; make a new commit instead"; exit }
    if (sub_ == "tag" && (flags ~ / -[A-Za-z]*[fd][A-Za-z]* / || flags ~ / --(force|delete) /)) { print "tags are never moved or deleted; use a new suffix (-2)"; exit }
  }')
[ -z "$reason" ] || block "git: $reason."

# ---- pipeline checks ----
root="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$root" ]; then
  root=$(printf '%s' "$input" | "$JQ" -r '.cwd // empty' | tr -d '\r')
  command -v cygpath >/dev/null 2>&1 && [ -n "$root" ] && root=$(cygpath -u "$root")
fi
[ -n "$root" ] && cd "$root" 2>/dev/null || exit 0
ls plans/*/approvals/brief >/dev/null 2>&1 || exit 0

segments=$(printf '%s\n' "$cmd" | tr ';&|\n' '\n\n\n\n')

# R60: decisions.tsv and approvals/ are written by log-decision.sh and approve.sh only.
bookkeeping='(decisions\.tsv|approvals/)'
# A variable set to such a path (L=plans/x/decisions.tsv ... >> "$L") counts as the path itself.
for v in $(printf '%s\n' "$cmd" | grep -oE "(^|[^A-Za-z0-9_])[A-Za-z_][A-Za-z0-9_]*=[\"']?[^[:space:];&|]*$bookkeeping" |
           sed -E 's/^[^A-Za-z_]//; s/=.*//' | sort -u); do
  bookkeeping="${bookkeeping%)}|\\\$\\{?$v([^A-Za-z0-9_]|\$))"
done
while IFS= read -r seg; do
  printf '%s' "$seg" | grep -qE "$bookkeeping" || continue
  first=$(printf '%s' "$seg" | awk '{ print $1 }')
  if printf '%s' "$seg" | grep -qE ">>?[[:space:]]*[\"']?[^[:space:]]*$bookkeeping" ||
     printf '%s' "$first" | grep -qxE 'tee|touch|rm|mv|cp|truncate|dd' ||
     { [ "$first" = sed ] && printf '%s' "$seg" | grep -qE '(^|[[:space:]])-[a-zA-Z]*i'; }; then
    block "decisions.tsv and approvals/ are written only by log-decision.sh and approve.sh (build-feature, Decision trail). Log with: bash <scripts>/log-decision.sh PLAN <step> <decision> <why> <evidence> <result>."
  fi
done <<< "$segments"

ls plans/*/approvals/tasks >/dev/null 2>&1 || exit 0

# Words of a git segment after the subcommand, with quotes removed; prints "<sub> <word>..." or nothing.
git_words() {
  printf '%s\n' "$1" | awk '{
    n = split($0, t, /[ \t]+/); g = 0
    for (i = 1; i <= n; i++) if (t[i] == "git" || t[i] ~ /\/git(\.exe)?$/) { g = i; break }
    if (!g) exit
    i = g + 1
    while (i <= n && t[i] ~ /^-/) { if (t[i] == "-C" || t[i] == "-c") i++; i++ }
    out = t[i]
    for (j = i + 1; j <= n; j++) { w = t[j]; gsub(/["\047]/, "", w); out = out " " w }
    print out }'
}
# newest_report <dir> <name>: the newest of <dir>/<name>.md, <name>-2.md, ... (report-path.sh numbering).
newest_report() {
  local d="$1" b="$2" f n best="" bn=0
  for f in "$d/$b".md "$d/$b"-[0-9]*.md; do
    [ -f "$f" ] || continue
    n=$(basename "$f" .md); n="${n#"$b"}"; n="${n#-}"; [ -n "$n" ] || n=1
    case "$n" in *[!0-9]*) continue ;; esac
    if [ "$n" -gt "$bn" ] || { [ "$n" -eq "$bn" ] && [ "$f" -nt "$best" ]; }; then best="$f"; bn="$n"; fi
  done
  printf '%s' "$best"
}
commits=0
set -f
while IFS= read -r seg; do
  w=$(git_words "$seg"); [ -n "$w" ] || continue
  set -- $w; sub="$1"; shift
  case "$sub" in
    add)
      for p in "$@"; do
        p="${p#./}"
        case "$p" in
          --) ;;
          -A|--all|-u|--update|.|'*'|:/) block "git add $p stages files outside the plan. Unit code is staged only by stage-unit.sh; git add takes literal plans/<feature> paths (build-feature, Git)." ;;
          -*) ;;
          plans/*) ;;
          *) block "git add $p: unit code is staged only by stage-unit.sh; git add takes literal plans/<feature> paths (build-feature, Git)." ;;
        esac
      done ;;
    tag)
      # A phase tag closes a phase: it needs the phase end done first (R55): a finished conformance report and
      # the phase report in plans/<feature>/reports/phase-<N>/.
      t=""; for p in "$@"; do case "$p" in -m|-F) t="skip" ;; -*) ;; *) [ "$t" = skip ] && { t=""; continue; }; t="$p"; break ;; esac; done
      ft=$(printf '%s' "$t" | sed -nE 's/^([a-z0-9][a-z0-9-]*)-phase-([0-9]+)(-[0-9]+)?$/\1 \2/p')
      if [ -n "$ft" ]; then
        set -- $ft; tp="plans/$1"; tn="$2"
        if [ -d "$tp" ]; then
          c=$(set +f; newest_report "$tp/reports/phase-$tn" conformance)
          [ -n "$c" ] || block "git tag $t: phase $tn has no conformance report ($tp/reports/phase-$tn/conformance.md). Run the phase end first: spec-matcher, then the phase report (build-feature 4.6)."
          out=$(bash "$SCRIPTS/check-report.sh" "$c" 2>&1) || block "git tag $t: the phase $tn conformance report $c is not finished ($out)."
          r=$(set +f; newest_report "$tp/reports/phase-$tn" report)
          [ -n "$r" ] || block "git tag $t: phase $tn has no phase report ($tp/reports/phase-$tn/report.md). Write it before the tag (build-feature 4.6.3)."
        fi
      fi ;;
    commit)
      for p in "$@"; do
        case "$p" in
          --all) block "git commit --all stages tracked files itself; unit code is staged only by stage-unit.sh." ;;
          --*) ;;
          -*a*) block "git commit $p stages tracked files itself; unit code is staged only by stage-unit.sh." ;;
        esac
      done
      commits=1 ;;
  esac
done <<< "$segments"
set +f
[ "$commits" = 1 ] || exit 0

# R54: a commit that carries code needs a passing review of the unit open at HEAD.
code=$(git -c core.quotePath=false diff --cached --name-only 2>/dev/null | grep -v '^plans/')
[ -n "$code" ] || exit 0
plan=""; unit=""
for d in plans/*/; do
  d="${d%/}"
  [ -f "$d/approvals/tasks" ] || continue
  u=$(next_unit_at "$d" HEAD 2>/dev/null) || continue
  [ -n "$u" ] || continue
  plan="$d"; unit="${u%%:*}"; break
done
[ -n "$unit" ] || block "the index holds files outside plans/ ($(printf '%s' "$code" | head -3 | tr '\n' ' ')) but no unit is open at HEAD. Unstage them; only a reviewed unit commits code."
[ -f "$plan/approvals/commit-$unit" ] && exit 0
best=""; bn=0
for f in "$plan"/reports/phase-*/review-"$unit".md "$plan"/reports/phase-*/review-"$unit"-[0-9]*.md; do
  [ -f "$f" ] || continue
  n=$(basename "$f" .md); n="${n#review-"$unit"}"; n="${n#-}"; [ -n "$n" ] || n=1
  case "$n" in *[!0-9]*) continue ;; esac
  if [ "$n" -gt "$bn" ] || { [ "$n" -eq "$bn" ] && [ "$f" -nt "$best" ]; }; then best="$f"; bn="$n"; fi
done
why=""
if [ -z "$best" ]; then
  why="unit $unit has no review report under $plan/reports/phase-*/"
elif ! out=$(bash "$SCRIPTS/check-report.sh" "$best" 2>&1); then
  why="the newest review of unit $unit, $best, is not finished ($out)"
elif ! tr -d '\r' < "$best" | grep -qiE '^[[:space:]]*[*`_]*verdict[*`_]*[[:space:]]*:[[:space:]*`_]*pass'; then
  why="the newest review of unit $unit, $best, says verdict: fail"
fi
[ -z "$why" ] && exit 0
block "commit with unit code: $why. A unit commits only after its review passes (build-feature 4.5), or after the user chose Commit anyway (bash <scripts>/approve.sh $plan commit-$unit). A stopped run commits nothing: leave the change staged; status.sh resumes at the review."
