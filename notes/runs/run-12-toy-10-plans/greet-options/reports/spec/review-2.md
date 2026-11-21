# Spec review (recheck): greet-options

- Target: `plans/greet-options/feature-greet-options-spec.md`
- Mode: spec (recheck)
- Date: 2026-11-21
- Previous report: `plans/greet-options/reports/spec/review.md`

## Recheck of previous findings

F01 [P1] feature-greet-options-spec.md:60 **fixed**. SEC-001 now names a bounded static check (TEST-008) for each negative: "read from the working directory only" via the only-fs-call assertion, "contents are never executed" via the import/call/require-arg bans, and the unboundable "oversized content cannot reach the formatter" phrase is dropped (now "malformed content never reaches the formatter", grounded in REQ-021/REQ-030 with TEST-007/TEST-015).

F02 [P1] feature-greet-options-spec.md:62 **fixed**. SEC-002 now names TEST-008: the child_process/eval/Function import-call ban bounds "never passed to a shell or `eval`", and the fixed `path.join(process.cwd(), 'greet.config.json')` assertion bounds "never changes which file is read".

F03 [P1] feature-greet-options-spec.md:127 **fixed**. `formatJson(value, times)` now specifies both shapes (single greeting string when `times` is 1, array when `times` > 1), and TEST-005 (line 189) unit-tests both single cases (`{"greeting":"Hello, world"}\n`, `{"greeting":"HELLO, ADA"}\n`) plus the array case.

## New findings

F04 [P1] feature-greet-options-spec.md:60 vs 192 SEC-001(a) claims the static test asserts "the only `fs` call in `bin/greet.js` is `readFileSync(path.join(process.cwd(), 'greet.config.json'))`", but TEST-008 only asserts "the only `readFileSync`/`readFile` occurrence" is that string. A write or other read (`writeFileSync`, `writeFile`, `appendFile`, `readdirSync`, `statSync`, `createWriteStream`, ...) would pass TEST-008, so CON-004's "no file is written / no other file is read" and SEC-002's "never passed to the filesystem" have no test that actually bounds them. Fix: align the two so TEST-008 asserts the only `fs.` method call in `bin/greet.js` is `readFileSync(path.join(process.cwd(), 'greet.config.json'))` (and name the write/read methods it bans), matching SEC-001(a).

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
top:
- SEC-001(a) says "only fs call is readFileSync" but TEST-008 only checks "readFileSync/readFile", leaving writes and other reads unbounded.
report: plans/greet-options/reports/spec/review-2.md
