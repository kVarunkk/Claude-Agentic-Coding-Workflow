---
name: checking-spec-conformance
description: Checks the code against a feature spec in plans/<feature>/. It runs the tests, then grades every REQ, SEC, CON, GUD, PAT and TEST id as met, untested, partial, missing, diverging, accepted or outdated, with file:line and test evidence. It also finds behaviour no spec id covers and checks the tasks file's ticks. Use when the user asks whether the code matches the spec or what is left to build, to verify or audit an implementation, at the end of a phase, or before marking a feature done.
argument-hint: "[feature | path to spec] [--phase N]"
---

# Checking code against the spec

Feature: **$ARGUMENTS**

For each spec id, answer one question: **does the code do exactly this, and does a test that ran today prove it?** Evidence decides. File names, task ticks and "the code looks right" don't.

This skill checks evidence; it doesn't hunt for new defects. That is the job of `reviewing-code`, which you offer at the end.

## 1. Load

- Read `plans/<feature>/feature-<feature>-spec.md` and `-tasks.md`. With no feature given and exactly one folder in `plans/`, use that folder; otherwise ask.
- From the spec, list every checkable item: `REQ`, `SEC`, `CON`, `GUD`, `PAT` and `TEST` ids, the data model (§3), component signatures (§4), API contracts and config values. Note each item's exact limits and values.
- From the tasks file, read the ticked tasks, **Decisions taken** and **Differences from the spec**. A logged difference is an accepted deviation.
- With `--phase N`, limit grading to the ids in the Spec column of phase N's units (`## Phase N…`, including sub-phases `Na`, `Nb`). Still run the full suite.

## 2. Run the tests

Find the test command (CLAUDE.md, README, `package.json` scripts, CI config). Run the **full** suite with per-test names in the output (`vitest run --reporter=verbose`, `pytest -v`, `go test -v`) and save the log to the scratchpad. Also run the lint and type checks the spec names.

- **Any test fails:** report each failure as Critical and stop, because conformance on a red suite means little. If the user says to continue anyway, continue in **diagnostic mode** and say so in the report's first line.
- **No runnable suite:** note it. Every id can reach Untested at best.
- Leave the tests as they are: a test skipped, edited or deleted to get green is itself a Critical finding.

## 3. Grade every id

For each id:

1. **Locate it.** Find where it should live: the files named in spec §4 and §8, then grep for its names, constants, routes, columns and messages.
2. **Check the exact behaviour.** Read the implementation and check limits, defaults, ordering, error codes, and the edge cases the id names.
3. **Read the proving test.** Find the test and **read its assertions**; a test name is not evidence. Confirm in the log that it ran and passed.
4. **Universal ids** ("every turn…", "never…", "all errors…"). List every code location that writes or decides the value, including retries, shortcuts, fallbacks and legacy paths. Each one needs a test that goes through it. One passing test on the main path doesn't cover a fallback branch.
5. **Input space.** When an id ranges over inputs ("any message", "1–5 queries"), check that the tests cover the boundaries and the failure side, not just one happy case.

**Evidence tiers:**

| Tier | Meaning | Cite |
|---|---|---|
| **Verified** | an inspectable artifact from this run: captured output, a generated schema, an integration test's response | the path or field |
| **Tested** | a named test that ran green this run, with assertions that prove the claim | `file › test name` |
| **Inspected** | only a reading of the code; nothing that ran shows it | `(no executable evidence)` |

Code existing isn't evidence. If a test was skipped, or its assertions don't check the claim, the id drops to Inspected.

**Run it for real.** When the spec names a runnable entry point with an example (a CLI command, a request, a script), run it once in the scratchpad and use the output as Verified evidence for the ids it shows. Tests alone are not the whole proof.

**Statuses:**

| Status | When | Severity |
|---|---|---|
| ✅ Met | does exactly what the id says; Tested or Verified | none |
| 🧪 Untested | looks right, but Inspected only | Critical for REQ/SEC; Warning for CON/GUD/PAT/TEST |
| 🟡 Partial | some of the stated behaviour is there; name exactly what is missing | Major (Critical for SEC) |
| ❌ Missing | nothing implements it | Critical |
| ⚠️ Diverges | does something else, with no Differences entry | Critical |
| 📝 Accepted | differs, but logged under Differences or Decisions taken | none |
| 🔄 Outdated | the code is right and the spec is stale (a deliberate, unlogged improvement) | Warning: update the spec |
| ➖ Not started | its task hasn't started (only when checking work in progress) | none |

**Checked by code review.** A CON, GUD or PAT id that the spec itself marks "Checked by code review" (an implementation choice no test can observe, such as `process.exitCode` over `process.exit`) is ✅ Met on Inspected evidence: give the file:line, and grade it Diverges if the code does otherwise. It is not Untested and carries no Warning. This never applies to REQ or SEC ids, nor to a marker added outside the approved spec (a tasks Decisions row or a Differences entry).

**A logged test change is not Accepted.** A Differences entry or Decisions-taken row that narrows, weakens, removes or replaces a test for a REQ or SEC id, or leaves part of it to code review or reading, does not make that id Accepted. Grade the id on the evidence that remains: behaviour with no test left is Untested, behaviour only partly tested is Partial, at the severity in the table. Accepted is only for behaviour that differs on purpose. Phase and final checks must grade the same evidence the same way.

**Final check carries the phase findings.** Without `--phase`, read the newest `conformance*.md` of every `reports/phase-*/` folder first. Each Critical, Major and Warning they list appears in your report again at the same severity, unless you name what closed it (the test, `file › test name`, or the commit). Dropping a phase finding silently is not allowed: the same evidence gets the same grade.

**Materiality.** If the naming, file layout or technique differs but the behaviour and contract hold, the id conforms. Flag missing behaviour, contradicted decisions, broken contracts, skipped validation or migration steps, and unplanned scope. When torn between two statuses, give the evidence for both and pick the stricter one.

## 4. Whole-change checks

- **Scope (code → spec).** List meaningful behaviour that no spec id covers: routes, exports, tables or columns, env vars, UI states, background jobs. If it is public API, schema or security-relevant, it is Critical; internal behaviour is a Warning; harmless helpers need no entry.
- **Contracts.** Compare the data model with spec §3 (columns, types, constraints, indexes, triggers). Compare the API routes with the contract table (methods, request and response shapes, status codes). Compare config constants with their spec values.
- **Decisions.** Every CON, GUD and PAT id and every Decisions-taken row is followed, and no rejected ALT has crept in.
- **Tasks file.** Flag ticked tasks whose ids aren't Met, unticked tasks that look done, and divergences missing from Differences.
- **Coverage smells** (Warning). Flag ids whose tests are happy-path only, or whose tests all share one setup.

For a large spec (40+ ids), offer to grade sections in parallel with read-only subagents. Each one gets its id list, the spec path, the test log path, and the tier and status tables above, and returns one row per id. You run steps 2 and 4 and the synthesis yourself.

## 5. Report

Write the report to the `REPORT:` path from your prompt. Without one, use `plans/<feature>/reports/final/conformance.md` (with `--phase N`: `reports/phase-N/conformance.md`), adding `-2`, `-3` instead of overwriting an earlier one. That report is the only file you write.

**Severity mapping**, the same as every pipeline SUMMARY (p0 and p1 fail, p2 never does): Critical → p0, Major → p1, Warning → p2. Unplanned public behaviour (see Scope) is Critical; unplanned internal behaviour and coverage smells are Warnings. Post the summary and the gaps in chat, then end with this block and nothing after it:

```
SUMMARY
verdict: pass|fail
p0: <Critical count>
p1: <Major count>
p2: <Warning count>
top:
- <id> <status> <one line>   (max 5, Critical first)
report: <the report path>
```

`verdict` is `fail` when p0 or p1 is above 0.

```
---
spec: plans/<feature>/feature-<feature>-spec.md
spec_version: <from spec front-matter>
checked: <YYYY-MM-DD>
commit: <short sha, or "no git">
tests: <command>: <passed>/<total> (<log location>)
mode: full | diagnostic (suite failing) | phase N
---

# Conformance: <feature>

**Summary:** <n> met · <n> untested · <n> partial · <n> missing · <n> diverge · <n> accepted · <n> outdated
**Verdict:** conforms | conforms with gaps | does not conform

## Critical
- **REQ-014** ⚠️ Diverges: spec: at most 5 turns; `lib/memory/recall.ts:88` returns 10. No Differences entry.

## Major
## Warnings
## Real run
<command and output, or "the spec names no runnable example">
## Attention
<only with DECISIONS: in the prompt>
## Not in the spec
## Contracts (data model, API, config)
## Tasks file
## All ids
| Id | Status | Tier | Evidence (code) | Test |
|---|---|---|---|---|
```

Omit empty sections.

**Attention** (when the prompt has `DECISIONS: <decisions.tsv>`, an unattended run): read the decision trail and list, most important first, what the user must look at before accepting: fix rounds that did not converge, units committed with open findings, added units, skipped steps, accepted Differences that change behaviour, anything decided without the user. One line each, with the row's step and evidence. You did not do this work; judge it as an outsider.

## 6. Next steps

When you run as a subagent, skip this section: the SUMMARY block is your last output. Otherwise offer these options, and wait for the user to pick before changing anything:

- **Fix the Critical items** as new or reopened tasks, test-first.
- **Record intended divergences.** For Outdated or intended divergences, log them under **Differences from the spec** and update the spec through `writing-specs`.
- **Correct task ticks** that don't match the evidence.
- **Run `reviewing-code`** on the areas where the evidence was thin, to look for defects the spec doesn't name.

A clean report means the evidence covers the spec, not that the code has no bugs. Say so in the summary.
