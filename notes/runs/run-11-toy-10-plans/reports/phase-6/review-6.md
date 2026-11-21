# Review: unit 6 (TASK-601, TASK-602) (21f692f → staged)

date: 2026-11-20
base: 21f692fe1b5da6efc4aef835730ce826550615cd
scope: `git diff --cached 21f692f` (tasks file tick + Differences, three new fixture files, six new CLI tests)

Findings: P0 0 · P1 0 · P2 1 · P3 0    Partitions reviewed: 6

## Index

1. [P2][Low] F01: REQ-064's "no home directory / no user config directory" clause has no test `plans/greet-options/feature-greet-options-spec.md:81`

### F01: REQ-064's home-directory clause has no test

- Severity / confidence: P2 / Medium
- Location: `plans/greet-options/feature-greet-options-spec.md:81` (REQ-064), `test/greet.test.js:552-563` (the three TASK-601 CLI tests)
- Lens: tests | spec
- Failure: REQ-064 says "It does not look in parent directories, and it does not look at a home directory or a user config directory." The three new CLI tests cover the working-directory case and the parent-directory case only. No test puts a `greet.config.json` in `$HOME` (or a user config dir) and shows the CLI ignores it. A future change that added `path.join(os.homedir(), 'greet.config.json')` as a fallback would pass every test in this repo, because no fixture directory holds a second config file and no test sets `HOME`.
- Evidence: `grep -rn "home\|HOME\|homedir" test/greet.test.js` returns nothing. The production code is clean today (`grep -rn "homedir\|HOME\|USERPROFILE\|XDG" src/ bin/` returns nothing) and a live probe with `HOME=/tmp/fakehome USERPROFILE=/tmp/fakehome` (holding `{"name":"HOMEBOSS","lang":"fr"}`) printed `Hello, world`, so this is a gap in the guard, not a live defect.
- Fix: the smallest fix is one test that runs the CLI with `cwd` set to a fixture with no config and with `HOME`/`USERPROFILE` pointed at a directory that holds a `greet.config.json`, asserting `Hello, world\n`. The spec's own TEST list (TEST-016, TEST-020) does not name such a case, so this is a plan-level note rather than a task-row miss; the plan's `Decisions` row does not name it either.

### Tests

No test was deleted, skipped, or relaxed. The diff to `test/greet.test.js` is additions only (`git diff --cached` shows no `-` lines in that file), and no `.skip`/`todo`/`.only` was introduced. The new `assertConfigUsageError` helper asserts the four properties of the usage-error contract (exit code 2, empty stdout, exact stderr, exactly one line) against the process interface, not against internals, so it is not implementation-coupled.

Behaviour changed without a test: none. This unit adds no production behaviour; `bin/greet.js` and `src/greet.js` are untouched by the diff.

The five TASK-602 CLI cases cover `lang`, `name` (empty), `name` (number), a top-level array and `times` with a flag override. The `shout` and `format` config keys are covered at the unit layer by TASK-301's `loadConfig` tests, which the task file cites for REQ-062, so REQ-062 is traced. The CLI layer does not exercise an invalid `shout` or `format`; that is the plan's split of ownership, not a gap this unit introduced.

### Guards

Six mutations, all in a scratch copy at `${TMPDIR:-/tmp}/mut-6` (deleted afterwards; the repo was never edited).

- `mutation: loadConfig walks up to the parent directory (REQ-064 / SEC-006) -> test red` — `cli does not look for the config file in a parent directory` fails (1 fail).
- `mutation: the config is dropped from the merge (REQ-060 / REQ-063) -> test red` — `cli applies the config file in the working directory` and `cli lets a flag override only its own key` fail (5 fail).
- `mutation: loadConfig skips the per-key validation (REQ-062 / REQ-079) -> test red` — the four TASK-602 value cases fail, including `cli validates the whole config file even when a flag overrides the offending key` (10 fail).
- `mutation: the per-key validation moves after the merge (REQ-069) -> test red` — only `cli validates the whole config file even when a flag overrides the offending key` fails, which is exactly the case REQ-069 names (7 fail).
- `mutation: the CLI catch block no longer handles UsageError (REQ-070) -> test red` — the usage-error CLI tests fail (24 fail).
- `mutation: the usage error writes a line to stdout as well (SEC-005) -> test red` — all five TASK-602 config cases fail (8 fail).

Two further mutations were run and are recorded as equivalent, not as gaps:

- `mutation: loadConfig globs for any *.config.json in the cwd (SEC-006) -> test green` — equivalent: no fixture directory holds any `*.config.json` other than `greet.config.json` (verified with `find test/fixtures -name "*.config.json"`), so the glob branch never fires and no output can change.
- `mutation: the merge replaces the whole config when any flag is given (REQ-063) -> test red` — caught by `cli lets a flag override only its own key, keeping the other config values` (4 fail).

An exit-code mutation (`process.exitCode = 1` instead of `2`) was also confirmed red against all five TASK-602 config cases.

### Checked and fine

- **Scope.** Every changed file is in a Files column of TASK-601 or TASK-602: `test/fixtures/name-ada-lang-es/greet.config.json`, `test/fixtures/parent-has-config/greet.config.json` and `test/fixtures/parent-has-config/child/.gitkeep` (TASK-601), `test/greet.test.js` (both). The tasks file itself is ticked and its Differences section extended, which is the plan's own mechanism. No production file changed, so no behaviour beyond the two tasks was added.
- **Differences entries are accurate.** The TASK-602 entry claims the five fixtures already existed from TASK-301: confirmed, `git ls-tree -r 21f692f test/fixtures/` lists all five, and `git log -- test/fixtures/times-six/greet.config.json` shows they came in with `7623912 feat(greet-options): unit 3`. The TASK-601 entry claims the parent-directory test is load-bearing against a parent-walking `loadConfig`: confirmed by mutation 1 above. The claim that the first Red run failed on the parent case because `fixture` takes one path segment is consistent with `test/greet.test.js:27` and the `path.join` at line 561.
- **The TASK-502 Differences entry was amended** to record that TASK-602 has now covered the config half of TEST-023. That is a truthful update, not a weakening: the `usage: greet [options] invalid greet.config.json\n` line is now asserted at `test/greet.test.js:586-591`.
- **No parent or home lookup in the code.** `grep -rn "homedir\|HOME\|USERPROFILE\|XDG" src/ bin/` returns nothing, and a live run with `HOME` pointed at a directory holding a config printed `Hello, world`, so REQ-064 holds in the running code (see F01 for the untested clause).
- **The parent fixture is loud.** `test/fixtures/parent-has-config/greet.config.json` holds `{"name": "Config", "lang": "fr"}`, so a parent lookup would print `Bonjour, Config` and fail the assertion, exactly as the Differences entry says.
- **Config reasons use the config key form.** `invalid value for lang: de`, `empty value for name`, `invalid value for name: 123`, `invalid value for times: 6` all omit the `--` prefix, matching the flag reasons `invalid value for --lang: de` and `invalid value for --times: 6`. The two forms are distinguishable, and the tests assert the config form.
- **Gate integrity.** `npm test` is green at 86/86 (78 before this unit, 8 new). No lint, type, coverage or CI config was touched; `package.json` is unchanged.
- **The scratch copy has no `.git`,** so `git checkout` does not work there; the file was restored by copying from the repo instead. The repo working tree is unchanged (`git diff -- src/ bin/ test/` is empty).

### Set aside

- `shout` and `format` are not exercised as invalid config values at the CLI layer — owned by TASK-301's unit tests, which REQ-062 cites; not this unit's gap.
- The unreadable-config branch at `src/greet.js:146-151` still has no test — a pre-existing phase-3 warning, already accepted by the user at the phase-3 gate, and untouched by this diff.
- The fixture directories `test/fixtures/top-level-string/`, `top-level-number/` and `top-level-boolean/` sit outside the spec §8 inventory — a pre-existing phase-3 warning, untouched by this diff.

### Open questions

Q01: Should the plan add a home-directory-lookup case to TASK-601 (or a later task) to close REQ-064's second clause, or is the current coverage accepted? Blocking: no

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
scope: clean
mutations: 6 run, 0 still green
top:
- F01 [P2] plans/greet-options/feature-greet-options-spec.md:81 REQ-064's "no home directory / user config directory" clause has no test
report: plans/greet-options/reports/phase-6/review-6.md
