---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 53f32ec
tests: npm test: 59/59 (log: ${TMPDIR:-/tmp}/greet-phase4-tests.log)
mode: phase 4
---

# Conformance: greet-options (phase 4)

**Summary:** 14 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms

Phase 4 covers TASK-401 and TASK-402: the CLI entry point in `bin/greet.js` (the parse → load →
merge → build → render pipeline, the usage-error path and the exit codes) and the `formatUsage`
export in `src/greet.js`. Every id in the two task rows' Spec column is graded below on the
behaviour those rows ask for. Ids whose remaining part a later phase owns are marked
➖ Not started with the owning task named.

Phase 3's two open P2 Warnings (the unreadable-config branch and the stale fixture enumeration)
are carried forward unchanged; neither is a phase-4 finding and neither was closed by this unit.
The phase-4 review's one P1 (F01, the usage-error test asserted only the stderr prefix) was fixed
in the unit's fix round and the fix is present in today's tree (`test/greet.test.js:408` asserts
the exact stderr string).

## Critical

None.

## Major

None.

## Warnings

None new in phase 4. The two phase-3 Warnings are carried to the final report (see "Carried from
earlier phases"), at the same severity.

## Real run

`npm test` (`node --test`): **59 tests, 59 pass, 0 fail, 0 cancelled, 0 skipped, 0 todo.**
Log: `${TMPDIR:-/tmp}/greet-phase4-tests.log`. Node v22.20.0. `package.json` unchanged
(`npm test` still `node --test`; no new dependency, no new script).

The spec names a runnable CLI example (`node bin/greet.js ...`, spec §9 process seam). I ran the
real CLI against a scratch directory and captured stdout, stderr and the exit code for every case
in phase 4's slice, as Verified evidence:

```
greet                       -> exit=0 stdout="Hello, world\n"        stderr=(empty)
greet --name Ada --shout    -> exit=0 stdout="HELLO, ADA\n"          stderr=(empty)
greet --lang es             -> exit=0 stdout="Hola, world\n"         stderr=(empty)
greet --lang fr             -> exit=0 stdout="Bonjour, world\n"      stderr=(empty)
greet --times 3             -> exit=0 stdout=3 lines, last byte one \n
greet --times 5             -> exit=0 stdout=5 lines
greet --times 1             -> exit=0 byte-identical to `greet` (cmp: IDENTICAL)
greet --format json         -> exit=0 stdout='{"greeting":"Hello, world"}\n'  (1 line, no space after colon)
greet --name Ada --format json --shout -> exit=0 stdout='{"greeting":"HELLO, ADA"}\n'
greet --times 3 --format json -> exit=0 stdout='{"greeting":"Hello, world\nHello, world\nHello, world"}\n'
greet --nmae x               -> exit=2 stdout=0 bytes  stderr="usage: greet [options] unknown flag: --nmae\n"  (1 line)
greet --help                 -> exit=2 stdout=0 bytes  stderr="usage: greet [options] unknown flag: --help\n"
greet --version              -> exit=2 stdout=0 bytes  stderr="usage: greet [options] unknown flag: --version\n"
greet Ada                    -> exit=2 stdout=0 bytes  stderr="usage: greet [options] unexpected argument: Ada\n"
greet --name                 -> exit=2 stdout=0 bytes  stderr="usage: greet [options] missing value for --name\n"
greet --name ""              -> exit=2 stdout=0 bytes  stderr="usage: greet [options] empty value for --name\n"
greet --name -x              -> exit=2 stdout=0 bytes  stderr="usage: greet [options] missing value for --name\n"
greet --name=Ada             -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid flag syntax: --name=Ada\n"
greet --                     -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid argument: --\n"
greet --times 0              -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid value for --times: 0\n"
greet --times abc            -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid value for --times: abc\n"
greet --times 03             -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid value for --times: 03\n"
greet --lang de              -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid value for --lang: de\n"
greet --format xml           -> exit=2 stdout=0 bytes  stderr="usage: greet [options] invalid value for --format: xml\n"
JSON keys across combinations (--format json with and without --shout/--times/--name/--lang) -> ["greeting"] every time
greet --times 3 | cat       -> 39 bytes (no truncation through a pipe)
```

The spec's §4.3 usage-error table rows that belong to phases 5 and 6 (the remaining exact reason
strings, and the config reasons) are not phase 4's slice; the table above shows them anyway
because they are cheap and they confirm no divergence.

### Mutation pass (my own, in a scratch copy outside the repo)

Every phase-4 behaviour turns red on a targeted mutation, so the tests really pin the claim and
not just the file names. Baseline in the scratch copy: 59 pass, 0 fail. Results (`pass/fail`):

```
M1  formatUsage ignores its reason argument        -> 58/1   (red)
M2  formatUsage drops the trailing newline          -> 58/1   (red)
M3  formatUsage emits two lines instead of one      -> 58/1   (red)
M4  the usage-error path exits 1 instead of 2       -> 58/1   (red)
M5  the usage line goes to stdout, not stderr       -> 58/1   (red)
M6  the success path exits 1 instead of 0            -> 48/11  (red)
M7  the JSON object gains a second key              -> 48/11  (red)
M8  the JSON value gets a trailing newline in-string -> 49/10  (red)
M9  the JSON output gains a space after the colon    -> 49/10  (red)
M10 the text format drops the repeat count           -> 56/3   (red)
M11 buildGreeting never upper-cases the line         -> 55/4   (red)
M12 the text output loses its trailing newline      -> 50/9   (red)
M13 the CLI writes to stdout before the render       -> 49/10  (red)
M14 the success path writes to stderr               -> 58/1   (red)
M15 the usage path also writes to stdout            -> 58/1   (red)
M16 the CLI ignores the parsed flags                -> 51/8   (red)
M18 formatUsage prints a fixed wrong reason         -> 58/1   (red)
M19 formatUsage prints the wrong prefix             -> 58/1   (red)
M20 the text format uses CRLF                       -> 50/9   (red)
M21 --times 1 emits an extra newline                -> 53/6   (red)
M22 buildGreeting ignores options.shout             -> 55/4   (red)
M23 GREETING_WORDS.es maps to "Hello"               -> 55/4   (red)
M24 GREETING_WORDS.fr maps to "Hello"               -> 56/3   (red)
M25 the default name is "there", not "world"        -> 53/6   (red)
```

One mutant stayed green: **M17**, reading the JSON repeat count from `options.times` instead of
`greeting.count` (59/0). It is an equivalent mutant, already judged equivalent in the phase-2
review (`reports/phase-2/conformance-2.md`): spec §4.2 calls `buildGreeting(options)` and
`renderOutput(options, greeting)` with the same options object, and `buildGreeting` sets
`count: options.times`, so `greeting.count === options.times` on every production path.

## Attention

- `decisions.tsv` row `2026-11-20T12:21:49Z` (unit-4 gate-reason, REQ-071): the unit's one P1 was
  that the usage-error test asserted only the stderr prefix, the trailing newline and the line
  count, so a `formatUsage` that discarded its reason left the suite green. The fix asserts the
  exact stderr string and is present in today's tree (`test/greet.test.js:408`). I re-ran that
  mutation myself (M1, M18) and both turn the suite red, so the finding is closed by evidence,
  not by the note.
- `decisions.tsv` row `2026-11-20T12:21:49Z` (unit-4 gate-reason): two mutants stayed green and
  were set aside by the reviewer: the non-`UsageError` re-throw branch (no REQ or SEC id in the
  unit's Spec column states it, and the branch is unreachable because `loadConfig` converts every
  config problem into a `UsageError`) and the `process.exit(0)` flush mutant (equivalent on this
  platform, where Node's stdout to a pipe is synchronous). I checked the second independently:
  `bin/greet.js` contains no `process.exit(` call, so the implementation follows spec §4.2
  exactly, and the piped run above produced all 39 bytes. The first is a real, small coverage gap
  in a branch that no phase-4 row owns; I record it below as a coverage note rather than a
  Warning, because no phase-4 requirement states it.
- `decisions.tsv` row `2026-11-20T11:58:02Z` (phase-3 gate-reason): the user accepted phase 3
  with two P2 Warnings open (the unreadable-config branch has no test; the spec §8 fixture
  inventory and the plan's Decisions-row fixture list are stale relative to the three new fixture
  directories). The user accepted them explicitly, so they are not new findings, but they are
  carried to the final report as open.
- `decisions.tsv` rows `2026-11-20T11:39:17Z` and `2026-11-20T11:45:40Z` (phase-3 stop): the
  phase-3 gate stopped the run twice over P2-only verdicts. Phase 4 was built after that, and
  this phase-4 check passes clean, so the phase-3 stop is not repeated here.
- The four spec-gate answers Q-1 to Q-7 (`decisions.tsv`, 2026-11-19) are binding and were
  applied by the implementer, not re-decided here. No open spec question was answered by an
  implementation unit in phase 4.

## Not in the spec

None for phase 4. The unit adds exactly one exported function (`formatUsage`) and one export
line to `src/greet.js`, and rewrites `bin/greet.js` to the spec's §4.2 code. No new flag, no
sixth option, no `--help`, no `--version`, no environment variable, no new file in the shipped
package. `package.json` is unchanged. `bin/greet.js` is byte-for-byte the code the spec shows at
`plans/greet-options/feature-greet-options-spec.md:290-311`.

## Contracts (data model, API, config)

- **CLI surface (CON-004, REQ-001):** exactly the five options. Verified live: `--help` and
  `--version` are usage errors with exit code 2, as Q-3 and CON-004 pin.
- **Usage line (REQ-071, REQ-072):** `src/greet.js:184-186` returns
  `` `usage: greet [options] ${reason}\n` ``. The prefix is fixed, the reason follows one space,
  and the line ends with a single `\n`. Live stderr bytes for `--nmae x` are exactly 44 bytes,
  one `\n`, one line.
- **Exit codes (REQ-070, REQ-073):** `bin/greet.js:12` sets `process.exitCode = 0` on success and
  `bin/greet.js:16` sets `process.exitCode = 2` on a usage error. Both confirmed live.
- **stdout discipline (SEC-005, REQ-070):** the pipeline order is parse → load → merge → build →
  write, and `process.stdout.write` is reached only after every step that can throw. M13 (a write
  before the render) turns the suite red, so no partial output can precede a usage error.
- **JSON contract (REQ-051 to REQ-055):** `src/greet.js:49-58`. `JSON.stringify` on an object with
  the single key `greeting`, no space after the colon, one trailing `\n` outside the string, the
  repeated lines joined by `\n` with no trailing newline inside the string. Live output for
  `--format json` is `{"greeting":"Hello, world"}\n` (34 bytes) and the parsed key list is
  `["greeting"]` in every combination tried.
- **Text contract (REQ-050, REQ-031):** `src/greet.js:57` returns the line repeated
  `greeting.count` times, each followed by `\n`. Live: `--times 3` yields exactly three lines and
  `--times 1` is byte-identical to no arguments.
- **Preserved export (CON-003, TEST-018):** `greet(name)` still returns `Hello, ${name}`
  (`src/greet.js:36-38`) and the three pre-existing tests (`greet formats the name`,
  `cli defaults to world`, `cli takes --name`) are unchanged in `test/greet.test.js:35-45` and
  pass.

## Tasks file

- Ticked: TASK-401 and TASK-402 (`tasks:148-149`), both dated 2026-11-20. Every id in their Spec
  columns is Met in this report.
- Untick-worthy: none in phase 4. No ticked task in the file has an id that is not Met.
- Unticked: TASK-501, TASK-502, TASK-601, TASK-602, TASK-701, TASK-702, all `[ ]`, all in
  phases 5 to 7. None of them looks done: the CLI still has no end-to-end test for the remaining
  exact reason strings, the config file is not read end to end, and the name-fidelity and
  security-boundary cases are untested at the process seam. The behaviour itself is already
  correct (probed live above), but the coverage those tasks own is genuinely absent.
- **Differences from the spec:** no new entry was added in phase 4 and none is needed. The unit
  deviates from nothing: `bin/greet.js` matches spec §4.2 byte-for-byte, and `formatUsage`
  matches §4.1's contract exactly.

## Carried from earlier phases

Both phase-3 Warnings are carried at the same severity, per the final-check rule. Neither is
closed by this unit and neither is a phase-4 finding.

- **Coverage smell (the unreadable-config branch, `src/greet.js:146-151`):** the `catch` around
  `fs.readFileSync` has two paths and only the `ENOENT` one is guarded by a test; a file that
  exists but cannot be read has no test. The behaviour is correct (an `EISDIR` read error gives
  `UsageError` with reason `invalid greet.config.json`, which spec §4.3 pins). Same finding as
  `reports/phase-3/conformance-3.md` and `reports/phase-3/review-3-2.md:24`; the user accepted
  it at the phase-3 gate (`decisions.tsv` row `2026-11-20T11:58:02Z`).
- **Plan bookkeeping (three fixture directories outside the spec §8 inventory and outside the
  plan's Differences section):** `test/fixtures/top-level-string/`, `top-level-number/` and
  `top-level-boolean/` are added by TASK-303, documented in the task row rather than under
  Differences. No behaviour diverges. Same finding as `reports/phase-3/conformance-3.md` and
  `reports/phase-3/review-3a.md:11`; accepted at the phase-3 gate.

## Coverage notes

- `formatUsage` has no unit-seam test (`grep -n formatUsage test/greet.test.js` returns nothing);
  it is exercised only through the CLI. That is sufficient for the phase-4 requirements, because
  the CLI test asserts the exact stderr string and M1, M18 and M19 all turn the suite red.
- The re-throw of a non-`UsageError` in `bin/greet.js:18` has no test, and a mutant that turns
  every error into a usage line stays green. No phase-4 REQ or SEC id states this behaviour
  (spec §4.2 describes it as an implementation note), and the branch is unreachable because
  `loadConfig` converts every config problem into a `UsageError`. Not raised as a Warning; noted
  here so the phase-5 owner can pin it in TASK-501 if they want.
- The five TEST-015 inputs other than `--nmae x` (`--times 0`, `--lang de`, `--help`, `--name`,
  `--name ""`) are named by TEST-015 but are claimed by TASK-501 (phase 5), which pins each exact
  stderr line. Their behaviour is verified correct live above, but the exact-string assertions
  belong to phase 5, so they are ➖ Not started here.

## All ids
Met: REQ-010, REQ-030, REQ-031, REQ-033, REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-056, REQ-070, REQ-071, REQ-072, REQ-073, SEC-005, TEST-010, TEST-011, TEST-012, TEST-013, TEST-014, TEST-015, TEST-018

| Id | Status | Tier | Test |
|---|---|---|---|
| REQ-050 | ➖ Not started | — | text-format default at the CLI is exercised by TASK-401's `--times 3` case; the id's own owner is TASK-202/TASK-204 (phases 2), already Met there |
| REQ-074 | ➖ Not started | — | the usage-error *cases* are listed by TEST-015 but the exact per-flag reason strings are TASK-501/TASK-502 (phase 5) |
| TEST-016 | ➖ Not started | — | TASK-601 (phase 6) owns the config-file CLI case |
| TEST-017 | ➖ Not started | — | TASK-602 (phase 6) owns the broken-config CLI case |
| TEST-019 | ➖ Not started | — | TASK-701 (phase 7) owns the name-fidelity CLI case |
| TEST-020 | ➖ Not started | — | TASK-601 (phase 6) owns the parent-directory case |
| TEST-021 | ➖ Not started | — | TASK-702 (phase 7) owns the shell-metacharacter case |
| TEST-022 | ➖ Not started | — | TASK-602 (phase 6) owns the invalid-config-with-flag case |
| TEST-023 | ➖ Not started | — | TASK-501/TASK-502 (phase 5) own the pinned reason strings |
| TEST-024 | ➖ Not started | — | TASK-602 (phase 6) owns the empty config name case |
