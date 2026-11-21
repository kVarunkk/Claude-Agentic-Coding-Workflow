# P2 notes to fix in the new unit 2c

Source: plans/greet-options/reports/phase-2/fix-unit-review.md (verdict: pass, p2: 5)

1. **F01** - TASK-206 is marked `**Red:**` but all four of its assertions pass with the
   current code (its own Green says no `src/greet.js` change is needed). Relabel it
   `**Guard:**` like TASK-205, so the implementer does not log a spurious Difference and
   stop the unit.

2. **F02** - TASK-206's Files column lists `src/greet.js` even though the task says that
   file does not change. Remove it from the Files column.

3. **F03** - TASK-205 and TASK-206 cite TEST-009, but the spec's TEST-009 is the
   isolated-`renderOutput` test and does not cover REQ-056. The composed seam belongs to
   TEST-013 (TASK-402). Cite the right test ids.

4. **F04** - GOAL-009 claims the JSON value is proven end to end, but REQ-056 names four
   rules and no composed test uses `times > 1`, so the count rule over the seam is still
   only proven via a hand-written line literal. Either add a composed count case to
   TASK-205 or TASK-206, or narrow the GOAL wording to what is actually proven.

5. **F05** - TASK-206 cites REQ-012, REQ-020 and REQ-021, but the traceability table does
   not list TASK-206 under any of them. Add the traceability rows so the table and the
   Spec columns agree.

Change nothing else.
