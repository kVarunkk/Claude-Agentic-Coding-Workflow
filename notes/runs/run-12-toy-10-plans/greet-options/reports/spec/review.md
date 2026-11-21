# Spec review: greet-options

- Target: `plans/greet-options/feature-greet-options-spec.md`
- Mode: spec
- Date: 2026-11-21

## Findings

F01 [P1] feature-greet-options-spec.md:60 SEC-001 contains negatives with no bounded check named: "never an environment variable or absolute path", "is not executable", and "oversized content cannot reach the formatter". "Oversized" has no size bound at all, and "never"/"is not" can only be proven in full by a bounded check. Fix: name the check for each (e.g. a static assertion that only `<cwd>/greet.config.json` is opened and no `process.env`/absolute path is used; drop "oversized" or give it a byte limit with a test) and add the matching test.

F02 [P1] feature-greet-options-spec.md:62 SEC-002 ("never passed to a shell, `eval`, or the filesystem, and it never changes which file is read") is a negative id with no bounded check named, so no test can prove it. Fix: name the check (a static import/call ban on `child_process`/`eval` in `src/greet.js` and `bin/greet.js`, or a spy asserting the name is not passed to fs/shell) so the code review has a concrete thing to verify.

F03 [P1] feature-greet-options-spec.md:127 §4.1 `formatJson(greetings, times)` is specified and unit-tested only for the array case (TEST-005, line 189); the single-greeting bare-string case (REQ-010, REQ-012) is never assigned to a pure-function contract or a unit test. If `formatJson` always receives an array, `JSON.stringify({greeting: greetings})` would emit `{"greeting":["Hello, world"]}` and contradict REQ-010. Fix: specify the single case (string vs one-element array, and what `times` is for) and add a unit test alongside TEST-005 for `{"greeting":"Hello, world"}\n` and `{"greeting":"HELLO, ADA"}\n`.

## Notes

- Brief decisions D-01, D-02, D-03 and the out-of-scope positional rule are all honoured; the Q-1/Q-2/Q-3 open questions correctly flag the three places the spec took a reading beyond the brief's literal text.
- No placeholders, no naming drift between files, and the usage-line text matches REQ-031 across §4.2 and TEST-015.

SUMMARY
verdict: fail
p0: 0
p1: 3
p2: 0
top:
- SEC-001 and SEC-002 are unbounded negatives; name a bounded check for each.
- formatJson is specified/tested only for the array case; the single bare-string case is ambiguous and untested at the unit seam.
report: plans/greet-options/reports/spec/review.md
