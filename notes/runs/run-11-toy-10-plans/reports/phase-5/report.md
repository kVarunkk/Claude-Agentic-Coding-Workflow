# Phase 5 report: The usage-error contract end to end

Feature: greet-options
Phase: 5 (unit 5)
Previous tag: greet-options-phase-4

## Units and commits

| Unit | Tasks | Commit | Last review | Verdict |
|---|---|---|---|---|
| 5 | TASK-501, TASK-502 | d76d786 | plans/greet-options/reports/phase-5/review-5-2.md | pass (p0: 0, p1: 0, p2: 0, scope: clean, mutations: 11 run, 1 still green) |

## Reviews

| Report | Verdict | p0 | p1 | p2 | Note |
|---|---|---|---|---|---|
| plans/greet-options/reports/phase-5/review-5.md | fail | 0 | 1 | 0 | F01: a value containing a newline made stderr hold two lines, contradicting REQ-070 and REQ-072 |
| plans/greet-options/reports/phase-5/review-5-2.md | pass | 0 | 0 | 0 | recheck after 1 fix round |

## Fix rounds

1 round on unit 5. The fix added `oneLine` to `src/greet.js` and applied it inside
`formatUsage`, the single stderr writer, so a value holding a newline cannot make
stderr hold more than one line. The fix covers the flag path and the config path alike.
The stdout path is untouched: a name holding a newline is still echoed as given.

## Added units

None.

## Differences from the spec (phase 5 tasks)

- TASK-501 and TASK-502: the Red cases pass as soon as they are written, so the
  end-to-end layer only needed the tests. The reasons were already pinned by TASK-102
  at the unit seam and the `usage: greet [options] ` prefix and exit code 2 were already
  wired by TASK-402. Each new test was checked to be load-bearing by mutating the prefix,
  the exit code and each reason string in turn.
- TASK-502 (TEST-023): the config half of TEST-023, the `usage: greet [options] invalid greet.config.json\n`
  line for a config file whose top level is not an object, is not tested here. It needs a
  child process run with a `cwd` set to a fixture directory, and the `runIn` helper
  belongs to TASK-601 and the config CLI tests to TASK-602. REQ-066 is already traced to
  TASK-301, TASK-303 and TASK-602.
- TASK-501 and TASK-502 (REQ-070, REQ-071, REQ-072, SEC-005, GUD-004): `formatUsage` no
  longer returns `` `usage: greet [options] ${reason}` `` verbatim as spec §4.1 line 283
  states. It collapses a line break inside the reason to a space first, so a value that
  holds a newline cannot make stderr hold more than one line. REQ-070 and REQ-072 are
  absolute and win over §4.1's shorter description of the helper. The offending value is
  still named (GUD-005), so every reason string pinned in spec §4.3 stays byte for byte
  the same. The spec does not say what a newline-bearing value should look like in a
  reason, so this is the choice this unit made: the line break becomes a space.

## Conformance

Report: plans/greet-options/reports/phase-5/conformance.md
Verdict: pass (p0: 0, p1: 0, p2: 0)

All 10 ids Met, with no Untested, Partial, Missing, Diverges, Accepted or Outdated. The
matcher re-ran the CLI live and byte-compared all 15 flag-side rows of the spec's §4.3
table: every one matched exactly, with 0 bytes on stdout, exactly one `\n` on stderr and
exit code 2. Its mutation pass ran 17 mutants, all red except one equivalent mutant
(`oneLine`'s `+` quantifier), which it confirmed affects only consecutive line breaks,
a shape no cited id constrains.

The matcher's top findings:

- REQ-070: one stderr line, empty stdout, exit code 2 on every usage error
- REQ-071: the fixed prefix and the reason are pinned by exact-string assertions
- REQ-074: every bad input the spec lists is a usage error with exit code 2
- REQ-072: stderr holds exactly one line, including for a newline-bearing value
- SEC-005: stdout is 0 bytes on every usage error

The two phase-3 Warnings (the unreadable-config branch and the stale fixture inventory)
are carried forward at the same severity. Phase 5's diff touches neither.

## Attention for the user

The `formatUsage` change now diverges from spec §4.1 line 283's literal wording
("Returns `usage: greet [options] ${reason}`"). The decision row says the spec owner may
want to confirm the choice. The behaviour itself satisfies REQ-070 and REQ-072, and
every reason string the spec pins in §4.3 is unchanged. This is carried to the final
report as an open item.

## Test run

Command: `npm test`
Result: 78 tests, 78 pass, 0 fail, 0 skipped.

## Diffstat

```
 plans/greet-options/decisions.tsv                  |   7 +
 plans/greet-options/feature-greet-options-tasks.md |   8 +-
 plans/greet-options/reports/phase-5/review-5-2.md  | 156 ++++++++++++++++++
 plans/greet-options/reports/phase-5/review-5.md    | 130 +++++++++++++
 src/greet.js                                       |   6 +-
 test/greet.test.js                                 |  94 +++++++++++++
 6 files changed, 398 insertions(+), 3 deletions(-)
```
