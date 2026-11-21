# Review: unit 2c (TASK-205, TASK-206) — the REQ-056 JSON name and language auto-fix unit

Date: 2026-11-20
Unit: 2c / TASK-205, TASK-206 (Phase 2c, GOAL-009)
Mode: UNIT review (added unit). Reviewed against the finding it was added for: the REQ-056 🟡 Partial in `plans/greet-options/reports/phase-2/conformance.md:20`.
Files changed: `plans/greet-options/feature-greet-options-tasks.md` (new unit section + traceability rows only)

Findings: P0 0 · P1 0 · P2 5

## What the unit is for

The phase-2 conformance report graded REQ-056 🟡 Partial: the JSON `greeting` value followed the shout and count rules in tests, but the **name** and **language** rules in the JSON value were Inspected only, because every JSON test in `test/greet.test.js:161-191` passed a hand-written `line` literal into `renderOutput` and never composed `buildGreeting` with it.

Unit 2c adds exactly that seam: TASK-205 composes `buildGreeting` and `renderOutput` for a named, non-English greeting, TASK-206 does the same for name fidelity and the combined name/language/shout case. Both are unit-seam tasks in `test/greet.test.js`, which is the right seam for the gap (the CLI-level proof is TEST-013, already owned by TASK-402).

## The gap is closed

Probe against the live module (`node -e` against `src/greet.js`), each composition driven through one `options` object exactly as the task text specifies:

```
renderOutput(o, buildGreeting(o))  o={format:'json',name:'Ada',lang:'es'}      -> {"greeting":"Hola, Ada"}\n
renderOutput(o, buildGreeting(o))  o={format:'json',name:'Ada',lang:'fr'}      -> {"greeting":"Bonjour, Ada"}\n
renderOutput(o, buildGreeting(o))  o={format:'json',name:'  Ada  '}           -> {"greeting":"Hello,   Ada  "}\n
renderOutput(o, buildGreeting(o))  o={format:'json',name:'Ada',lang:'es',shout:true} -> {"greeting":"HOLA, ADA"}\n
```

All four expected strings in TASK-205 and TASK-206 match exactly. The name, the language and the shout rule are now exercised through the real seam rather than through a literal, which is what the conformance report asked for.

## Mechanical checks

- `bash .dostuff/scripts/check-plan.sh plans/greet-options` → `Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 50 REQ/SEC ids, 17 tasks.` then `OK`. No FAIL, no WARN.
- `bash .dostuff/scripts/fix-unit.sh plans/greet-options check 2c` → `fix unit 2c: only the new unit was added` (exit 0). The diff adds only the Phase 2c section and the REQ-056 traceability row.
- Unit id `2c` matches the script's grammar `^[0-9]+[a-z]?$` (`check-plan.sh` → `parse_tasks`, `lib.sh:116`). `depends: 2a, 2b` resolves to two existing unit ids, so the dependency check passes on real ids, not by luck.
- `MAX_UNIT_TASKS=2` (`.dostuff/pipeline.conf`); unit 2c has exactly 2 tasks, at the limit but within it.
- Source references in the task text are accurate: `src/greet.js:39` is the `${GREETING_WORDS[options.lang]}, ${options.name}` line and `src/greet.js:50` is the `Array.from(...).join('\n')` line that copies `greeting.line` into the JSON value. Both cited claims hold.
- Files disjointness: unit 2c (`depends: 2a, 2b`) does not share a `depends:` set with units 2a or 2b, so the disjoint-files rule does not apply here. Its only file is `test/greet.test.js`, plus `src/greet.js` on TASK-206 (see F02).

## Findings

F01 [P2] plans/greet-options/feature-greet-options-tasks.md:110 TASK-206 is marked `**Red:**` but all four of its assertions already pass with the current `src/greet.js` (probe output above). Its own Green text says "no change to `src/greet.js` is needed, because `buildGreeting` already applies the name verbatim and upper-cases the whole assembled line when `shout` is true". A test that passes as soon as it is written belongs under `**Guard:**`, with one line on which earlier code makes it pass, exactly as TASK-205 does. Fix: change TASK-206's `**Red:**` to `**Guard:**` and add the one-line reason (`buildGreeting` at `src/greet.js:38-44` applies the name verbatim and upper-cases the assembled line; `renderOutput` at `src/greet.js:46-55` copies `greeting.line` into the JSON value, so both cases pass at once).

F02 [P2] plans/greet-options/feature-greet-options-tasks.md:110 TASK-206's Files column lists `src/greet.js` ("`src/greet.js` changes only if a test fails"), but the Green explicitly says no change to `src/greet.js` is needed and the only expected edit is the test file. Listing a file the task tells the implementer not to change invites either a no-op edit or an out-of-scope refactor. Fix: make the Files column `test/greet.test.js` alone, and drop the `src/greet.js` clause from the Files note.

F03 [P2] plans/greet-options/feature-greet-options-tasks.md:109-110 TASK-205 and TASK-206 cite TEST-009, but the spec's TEST-009 (`feature-greet-options-spec.md:425`) is the isolated-`renderOutput` test and cites REQ-031, REQ-050, REQ-051, REQ-052, REQ-053 and REQ-055, not REQ-056. The composed `buildGreeting` → `renderOutput` seam is the spec's TEST-013 (route, `spec:429`, already owned by TASK-402) or no spec id at all. Citing TEST-009 as the proof of the REQ-056 seam is a mapping stretch that a conformance run will not find. Fix: drop TEST-009 from both rows, or replace it with a one-line note in the Task cell that the composed seam is the unit-level stand-in for TEST-013 (owned by TASK-402) and say so plainly.

F04 [P2] plans/greet-options/feature-greet-options-tasks.md:105 GOAL-009 claims "The JSON `greeting` value is proven end to end from `buildGreeting` through `renderOutput`", and the unit's **Done when:** line repeats the claim. REQ-056 names four rules (name, shout, language, count) and no composed test in 2c uses `times > 1`, so the count rule over the composed seam stays proven only by TASK-204's hand-written-line test (`renderOutput joins the repeated lines inside the JSON value`). The composed count case works (probe: `{format:'json',times:3,name:'Ada',lang:'es'}` → `{"greeting":"Hola, Ada\nHola, Ada\nHola, Ada"}\n`), so this is a wording/coverage gap, not a broken behaviour. Fix: add one composed count case (times 3, a named non-English greeting) to TASK-206, or narrow GOAL-009 to "the name, language and shout rules".

F05 [P2] plans/greet-options/feature-greet-options-tasks.md:110 TASK-206's Spec column cites REQ-012, REQ-020 and REQ-021, but the Requirement traceability table lists REQ-012 as `TASK-201, TASK-701` (line 191), REQ-020 as `TASK-201, TASK-202` (line 192) and REQ-021 as `TASK-201` (line 193). TASK-206 appears in neither, so the two halves of the plan disagree about who owns those ids. Fix: add TASK-206 to the REQ-012, REQ-020 and REQ-021 rows, or drop those three ids from TASK-206's Spec column (REQ-056 alone carries the composed claim; the ids stay owned by TASK-201 and TASK-701).

## Checked and fine

- **The unit is a real answer to the conformance gap.** The conformance report named the missing seam precisely (name and language in the JSON value, Inspected only) and 2c composes `buildGreeting` with `renderOutput` for exactly those two cases. The count rule was already graded tested, so 2c does not need to redo it.
- **TASK-205 is correctly marked `**Guard:**`** and gives the one-line reason the skill asks for, with accurate source references.
- **TASK-206 drives both functions through the same `options` object** and explicitly forbids "a hand-written `line` literal". That is the exact requirement that closes the coverage smell the conformance report raised.
- **Both expected byte strings are correct** against the live module, including the three spaces around `Ada` in `{"greeting":"Hello,   Ada  "}\n` and the whole-line upper-casing in `{"greeting":"HOLA, ADA"}\n`.
- **REQ-056's spec text is honoured.** `spec:71` asks that the JSON `greeting` value use the same name, shout, language and count rules as the text format; the composed cases prove name, language and shout (see F04 for count).
- **No scope creep.** The unit adds no export, no file, no dependency, no `package.json` change and no CLI surface. It only adds tests to `test/greet.test.js`, which is the file its rows name.
- **The unit ends green.** `npm test` is `node --test`; the unit adds passing tests to a suite that is currently 28/28 green, so the unit leaves the build runnable and green, as a sub-phase must.
- **Phase ordering holds.** 2c depends on 2a and 2b, both of which are ticked (`[x]`, 2026-11-20), and both of which 2c's composed tests build on (`buildGreeting` from TASK-201, the JSON branch from TASK-204). Later phases (3, 4, 5, 6, 7) do not depend on 2c, so adding it did not invalidate any other unit's `depends:`.
- **The added-unit rule is respected.** `fix-unit.sh check 2c` passes: only the Phase 2c section and the REQ-056 traceability row were added, and the unit sits after phase 2's last unit (2b) and before phase 3, which is where the script requires it.
- **No placeholders, no invisible characters, no TODO/TBD.** The script's placeholder and invisible-character scans are clean.

## Open questions

None blocking.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 5
top:
- TASK-206 is marked **Red:** but all four of its assertions pass with the current code (its own Green says no `src/greet.js` change is needed); it should be **Guard:** like TASK-205
- TASK-206's Files column lists `src/greet.js` even though the task says that file does not change
- TASK-205 and TASK-206 cite TEST-009, but the spec's TEST-009 is the isolated-`renderOutput` test and does not cover REQ-056
- GOAL-009 claims the JSON value is proven end to end, but no composed test uses `times > 1`, so the count rule over the seam is unproven
- TASK-206 cites REQ-012, REQ-020 and REQ-021, which the traceability table does not list it under
report: plans/greet-options/reports/phase-2/fix-unit-review.md
