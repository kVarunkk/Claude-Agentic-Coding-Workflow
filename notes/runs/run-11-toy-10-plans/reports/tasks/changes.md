# P2 notes to fix in the tasks file

Source: plans/greet-options/reports/tasks/review-2.md (verdict: pass, p2: 1)

1. **F11** - TASK-203's two cases are labelled `**Red:**` but they already pass once
   TASK-202's Green is in place. Relabel TASK-203's cases as `**Guard:**` and say in the
   task that TASK-202's Green already makes them pass. If TASK-203 then adds no new
   behaviour, fold it into TASK-202 and keep the phase at two tasks.

2. **F08** - The Decisions row says `OPTION_SPECS` holds "their reason prefixes", which
   disagrees with TASK-101's Green. Make the Decisions row agree with TASK-101.

3. **F09** - The Decisions row cites GUD-003 for the `OPTION_SPECS` decision. GUD-003 is
   the greeting-word map; the option list is RISK-004's mitigation with GUD-001's
   one-file layout behind it. Correct the citation.

4. **F10** - Sibling units sharing a `depends:` set list overlapping Files. The new
   Phase 2b shares `depends: 1` with Phase 2a and Phase 3 and lists the same
   `src/greet.js` and `test/greet.test.js`. The runner works in file order, so this does
   not block the build, but make the Files column reflect what each unit actually
   changes.

Change nothing else.
