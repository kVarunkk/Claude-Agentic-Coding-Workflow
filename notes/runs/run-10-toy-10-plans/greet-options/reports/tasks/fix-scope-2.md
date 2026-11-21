# Narrow recheck scope for the tasks file

Run `bash .dostuff/scripts/check-plan.sh plans/greet-options` once and report its result.

Then do only these four checks, in this order. Do not run the design-review or critical-challenge passes over the whole file, do not re-read the spec end to end, and do not re-verify findings that earlier reports already closed.

1. **F16 status.** Confirm that TASK-010's Red step asserts `parseArgs(['--shout'])` returns `{ shout: true }`, that its Green step states `parseArgs` recognises `--shout` as a flag that takes no value, and that REQ-015 is in TASK-010's Spec column. Report fixed or still open.

2. **The `times` and `format` wiring gap.** The candidate finding is that TASK-050 and TASK-051 never say where `bin/greet.js` gets `times` and `format` from before TASK-070 replaces the temporary merge, so their CLI Red tests (`--name Ada --times 3` printing three lines, `--format json --name Ada` printing the JSON line) have no stated code path. Check the Decisions table and the Green steps of TASK-050, TASK-051 and TASK-040. Grade this P0, P1, P2 or not a finding, with the line numbers you relied on.

3. **Traceability table drift.** Check whether these four pairs agree between the "Requirement traceability" table and the tasks' Spec columns: REQ-005 (table says TASK-020, TASK-090), REQ-010 (table says TASK-050, TASK-051), REQ-015 (table omits TASK-080), REQ-040 (table says TASK-011, TASK-030). Report each mismatch with both line numbers.

4. **Coverage confirmation.** Confirm that all 35 REQ/SEC ids and all 31 TEST ids in the spec appear in the tasks file and that every REQ/SEC id has at least one owner task. This is a set comparison, not a read of every task.

Write the report to the REPORT: path with the four results above and a SUMMARY block with the verdict and the counts. The verdict is fail if any p0 or p1 above 0, otherwise pass.
