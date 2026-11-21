---
goal: TDD task breakdown for the greet CLI long-flag parsing, config file defaults and text or JSON output
version: 0.1
date_created: 2026-11-19
last_updated: 2026-11-19
owner: pipeline-toy
status: 'In progress'
spec: plans/greet-options/feature-greet-options-spec.md
tags: [feature, cli, options, tasks, tdd]
---

# Introduction

![Status: In progress](https://img.shields.io/badge/status-In%20progress-yellow)

These tasks implement `plans/greet-options/feature-greet-options-spec.md` (v0.3) with test-driven development. Every task follows **Red → Green → Refactor**:

1. **Red:** write the next listed test and confirm it fails for the right reason: an assertion about behaviour, not an import error or a missing mock.
2. **Green:** write the minimum code that makes it pass. Repeat 1-2 for each listed test.
3. **Refactor:** with the tests green, clean up, then run the test command.

A test listed under **Guard:** is expected to pass as soon as it is written, because earlier code already gives the behaviour. It is not logged as a difference.

Rules:
- The test command is `npm test`, which runs `node --test` (CON-003). The new test files are `test/options.test.js`, `test/config.test.js` and `test/cli.test.js`.
- Tests drive the seams agreed in spec §9: `parseArgs(argv)`, `readConfig(cwd)`, `mergeSettings(flags, config)` and `resolveGreeting(settings)` as unit seams, and `bin/greet.js` as a child process so stdout, stderr and the exit code are observed.
- No test touches the network. The CLI tests spawn the binary with `child_process.spawnSync` and use temporary directories from `fs.mkdtempSync` under `os.tmpdir()`.
- Tasks marked **Manual** need a real key or a human. Record what was observed in the task and, where it changes the plan, under Differences.
- Tick a task (`[x]` plus the ISO date in Done) when its tests pass. Tasks run in order within a unit.
- The **Spec** column maps each task to the spec's ids. The **Files** column lists every file the task touches.
- The seeded file `test/zz-seeded.test.js` (written by `scripts/seed-red.sh`) asserts that `greet` trims the name, which REQ-017 and D-16 forbid. It is not a target of this feature, it is not deleted here, and its failure is expected while the feature is built (spec §8). A "Done when" line therefore names the test file that must be green rather than claiming the whole suite is green.

## Decisions taken for these tasks

Settled up front so work can start. Revisit in the last task if any turns out wrong.

| Decision | Taken |
|---|---|
| Which test file holds which seam's tests | `test/options.test.js` for `parseArgs`, `mergeSettings`, `resolveGreeting` and `render`; `test/config.test.js` for `readConfig`; `test/cli.test.js` for the process-level tests. This is the split in spec §8. |
| How the CLI tests observe the process | `child_process.spawnSync(process.execPath, [bin, ...args], { cwd, encoding: 'utf8' })`, then assert on `status`, `stdout` and `stderr` separately. `execFileSync` throws on a non-zero exit, which would hide the exit-code assertions, so the CLI tests use `spawnSync`. |
| Where temporary directories come from | `fs.mkdtempSync(path.join(os.tmpdir(), 'greet-'))`, removed with `fs.rmSync(dir, { recursive: true, force: true })` after the test. The one exception is the existing `test/greet.test.js`, which the spec keeps unchanged and which runs the binary with the repository root as its working directory because it passes no `cwd` to `execFileSync`. So a `greet.config.json` in the repo root would change the result of that file's `cli defaults to world` and `cli takes --name` cases once TASK-070 lands. The repo holds no such file today and none is created by this feature, so the suite is green, but a developer who drops one in the repo root to try the feature by hand must delete it again before running the suite. |
| What the `UsageError` message says | The message names the offending argument, for example `unknown flag: --bogus`. It is never printed: `bin/greet.js` prints only `USAGE`, so the message text is free and no second stderr line can appear. |
| What an absent flag looks like in the parsed object | `parseArgs` returns an object holding only the keys whose flags were present. A flag that was not given means the key is absent from the object, not present with an `undefined` value, so `mergeSettings` can test for the key with `Object.prototype.hasOwnProperty`. |
| Whether `mergeSettings` re-validates flag values | No. A flag value can only come from `parseArgs`, which already validated it, so `mergeSettings` trusts it and validates only the config values (spec §4.1). |
| How the usage error exits | `bin/greet.js` sets `process.exitCode = 2` and returns from the main function instead of calling `process.exit(2)`, so a pending stdout write is never truncated. |
| What `render` returns | The whole stdout payload including the final newline, as one string. `bin/greet.js` writes it with `process.stdout.write(payload)`. The payload is built once, so a text run of three repetitions ends with exactly three newlines and no fourth. |
| The order of operations in `bin/greet.js` | Parse, then read the config file, then merge, then resolve, then render, then write. A usage error stops the run before the config file is read (spec §2). |
| The temporary flag-to-default merge in `bin/greet.js` | Phases 4 to 6 read the flag values in `bin/greet.js` and fall back to `DEFAULTS` there, for all five keys `name`, `shout`, `times`, `lang` and `format`, so the settings object is always complete and no key is ever `undefined`. The keys are read into the settings in TASK-040 (`name`, `lang`, `times`, `format`) and TASK-041 (`shout`), and TASK-050 and TASK-051 each name the key they consume. Phase 7 replaces that with `mergeSettings(flags, readConfig(process.cwd()))` and the temporary logic is deleted in the same task. It never ships. |
| The seeded trimming test | `test/zz-seeded.test.js` contradicts REQ-017 and D-16. No task deletes it, and no task adds trimming to `greet` to make it pass. Its failure while the feature is built is expected (spec §8). |
| The `times` value grammar | The command-line value must match `^[0-9]+$` exactly, so `03` is the number 3 and `2.5`, `+3`, `-3`, `0x2`, `1e1` and `" 3"` are usage errors (REQ-011). |
| Which flag's repeated occurrences are tested where | The repeated-flag cases are split by the flag that owns the value's semantics, so each unit's Green step builds what its own Red step asserts. `--name` is tested in TASK-010, where the value stays a raw string. `--times` is tested in TASK-030, where the value is converted with `Number`. `--lang` and `--format` are tested in TASK-031, where the value is matched against the allowed values. Every flag follows the same rule: the last occurrence wins and no error is raised (REQ-003, D-01). |
| When a flag value is validated, and the `--`-prefix rule | A flag value is validated as it is read, so the value of the last occurrence is the one that is validated: `parseArgs(['--name', 'Ada', '--name', ''])` raises `UsageError` (REQ-003 and REQ-006 together). The rule that a value starting with `--` is a missing value applies to the space form and the equals form alike, so `parseArgs(['--name=--foo'])` raises `UsageError` (REQ-005, PAT-002). |
| The `lang` and `format` case rules | The command-line values are matched exactly (REQ-013, REQ-014). The config values are trimmed and lower-cased before the match (REQ-034). The two rules live in two different functions, so the asymmetry is visible in the code. |

## Review focus

The inputs and failure modes most likely to hurt a real user that no requirement spells out, most likely first. Each one has a test in the named task.

1. The user types `--name --lang es` expecting the name to be `--lang` → the run fails loudly with one usage line and exit 2, because a value that starts with `--` is a missing value, not a name (REQ-005, Q-3). Test in TASK-020.
2. A `greet.config.json` sits unnoticed in the working directory and silently changes every run, for example a leftover file holding `{"shout": true}` → the greeting is upper-cased and no command-line flag can turn it off, because a flag overrides only its own key (RISK-001, RISK-005, REQ-031). Test in TASK-080.
3. The config file holds a value of the wrong type, for example `{"lang": 42}` or `{"times": "2"}` → that one value falls back to its built-in default, the other config values still apply and the run still exits 0 with no stack trace (SEC-004, REQ-034). Test in TASK-061 and TASK-071.
4. The name holds a double quote, a backslash or a newline → in text format it is printed verbatim, in JSON format it is escaped inside the JSON string, and it is never evaluated as code (REQ-023, REQ-024, SEC-003). Test in TASK-051 and TASK-090.
5. The user gives `--times 9` or `--times 2.5` → empty stdout, one usage line on stderr and exit 2, never a partially printed greeting (REQ-011, REQ-012, REQ-040). Test in TASK-030.

---

## Phase 1: Option parsing core and the CLI wiring

- **GOAL-001**: `greet --name Ada` prints `Hello, Ada` and `greet --bogus` prints exactly one usage line on stderr and exits 2, with the old hand-rolled `--name` lookup gone.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-010 | **Red → Green:** `src/options.js` gains `parseArgs(argv)`, `DEFAULTS` (frozen `{ name: 'world', shout: false, times: 1, lang: 'en', format: 'text' }`), `LANGS`, `FORMATS`, `TIMES_MIN` (1), `TIMES_MAX` (5) and `USAGE`; `bin/greet.js` loses the hand-rolled `--name` lookup and calls `parseArgs(process.argv.slice(2))`. **Red:** write `test/options.test.js`: `parseArgs([])` returns `{}`; `parseArgs(['--name', 'Ada'])` and `parseArgs(['--name=Ada'])` both return `{ name: 'Ada' }`; `parseArgs(['--name', 'Bob', '--name', 'Ada'])` returns `{ name: 'Ada' }` with no error, because the last occurrence of a repeated `--name` wins; `parseArgs(['--shout'])` returns `{ shout: true }` with no error, because `--shout` is a flag that takes no value and its presence sets `shout` to `true`. The repeated-flag cases for `--times`, `--lang` and `--format` are written in TASK-030 and TASK-031, which own the conversion and the membership check for those values. Write `test/cli.test.js`: the binary with no arguments prints `Hello, world\n` on stdout, nothing on stderr and exits 0; with `--name Ada` and with `--name=Ada` it prints `Hello, Ada\n` and exits 0. **Green:** `parseArgs` takes only the argument list, never reads `process.argv`, returns an object holding only the keys whose flags were present, and for a repeated `--name` keeps the value of the last occurrence, as the raw string. `parseArgs` recognises `--shout` as a long flag that takes no value: when it is present the returned object holds `shout: true`, and when it is absent the key is absent from the object, as with every other flag (REQ-015). This task owns the parsing of `--shout`; the upper-casing it causes is built in TASK-041. At this stage the `--times`, `--lang` and `--format` values are read as raw strings, without the conversion and the membership check that TASK-030 and TASK-031 add; their repeated-flag cases are therefore tested in those two tasks, not here. `bin/greet.js` uses `flags.name` when the key is present and `DEFAULTS.name` otherwise, and still prints through `greet(name)` from `src/greet.js`. **Tests:** TEST-001, TEST-002, TEST-008 | REQ-001, REQ-002, REQ-003, REQ-015, CON-001, CON-002, CON-004, DEP-001, PAT-001 | src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js | [x] | 2026-11-19 |
| TASK-011 | **Red → Green:** the usage-error path, end to end. **Red:** write `test/options.test.js`: `assert.throws(() => parseArgs(['--bogus']), (err) => err instanceof UsageError && err.name === 'UsageError')`. Write `test/cli.test.js`: the binary run with `--bogus` has empty stdout, stderr of exactly `Usage: greet [--name NAME] [--shout] [--times N] [--lang en\|es\|fr] [--format text\|json]` followed by one newline, and exit code 2, with no stack trace and no second stderr line. **Green:** add `class UsageError extends Error` to `src/options.js` with `this.name = 'UsageError'`, exported as `UsageError`; every usage error is raised as that type. `bin/greet.js` wraps the parse in a `try`/`catch` that re-throws anything that is not a `UsageError`, and for a `UsageError` writes `USAGE` plus one newline to stderr, sets `process.exitCode = 2` and returns, leaving stdout empty. **Guard (fix round):** the re-throw rule was implemented but unguarded, so a weakened catch stayed green. Write `test/cli.test.js`: the binary is run with a `--require` preload module, written to a temporary directory at test time, that replaces `parseArgs` on the loaded `src/options.js` module with one that throws a plain `TypeError`; the run has empty stdout, an exit code that is not 2, stderr that does not hold the usage line, and stderr that holds the `TypeError` stack trace. **Tests:** TEST-003, TEST-011, TEST-023 | REQ-004, REQ-040, REQ-041, REQ-042, GUD-003 | src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js | [x] | 2026-11-19 |

**Done when:** `test/options.test.js` and `test/cli.test.js` are green, `test/greet.test.js` still passes unchanged, and the binary with `--bogus` writes one usage line to stderr and exits 2.

## Phase 2: Missing values and stray arguments

depends: 1

- **GOAL-002**: Every argument that is not a well-formed flag or flag value fails the same way: empty stdout, one usage line on stderr, exit 2.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-020 | **Red → Green:** the missing-value and empty-name rules. **Red:** write `test/options.test.js`: `parseArgs(['--name'])`, `parseArgs(['--name', '--lang', 'es'])` and `parseArgs(['--name', '--shout'])` all throw `UsageError`; `parseArgs(['--name', ''])` and `parseArgs(['--name='])` throw `UsageError`; `parseArgs(['--name', '-x'])` returns `{ name: '-x' }` because a value that starts with a single dash is an ordinary value; `parseArgs(['--name=--foo'])` throws `UsageError`, because the `--`-prefix rule applies to the equals form too; `parseArgs(['--name', 'Ada', '--name', ''])` throws `UsageError`, because the last occurrence's value is the one that is validated. Write `test/cli.test.js`: the binary with `--name` as the last argument, with `--name ""` and with `--name --shout` has empty stdout, one usage line on stderr and exit code 2; the binary with `--name -x` prints `Hello, -x\n` on stdout, nothing on stderr and exits 0, so a value starting with a single dash is an ordinary value. **Green:** in `parseArgs`, a flag that takes a value raises `UsageError` when no next argument exists or when the next argument starts with `--`, in the space form and in the equals form alike; a name value of the empty string raises `UsageError`; a value that starts with a single `-` is used as an ordinary value. **Tests:** TEST-003, TEST-015, TEST-028 | REQ-005, REQ-006, Q-3, PAT-002 | src/options.js, test/options.test.js, test/cli.test.js | [x] | 2026-11-19 |
| TASK-021 | **Red → Green:** stray arguments are usage errors. **Red:** write `test/options.test.js`: `parseArgs(['Ada'])`, `parseArgs(['--', 'Ada'])`, `parseArgs(['--'])`, `parseArgs(['--name', 'Ada', 'extra'])`, `parseArgs(['-n'])` and `parseArgs(['-x'])` all throw `UsageError`; `parseArgs(['--shout=true'])` throws `UsageError`, because `--shout` takes no value and `--shout=true` is an unknown flag. Write `test/cli.test.js`: the binary run with `Ada` has empty stdout, exactly one usage line on stderr and exit code 2; the binary run with `--shout=true` has empty stdout, exactly one usage line on stderr and exit code 2. **Green:** `parseArgs` treats any argument that is not one of the five recognised long flags and is not consumed as a flag value as a usage error; `--` is not a separator and is an unknown argument; `--shout` takes no value, so `--shout=true` is an unknown flag; a single-dash argument that is not consumed as a preceding flag's value is an unknown flag, while a single-dash argument in value position is an ordinary value (TASK-020). **Tests:** TEST-003, TEST-011, TEST-016 | REQ-007, D-10, D-11 | src/options.js, test/options.test.js, test/cli.test.js | [x] | 2026-11-19 |

**Done when:** `test/options.test.js` and `test/cli.test.js` are green, and every argument listed in TASK-020 and TASK-021 ends the run with empty stdout, one usage line on stderr and exit code 2.

## Phase 3: Value validation for --times, --lang and --format

depends: 1, 2

- **GOAL-003**: `--times`, `--lang` and `--format` accept only the values the spec names, and every other value is a usage error with exit 2.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-030 | **Red → Green:** the `--times` value rules. **Red:** write `test/options.test.js`: `parseArgs(['--times', '3'])` and `parseArgs(['--times=3'])` both return `{ times: 3 }`; `parseArgs(['--times', '3', '--times', '4'])` returns `{ times: 4 }` with no error, because the last occurrence of a repeated `--times` wins; `parseArgs(['--times', '03'])` returns `{ times: 3 }`, because the grammar is `^[0-9]+$` exactly, so the leading zero is allowed; `parseArgs(['--times', '0x2'])`, `['--times', '1e1']`, `['--times', '2.5']`, `['--times', '+3']`, `['--times', '-3']`, `['--times', ' 3']` and `['--times', '3 ']` all throw `UsageError`; `['--times', '0']` and `['--times', '6']` throw `UsageError` because the range is 1 to 5 inclusive. **Green:** `parseArgs` accepts a `--times` value only when the string matches `^[0-9]+$` exactly, converts it with `Number`, and raises `UsageError` when the result lies outside `TIMES_MIN` to `TIMES_MAX` inclusive, both read from the exported constants. For a repeated `--times`, the value of the last occurrence is the one that is converted and validated. **Tests:** TEST-002, TEST-003, TEST-027 | REQ-003, REQ-011, REQ-012, REQ-040, Q-1, PAT-002 | src/options.js, test/options.test.js | [x] | 2026-11-19 |
| TASK-031 | **Red → Green:** the `--lang` and `--format` value rules. **Red:** write `test/options.test.js`: `parseArgs(['--lang', 'es'])` and `parseArgs(['--lang=es'])` both return `{ lang: 'es' }`; `parseArgs(['--lang', 'de'])` and `parseArgs(['--lang', 'ES'])` throw `UsageError`; `parseArgs(['--lang', 'es', '--lang', 'fr'])` returns `{ lang: 'fr' }` with no error, because the last occurrence of a repeated `--lang` wins; `parseArgs(['--format', 'json'])` and `parseArgs(['--format=json'])` both return `{ format: 'json' }`; `parseArgs(['--format', 'xml'])` and `parseArgs(['--format', 'JSON'])` throw `UsageError`; `parseArgs(['--format', 'json', '--format', 'text'])` returns `{ format: 'text' }` with no error, because the last occurrence of a repeated `--format` wins. **Green:** `parseArgs` matches the `--lang` value against the keys of `LANGS` and the `--format` value against the entries of `FORMATS`, exactly and case-sensitively, and raises `UsageError` for a value that is not a member. The command-line values are neither trimmed nor lower-cased. For a repeated `--lang` or `--format`, the value of the last occurrence is the one that is matched against the allowed values. **Tests:** TEST-002, TEST-003 | REQ-003, REQ-013, REQ-014, Q-2 | src/options.js, test/options.test.js | [x] | 2026-11-19 |

**Done when:** `test/options.test.js` is green, `--times 0x2`, `--times 9`, `--lang ES` and `--format JSON` each end the run with empty stdout, one usage line on stderr and exit code 2, and the repeated-flag cases for `--times`, `--lang` and `--format` take the last occurrence with no error.

## Phase 4: The greeting word, the name and --shout

depends: 1, 3

- **GOAL-004**: `--lang es` prints `Hola, Ada`, `--lang fr` prints `Bonjour, Ada` and `--shout` upper-cases the whole greeting including the name.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-040 | **Red → Green:** the language table and the greeting resolution. **Red:** write `test/options.test.js`: `resolveGreeting({ lang: 'en', name: 'Ada', shout: false })` returns `Hello, Ada`; `{ lang: 'es', name: 'Ada', shout: false }` returns `Hola, Ada`; `{ lang: 'fr', name: 'Ada', shout: false }` returns `Bonjour, Ada`. Write `test/cli.test.js`: the binary run with `--lang es --name Ada` prints `Hola, Ada\n` and exits 0. **Green:** `src/options.js` gains `resolveGreeting(settings)`, which looks the word up in the `LANGS` table by `settings.lang` and returns the word, a comma, a space and `settings.name`. `bin/greet.js` builds the settings from the parsed flags and `DEFAULTS` and prints `resolveGreeting(settings)` instead of `greet(name)`; every key of the settings object is read from the flags when the key is present and from `DEFAULTS` otherwise, so the settings always holds all five keys `name`, `shout`, `times`, `lang` and `format`, and no key is ever `undefined`. The name and the language are read this way from the start; `shout` is added by TASK-041, and `times` and `format` are read this way from the start as well, so the settings object is complete before `render` is built in TASK-050 and TASK-051. `LANGS` holds one entry per language code, so there is no switch and no chain of ifs. **Tests:** TEST-006, TEST-009 | REQ-016, D-15, GUD-001, GUD-002 | src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js | [ ] | |
| TASK-041 | **Red → Green:** `--shout` and the name used as given. **Red:** write `test/options.test.js`: `resolveGreeting({ lang: 'en', name: 'Ada', shout: true })` returns `HELLO, ADA`; `resolveGreeting({ lang: 'es', name: 'Ada', shout: true })` returns `HOLA, ADA`. Write `test/cli.test.js`: the binary run with `--shout --name Ada` prints `HELLO, ADA\n` and exits 0. **Green:** `resolveGreeting` upper-cases the whole greeting, name included, when `settings.shout` is true; `bin/greet.js` passes `shout` from the parsed flag, which is `true` only when `--shout` was given, and `DEFAULTS.shout` otherwise. The name is interpolated exactly as given, with no trimming of surrounding whitespace. **Tests:** TEST-006, TEST-013 | REQ-015, REQ-017, D-13, D-14, D-16 | src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js | [ ] | |

**Done when:** `test/options.test.js` and `test/cli.test.js` are green, `--lang es --name Ada` prints `Hola, Ada` and `--shout --name Ada` prints `HELLO, ADA`.

## Phase 5: Text and JSON output

depends: 3, 4

- **GOAL-005**: `--times N` prints one line per repetition in text format, and `--format json` prints exactly one JSON object on one line with the greeting repeated inside it.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-050 | **Red → Green:** the text payload and the repetition count. **Red:** write `test/options.test.js`: `render({ lang: 'en', name: 'Ada', shout: false, times: 1, format: 'text' })` returns `Hello, Ada\n`; `render` with `times: 3` returns `Hello, Ada\nHello, Ada\nHello, Ada\n`. Write `test/cli.test.js`: the binary run with `--name Ada --times 3` prints three identical lines `Hello, Ada` on stdout and exits 0; the binary run with `--name Ada --times 2 --lang es` prints `Hola, Ada` on two lines. **Green:** `src/options.js` gains `render(settings)`, which calls `resolveGreeting` once and returns the whole stdout payload as one string: in text format the greeting repeated `settings.times` times, each repetition followed by a newline. `bin/greet.js` writes the payload with `process.stdout.write(payload)` and stops using `console.log`. `bin/greet.js` puts the parsed `times` into the settings, falling back to `DEFAULTS.times`, so `render` repeats the greeting that many times; the settings object is the one TASK-040 builds, and `times` is one of its five keys. The greeting is built once, so every repetition in a run is identical. **Tests:** TEST-009, TEST-010 | REQ-010, REQ-020, REQ-021, REQ-024, D-02 | src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js | [ ] | |
| TASK-051 | **Red → Green:** the JSON payload and its escaping. **Red:** write `test/options.test.js`: `render` with `format: 'json'` and `times: 1` returns `{"greeting": "Hello, Ada"}\n`; with `times: 2` it returns `{"greeting": "Hello, Ada\nHello, Ada"}\n`, one line whose escaped newline sits inside the JSON string. Write `test/cli.test.js`: the binary run with `--format json --name Ada` prints `{"greeting": "Hello, Ada"}\n` and exits 0; with `--name Ada --format json --times 2` it prints one line that `JSON.parse` reads back as an object whose `greeting` value is `Hello, Ada` and `Hello, Ada` joined by a newline; with `--format json --shout --name Ada` it prints `{"greeting": "HELLO, ADA"}\n`; with `--format json --name 'Ada "The Countess" Lovelace'` it prints a line that `JSON.parse` reads back as `{"greeting": "Hello, Ada \"The Countess\" Lovelace"}`. **Green:** `render` in json format returns the line built as `'{"greeting": ' + JSON.stringify(repeatedGreeting) + '}'` followed by a newline, where `repeatedGreeting` is the greeting repeated once per repetition and joined by a single newline character. `JSON.stringify` does the escaping, so a quote, a backslash or a control character in the name stays valid JSON, and the space after the colon is kept. `bin/greet.js` puts the parsed `format` into the settings, falling back to `DEFAULTS.format`, so `render` takes the json branch; the settings object is the one TASK-040 builds, and `format` is one of its five keys. **Tests:** TEST-010, TEST-013, TEST-014, TEST-017 | REQ-010, REQ-015, REQ-022, REQ-023, D-03 | src/options.js, bin/greet.js, test/options.test.js, test/cli.test.js | [ ] | |

**Done when:** `test/options.test.js` and `test/cli.test.js` are green, `--times 3` prints three identical lines in text format, and `--format json` always prints exactly one line that parses as JSON.

## Phase 6: The config file reader and the merge

depends: 1, 2, 3

- **GOAL-006**: `readConfig(cwd)` returns the config object or an empty object, and `mergeSettings(flags, config)` resolves every key from the flag, then the config, then the built-in default.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-060 | **Red → Green:** the config file reader. **Red:** write `test/config.test.js`: `readConfig` on a directory with no `greet.config.json` returns `{}`; on a directory holding `{"name": "Bob"}` it returns `{ name: 'Bob' }`; on a directory holding malformed JSON it returns `{}`; on a directory holding `[1, 2]`, `"hello"`, `42` or `null` it returns `{}`, so a non-object config never reaches the merge. **Green:** create `src/config.js` exporting `CONFIG_FILE_NAME` (`'greet.config.json'`) and `readConfig(cwd)`. It reads `path.join(cwd, CONFIG_FILE_NAME)` as UTF-8 text with `fs.readFileSync` and parses it with `JSON.parse`, both inside one `try`/`catch`. A missing file, an unreadable file and invalid JSON all return `{}`. When the parsed value is not a plain object it returns `{}`. It never throws and never writes anything. **Tests:** TEST-007 | REQ-030, REQ-032, REQ-033, SEC-001, SEC-004, CON-002, DEP-001, GUD-002, PAT-001 | src/config.js, test/config.test.js | [ ] | |
| TASK-061 | **Red → Green:** the merge of the three sources. **Red:** write `test/options.test.js`: `mergeSettings({ name: 'Ada' }, { lang: 'es' })` returns `{ name: 'Ada', shout: false, times: 1, lang: 'es', format: 'text' }`; `mergeSettings({}, {})` returns exactly `DEFAULTS`; `mergeSettings({ times: 3 }, { times: 2 })` returns `times: 3`, the flag winning. Then the fallback cases: a config `name` of `''` resolves to `world`; a config `name` of `'   '`, a name holding only whitespace, resolves to `world`, because a name that is entirely whitespace is not a valid name; a config `name` of `'  Ada  '` resolves to `'  Ada  '`, untrimmed; a config `name` of `42` or of `true` resolves to `world`; a config `shout` of `'true'` or of `'false'` resolves to `false`; a config `times` of `0`, of `6`, of `2.5` or of `'2'` resolves to `1`; a config `lang` of `42` or of `true` resolves to `en`; a config `format` of `42` resolves to `text`; a config `lang` of `'de'` resolves to `en`; a config `format` of `'xml'` resolves to `text`; a config `lang` of `'ES'` resolves to `es`; a config `format` of `' JSON '` resolves to `json`. In every fallback case the other config values still apply, for example `mergeSettings({}, { name: 'Bob', lang: 42 })` returns `name: 'Bob'` and `lang: 'en'`. **Green:** `src/options.js` gains `mergeSettings(flags, config)`, which returns an object with all five keys present: the flag value when the flag was present, else the config value when it is valid for its key, else the built-in default. The config `name` is valid when it is a non-empty string that is not only whitespace, and is used verbatim. The config `shout` is valid when it is a boolean. The config `times` is valid when it is a whole number from `TIMES_MIN` to `TIMES_MAX` inclusive. The config `lang` and `format` are valid when the value is a string and its trimmed, lower-cased form is one of the allowed values. Flag values are not re-validated, because `parseArgs` already validated them. **Tests:** TEST-004, TEST-005, TEST-019, TEST-030 | REQ-031, REQ-034, REQ-035, REQ-036, REQ-037, SEC-003, D-04, D-12 | src/options.js, test/options.test.js | [ ] | |

**Done when:** `test/config.test.js` and `test/options.test.js` are green, `readConfig` never throws, and `mergeSettings` resolves every one of the five keys for every combination of flag and config value listed in TASK-061.

## Phase 7: The CLI reads the config file

depends: 1, 6

- **GOAL-007**: A `greet.config.json` in the working directory supplies the defaults, a command-line flag overrides only its own key, and a broken config file never stops the run.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-070 | **Red → Green:** the CLI reads the config file from the working directory. **Red:** write `test/cli.test.js`: the binary run in a temporary directory holding `{"name": "Bob"}` prints `Hello, Bob\n` and exits 0; run in the same directory with `--name Ada` it prints `Hello, Ada\n`; run in a temporary directory holding `{"name": "Bob", "lang": "es"}` it prints `Hola, Bob\n`; run in a temporary directory holding `{"name": "Bob", "lang": "es"}` with `--lang fr` it prints `Bonjour, Bob\n`, the flag overriding only its own key; run in a temporary directory with no config file it prints `Hello, world\n`. **Green:** `bin/greet.js` reads the config once at startup with `readConfig(process.cwd())`, then resolves the settings with `mergeSettings(flags, config)` and prints `render(settings)`. The temporary flag-to-default merge that lived in `bin/greet.js` is deleted in this task, so `bin/greet.js` only does: parse, read the config, merge, resolve, render, write. A usage error still stops the run before the config file is read. **Tests:** TEST-012, TEST-022 | REQ-001, REQ-030, REQ-031, D-07 | bin/greet.js, test/cli.test.js | [ ] | |
| TASK-071 | **Guard → Green:** a broken or partly broken config file never stops the run. **Guard:** the cases below already pass once TASK-070 and TASK-061 are green, because `readConfig` returns `{}` for a malformed or non-object file and `mergeSettings` falls back per key; the green step is the confirmation that the end-to-end path holds for every one of these files. Write `test/cli.test.js`: the binary run in a temporary directory holding `{"times": 9}` prints `Hello, world\n` on one line and exits 0, the invalid `times` falling back to one repetition; run in a directory holding `{"name": "Bob", "unknownKey": 1}` it prints `Hello, Bob\n`, the unknown key being ignored; run in a directory holding malformed JSON it prints `Hello, world\n`, writes nothing to stderr and exits 0; run in a directory holding `null` it prints `Hello, world\n`, writes nothing to stderr and exits 0; run in a directory holding `{"name": "Bob", "lang": 42}` it prints `Hello, Bob\n`, the invalid `lang` falling back while the other config value still applies. **Green:** no change is needed in `bin/greet.js` beyond what TASK-070 wrote, because `readConfig` already returns `{}` for a malformed or non-object file and `mergeSettings` already falls back per key. The green step is the confirmation that the end-to-end path holds for every one of these files, plus the assertion that the process never writes a stack trace to stderr. If any case fails, fix the reader or the merge, not the CLI. **Tests:** TEST-018, TEST-025, TEST-031 | REQ-033, REQ-034, REQ-035, SEC-004 | src/config.js, src/options.js, test/cli.test.js | [ ] | |

**Done when:** `test/cli.test.js` is green, a config file in the working directory supplies the defaults, a flag overrides only its own key, and a malformed or partly invalid config file still prints the built-in default greeting and exits 0 with empty stderr.

## Phase 8: File system and literal-data guarantees

depends: 7

- **GOAL-008**: The CLI writes nothing to disk, reads only the config file in the working directory, and prints config values literally.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-080 | **Guard → Green:** a config file that sets `shout`. **Guard:** the cases below already pass once TASK-070 and TASK-061 are green, because `mergeSettings` takes the flag value for the key the flag covers and the config value for every other key, so the config `shout` reaches `resolveGreeting` through the merge and is upper-cased in both formats. Write `test/cli.test.js`: the binary run in a temporary directory holding `{"shout": true}` prints `HELLO, WORLD\n` and exits 0; run in the same directory with `--name Ada` it prints `HELLO, ADA\n`, the flag overriding only its own key and the config `shout` still applying; run in the same directory with `--name Ada --format json` it prints `{"greeting": "HELLO, ADA"}\n`. There is no flag that turns the config `shout` off, so no test asks for one. **Green:** `mergeSettings` already takes the flag value for the key the flag covers and the config value for every other key, so the config `shout` applies while the flag `name` wins. The green step is the end-to-end confirmation that the config `shout` reaches `resolveGreeting` through the merge and is upper-cased in both formats. If any case fails, fix the merge, not the CLI. **Tests:** TEST-029 | REQ-015, REQ-031, RISK-005 | src/options.js, test/cli.test.js | [ ] | |
| TASK-081 | **Guard → Green:** the file system and literal-data guarantees. **Guard:** the cases below already pass once TASK-060 and TASK-070 are green, because `readConfig` reads only `path.join(cwd, CONFIG_FILE_NAME)` and neither `readConfig` nor `bin/greet.js` writes anything; the green step confirms all three. Write `test/cli.test.js`: list the files in a temporary directory before and after a run of the binary in it and assert the two lists are equal, so no config file is created, changed or removed; create a dedicated parent directory with a second `fs.mkdtempSync(path.join(os.tmpdir(), 'greet-parent-'))`, put a `greet.config.json` holding `{"name": "Parent"}` in that parent, create the child working directory inside the parent with a third `fs.mkdtempSync`, run the binary in the child directory and assert it prints `Hello, world\n`, so a config file in a parent directory is never read; remove the child and the parent in the same cleanup, so nothing is left in the shared system temp directory; put a `greet.config.json` holding a name with a double quote, a backslash and a control character in the temporary directory, run the binary and assert the printed line holds that name literally and never evaluates it. **Green:** `readConfig` reads only `path.join(cwd, CONFIG_FILE_NAME)`, so the parent-directory case already passes; `readConfig` and `bin/greet.js` write nothing, so the file-list case already passes; and the config value is interpolated as plain data, so the literal-name case already passes. The green step confirms all three and adds the assertion that no value from argv or from the config file is ever passed to a shell or used to build a command string, which is a code-review check over `bin/greet.js`, `src/options.js` and `src/config.js`. **Tests:** TEST-021, TEST-024 | SEC-001, SEC-002, SEC-003, PAT-003 | src/config.js, src/options.js, bin/greet.js, test/cli.test.js | [ ] | |

**Done when:** `test/cli.test.js` is green, a run leaves the working directory unchanged, a `greet.config.json` in a parent directory is ignored, and a config name holding a quote, a backslash or a control character is printed literally.

## Phase 9: Names with awkward characters

depends: 3, 5, 7

- **GOAL-009**: A name holding a newline or surrounding whitespace is printed exactly as given, in text format and in JSON format.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-090 | **Guard → Green:** a name holding a newline. **Guard:** the cases below already pass once TASK-041 and TASK-051 are green, because `resolveGreeting` interpolates the name as given and `render` in json format escapes it through `JSON.stringify`; the green step confirms all three. Write `test/cli.test.js`: the binary run with `--name` and the value `Ada` followed by a newline character and then `Lovelace` (built in the test as `'Ada' + String.fromCharCode(0x0A) + 'Lovelace'`, so the source file holds no invisible character) prints that name verbatim in text format, so stdout holds more lines than the repetition count; run with `--times 2` the name is printed twice, each repetition holding its own newline; run with `--format json` it prints one line whose `greeting` value holds the name with the newline escaped, and `JSON.parse` reads that line back as an object whose `greeting` value holds a real newline. **Green:** `resolveGreeting` interpolates the name as given, and `render` in text format writes the name verbatim, so the newline inside the name adds lines of its own and the line count is not the repetition count; `render` in json format escapes it through `JSON.stringify`, so the line stays valid JSON. **Tests:** TEST-020 | REQ-023, REQ-024 | src/options.js, bin/greet.js, test/cli.test.js | [ ] | |
| TASK-091 | **Guard → Green:** a name holding surrounding whitespace. **Guard:** the cases below already pass once TASK-041 and TASK-070 are green, because `parseArgs` keeps the name as given and `mergeSettings` keeps a valid config name verbatim; the green step confirms all three paths end to end. Write `test/cli.test.js`: the binary run with `--name` and the value `  Ada  ` prints `Hello,   Ada  \n` on stdout, the name used with its surrounding whitespace intact, and exits 0; run with `--name=  Ada  ` it prints the same line; run in a temporary directory holding `{"name": "  Ada  "}` it prints the same line, the config name used untrimmed as well. **Green:** nothing trims the name at any step: `parseArgs` keeps the value as given, `mergeSettings` keeps a valid config name verbatim, and `resolveGreeting` interpolates it without trimming. The green step confirms all three paths end to end and that the seeded trimming test in `test/zz-seeded.test.js` still fails, because REQ-017 and D-16 forbid trimming. **Tests:** TEST-019, TEST-026 | REQ-017, REQ-037, D-16 | src/options.js, bin/greet.js, test/cli.test.js | [ ] | |

**Done when:** `test/options.test.js`, `test/config.test.js` and `test/cli.test.js` are green, a name with a newline is printed verbatim in text format and escaped in JSON format, and a name with surrounding whitespace is never trimmed.

## Requirement traceability

| Requirement | Tasks |
|---|---|
| REQ-001 | TASK-010, TASK-070 |
| REQ-002 | TASK-010 |
| REQ-003 | TASK-010, TASK-030, TASK-031 |
| REQ-004 | TASK-011 |
| REQ-005 | TASK-020 |
| REQ-006 | TASK-020 |
| REQ-007 | TASK-021 |
| REQ-010 | TASK-050, TASK-051 |
| REQ-011 | TASK-030 |
| REQ-012 | TASK-030 |
| REQ-013 | TASK-031 |
| REQ-014 | TASK-031 |
| REQ-015 | TASK-010, TASK-041, TASK-051, TASK-080 |
| REQ-016 | TASK-040 |
| REQ-017 | TASK-041, TASK-091 |
| REQ-020 | TASK-050 |
| REQ-021 | TASK-050 |
| REQ-022 | TASK-051 |
| REQ-023 | TASK-051, TASK-090 |
| REQ-024 | TASK-050, TASK-090 |
| REQ-030 | TASK-060, TASK-070 |
| REQ-031 | TASK-061, TASK-070, TASK-080 |
| REQ-032 | TASK-060 |
| REQ-033 | TASK-060, TASK-071 |
| REQ-034 | TASK-061, TASK-071 |
| REQ-035 | TASK-061, TASK-071 |
| REQ-036 | TASK-061 |
| REQ-037 | TASK-061, TASK-091 |
| REQ-040 | TASK-011, TASK-030 |
| REQ-041 | TASK-011 |
| REQ-042 | TASK-011 |
| SEC-001 | TASK-060, TASK-081 |
| SEC-002 | TASK-081 |
| SEC-003 | TASK-061, TASK-081 |
| SEC-004 | TASK-060, TASK-071 |

## Differences from the spec

- TASK-010: the Red step needed `src/options.js` to exist before `test/options.test.js` could fail on an assertion instead of an import error, so the module was created first with the exported constants and a `parseArgs` that returned `{}`. The Red then failed on the four behavioural assertions, and the Green filled in the real `parseArgs`. The end state matches the task: no behaviour was added earlier than the plan assigns it.
- TASK-010: a flag value may itself hold an `=`, for example `--name A=B` or `--name=A=B`. The plan does not name this case. The equals sign is treated as a separator only inside an argument that starts with `--`, so both forms give the name `A=B` and the space form is not split on its `=`.
- TASK-011: the usage error for an unknown flag names the offending flag with its dashes, for example `unknown flag: --bogus`. The plan leaves the message text free, because `bin/greet.js` prints only `USAGE` and never this message.
- TASK-011 (fix round, F01): the "catch only `UsageError`" rule is guarded by a process-level test that uses a `--require` preload module, written to a temporary directory at test time, to replace `parseArgs` with one that throws a plain `TypeError`. The plan named the re-throw as a deliverable but no test asserted it, and the review showed that weakening the catch kept the whole suite green. The preload approach was chosen over exporting `main` from `bin/greet.js` and over a new export in `src/options.js`, because the spec pins the export list of `src/options.js` (spec section 4.1) and the preload adds no production affordance. The test asserts the process contract itself: empty stdout, an exit code that is not 2, no usage line on stderr and the stack trace on stderr.
- TASK-020: the plan names no message text for the new usage errors, so each one names the offending argument: `missing value for --name` for a missing or `--`-prefixed value, `empty value for --name` for an empty name value, and `unknown argument: Ada` for a stray argument (TASK-021). The messages are never printed, because `bin/greet.js` prints only `USAGE`, so no assertion depends on them.
- TASK-020 (fix round, F01): the REQ-005 missing-value rule was implemented generically, but only `--name` was tested, so narrowing the guard to `--name` alone kept the whole suite green. The unit test and the process-level test now also cover `--times`, `--lang` and `--format`, so the rule is guarded for every flag that takes a value, and `parseArgs(['--lang', '--shout'])` pins the rule that the next flag is not swallowed as a value. The value rules for those flags (REQ-011 to REQ-014) stay with TASK-030 and TASK-031; only the missing-value rule is pinned here.
- TASK-021: the `--` argument is reported as an unknown argument (`unknown argument: --`) rather than as an unknown flag, because the plan calls `--` an unknown argument and not a flag. The behaviour is the same, a `UsageError` with exit code 2, and the message is never printed.
- TASK-021: `--shout=true` is reported as `unknown flag: --shout`, matching the plan's wording that `--shout` takes no value and so `--shout=true` is an unknown flag. The message is never printed.
- TASK-030: `test/cli.test.js` was touched, which is outside the task's Files column, because the unit's Done when line requires `--times 0x2` and `--times 9` to end the run with empty stdout, one usage line on stderr and exit code 2, and because REQ-040 is in the task's Spec column. The test is a guard: `bin/greet.js` already caught every `UsageError` and printed the usage line with exit code 2, so the test passed as soon as `parseArgs` raised the error. No production code in `bin/greet.js` was changed.
- TASK-031: `test/cli.test.js` was touched, which is outside the task's Files column, for the same reason as TASK-030: the unit's Done when line names `--lang ES` and `--format JSON` as process-level cases that must end with empty stdout, one usage line on stderr and exit code 2. This test was the Red step for the task at the process level: it failed while `parseArgs` still accepted any `--lang` and `--format` value, and it passes now. No production code in `bin/greet.js` was changed.
- TASK-030: the plan names no message text for the new usage errors, so each one names the offending flag and value: `invalid value for --times: 2.5` for a value that does not match `^[0-9]+$`, and `--times must be between 1 and 5: 9` for a value outside the range. The messages are never printed, because `bin/greet.js` prints only `USAGE`, so no assertion depends on them.
- TASK-031: the new usage errors follow the same rule as TASK-030: `invalid value for --lang: ES` and `invalid value for --format: JSON`. The messages are never printed.
- TASK-030 and TASK-031: the per-flag value checks live in three small functions, `parseTimes`, `parseLang` and `parseFormat`, held in a `VALUE_PARSERS` table that `parseArgs` looks up by flag name. The plan describes the checks but not their shape; the table keeps the parse loop free of a growing chain of `if` branches, and it puts the exact, case-sensitive command-line match in its own function so the trimmed, lower-cased config match that TASK-061 adds later stays visibly separate (REQ-013, REQ-034).
- TASK-030: the range check uses the exported `TIMES_MIN` and `TIMES_MAX` constants, as the plan requires, so the valid range is stated in one place and the config file range check that TASK-061 adds reads the same two constants.
