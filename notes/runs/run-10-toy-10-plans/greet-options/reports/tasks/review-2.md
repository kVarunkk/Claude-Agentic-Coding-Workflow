# tasks/review-2.md

Target: `plans/greet-options/feature-greet-options-tasks.md` (v0.1), reviewed against `plans/greet-options/feature-greet-options-spec.md` (v0.3) and `plans/greet-options/feature-greet-options-brief.md`.

Date: 2026-11-19

Mode: `tasks` (PARTIAL review: the earlier report `plans/greet-options/reports/tasks/review.md` was still the `verdict: pending` skeleton, so there were no prior findings to carry over. This is a full review.)

## Mechanical checks

`bash .dostuff/scripts/check-plan.sh plans/greet-options` → exit 0, no FAIL, no WARN.

```
Checked feature-greet-options-spec.md + feature-greet-options-tasks.md: 35 REQ/SEC ids, 18 tasks.
OK
```

## Findings

### F01 [P1] tasks.md:71 (TASK-010) REQ-003 is only tested for `--name`; `--times`, `--lang` and `--format` have no repeated-flag test

REQ-003 says: "When the same flag is given more than once, then the last occurrence wins and no error is raised; this holds for `--name`, `--times`, `--lang` and `--format` (D-01)."

TASK-010's Red step writes exactly one repetition case: `parseArgs(['--name', 'Bob', '--name', 'Ada'])` returns `{ name: 'Ada' }`. No task writes a repeated `--times`, `--lang` or `--format` (verified by grep across the file: the only repeated-flag literal is the `--name` one). TEST-002 says "takes the last occurrence of a repeated flag", which reads as one case, but REQ-003 enumerates four flags, and the conformance check grades REQ-003 as one id: with only `--name` covered, three quarters of it will grade Untested or Partial.

Fix: in TASK-010's Red step, add `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }`, `parseArgs(['--lang', 'es', '--lang', 'fr'])` returns `{ lang: 'fr' }` and `parseArgs(['--format', 'json', '--format', 'text'])` returns `{ format: 'text' }`, all with no error. (TASK-030 and TASK-031 already exist and are the natural owners of the last two, so splitting them there is also acceptable as long as each of the four flags gets one case.)

### F02 [P1] tasks.md:85 (TASK-021) TEST-016 is claimed but its `--shout=true` case is never written

TEST-016 says: "`parseArgs` raises the usage error for `--shout=true` and for a bare `--` argument, and raises the usage error for a single-dash argument used as a flag (`-n`, `-x`)."

TASK-021 lists TEST-016 in its Tests column, but its Red step writes only `parseArgs(['Ada'])`, `parseArgs(['--', 'Ada'])`, `parseArgs(['--name', 'Ada', 'extra'])` and `parseArgs(['-n'])`. The `--shout=true` case appears nowhere in the tasks file (verified by grep: only the spec mentions it). The bare `--` case is only covered as `['--', 'Ada']`, not `--` on its own, and `-x` as a bare flag is never tested. The spec's §4.1 rule ("`--shout` takes no value. `--shout=true` is not accepted: it is an unknown flag and a usage error") therefore has no test, and conformance will grade it Untested.

Fix: add to TASK-021's Red step, in `test/options.test.js`: `parseArgs(['--shout=true'])` throws `UsageError`, `parseArgs(['--'])` throws `UsageError`, and `parseArgs(['-x'])` throws `UsageError`. Add a CLI case for `--shout=true` in `test/cli.test.js` (empty stdout, one usage line, exit 2) so the exit-code path is covered too.

### F03 [P1] tasks.md:84 (TASK-020) TEST-028's CLI half is never written

TEST-028 says: "running `bin/greet.js` with `--name -x` prints `Hello, -x` on stdout and exits 0, so a value starting with a single dash is an ordinary value (REQ-005). Running it with `--name --shout` prints one usage line on stderr and exits 2."

TASK-020 lists TEST-028 in its Tests column. Its Red step writes the unit case `parseArgs(['--name', '-x'])` returns `{ name: '-x' }`, and the CLI cases for `--name` as the last argument, `--name ""` and `--name --shout`. The CLI case `--name -x` printing `Hello, -x` and exiting 0 is never written anywhere (verified by grep: `'-x'` appears only in the unit-level assertion). REQ-005 is a CLI-level requirement ("the CLI prints nothing on stdout ... and exits with code 2" for the error half, "uses `-x` as the name" for the ordinary-value half), so the end-to-end half of it has no test.

Fix: add to TASK-020's Red step, in `test/cli.test.js`: the binary run with `--name -x` prints `Hello, -x\n` on stdout, nothing on stderr, and exits 0.

### F04 [P1] tasks.md:84, :71 (TASK-020, TASK-010) The plan decides nothing about two edge cases the spec leaves open, and both have two reasonable implementations

(a) A repeated `--name` whose last occurrence is empty. REQ-003 says the last occurrence "wins and no error is raised"; REQ-006 says an empty `--name` value is a usage error. For `parseArgs(['--name', 'Ada', '--name', ''])` the plan allows two implementations: validate each value as it is parsed (raises `UsageError` on the empty one), or store the last value and validate once at the end (the same `UsageError`, but raised for a different reason and with a different message). TASK-010's Green says only "treats the last occurrence of a repeated flag as the value" and TASK-020's Green says only "a name value of the empty string raises `UsageError`" without saying when.

(b) The equals form with a `--`-prefixed value. Spec §4.1 says "A value that starts with `--` is treated as a missing value, not as the value of the flag (REQ-005)" and PAT-002 says the space and equals forms give "the resulting value identical". For `--name=--foo` the plan is silent: TASK-020's Green only describes the space form ("a flag that takes a value raises `UsageError` when no next argument exists or when the next argument starts with `--`"), so `--name=--foo` may be a usage error or the ordinary name `--foo`.

Neither case has a test, and neither is in the plan's "Decisions taken for these tasks" table, which is the place the writing-tasks skill expects such choices to land ("every choice the spec left open that an implementer would otherwise stop and ask about").

Fix: add one row to the Decisions table stating that a flag value is validated when it is read, so the last occurrence's value is the one validated (a) `parseArgs(['--name','Ada','--name',''])` raises `UsageError`, and that the `--`-prefix rule applies to the equals form too, so `--name=--foo` raises `UsageError` (b). Then add the two assertions to TASK-020's Red step.

### F05 [P2] tasks.md:150, :162, :163, :175, :176 (TASK-071, TASK-080, TASK-081, TASK-090, TASK-091) Five units are marked `**Red:**` but their tests already pass once the earlier units are green

The writing-tasks skill and the reviewing-plans skill both require a test that passes as soon as it is written to be marked `**Guard:**`, not `**Red:**`. Reading the Green steps in the file shows the plan already knows this:

- TASK-071's Green says "no change is needed in `bin/greet.js` beyond what TASK-070 wrote, because `readConfig` already returns `{}` ... and `mergeSettings` already falls back per key". All five of its Red assertions (invalid `times`, unknown key, malformed JSON, `null`, invalid `lang`) already pass after TASK-070.
- TASK-080's Green says "`mergeSettings` already takes the flag value for the key the flag covers and the config value for every other key". All three Red assertions already pass after TASK-070.
- TASK-081's Green says "the parent-directory case already passes; the file-list case already passes; and the config value is interpolated as plain data, so the literal-name case already passes". All three Red assertions are guards.
- TASK-090's Red assertions are already satisfied by TASK-050's text `render` (the name is interpolated verbatim) and TASK-051's `JSON.stringify` (the newline is escaped).
- TASK-091's Red assertions are already satisfied by TASK-041 (the name is used as given) and TASK-070 (the config name is untrimmed).

Consequence: an implementer following the writing-tasks rules ("A `**Red:**` test that passes before its code is written: log it with the reason") will log five units' worth of spurious Differences, and the plan's "Guard:" mechanism, which exists precisely for this, is never used.

Fix: relabel the `**Red:**` markers in TASK-071, TASK-080, TASK-081, TASK-090 and TASK-091 as `**Guard:**` with one line each naming the earlier task that makes the test pass (for example "Guard: TASK-070 already reads the config file and TASK-061 already falls back per key"), and keep the `**Green:**` step as the confirmation.

### F06 [P2] tasks.md:104, :117, :169 (Phase 4, Phase 5, Phase 9) The `depends:` lines understate real dependencies on Phase 3

Phase 3 (TASK-030, TASK-031) is where `--times`, `--lang` and `--format` become parseable. Three later phases use them in their CLI tests but do not declare the dependency:

- Phase 4 (L104, `depends: 1`) — TASK-040's CLI test runs the binary with `--lang es --name Ada`.
- Phase 5 (L117, `depends: 4`) — TASK-050's CLI test runs the binary with `--name Ada --times 3` and `--name Ada --times 2 --lang es`.
- Phase 9 (L169, `depends: 5, 7`) — TASK-090's CLI test runs the binary with `--times 2` and `--format json`.

The runner picks units in file order (`next-unit.sh` prints "the first unit (file order) that has an open task"), so the build does not break today. The declared graph is still wrong, and a reader who trusts `depends:` would schedule Phase 4 before Phase 3 and get a red unit.

Fix: change Phase 4 to `depends: 1, 3`, Phase 5 to `depends: 3, 4`, and Phase 9 to `depends: 3, 5, 7`.

### F07 [P2] tasks.md:163 (TASK-081) The parent-directory test writes `greet.config.json` into the shared system temp directory and leaves it there

TASK-081's Red step says to "put a `greet.config.json` holding `{"name": "Parent"}` in the parent of the temporary directory". The temporary directory comes from `fs.mkdtempSync(path.join(os.tmpdir(), 'greet-'))` (Decisions table), so the parent is `os.tmpdir()` itself. The Decisions table's cleanup rule ("removed with `fs.rmSync(dir, { recursive: true, force: true })` after the test") removes only the `greet-XXXX` child, so the file is left in the shared system temp directory for the rest of the machine's life and for every later run of the suite. `node --test` runs test files in parallel, so any test that ever uses `os.tmpdir()` as a working directory would pick it up.

Fix: in TASK-081, create a dedicated parent with a second `fs.mkdtempSync`, put the `greet.config.json` in that parent and the child working directory inside it, then remove the parent in the same cleanup; add the parent to the Files/cleanup note.

### F08 [P2] tasks.md:41 (Decisions table) The claim "The repo directory is never used as a working directory for a test" is not true

The Decisions table says: "The repo directory is never used as a working directory for a test, so a real `greet.config.json` in the repo root can never change a test result."

`test/greet.test.js` (preserved unchanged, per the spec) calls `execFileSync(process.execPath, [bin, ...args], { encoding: 'utf8' })` with no `cwd`, so it runs the binary with the repository root as the working directory. Once `bin/greet.js` reads the config file (TASK-070), a `greet.config.json` in the repo root would change the result of the existing `cli defaults to world` and `cli takes --name` tests. The repo has no such file today, so nothing fails now, but the stated guarantee does not hold and the risk is real the moment a developer creates one while testing the feature by hand.

Fix: either soften the Decisions row to name `test/greet.test.js` as the one exception and say what happens if the repo root holds a config file, or add `cwd` to that existing test's helper (which changes a file the spec says stays unchanged, so it must be logged as a Difference).

### F09 [P2] tasks.md:191 (traceability table) REQ-010 does not list TASK-051

REQ-010 covers both output formats: "in text format each repetition is one line, in JSON format the single object's `greeting` value holds the greeting repeated". The traceability row reads `REQ-010 | TASK-050` only. TASK-051 is the unit that builds the JSON half (it cites REQ-022 and REQ-023 and lists TEST-010 and TEST-017).

Fix: change the row to `REQ-010 | TASK-050, TASK-051`.

### F10 [P2] tasks.md:163 (TASK-081) The Files column omits `src/options.js`, which the task's Green step names

TASK-081's Files column is `src/config.js, bin/greet.js, test/cli.test.js`. Its Green step says the code-review assertion covers "`bin/greet.js`, `src/options.js` and `src/config.js`". The writing-tasks skill requires the Files column to list every file the task creates or changes.

Fix: add `src/options.js` to TASK-081's Files column.

### F11 [P2] tasks.md:85 (TASK-021) The Green wording "a single-dash argument is an unknown flag, not a value" reads as a contradiction of TASK-020

TASK-020's Green says "a value that starts with a single `-` is used as an ordinary value"; TASK-021's Green says "a single-dash argument is an unknown flag, not a value". The two are consistent only if "argument" means "an argument in flag position", but read literally they contradict, and an implementer may pick either reading and break REQ-005 (`--name -x` prints `Hello, -x`).

Fix: reword TASK-021's Green to "a single-dash argument that is not consumed as a preceding flag's value is an unknown flag; a single-dash argument in value position is an ordinary value (TASK-020)".

### F12 [P2] tasks.md:50 (Decisions table) The `times` grammar row states a behaviour (`03` is 3) that no test covers

The Decisions table says: "The command-line value must match `^[0-9]+$` exactly, so `03` is the number 3". No task writes `parseArgs(['--times', '03'])`. REQ-011's own named list does not include `03`, so this is not a REQ gap, but the Decisions table states a behaviour that nothing checks, and the writing-tasks skill warns that a Decisions row which leaves behaviour untested fails conformance later.

Fix: either drop `03` from the Decisions row (the `^[0-9]+$` rule and the tested cases already carry the rule), or add `parseArgs(['--times', '03'])` returns `{ times: 3 }` to TASK-030's Red step.

### F13 [P2] tasks.md:58 (Review focus) Item 2 names TASK-070 for the config-`shout` case, which does not test it

Review focus item 2 says "Test in TASK-070 and TASK-080". TASK-070's Red step covers a config file with `name` and `lang` only; the config `shout` case is in TASK-080 alone.

Fix: change the line to "Test in TASK-080."

### F14 [P2] tasks.md:176 (TASK-091) The Green step asserts "the seeded trimming test in `test/zz-seeded.test.js` is still the only failing test in the suite"

`test/zz-seeded.test.js` is written by `scripts/seed-red.sh` and is not part of the repository today (`test/` holds only `greet.test.js`). The assertion only holds if the seed script has been run, and it also fails if any other unrelated test is broken. The Introduction already tells the reader that the seeded failure is expected, so this adds a brittle claim on top of an accurate one.

Fix: drop the "only failing test in the suite" clause and keep "the seeded trimming test in `test/zz-seeded.test.js` still fails, because REQ-017 and D-16 forbid trimming" as a plain statement about the seeded file, or remove the clause entirely.

## Coverage summary

Every REQ id (REQ-001 to REQ-042) and every SEC id (SEC-001 to SEC-004) is referenced by at least one task, and every task maps to at least one spec id. The gaps found are gaps inside a cited requirement, not missing rows: REQ-003 (F01), REQ-005's CLI half (F03), TEST-016 (F02).

All 31 TEST ids in the spec §9 are claimed by at least one task. Two of them (TEST-016, TEST-028) are claimed but not fully written (F02, F03).

## Open items for the writer

- Nothing in the plan depends on a code change I could not verify: `src/greet.js` keeps its signature, `test/greet.test.js` keeps passing with the new `bin/greet.js` (it asserts `Hello, world\n` and `Hello, Ada\n`, both of which the new code still prints), and `package.json` is untouched, so CON-002 and CON-003 hold.
- The `bin/greet.js` churn (a temporary flag-to-default merge built in TASK-010 and TASK-040, replaced by `mergeSettings` in TASK-070) is explicitly decided in the Decisions table and never ships. Noted, not a finding.

SUMMARY
verdict: fail
p0: 0
p1: 4
p2: 10
top:
- REQ-003 is only tested for `--name`; `--times`, `--lang` and `--format` have no repeated-flag test (F01)
- TASK-021 claims TEST-016 but never writes the `--shout=true` case (F02)
- TASK-020 claims TEST-028 but never writes the CLI case `--name -x` printing `Hello, -x` (F03)
- The plan decides nothing about a repeated `--name` ending empty, nor about `--name=--foo` (F04)
- Five units are marked Red but their tests already pass after earlier units (F05)
report: plans/greet-options/reports/tasks/review-2.md
