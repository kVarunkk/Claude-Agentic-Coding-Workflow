---
name: reviewing-code
description: Reviews code changes (uncommitted work, a branch, a commit, a PR or named files) for bugs, security holes, weak tests, data-shape and design problems, and reports only verified findings, each with file:line, a concrete failure scenario and a fix. Use when the user asks for a review, a second opinion or "does this look right?", before a commit or PR, and after finishing a task or phase from a plans/ tasks file.
argument-hint: "[files | commit | branch | PR# | --quick | --deep]"
---

# Reviewing code

Target: **$ARGUMENTS**

Find the defects that matter, prove each one, and report them so a human can act within a minute and an agent can act directly. The review is read-only: repository files stay untouched until the user asks for fixes.

## 1. Scope

The first match wins:

1. **Explicit target.** Files or dirs (read them), a commit (`git show <sha>`), a branch (`git diff <branch>...HEAD`) or a PR (`gh pr diff <n>`).
2. **"This branch" / "my changes" on a branch ahead of its base.** Run `git diff <base>...HEAD`. Take the base from `git symbolic-ref refs/remotes/origin/HEAD`, else `main`, else `master`.
3. **Uncommitted work.** `git diff HEAD`, plus untracked files from `git status --short`.
4. **No git.** The files changed in this session. If there are none, ask which files to review.

If the scope is empty, say so and stop. Past ~1,500 changed lines, say so and review risk-first (security boundary, data model, public interfaces) unless the user narrows it.

Depth: `--quick` is one pass on correctness and security only. The default is standard. `--deep` runs every lens, the parallel path, and a variant hunt on every finding.

## 2. Context

- Skim the whole diff once before judging anything.
- **Find the source of truth**: what the change is meant to do. Look at the user's words, the matching task and spec ids in `plans/<feature>/feature-<feature>-tasks.md`, and the commit messages. Judge spec alignment only against a spec you have actually read. With no spec, judge against the stated intent and say so.
- **Standards.** Read `CLAUDE.md`, contributing docs and lint/format config. A documented project rule outranks the general lenses.
- For every non-trivial hunk, read around it: callers and callees, types, the tests that cover it, and nearby comments (`keep in sync`, `do not change`, TODOs). When code looks deliberately odd, check its recent history with `git log -3 -p -- <file>`.

## 3. Partition before hunting

List the domain features the changed code handles, in the domain's own terms. For example: "dates near midnight in the user's timezone", "search text containing FTS operators", "a turn whose stream fails half-way". Add each generic construct the diff uses: error paths, concurrency, resource lifetimes, boundary values, untrusted input. Rank them: security boundary first, then the features the diff changes. Review one partition at a time, so the search covers the whole domain instead of circling the first bug you find.

## 4. Review

Work through the lenses in [references/lenses.md](references/lenses.md), tests first:

0. **Gate integrity.** The author wants green, so anything that loosens a gate needs proof. Flag: a test deleted, skipped (`.skip`, `xit`, `@pytest.mark.skip`) or with relaxed asserts; snapshots changed without their behaviour; lint, type or CI config relaxed; exceptions swallowed; coverage or timeout thresholds lowered. Each is P0 (P1 if the reason is logged and plausible). Never auto-fix these.
1. **Tests.** For each test of changed behaviour, imagine two edits: break the behaviour (does the test fail?) and change only internals (does it still pass?). A test that fails either is weak. Ask what wrong implementation would still pass it. When a distinguishing input is cheap, write it as a probe script in the scratchpad (or `$TMPDIR`) and run it with the project's runner. Keep the output as evidence.
2. **Data shape.** Look for structures that can hold invalid states, information stored twice and kept in sync by hand, and cases you can only extend by grepping.
3. **Correctness.** Partition by partition.
4. **Security.** Apply whenever the change reads untrusted input, makes an access or policy decision, or handles secrets.
5. **Spec alignment and scope.** Missing or partial requirements, behaviour nobody asked for, contradicted decisions. When the change belongs to a task unit: every changed file is in the unit's Files column or logged under Differences, and there is no unrequested refactor or behaviour. Anything else is scope drift (P1). A new Differences entry that narrows, weakens or drops a spec test is not authorised by being logged: check the stated cause yourself, and when it is wrong or the behaviour is now untested, report it as P1.
6. **Design and standards.** Project rules first, then the smell baseline. Cleanup: comments that restate the code (keep license headers, external constraints, public API docs, issue links and a non-obvious why), try/catch or defensive checks on trusted paths, casts that dodge types, deep nesting. P2 unless they hide a bug.
7. **Performance and operations.**

Review the change itself. Flag pre-existing problems only on lines the diff touches or makes worse. Leave what a linter, formatter or type checker already enforces.

For each confirmed defect, hunt its variants: other paths into the same code, and sibling sites that handle the same feature.

**Large or risky change** (2+ modules, >300 changed lines, a security boundary, or `--deep`): offer the parallel path in [references/parallel-review.md](references/parallel-review.md). Read-only lens reviewers run in parallel and you synthesize their findings.

## 4b. Prove the guards

Do not trust "the test fails without the code"; run it. For each task whose tests guard a behaviour (a validation, an escape, a limit, an error path), make one named mutation that breaks that behaviour **in a scratch copy, never in the repo** (`bash .claude/scripts/scratch-copy.sh "$TMPDIR/mut-<scope>"` in a pipeline repo, else a copy under the scratchpad). Run the project's test command there. Expect red.

- Record each as `mutation: <what you broke> -> <test> red|green`.
- A guard test that stays green under its mutation is P1 (the test does not guard anything).
- Cheap alternative for a new test: copy the tree at the base (`scratch-copy.sh <dir> --base <BASE>`), add the new test file, and show it fails there.
- Delete the copy when done. One mutation per guard task is enough.

**Recheck mode** (`RECHECK: <previous report>`): check each P0 and P1 finding of that report (`fixed` or `open`, with evidence), rerun its mutation, and look for new P0 or P1 problems in the lines the fix touched. Report no new P2s.

## 5. Verify

Before you report a candidate, it needs all three:

- you re-read the exact code and traced the path that triggers it;
- a **failure scenario**: a concrete input or state → the wrong result;
- **evidence**: a probe or test run (strongest), a caller, type or test that proves it, or a quoted spec line.

Then take the author's side against every finding that no run confirmed: is it guarded elsewhere, intended, or overstated? Drop what doesn't survive, and downgrade what is real but smaller. If you can't settle a finding, keep it at confidence Low and say what would settle it. Finally, ask "so what?" of each finding and cut the ones without an answer. Six sharp findings beat forty.

## 6. Report

```
## Review: <scope> (<base> → <head>)
Verdict: approve | approve-with-notes | changes-requested
Findings: P0 <n> · P1 <n> · P2 <n> · P3 <n>    Partitions reviewed: <n>

### Index
1. [P0][High] F01: <title> `path/file.ts:42`
2. [P1][Med]  F02: <title> `path/other.ts:10`

### F01: <title>
- Severity / confidence: P0 / High
- Location: `path/file.ts:42` (`functionName`). Also affects: <…>
- Lens: tests | data-shape | correctness | security | spec | design | performance
- Failure: <input or state → wrong result>
- Evidence: <probe output, caller, test, spec line>
- Fix: <the smallest change that fixes it>

### Tests
<behaviour changed without a test; tests a wrong implementation would still pass>

### Open questions
Q01: <question> Blocking: yes | no

### Set aside
<behaviour considered and judged out of scope, one line each, with the reason>

### Checked and fine
<risky areas you looked at and found correct>
```

- **P0**: wrong behaviour, data loss, a security hole or a broken contract. Fix before merge.
- **P1**: a real bug in an edge case, behaviour changed without a test, or a spec contradiction. A finding you reproduced with a concrete input that gives output the spec or the task row forbids is P1, however small: a P2 never starts a fix round, so a reproduced defect rated P2 ships and fails the phase check later.
- **P2**: a design or maintainability cost that will hurt within weeks.
- **P3**: a nit; the author decides.

Add a `### Guards` section with the mutation lines and a `Scope: clean | drift (<files or behaviour>)` line when the change belongs to a task unit.

Ids (`F01`, `Q01`) stay stable through the follow-up discussion. One root cause is one finding. Omit empty sections. When the change belongs to a feature in `plans/`, also save the report: to the `REPORT:` path in your prompt, else `plans/<feature>/reports/phase-<N>/review-<unit>.md` (N is the unit id without its letter), else `plans/<feature>/reports/review-<scope>.md`; add `-2`, `-3` instead of overwriting. Put the date inside the report. That report file is the only file you write.

End every reply with this block and nothing after it. Count P3 into `p2`. `verdict` is `fail` when p0 or p1 is above 0. `scope` is `n/a` outside a task unit.

```
SUMMARY
verdict: pass|fail
p0: <n>
p1: <n>
p2: <n>
scope: clean|drift|n/a
mutations: <n run>, <n still green>
top:
- <F-id> [P<n>] <file:line> <one line>   (max 5, most severe first)
report: <path to the saved report, or inline>
```

## 7. Fixes, when the user asks

Clarify any unclear finding first. Then fix in this order: P0s, then the quick fixes, then the larger ones. Do one finding at a time and run its test after each. Report each fix as "F03 fixed: <what changed>". If a finding turns out wrong while fixing, say so with the evidence.
