---
goal: Give the `greet` CLI real option parsing (--name, --shout, --times, --lang, --format) plus a greet.config.json defaults file, so scripts and teammates get repeatable greetings.
version: 0.4
date_created: 2026-11-19
last_updated: 2026-11-19
owner: pipeline-toy
status: 'Approved'
tags: [feature, cli, options]
---

# Introduction

`greet` today takes one flag by hand: `bin/greet.js` scans argv for `--name` and falls back to `world`. There is no `--shout`, no `--times`, no `--lang`, no `--format`, and nothing a script can rely on beyond the three behaviours the current test file covers. Anyone driving the CLI from a script or CI has to re-implement the option handling each time, and a teammate gets a different greeting depending on which flags they remembered.

This feature gives `greet` a fixed, complete option set: `--name NAME`, `--shout`, `--times N`, `--lang en|es|fr` and `--format text|json`. It also adds `greet.config.json`, read once from the working directory at startup, which supplies defaults for the same five keys. Precedence is per key: built-in defaults, then the config file, then command-line flags, so a flag overrides only its own key and leaves the rest of the config intact.

Two output shapes are defined. The default `text` format prints the greeting, one line per repetition. The `json` format prints exactly one object, `{"greeting": "<value>"}`, and `--times` does not multiply it. Every usage error (unknown flag, missing value, out-of-range or non-numeric `--times`, unsupported `--lang` or `--format`) prints one line to stderr, prints nothing to stdout and exits 2.

The stack is unchanged: Node v22, CommonJS, no new dependencies, `node --test` as the test runner. The existing `greet(name)` function in `src/greet.js` keeps its signature and behaviour; the new parsing lives in new modules beside it. The implementation is test-driven; see `plans/greet-options/feature-greet-options-tasks.md`.

## 1. Requirements & Constraints

### Functional

Option parsing (the CLI accepts only options, never positional arguments or subcommands):

- **REQ-001**: When `greet` is run with no arguments and no `greet.config.json` in the working directory, then it prints exactly `Hello, world` followed by a newline on stdout and exits 0.
- **REQ-002**: When `--name NAME` is given, then the greeting uses `NAME` in place of the default name, e.g. `greet --name Ada` prints `Hello, Ada`. An empty name is not a name: `--name ""` is a usage error with the reason `invalid value for --name: ` (REQ-030, REQ-037). The empty `--name=` form is a missing value instead (REQ-032).
- **REQ-003**: Every value-taking option (`--name`, `--times`, `--lang`, `--format`) is accepted in both the `--opt value` and the `--opt=value` form, and both forms produce identical output (D-05).
- **REQ-004**: When `--shout` is given, then the entire greeting string is upper-cased, e.g. `greet --shout` prints `HELLO, WORLD` (D-01). The upper-casing applies to the greeting word and the name together, not to each part separately.
- **REQ-005**: When `--times N` is given with `N` an integer from 1 to 5 inclusive, then the greeting is printed on `N` separate lines, one line per repetition (D-02, D-16).
- **REQ-006**: When `--lang en` is given, the greeting word is `Hello`; `--lang es` gives `Hola`; `--lang fr` gives `Bonjour` (D-09). The rest of the greeting is unchanged, e.g. `greet --lang es` prints `Hola, world`.
- **REQ-007**: When `--format text` is given, the greeting is printed in the text shape described in REQ-001 and REQ-005.
- **REQ-008**: When `--format json` is given, then stdout contains exactly one line `{"greeting": "<greeting>"}` with the keys in that order, one space after the colon, and no other output on that line (D-15). For example `greet --format json` prints `{"greeting": "Hello, world"}`. The `<greeting>` value is escaped as a JSON string before it is embedded, so the line always parses as JSON and always stays one line: a name containing `"` appears as `\"`, a name containing `\` appears as `\\`, and a name containing a control character (U+0000 to U+001F) appears as `\n`, `\t`, `\r`, `\b`, `\f` or `\u00XX`, so no raw newline reaches stdout.
- **REQ-009**: When both `--format json` and `--times N` are given, then the JSON output still contains exactly one `greeting` key and one line; `--times` does not multiply or array-ify the JSON (D-03).
- **REQ-010**: When `--shout` and `--format json` are given together, then the value inside the JSON object is the upper-cased greeting, e.g. `{"greeting": "HELLO, WORLD"}` (D-11).
- **REQ-011**: When the same option is given more than once, e.g. `--name A --name B`, then the last occurrence wins (D-17).
- **REQ-012**: `--shout` is a boolean flag and takes no value. The form `--shout=true` is a usage error (D-18).

Config file:

- **REQ-020**: When `greet.config.json` exists in the working directory, then it is read once at process start, before flags are parsed, and it supplies defaults for the keys `name`, `shout`, `times`, `lang` and `format` (D-08, D-19).
- **REQ-021**: Precedence is resolved per key: built-in defaults < `greet.config.json` < command-line flags. A command-line flag overrides only the key it names; every other key keeps its config value or, if absent from the config, its built-in default (D-14).
- **REQ-022**: When `greet.config.json` does not exist, the run uses built-in defaults and succeeds (D-04).
- **REQ-023**: When `greet.config.json` contains malformed JSON, is not a JSON object, or contains an invalid value for a key, then the whole config is ignored and the run uses built-in defaults; the run still exits 0 and prints no error (D-04, D-07, D-20). No partial application: one bad key discards the whole file.
- **REQ-024**: Config values are validated with the same rules as the equivalent flags: `name` a non-empty string, `shout` a boolean, `times` an integer from 1 to 5, `lang` one of `en`/`es`/`fr`, `format` one of `text`/`json` (D-07). A value that fails its rule triggers REQ-023 rather than exit 2.
- **REQ-025**: When `greet.config.json` contains a key that is not one of the five known keys, that key is silently ignored and the rest of the file still applies (D-10).

Usage errors:

- **REQ-030**: If any usage error occurs, then stdout is empty, one line naming the reason is written to stderr, and the process exits with code 2 (D-06).
- **REQ-031**: An unknown option (for example `--bogus`) is a usage error with the reason `unknown option --bogus` (D-06).
- **REQ-032**: An option that needs a value but has none is a usage error. This covers `--name` as the last argument, and `--name --shout`, where the next token starts with `--` and is therefore not usable as the value. An empty value is also a missing value: `--name=`, `--times=`, `--lang=` and `--format=` (the `--opt=` form with nothing after the `=`) are usage errors with the reason `missing value for --<opt>`.
- **REQ-033**: A `--times` value that is not an integer, or is an integer outside 1 to 5 inclusive, is a usage error (D-12, D-16). `--times 0` and `--times 6` are usage errors.
- **REQ-034**: A `--lang` value other than `en`, `es` or `fr` is a usage error.
- **REQ-035**: A `--format` value other than `text` or `json` is a usage error.
- **REQ-036**: A positional argument (an argument that is not an option and not the value of an option) is a usage error.
- **REQ-037**: The stderr usage line is a single line of the form `greet: <reason> (usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json])` (D-06). The reason names what went wrong; the usage summary is appended on the same line.

### Preserved & superseded behaviour

- Preserved: `greet(name)` in `src/greet.js` keeps its current signature and returns `Hello, <name>` for the name it is given, e.g. `greet('Ada') === 'Hello, Ada'` (D-13).
- Preserved: `greet` with no arguments prints `Hello, world` and exits 0 (REQ-001).
- Preserved: `greet --name Ada` prints `Hello, Ada` and exits 0 (REQ-002).
- Superseded: the ad-hoc `--name` scan inside `bin/greet.js` → removed, replaced by the shared option parser (REQ-002, REQ-003).

### Security

- **SEC-001**: The greeting is written to stdout as data only. No option value, config value or file content is ever evaluated as code, passed to a shell, or interpolated into a command line.
- **SEC-002**: `greet.config.json` is untrusted input. It is parsed with `JSON.parse` only, treated as plain data, and any parse failure, non-object value or invalid value causes the file to be discarded (REQ-023). Unknown keys are ignored without discarding the file (REQ-025). No key in it selects a file path, a module or a URL.
- **SEC-003**: The config file is read only from the working directory, by fixed name `greet.config.json`, never from a path in an environment variable or a flag (D-08). The file is read as UTF-8 text and is not executed.

### Constraints & guidelines

- **CON-001**: Node v22, CommonJS (`require`/`module.exports`), no new npm dependencies.
- **CON-002**: `npm test` (which runs `node --test`) must stay green, including the three existing tests in `test/greet.test.js`.
- **CON-003**: The config file is read once per process, not once per option (D-19).
- **GUD-001**: The language table (en `Hello`, es `Hola`, fr `Bonjour`) lives in `src/greet.js` next to `greet(name)`, so the word and the function that uses it stay together.
- **GUD-002**: The usage line is composed by one helper so the reason and the usage summary cannot drift apart.
- **PAT-001**: Every module exports plain functions, no classes, and each function takes its inputs as arguments (working directory path, argv array) rather than reading globals. This keeps the parser and the config loader directly callable from tests.
- **PAT-002**: Tests drive the CLI through the real binary via `execFileSync` (the existing pattern in `test/greet.test.js`) and the modules through their exported functions. No test touches the network. A test that must assert a non-zero exit code, stderr or empty stdout uses `spawnSync` instead of `execFileSync`, because `execFileSync` throws on a non-zero exit and its error object is not a reliable source of the three values; alternatively it catches the `execFileSync` error and reads `error.status`, `error.stdout` and `error.stderr`.

## 2. Architecture

```
greet --name Ada --shout --times 3
  |
  1. bin/greet.js  -> argv = process.argv.slice(2)
  |
  2. src/config.js : loadConfig(process.cwd())
  |       reads greet.config.json once; invalid/missing -> {}
  |
  3. src/options.js : parseArgs(argv)      -> { values, error }
  |       unknown flag / missing value / bad --times / bad --lang / bad --format
  |       -> error set, step 5 taken
  |       resolveOptions(argv, config) -> { options, error }
  |       built-in defaults < config < flag values
  |
  4. src/greet.js : buildGreeting(options) -> "HELLO, ADA"
  |       language table + name + shout
  |
  5. bin/greet.js  -> print the output
        text -> one line per --times repetition
        json -> {"greeting": "..."}
     usage error -> one line on stderr, exit 2, stdout empty
```

Order matters: the config is read before the flags are resolved (step 2 before step 3, D-19), and a usage error in step 3 short-circuits before any output is produced (REQ-030).

## 3. Data model (`src/options.js`)

There is no database. The option record is the data model:

```js
// Resolved options, one key per supported option.
{
  name: 'world',      // string, non-empty
  shout: false,      // boolean
  times: 1,          // integer, 1..5
  lang: 'en',        // 'en' | 'es' | 'fr'
  format: 'text'     // 'text' | 'json'
}
```

`greet.config.json` has the same shape with any subset of the five keys:

```json
{ "name": "Ada", "shout": true, "times": 2, "lang": "es", "format": "json" }
```

Notes:
- The five keys are fixed. Any other key is ignored (REQ-025).
- The config is read as a whole: it is applied only when the parsed value is a JSON object and every present key passes validation (REQ-023, REQ-024).
- Lifecycle: the config lives only for the duration of the process; nothing is written back.

## 4. Components

### 4.1 Greeting: `src/greet.js`

Preserves the existing export and adds the language table and the greeting builder.

```js
// existing, unchanged signature and behaviour
function greet(name) { return `Hello, ${name}`; }

// new
const GREETINGS = { en: 'Hello', es: 'Hola', fr: 'Bonjour' };
function buildGreeting({ name, lang, shout }) { /* -> "<word>, <name>" or upper-cased */ }
```

- `greet(name)` still returns `Hello, <name>` and is unchanged (D-13).
- `buildGreeting` looks the word up in `GREETINGS[lang]`, builds `<word>, <name>`, and applies `toUpperCase()` to the whole string when `shout` is true (REQ-004, D-01). It does not escape anything: JSON escaping belongs to the `json` output path in `bin/greet.js`, not to the greeting builder (REQ-008).
- `buildGreeting` does not pluralise the name; `Hello, world` stays `Hello, world` whatever the name (out of scope in the brief).
- The name is used verbatim in the greeting string: no trimming or casing is applied to it, in either output format. The only transformation applied to the name is escaping it as a JSON string, and only when the value is embedded in the `json` output (REQ-008, section 4.5); the `text` format prints the name exactly as given. The name reaching the builder is never empty: an empty `--name ""` is rejected as a usage error and an empty `name` in the config discards the config (REQ-002, REQ-024), so the greeting is never `Hello, ` with a trailing space. The brief did not settle escaping, so the spec settles it here.

### 4.2 Options: `src/options.js`

```js
const DEFAULTS = { name: 'world', shout: false, times: 1, lang: 'en', format: 'text' };

function parseArgs(argv);              // -> { values: {...}|null, error: string|null }
function resolveOptions(argv, config); // -> { options: {...}|null, error: string|null }
function formatUsage(reason);          // -> "greet: <reason> (usage: ...)"
```

`parseArgs(argv)`:
- Returns `{ values, error }`. On success `values` holds only the options the flags actually named, and `error` is `null`. On failure `values` is `null` and `error` is the reason string.
- Recognised options: `--name`, `--shout`, `--times`, `--lang`, `--format`. The value-taking ones are accepted in the `--opt value` and `--opt=value` form (REQ-003, D-05).
- `--shout` is boolean and takes no value; `--shout=true` is a usage error (REQ-012, D-18).
- A repeated option keeps the last occurrence (REQ-011, D-17).
- A value that starts with `--` is not consumed as the value of the preceding option; it is a missing value instead (REQ-032).
- In the `--opt=value` form, a value that is the empty string is a missing value, the same as an absent value: `--name=`, `--times=`, `--lang=` and `--format=` are usage errors with the reason `missing value for --<opt>` (REQ-032).
- The `--name` value must be a non-empty string. `--name ""` is a usage error with the reason `invalid value for --name: ` (REQ-002). It is not folded into the missing-value case, because the value was supplied and was read; it was its content that was rejected.
- Reasons returned: `unknown option --bogus` (REQ-031), `missing value for --name` (REQ-032, including the empty `--name=` form), `invalid value for --name: ` (REQ-002, the empty `--name ""` value), `unknown option --shout=true` (REQ-012), `invalid value for --times: 0` (REQ-033), `unsupported --lang: de` (REQ-034), `unsupported --format: xml` (REQ-035), `unexpected argument: hello` (REQ-036).
- It never reads the environment, the filesystem or `process.argv`; `argv` is always passed in (PAT-001).

`resolveOptions(argv, config)`:
- Starts from `DEFAULTS`, applies `config` key by key, then applies the parsed flag values key by key (REQ-021, D-14).
- Only the keys the flags actually named are applied, so a flag overrides just its own key and the other config keys survive (REQ-021).
- When `parseArgs` reports an error, it returns `{ options: null, error }` and does not apply the config (a usage error beats the config, REQ-030).
- The `config` argument is expected to be `{}` or a fully validated config object; validation happens in `src/config.js` (REQ-024).

### 4.3 Config: `src/config.js`

```js
function loadConfig(dir); // -> { name?, shout?, times?, lang?, format? } or {}
```

- Reads `<dir>/greet.config.json` as UTF-8 text (D-08, SEC-002).
- Any read error yields `{}`: a missing file (REQ-022), a missing directory, an unreadable file (permissions) or a path that is a directory rather than a file. The read error is not reported to the user and does not change the exit code; the run continues on the built-in defaults (REQ-022).
- Malformed JSON → `{}` (REQ-023).
- Valid JSON that is not a plain object (array, number, string, null) → `{}` (REQ-023, D-20).
- A key with an invalid value → `{}` for the whole file, not a partial config (REQ-023, D-07).
- Unknown keys are ignored without invalidating the file (REQ-025, D-10).
- Validation rules are the same as the flag rules: `name` a non-empty string, `shout` boolean, `times` integer 1..5, `lang` in `en|es|fr`, `format` in `text|json` (REQ-024, D-07). An empty `name` in the config is an invalid value, so it discards the whole file and the run falls back to the built-in defaults (REQ-023); it is not a usage error, because an invalid config never changes the exit code (D-04, D-07).

### 4.4 CLI: `bin/greet.js`

- Reads `process.argv.slice(2)` and `process.cwd()`.
- Loads the config once (REQ-020, CON-003), resolves the options (REQ-021).
- On a usage error: writes `formatUsage(reason)` to stderr, writes nothing to stdout, exits 2 (REQ-030, REQ-037).
- Otherwise builds the greeting with `buildGreeting` and prints it:
  - `text` format: the greeting on `options.times` separate lines, each terminated by a newline (REQ-005).
  - `json` format: one line `{"greeting": "<greeting>"}` terminated by a newline, regardless of `options.times` (REQ-008, REQ-009). The greeting value is escaped as a JSON string before it is embedded, using the escape set in section 4.5, so the line stays one line and parses with `JSON.parse` (REQ-008).
- Exits 0 on success.
- Output goes through `console.log`, so the trailing newline comes from the stream, not from the string.

### 4.5 Output shapes

Text format, `--times 3` (`--shout`):

```
HELLO, ADA
HELLO, ADA
HELLO, ADA
```

JSON format:

```
{"greeting": "Hello, world"}
```

The JSON line is exactly one object with one key. It is produced by building the string from the greeting value, not by `JSON.stringify` of a wider object, so the key order and the spacing are fixed (REQ-008, D-15). The greeting value is escaped as a JSON string before it is embedded, so the printed line always parses with `JSON.parse` and always stays one line (REQ-008). The escape set is the complete JSON string escape set: `"` becomes `\"`, `\` becomes `\\`, the control characters U+0000 to U+001F become `\n`, `\t`, `\r`, `\b`, `\f` or `\u00XX` with two lower-case hex digits, and no raw control character survives into the output. Escaping applies only to the `json` format; the `text` format prints the name verbatim (REQ-008).

The escape is produced by `JSON.stringify(greeting)` on the value alone, which returns the surrounding double quotes as well; the implementation drops exactly those two outer quotes and embeds the remainder between the quotes of `{"greeting": "..."}`. `JSON.stringify` is the normative source of the escape set, so the guarantees above are its guarantees: it escapes `"` and `\`, it escapes every control character in U+0000 to U+001F, and it leaves no raw newline in the result. The key order and the single space after the colon stay fixed because the object is assembled by hand (REQ-008, D-15).

## 5. Approach summary

Three small modules, each a set of plain functions:

- `src/config.js` reads and validates `greet.config.json`, returning `{}` whenever anything is wrong with it (REQ-022, REQ-023).
- `src/options.js` parses argv into flag values, then merges defaults, config and flags per key (REQ-003, REQ-021).
- `src/greet.js` keeps `greet(name)` and adds the language table plus `buildGreeting` (REQ-006, REQ-004).
- `bin/greet.js` wires them together and owns stdout, stderr and the exit code (REQ-030).

A usage error is carried as a string reason, never as a thrown exception, so the CLI is the only place that decides to exit 2 and the parser stays testable without spawning a process.

## 6. Alternatives

- **ALT-001: Hand-written parser inside `bin/greet.js`.** Rejected. It would put parsing, config loading, formatting and I/O in one file, so none of it could be tested in pieces. Taken from the brief's "Approaches considered".
- **ALT-002: A third-party CLI parsing library (yargs, commander, minimist).** Rejected. Five fixed options do not justify a dependency, and the brief rules out new dependencies (CON-001).
- **ALT-003: Rewrite `greet()` to take an options object.** Rejected. It breaks the existing public `greet(name)` signature and its test for no gain (D-13).
- **ALT-004: A separate module for the language table.** Deferred. The table is three entries; keeping it in `src/greet.js` next to `greet(name)` avoids a module that exists only to hold a constant (GUD-001). Revisit if more languages or per-language punctuation appear.
- **ALT-005: Environment variables as a third precedence layer.** Deferred. The brief rules it out: no such requirement, and it adds a layer that has to be documented and tested (out of scope in the brief).
- **ALT-006: Throwing a typed error from the parser and catching it in `bin/greet.js`.** Rejected for v1. The reason strings are the contract (REQ-037), and a returned reason avoids a control-flow path that no test needs to cover separately.

## 7. Dependencies

- **DEP-001**: Node.js v22 built-ins only: `node:fs` (`readFileSync`), `node:path` (`join`). No npm packages are added (CON-001).

## 8. Files

New:
- `src/options.js`: flag parsing, defaults, per-key merge, usage line helper.
- `src/config.js`: reads and validates `greet.config.json`.
- `test/options.test.js`: unit tests for the parser and the merge.
- `test/config.test.js`: unit tests for config loading and validation.

Changed:
- `src/greet.js`: keeps `greet(name)` unchanged, adds `GREETINGS` and `buildGreeting`.
- `bin/greet.js`: replaces the ad-hoc `--name` scan with the parser, config loading, formatting, and the exit-2 usage path.
- `test/greet.test.js`: keeps the three existing tests, adds CLI-level tests for the new options and the config file.

## 9. Testing

Seams under test:

1. `parseArgs(argv)` and `resolveOptions(argv, config)` in `src/options.js`: the pure functions the tests call directly.
2. `loadConfig(dir)` in `src/config.js`: called with a temporary directory path, so the test controls the working directory contents.
3. The CLI itself, `bin/greet.js`, spawned as a child process via `execFileSync` (the pattern already used in `test/greet.test.js`), with `cwd` set to a temporary directory when the config file matters. For the usage-error cases the test spawns the binary with `spawnSync` (or catches the `execFileSync` error and reads `error.status`, `error.stdout` and `error.stderr`), so that the exit code and stderr can be asserted (PAT-002, TEST-011).

- **TEST-001 (unit)**: `parseArgs` accepts every value-taking option in the `--opt value` and `--opt=value` form and returns the expected values; `--shout` is accepted as a boolean and `--shout=true` is rejected. Proves REQ-002, REQ-003, REQ-012.
- **TEST-002 (unit)**: `parseArgs` returns an error reason for each usage error case (unknown option, missing value, bad `--times`, bad `--lang`, bad `--format`, positional argument). Proves REQ-031 to REQ-036.
- **TEST-002b (unit)**: `parseArgs` rejects an empty value in the `--opt=value` form (`--name=`, `--times=`, `--lang=`, `--format=`) with the reason `missing value for --<opt>`, and rejects `--name ""` with the reason `invalid value for --name: `. Proves REQ-032, REQ-002.
- **TEST-003 (unit)**: `resolveOptions` merges defaults, config and flags per key, so a flag overrides only its own key and the rest of the config survives; a repeated flag keeps the last value. Proves REQ-021, REQ-011.
- **TEST-004 (unit)**: `loadConfig` returns `{}` for a missing file, malformed JSON, a non-object value, a file with one invalid value, and a file it cannot read (a directory that does not exist, or an unreadable file); it returns the validated keys for a valid file and ignores unknown keys. A config whose `name` is the empty string returns `{}`. Proves REQ-022 to REQ-025.
- **TEST-005 (unit)**: `buildGreeting` returns `Hello, world`, `Hola, world`, `Bonjour, world` for `en`, `es`, `fr`, and upper-cases the whole string when `shout` is true. Proves REQ-004, REQ-006.
- **TEST-006 (unit)**: `greet('Ada')` still returns `Hello, Ada`. Proves the preserved behaviour.
- **TEST-007 (CLI)**: the CLI prints `Hello, world` with no arguments, `Hello, Ada` for `--name Ada`, and the same text output for `--format text` as for no format flag. Proves REQ-001, REQ-002, REQ-007.
- **TEST-008 (CLI)**: the CLI prints `HELLO, ADA` on three separate lines for `--name Ada --shout --times 3`. Proves REQ-004, REQ-005.
- **TEST-009 (CLI)**: the CLI prints `Hola, world` for `--lang es` and `Bonjour, world` for `--lang fr`. Proves REQ-006.
- **TEST-010 (CLI)**: the CLI prints exactly `{"greeting": "Hello, world"}` for `--format json`, one line even with `--times 3`, and the upper-cased value with `--shout`. Proves REQ-008, REQ-009, REQ-010.
- **TEST-011 (CLI)**: every usage error writes nothing to stdout, writes one line to stderr naming the reason, and exits 2. The test uses `spawnSync` (or catches the `execFileSync` error and reads `error.status`, `error.stdout` and `error.stderr`), because `execFileSync` throws on the non-zero exit (PAT-002). It asserts `status === 2`, `stdout === ''` and that stderr is exactly one line starting with the exact reason text. Proves REQ-030, REQ-031, REQ-037.
- **TEST-012 (CLI)**: run in a temporary directory holding a `greet.config.json`, the CLI applies the config; a command-line flag overrides only its own key; a malformed config file leaves the run on the built-in defaults and still exits 0. Proves REQ-020, REQ-021, REQ-022, REQ-023.
- **TEST-013 (CLI)**: the CLI prints a `--format json` line that `JSON.parse` accepts when the name contains a `"`, a `\` or a newline, and the parsed `greeting` value equals the raw greeting; the printed output contains exactly one newline, the terminating one; the same name supplied through a `greet.config.json` in a temporary directory produces the same JSON line; the `text` format prints the same name verbatim. Proves REQ-008.

## 10. Risks & assumptions

- **RISK-001**: The usage-error reason strings are part of the contract (REQ-031, REQ-037), so a later edit to the wording breaks a test that matches the line. Mitigation: the test asserts the reason text exactly (REQ-031 pins `unknown option --bogus`; section 4.2 lists every reason string) and matches the usage-summary part of the line, which is the part most likely to be reworded, rather than matching the whole line. The summary stays in one helper (GUD-002).
- **RISK-002**: A `greet.config.json` in the repo root would silently change what the CLI prints for every developer and for the test suite. Mitigation: the CLI tests that need the config run in a temporary directory; no `greet.config.json` is committed to the repo.
- **RISK-003**: Reading the config before parsing flags means an invalid config is discarded even when flags would have overridden that key. Mitigation: this is the intended behaviour (REQ-023, D-04); the spec and tests state it explicitly.
- **RISK-004**: `--name` values that look like options, e.g. `--name --shout`, are ambiguous. Mitigation: REQ-032 treats the next token as missing, so the run fails loudly instead of guessing.
- **ASSUMPTION-001**: The working directory of the process is the directory the user means by "the working directory" (D-08), which is `process.cwd()`.
- **ASSUMPTION-002**: The output is written with `console.log`, so stdout always ends with a newline and the JSON output is exactly one line.

## 11. Open questions

None. Every question the brief left open was settled in this spec (module and function names, the language table location, and the usage line text), and the brief's decisions cover the rest.

Settled in v0.2, completed in v0.3 (the brief left these open, so they are spec-level decisions, not brief decisions):

- JSON escaping in the `json` format: the greeting value is escaped as a JSON string before it is embedded, with the complete JSON string escape set (`"`, `\`, and every control character in U+0000 to U+001F as `\n`, `\t`, `\r`, `\b`, `\f` or `\u00XX`), so the line always parses with `JSON.parse` and always stays one line (REQ-008). The `text` format prints the name verbatim. v0.3 completes the escape set: v0.2 named only the quote and the backslash, which could not deliver the promised guarantee for a name containing a control character.

Settled in v0.4 (spec-level decisions; the brief did not cover these cases):

- An empty value in the `--opt=value` form is a missing value: `--name=`, `--times=`, `--lang=` and `--format=` are usage errors with the reason `missing value for --<opt>` (REQ-032).
- An empty name is rejected, and the two paths differ in the way the brief already requires of every invalid value (D-04, D-07): `--name ""` on the command line is a usage error with the reason `invalid value for --name: ` (REQ-002), while an empty `name` in `greet.config.json` is an invalid config value, so it discards the whole config and the run falls back to the built-in defaults and still exits 0 (REQ-023, REQ-024). The greeting is therefore never `Hello, ` with a trailing space.
- A read error on `greet.config.json` (missing directory, unreadable file, path that is a directory) yields `{}`, the same as a missing file, and never changes the exit code (REQ-022, section 4.3).
- The usage-error test asserts the reason text exactly and matches only the usage-summary part of the line; it runs the binary with `spawnSync` (or catches the `execFileSync` error and reads `error.status`, `error.stdout` and `error.stderr`), because `execFileSync` throws on the non-zero exit (PAT-002, TEST-011, RISK-001).

