---
goal: TDD task breakdown for greet CLI flags, config and output formats
version: 0.1
date_created: 2026-11-21
last_updated: 2026-11-21
owner: pipeline-toy
status: 'Planned'
spec: plans/greet-options/feature-greet-options-spec.md
tags: [feature, cli, greet, tasks, tdd]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

These tasks implement `plans/greet-options/feature-greet-options-spec.md` (v0.3) with test-driven development. Every task follows **Red → Green → Refactor**:

1. **Red:** write the next listed test and confirm it fails for the right reason: an assertion about behaviour, not an import error or a missing mock.
2. **Green:** write the minimum code that makes it pass. Repeat 1-2 for each listed test.
3. **Refactor:** with the tests green, clean up, then run `npm test`.

A test listed under **Guard:** is expected to pass as soon as it is written, because earlier code already gives the behaviour. It is not logged as a difference.

Rules:
- CLI tests spawn the real `bin/greet.js` through `execFileSync(process.execPath, ...)` as the existing suite does; config tests use a fresh temp working directory under `os.tmpdir()` and never read a real user file.
- Unit tests drive only the pure functions in `src/greet.js`; no process, fs or console.
- `src/greet.js` stays free of `process`, `console` and `fs`; `bin/greet.js` owns argv, console I/O, the one config read and exit codes.
- Tick a task (`[x]` plus the ISO date in Done) when its tests pass. Tasks run in order within a unit.
- The **Spec** column maps each task to the spec's ids. The **Files** column lists every file the task touches.

## Decisions taken for these tasks

Settled up front so work can start. Revisit in the last task if any turns out wrong.

| Decision | Taken |
|---|---|
| Shape of `validateConfig` vs `applyOverrides` | `validateConfig` returns only the keys present in the config file (a partial options object, validated); `applyOverrides` fills the defaults, then config keys, then cli keys, per key. This keeps the two functions separable and testable. |
| How `bin/greet.js` maps `parseArgs` to overrides | It maps parsed values to the same key names (`name`, `shout`, `times`, `lang`, `format`). `--times` is parsed as a string and range-checked in the bin with `Number(value)` plus `Number.isInteger`, because `parseArgs` returns strings for value options and the range check belongs to the usage-error path. |
| Config read call | `bin/greet.js` reads the config once with `readFileSync(path.join(process.cwd(), 'greet.config.json'), 'utf8')`; an `ENOENT` yields `{}`, and any `JSON.parse` or `validateConfig` failure becomes a usage error. |
| Exact JSON bytes | `formatJson` builds `{greeting: value}` and serializes with `JSON.stringify` (no extra spacing), so the exact bytes come from the built-in serializer, not hand-written JSON. |
| Existing export | The current `greet(name)` export stays untouched; the new functions are added beside it in `src/greet.js`. |

## Review focus

The inputs and failure modes most likely to hurt a real user that no requirement spells out, most likely first. Each one has a test in the named task.

1. A config file in the working directory that is never executed, only `JSON.parse`d and validated → the program must not run config contents or read anything else. Test in TASK-024.
2. Exact JSON bytes: double quotes, no spaces, the comma kept in the greeting, and casing applied inside the JSON value → a user consuming `--format json` gets parseable, expected output. Test in TASK-013 and TASK-021.
3. Per-key override: one flag must not reset an unrelated config key → a config of `{"name":"Ada","shout":true}` plus `--name Bob` keeps `shout` true. Test in TASK-014 and TASK-022.
4. `--times` non-integer or out of range, and `--shout` with an unexpected value, must route to the fixed usage line, not a raw stack trace → the user gets one clear error, never a crash. Test in TASK-023.
5. stdout must be empty on every usage error, and `--shout`/`--format` are never applied to the error path → scripts can rely on empty stdout plus exit 2. Test in TASK-023.
6. `parseArgs` error messages differ across Node versions → any parse failure maps to the fixed REQ-031 usage line, so tests assert the line and exit code, not the parser's wording. Test in TASK-023.

---

## Phase 1a: Greeting word and casing

- **GOAL-001**: `src/greet.js` turns a language and options into the base greeting with casing.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-010 | **Red → Green:** add `helloFor(lang)` to `src/greet.js`. **Red:** tests fail: `helloFor('en')` → `Hello`, `helloFor('es')` → `Hola`, `helloFor('fr')` → `Bonjour`. **Guard:** the existing `greet('Ada')` → `Hello, Ada` test stays green. **Green:** implement `helloFor` with the exact three returns above. | REQ-005, TEST-003 | src/greet.js, test/greet.test.js | [ ] | |
| TASK-011 | **Red → Green:** add `buildGreeting({name, shout, lang})`. **Red:** `buildGreeting({name:'Ada', shout:true, lang:'en'})` → `HELLO, ADA`; `buildGreeting({name:'world', shout:false, lang:'en'})` → `Hello, world`. **Green:** return `` `${helloFor(lang)}, ${name}` `` and `.toUpperCase()` it when `shout` is true, using `helloFor` from TASK-010. | REQ-003, REQ-005, TEST-002 | src/greet.js, test/greet.test.js | [ ] | |

**Done when:** `npm test` is green and `helloFor` plus `buildGreeting` cover the language and casing cases above.

## Phase 1b: Text and JSON formatting

- **GOAL-002**: format one greeting as repeated text or exact JSON.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-012 | **Red → Green:** add `formatText(greeting, times)`. **Red:** `formatText('Hello, world', 3)` → `Hello, world\nHello, world\nHello, world\n`. **Green:** return `greeting` followed by `\n`, repeated `times` times. | REQ-004, TEST-004 | src/greet.js, test/greet.test.js | [ ] | |
| TASK-013 | **Red → Green:** add `formatJson(value, times)`. **Red:** `formatJson('Hello, world', 1)` → `{"greeting":"Hello, world"}\n`; `formatJson('HELLO, ADA', 1)` → `{"greeting":"HELLO, ADA"}\n`; `formatJson(['Hello, world','Hello, world'], 2)` → `{"greeting":["Hello, world","Hello, world"]}\n`. **Green:** build `{greeting: value}` and return `JSON.stringify(...)` plus `\n`, with no spacing. | REQ-010, REQ-011, REQ-012, TEST-005 | src/greet.js, test/greet.test.js | [ ] | |

**Done when:** `npm test` is green and `formatText` plus `formatJson` produce the exact bytes above.

## Phase 1c: Merge and config validation

- **GOAL-003**: merge config and cli per key and validate config values.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-014 | **Red → Green:** add `applyOverrides(config, cli)`. **Red:** `applyOverrides({name:'Ada', shout:true}, {name:'Bob'})` returns an object with `name:'Bob'` and `shout:true`; `applyOverrides({}, {})` returns all defaults (`name:'world'`, `shout:false`, `times:1`, `lang:'en'`, `format:'text'`). **Green:** return the defaults object, then spread `config` keys, then spread `cli` keys, per key. | REQ-007, REQ-008, TEST-006 | src/greet.js, test/greet.test.js | [ ] | |
| TASK-015 | **Red → Green:** add `validateConfig(value)`. **Red:** accepts `{name:'Ada', shout:true, times:2, lang:'es', format:'json'}` and returns those keys; throws for a non-object, an unknown key, a non-string `name`, a non-boolean `shout`, a non-integer or out-of-range `times` (0, 6, 2.5, `'2'`), an unsupported `lang`, and an unsupported `format`. **Green:** implement the shape and per-key range checks and throw on any failure. | REQ-021, TEST-007 | src/greet.js, test/greet.test.js | [ ] | |

**Done when:** `npm test` is green and merge plus validation cover the cases above.

## Phase 2a: argv parsing and formatter dispatch

depends: 1

- **GOAL-004**: `bin/greet.js` parses flags and dispatches text or json output.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-020 | **Red → Green:** replace the manual `--name` scan in `bin/greet.js` with `parseArgs`. **Red:** existing CLI tests `run()` → `Hello, world\n` (exit 0) and `run('--name','Ada')` → `Hello, Ada\n` stay green. **Green:** use `require('node:util').parseArgs` with `strict: true` and `allowPositionals: false`, map the parsed values to `cli`, merge through `applyOverrides`, build the greeting, and print via `formatText` for `format:'text'`. | REQ-001, REQ-002, REQ-030, CON-001, CON-003, TEST-010, TEST-011 | bin/greet.js | [ ] | |
| TASK-021 | **Red → Green:** wire the `--shout`, `--lang`, `--times` and `--format json` flags through `bin/greet.js`. **Red:** `run('--shout','--name','Ada')` → `HELLO, ADA\n`; `run('--times','3')` → three `Hello, world` lines; `run('--lang','es')` → `Hola, world\n`; `run('--lang','fr')` → `Bonjour, world\n`; `run('--format','json')` → `{"greeting":"Hello, world"}\n`; `run('--format','json','--times','2')` → `{"greeting":["Hello, world","Hello, world"]}\n`; `run('--format','json','--shout','--name','Ada')` → `{"greeting":"HELLO, ADA"}\n`. **Green:** map `--shout`, `--times` (integer 1-5), `--lang` and `--format`, validate their values, and dispatch `formatJson` with a string for `times` 1 or an array for `times` > 1. | REQ-003, REQ-004, REQ-005, REQ-006, REQ-010, REQ-011, REQ-012, TEST-011, TEST-012, TEST-013 | bin/greet.js, test/greet.test.js | [ ] | |

**Done when:** `npm test` is green and the text plus json flag cases above pass end to end.

## Phase 2b: Config defaults and usage errors

depends: 2a

- **GOAL-005**: config defaults merge per key and every usage error prints the fixed line to stderr and exits 2.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-022 | **Red → Green:** read and validate `greet.config.json` once and merge it before argv. **Red:** with a temp working directory containing config `{"name":"Ada","shout":true}` plus `run('--name','Bob')` → `HELLO, BOB\n`; config `{"lang":"fr"}` plus `run('--times','2')` → two `Bonjour, world` lines; no config file → exactly the no-config output and exit 0. **Green:** read `readFileSync(path.join(process.cwd(), 'greet.config.json'), 'utf8')` once, map `ENOENT` to `{}`, `JSON.parse` then `validateConfig` the result, and call `applyOverrides(config, cli)`. | REQ-007, REQ-008, REQ-020, TEST-014, TEST-016 | bin/greet.js, test/greet.test.js | [ ] | |
| TASK-023 | **Red → Green:** route every usage error to one stderr line and exit 2. **Red:** for unknown flag `--nope`, missing value `--name`, `--times 0`, `--times 6`, `--times abc`, unsupported `--lang de`, unsupported `--format xml`, a stray positional `Bob`, malformed config `{`, and invalid config value `{"times":0}`, assert stderr is exactly `Usage: greet [--name NAME] [--shout] [--times N] [--lang en\|es\|fr] [--format text\|json]\n`, stdout is empty, and exit code is 2; `run('--shout','--nope')` and `run('--format','json','--times','0')` assert the same exact lowercase REQ-031 line, empty stdout and exit 2. **Green:** catch `parseArgs`, `JSON.parse` and `validateConfig` failures plus the `--times`/`--lang`/`--format` range checks, print the REQ-031 line to stderr, print nothing to stdout, and `process.exit(2)`. | REQ-030, REQ-031, REQ-032, RISK-001, RISK-002, TEST-015 | bin/greet.js, test/greet.test.js | [ ] | |

**Done when:** `npm test` is green and every usage-error case prints the fixed line, empty stdout and exit 2.

## Phase 2c: Static security check

depends: 2b

- **GOAL-006**: a static test locks the file-read and injection constraints.

| ID | Task | Spec | Files | Status | Done |
|----|------|------|-------|--------|------|
| TASK-024 | **Red → Green:** add the static security test in `test/greet.test.js`. **Red:** reads `bin/greet.js` and `src/greet.js` and asserts (a) neither file contains `process.env`, `path.isAbsolute`, `eval`, `Function(`, `child_process`, `exec`, `spawn`, `fork`, or `execFile`; (b) every `require(` argument in `bin/greet.js` is one of `'node:util'`, `'node:fs'`, `'node:path'`, `'../src/greet'`; (c) the only `fs.` call in `bin/greet.js` is `readFileSync(path.join(process.cwd(), 'greet.config.json'))` and none of `writeFileSync`, `writeFile`, `appendFileSync`, `appendFile`, `createWriteStream`, `readFile(`, `readdirSync`, `readdir`, `statSync`, `stat`, `createReadStream` appears in `bin/greet.js`; (d) in `src/greet.js` `name` appears only inside `buildGreeting`, and in `bin/greet.js` the name value is passed only to `buildGreeting` (never to `fs`, `child_process` or `eval`). **Green:** adjust `bin/greet.js` and `src/greet.js` if any assertion fails, keeping behaviour identical. | SEC-001, SEC-002, TEST-008 | test/greet.test.js, bin/greet.js, src/greet.js | [ ] | |

**Done when:** `npm test` is green including the static test, and no forbidden call or read path remains.

## Requirement traceability

| Requirement | Tasks |
|---|---|
| REQ-001 | TASK-020 |
| REQ-002 | TASK-020 |
| REQ-003 | TASK-011, TASK-021 |
| REQ-004 | TASK-012, TASK-021 |
| REQ-005 | TASK-010, TASK-011, TASK-021 |
| REQ-006 | TASK-021 |
| REQ-007 | TASK-014, TASK-022 |
| REQ-008 | TASK-014, TASK-022 |
| REQ-010 | TASK-013, TASK-021 |
| REQ-011 | TASK-013, TASK-021 |
| REQ-012 | TASK-013, TASK-021 |
| REQ-020 | TASK-022 |
| REQ-021 | TASK-015, TASK-023 |
| REQ-030 | TASK-020, TASK-023 |
| REQ-031 | TASK-023 |
| REQ-032 | TASK-023 |
| SEC-001 | TASK-024 |
| SEC-002 | TASK-024 |
| CON-001 | TASK-020 |
| CON-002 | TASK-010 |
| CON-003 | TASK-020 |
| CON-004 | TASK-022, TASK-024 |
| GUD-001 | TASK-010, TASK-011, TASK-012, TASK-013, TASK-014, TASK-015 |
| TEST-001 | TASK-010 |
| TEST-002 | TASK-011 |
| TEST-003 | TASK-010 |
| TEST-004 | TASK-012 |
| TEST-005 | TASK-013 |
| TEST-006 | TASK-014 |
| TEST-007 | TASK-015 |
| TEST-008 | TASK-024 |
| TEST-010 | TASK-020 |
| TEST-011 | TASK-020, TASK-021 |
| TEST-012 | TASK-021 |
| TEST-013 | TASK-021 |
| TEST-014 | TASK-022 |
| TEST-015 | TASK-023 |
| TEST-016 | TASK-022 |

## Differences from the spec

None yet.
