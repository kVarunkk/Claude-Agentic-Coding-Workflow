---
goal: Extend the `greet` CLI with long-flag option parsing, a config file for defaults, and text or JSON output.
version: 0.3
date_created: 2026-11-19
last_updated: 2026-11-19
owner: pipeline-toy
status: 'Approved'
tags: [feature, cli, options]
---

# Introduction

![Status: Approved](https://img.shields.io/badge/status-Approved-green)

The `greet` CLI today takes a single `--name` flag by hand and prints `Hello, <name>`. Users of the toy want to say hello properly: to a named person, in a chosen language, in a chosen output format, repeated a bounded number of times, without repeating the same flags on every invocation. This feature gives the CLI a real option parser with five long flags, an optional `greet.config.json` file for defaults, and a loud, uniform failure mode for anything the parser does not understand.

The examples that shape the design: `greet` prints `Hello, world` and exits 0. `greet --name Ada --lang es --times 2` prints `Hola, Ada` on two lines. `greet --format json --name Ada` prints `{"greeting": "Hello, Ada"}`. `greet --times 9` prints nothing on stdout, one usage line on stderr and exits 2. A `greet.config.json` with `{"name": "Bob"}` in the working directory supplies defaults, and a command-line flag overrides only its own key.

The core idea: one parse step resolves every value from three sources in order (command line, then config file, then built-in default), one resolve step turns those values into a greeting, one render step prints it in text or JSON. Every usage error is the same shape: nothing on stdout, exactly one usage line on stderr, exit code 2.

Node.js, CommonJS, no runtime dependencies. The implementation is test-driven; see `plans/greet-options/feature-greet-options-tasks.md`.

## 1. Requirements & Constraints

### Functional

Command-line parsing:

- **REQ-001**: When the CLI is run with no arguments and no `greet.config.json` in the process working directory, then it prints `Hello, world` followed by a newline on stdout and exits with code 0. When a config file is present, the name comes from it (REQ-030).
- **REQ-002**: When the CLI is run with `--name NAME` or `--name=NAME`, then it uses `NAME` as the name in the greeting.
- **REQ-003**: When the same flag is given more than once, then the last occurrence wins and no error is raised; this holds for `--name`, `--times`, `--lang` and `--format` (D-01).
- **REQ-004**: When an unknown long flag is given, then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2.
- **REQ-005**: When a flag that takes a value is given without one (last argument, or followed by another flag), then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2. A value that starts with `--` counts as a missing value, so `--name --lang es` is a usage error. A value that starts with a single `-` is an ordinary value, so `--name -x` uses `-x` as the name.
- **REQ-006**: When `--name` is given an empty value (`--name ""` or `--name=`), then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2 (D-05).
- **REQ-007**: When a bare positional argument is given (any argument that is not one of the five long flags, and not the value of a flag), then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2 (D-10).

Values:

- **REQ-010**: When `--times N` is given, then the greeting is printed `N` times; in text format each repetition is one line, in JSON format the single object's `greeting` value holds the greeting repeated (D-02, D-03). The exact repetition in each format is fixed by REQ-021 and REQ-022.
- **REQ-011**: When `--times` is given a value that is not a base-10 integer (a value that does not match `^[0-9]+$` exactly), then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2. So `0x2`, `1e1`, `2.5`, `+3`, `-3`, `" 3"` and `"3 "` are all usage errors.
- **REQ-012**: When `--times` is given a value outside 1 to 5 inclusive, then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2. The valid range is 1 to 5 inclusive, stated here and held as `TIMES_MIN` (1) and `TIMES_MAX` (5) in `src/options.js`; the same range applies to the config file (section 3).
- **REQ-013**: When `--lang` is given a value other than `en`, `es` or `fr`, then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2. The command-line value is matched exactly and is case-sensitive, so `--lang ES` is a usage error. This is deliberately different from the config file, where a trimmed, lower-cased value is matched (section 3, Q-2).
- **REQ-014**: When `--format` is given a value other than `text` or `json`, then the CLI prints nothing on stdout, prints exactly one usage line on stderr and exits with code 2. The command-line value is matched exactly and is case-sensitive, so `--format JSON` is a usage error. This is deliberately different from the config file, where a trimmed, lower-cased value is matched (section 3, Q-2).
- **REQ-015**: When `--shout` is given, then the whole greeting, including the name, is upper-cased in both text and JSON output (D-13, D-14).
- **REQ-016**: When `--lang es` is given, then the greeting word is `Hola`; when `--lang fr`, then it is `Bonjour`; when `--lang en` or no language is given, then it is `Hello` (D-15).
- **REQ-017**: When `--name` is given, then the name is used exactly as given, with no trimming of surrounding whitespace (D-16, out of scope).

Output:

- **REQ-020**: When the format is `text` and the repetition count is 1, then stdout holds exactly one line: the greeting followed by a newline.
- **REQ-021**: When the format is `text` and the repetition count is greater than 1, then stdout holds exactly one line per repetition, each the greeting followed by a newline, so `--times 3` prints three identical lines (D-02).
- **REQ-022**: When the format is `json`, then stdout holds exactly one line: the object `{"greeting": "<greeting>"}` followed by a newline, where `<greeting>` is the greeting repeated once per repetition count and the repetitions are joined by a single newline character (D-03). So `--times 2` prints `{"greeting": "Hello, Ada\nHello, Ada"}` on one line, with the newline escaped as `\n` inside the JSON string.
- **REQ-023**: When the format is `json`, then the `greeting` value is emitted as a JSON string literal, so a double quote, a backslash, a newline or any other control character in the name is escaped and the line stays valid JSON.
- **REQ-024**: When the format is `text` and the name contains a newline character, then the name is printed exactly as given, so the output holds more lines than the repetition count. This is the only exception to the line-count rules in REQ-020 and REQ-021: those count lines per repetition, and REQ-024 says a newline inside the name adds lines of its own. The name is never altered to fit the format (D-16).

Config file:

- **REQ-030**: When `greet.config.json` exists in the process working directory, then it is read once at startup and its values are used as defaults for `name`, `shout`, `times`, `lang` and `format`.
- **REQ-031**: When a command-line flag is given, then it overrides only its own key; every other value still comes from the config file, if present, and otherwise from the built-in default. A flag that is absent from the command line never overrides a config value, so a config file with `"shout": true` cannot be turned off from the command line: there is no `--no-shout` flag, and the accepted consequence is that the greeting stays upper-cased for that run.
- **REQ-032**: When `greet.config.json` does not exist, then the CLI runs with the built-in defaults and exits 0 (D-04).
- **REQ-033**: When `greet.config.json` is not valid JSON, or is not a JSON object, then the CLI ignores it, uses the built-in defaults and exits 0 (D-04).
- **REQ-034**: When a value in `greet.config.json` is invalid (a `name` that is not a non-empty string, or a `name` that holds only whitespace, a `shout` that is not a boolean, a `times` that is not a whole number in 1 to 5, a `lang` or `format` that is not a string, or a `lang` or `format` whose trimmed, lower-cased string value is not one of the allowed values, as matched in section 3), then that single value falls back to its built-in default and the other config values still apply (D-04, D-12).
- **REQ-035**: When `greet.config.json` holds a key the CLI does not know, then it is ignored and the run is unaffected (D-06).
- **REQ-036**: When `greet.config.json` holds `"name": ""`, then the name falls back to the built-in default `world` (D-12).
- **REQ-037**: When `greet.config.json` holds `"name": "  Ada  "`, then the name is used exactly as it is in the file, with no trimming (D-16).

Failure shape:

- **REQ-040**: When any usage error occurs, then stdout is empty, stderr holds exactly one line and the exit code is 2.
- **REQ-041**: When any usage error occurs, then the single stderr line is exactly `Usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json]` (D-08).
- **REQ-042**: When a usage error occurs, then the exit code is 2 and no stack trace, no usage text beyond that one line and no partial greeting is written to stderr or stdout.

### Preserved & superseded behaviour

- Preserved: `greet(name)` in `src/greet.js` keeps its current signature and keeps returning `Hello, <name>` for the default case; the three existing tests in `test/greet.test.js` keep passing unchanged.
- Preserved: `greet` with no arguments still prints `Hello, world` on stdout and exits 0, when no `greet.config.json` is present in the working directory.
- Superseded: the hand-rolled `--name` lookup in `bin/greet.js` (index-based, silently ignoring anything else) → removed, replaced by REQ-001 to REQ-007.

### Security

- **SEC-001**: The CLI reads only the file `greet.config.json` in the process working directory, and no other path; a config file elsewhere is never read.
- **SEC-002**: The CLI writes nothing to disk: no config file is created, changed or removed by any code path.
- **SEC-003**: Values taken from the config file are treated as plain data: a config value is printed literally, never evaluated as code.
- **SEC-004**: A malformed or oversized config file cannot crash the run: the parse is wrapped so that any failure leaves the built-in defaults in place and the CLI still exits 0.

### Constraints & guidelines

- **CON-001**: The implementation is Node.js with CommonJS `require`/`module.exports`, matching `src/greet.js` and `bin/greet.js` today.
- **CON-002**: No runtime dependency is added. `package.json` keeps no `dependencies` and no `devDependencies`; the parser is hand-written.
- **CON-003**: `npm test` runs `node --test` and stays the only test command.
- **CON-004**: The CLI keeps its public entry point `bin/greet.js`, invoked as `greet` through the `bin` entry in `package.json`.
- **GUD-001**: The greeting word for a language lives in one table keyed by language code, not in a switch or a chain of `if`s.
- **GUD-002**: The option parsing, the merge, the greeting resolution and the rendering live in one module, `src/options.js`, and the config file reading lives in a second module, `src/config.js`, so each can be tested on its own without spawning a process. The split is the one in section 4.
- **GUD-003**: Error handling in the CLI is one place: every usage error is raised as the dedicated `UsageError` type, `bin/greet.js` catches that type and nothing else, one place prints the usage line and sets exit code 2.
- **PAT-001**: Pure functions take their inputs as arguments and return values; the modules that touch the file system or the process take the working directory and the argument list as arguments, so tests can drive them without a real config file or a real argv.
- **PAT-002**: The `--name VALUE` and `--name=VALUE` forms are handled by the same code path, one for the space form and one for the equals form, with the resulting value identical.
- **PAT-003**: No value from argv or from the config file is ever passed to a shell or used to build a command string. Checked by code review.

## 2. Architecture

```
argv ──▶ parseArgs(argv)            config ──▶ readConfig(cwd)
             │  usage error             │  parse error (ignored)
             ▼                            ▼
        parsed flags ───────────────▶ mergeSettings(flags, config)
             (flags win per key)              │
                                              ▼
                                    resolveGreeting(settings)
                                              │
                                              ▼
                                    render(settings)
                                      │          │
                          text: N lines     json: 1 line
                                      ▼          ▼
                                   stdout (one payload)
```

Order matters:
1. Parse the command line. A usage error stops the run here, before the config file is read.
2. Read `greet.config.json` once from the working directory. A missing or invalid file leaves the defaults in place.
3. Merge: for each of the five keys, the command line wins, then the config file, then the built-in default.
4. Resolve the greeting word from the language and interpolate the name.
5. Render in the chosen format and write one payload to stdout: `N` lines in text format, one line in JSON format.

## 3. Data model (`src/options.js`, `src/config.js`)

There is no database. The data model is the resolved settings object and the config file shape.

```js
// src/options.js
const DEFAULTS = Object.freeze({
  name: 'world',
  shout: false,
  times: 1,
  lang: 'en',
  format: 'text'
});

const LANGS = Object.freeze({ en: 'Hello', es: 'Hola', fr: 'Bonjour' });
const FORMATS = Object.freeze(['text', 'json']);
const TIMES_MIN = 1;
const TIMES_MAX = 5;

// Result of parsing argv: one key per flag, or undefined when the flag was absent.
{
  name?: string,      // non-empty
  shout?: true,       // present or absent
  times?: number,     // integer, 1..5
  lang?: 'en'|'es'|'fr',
  format?: 'text'|'json'
}

// Config file shape (greet.config.json), every key optional, unknown keys ignored.
{
  name?: string,
  shout?: boolean,
  times?: number,
  lang?: 'en'|'es'|'fr',
  format?: 'text'|'json'
}

// Resolved settings: every key present, taken from flags, then config, then defaults.
{
  name: string,
  shout: boolean,
  times: number,
  lang: 'en'|'es'|'fr',
  format: 'text'|'json'
}
```

Notes:
- Who reads what: `DEFAULTS` is read by `mergeSettings` for every key that neither the command line nor the config file supplies. `LANGS` is read by `resolveGreeting` to look up the greeting word. `FORMATS` is read by `parseArgs` to validate the `--format` value and by `mergeSettings` to validate the config `format` value. `TIMES_MIN` and `TIMES_MAX` are read by `parseArgs` to range-check the `--times` value and by `mergeSettings` to range-check the config `times` value. `USAGE` is read by `bin/greet.js` to print the usage line.
- The config file is read with `fs.readFileSync(path.join(cwd, 'greet.config.json'), 'utf8')` and parsed with `JSON.parse`, both inside one `try`/`catch`. A missing file, an unreadable file and invalid JSON all end in the same place: the built-in defaults.
- The config file's `name` is used exactly as it is in the file. It is not trimmed (D-16). The one exception is a name that holds only whitespace: that is not a valid name, so it falls back to the default `world` (D-12, REQ-034).
- `shout` in the config file is read as a boolean only. The strings `"true"` and `"false"` are not accepted; a non-boolean value is ignored and the default `false` applies.
- `lang` and `format` in the config file are matched case-insensitively after trimming the value, so `"ES"` is read as `es`. The value must be a string: a non-string value (a number, a boolean, an array, an object, `null`) is invalid and falls back to the default `en` or `text`, so a config file holding `{"lang": 42}` never crashes the run. The command-line values are matched exactly: `--lang ES` is a usage error.
- `times` in the config file must be a whole number from 1 to 5 inclusive. A float, a string, a number outside the range and a missing value are all invalid and fall back to the default `1`. The range is `TIMES_MIN` to `TIMES_MAX` inclusive, the same 1 to 5 the command line uses (REQ-011, REQ-012).

## 4. Components

### 4.1 `src/options.js`: option parsing and defaults

Exports:

```js
module.exports = {
  DEFAULTS, LANGS, FORMATS, TIMES_MIN, TIMES_MAX, USAGE,
  UsageError,      // the error type that parseArgs raises for every usage error
  parseArgs,      // (argv: string[]) => flags
  mergeSettings,  // (flags, config) => resolved settings
  resolveGreeting,// (settings) => string
  render          // (settings) => string (the whole stdout payload)
};
```

`UsageError` is a dedicated error type for usage errors, distinct from a plain `Error`:

```js
class UsageError extends Error {
  constructor(message) {
    super(message);
    this.name = 'UsageError';
  }
}
```

Every usage error is raised as a `UsageError`. `bin/greet.js` catches `UsageError` and nothing else, so REQ-042's no-stack-trace rule is guaranteed: no other error type escapes the parse path as a stack trace.

`USAGE` is the single usage line, exactly:

```
Usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json]
```

`parseArgs(argv)`:
- Takes the argument list as given, without the node and script path. `bin/greet.js` does the slicing (`process.argv.slice(2)`) and hands the result to `parseArgs`; `parseArgs` never touches `process.argv` itself (section 4.3).
- Returns an object with only the keys whose flags were present.
- Accepts the space form `--name Ada`, `--times 3`, `--lang es`, `--format json` and the equals form `--name=Ada`, `--times=3`, `--lang=es`, `--format=json` (D-09, PAT-002). Both forms of `--times` are accepted, the same two forms as `--name`.
- `--shout` takes no value. `--shout=true` is not accepted: it is an unknown flag and a usage error.
- A value that starts with `--` is treated as a missing value, not as the value of the flag (REQ-005). So `--name --lang es` is a usage error.
- A value that starts with a single `-` is an ordinary value: `-x` is a valid name, so `greet --name -x` prints `Hello, -x` and exits 0. Only the two-dash `--` prefix marks a missing value (REQ-005).
- There are no short flags: `-n`, `-h` and every other single-dash argument are unknown arguments and usage errors, while `--name` and every other long flag is the only supported spelling (D-11, out of scope).
- The last occurrence of a repeated flag wins (D-01).
- Any argument that is not a recognised flag and is not consumed as a flag value is a usage error (REQ-007, D-10). `--` is not special: it is an unknown argument and a usage error.
- The `--lang` and `--format` values are matched exactly: they are case-sensitive, so `--lang ES` and `--format JSON` are usage errors. The config file is matched differently, trimmed and lower-cased (section 3, REQ-013, REQ-014).
- A `--times` value is read as a base-10 integer only: the value string must match `^[0-9]+$` exactly, and it is then converted with `Number`. So `3` is read as 3, while `0x2`, `1e1`, `2.5`, `+3`, `-3` and `" 3"` are usage errors (REQ-011). The value must then lie in the range `TIMES_MIN` to `TIMES_MAX` inclusive, which is 1 to 5 (REQ-012). The same range applies to the config file (section 3).
- Raises a `UsageError` for: an unknown flag, a missing value, an empty `--name` value, a `--times` value that is not a base-10 integer, a `--times` value outside 1 to 5, an unsupported `--lang`, an unsupported `--format`, and any bare positional argument.

`mergeSettings(flags, config)`:
- Returns a settings object with all five keys present.
- For each key: the flag value if the flag was present, else the config value if it is valid, else the built-in default.
- A config value is valid only under the rule for its key. An invalid config value falls back to the default for that key alone (REQ-034):
  - `name`: valid when it is a non-empty string that is not only whitespace; the value is used verbatim, with no trimming (REQ-034, REQ-036, REQ-037). A name of only whitespace (for example `"   "`) is invalid and falls back to the default `world`, the same as an empty name (D-12).
  - `shout`: valid when it is a boolean; the strings `"true"` and `"false"` are not valid.
  - `times`: valid when it is a whole number from 1 to 5 inclusive.
  - `lang` and `format`: valid when the value is a string AND its trimmed, lower-cased form is one of the allowed values (`en`, `es`, `fr` and `text`, `json`), so `"ES"` is valid and read as `es`. A value that is not a string (a number, a boolean, an array, an object, `null`) is invalid and falls back to the default, the same as any other invalid value for that key (section 3).

`resolveGreeting(settings)`:
- Looks the greeting word up in `LANGS` by `settings.lang` and returns `` `${word}, ${settings.name}` ``.
- When `settings.shout` is true, the returned string is upper-cased in full, name included (D-14).

`render(settings)`:
- Calls `resolveGreeting(settings)` once and returns the whole stdout payload as a single string.
- In `text` format: the greeting repeated `settings.times` times, each repetition followed by a newline (REQ-021).
- In `json` format: the line `{"greeting": "<repeated greeting>"}` with one space after the colon, followed by a newline, where the repeated greeting holds one greeting per repetition joined by a newline character (REQ-022, REQ-023). Build it as `'{"greeting": ' + JSON.stringify(repeatedGreeting) + '}'`, so the escaped string comes from `JSON.stringify` and the space after the colon is kept (plain `JSON.stringify({ greeting: repeatedGreeting })` would omit it).
- The greeting is built once and reused for every repetition, so every repetition in a run is identical.

### 4.2 `src/config.js`: config file reading

Exports:

```js
module.exports = {
  CONFIG_FILE_NAME,   // 'greet.config.json'
  readConfig          // (cwd: string) => config object ({} when there is none)
};
```

`readConfig(cwd)`:
- Reads `path.join(cwd, 'greet.config.json')` as UTF-8 text.
- On a missing file, an unreadable file or invalid JSON, returns `{}` (D-04, REQ-032, REQ-033).
- When the parsed value is not a plain object (an array, a string, a number, `null`), returns `{}`.
- Returns the parsed object as-is otherwise; the validation of individual keys happens in `mergeSettings`, so unknown keys and wrong types are handled in one place (REQ-034, REQ-035).
- Never throws and never writes anything (SEC-002, SEC-004).

### 4.3 `bin/greet.js`: the CLI

- Parses `process.argv.slice(2)` and hands that array to `parseArgs`. The slicing happens here, not inside `parseArgs` (section 4.1).
- On a `UsageError`: writes nothing to stdout, writes the single usage line from `USAGE` to stderr and exits with code 2 (REQ-040 to REQ-042). `UsageError` is the only type caught here, so an unexpected error is not swallowed and never prints a usage line in place of a stack trace.
- Reads the config file from `process.cwd()` exactly once (REQ-030).
- Merges, resolves, renders and writes the payload to stdout.
- On success: exits with code 0.

Usage line, exactly (this is `USAGE` in `src/options.js`):

```
Usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json]
```

### 4.4 API contracts

None. This feature is a command-line program with no HTTP or IPC surface. The observable contract is the process contract below.

| Invocation | stdout | stderr | Exit code |
|---|---|---|---|
| `greet` (no `greet.config.json` in the working directory) | `Hello, world\n` | empty | 0 |
| `greet --name Ada` | `Hello, Ada\n` | empty | 0 |
| `greet --name Ada --lang es --times 2` | `Hola, Ada\nHola, Ada\n` | empty | 0 |
| `greet --format json --name Ada` | `{"greeting": "Hello, Ada"}\n` | empty | 0 |
| `greet --shout --name Ada` | `HELLO, ADA\n` | empty | 0 |
| `greet --format json --shout --name Ada` | `{"greeting": "HELLO, ADA"}\n` | empty | 0 |
| `greet --name Ada --format json --times 2` | `{"greeting": "Hello, Ada\nHello, Ada"}\n` | empty | 0 |
| `greet --times 9` | empty | one usage line | 2 |
| `greet --bogus` | empty | one usage line | 2 |
| `greet Ada` | empty | one usage line | 2 |

## 5. Model / approach summary

Three sources, one merge, one render.

The CLI is a small teaching-quality toy, so the code stays small and the rules are visible. Option parsing is hand-written in `src/options.js`: five flags do not need a dependency, and the exact error cases the feature promises (unknown flag, missing value, bad value, stray argument) are only visible if the code names them.

The config file is one more source of defaults, not a second way to configure the run. It is read once, at startup, from the working directory only. Every value in it is validated; an invalid value falls back to the default rather than failing the run, because a config file is optional and a stale one should not stop a greeting. A command-line flag always wins for its own key and never disturbs the others.

Rendering is separate from resolution. The greeting is built once, then printed as text (one line per repetition) or as a single JSON object (the greeting repeated inside one `greeting` value).

## 6. Alternatives

- **ALT-001: A third-party argument parser (yargs, minimist, commander).** Rejected. It adds a runtime dependency to a project that deliberately has none (CON-002), and it hides the exact error messages the feature requires. Evidence: `package.json` has no `dependencies` today and the brief names hand-written parsing as the chosen approach.
- **ALT-002: `process.argv` parsing with `node:util.parseArgs`.** Rejected. It is built into Node, but its error messages and its handling of `--name=` differ from the usage line the feature promises, and it does not support the "a value that starts with `--` is a missing value" rule without extra code. Evidence: the feature needs one uniform stderr line and exit 2 for every usage error.
- **ALT-003: Search for the config file in parent directories.** Rejected. D-07 fixes the config file to the process working directory, and searching upward makes the run depend on where it was started from.
- **ALT-004: Keep the config file lookup in `bin/greet.js`.** Rejected. The config file is read through `readConfig(cwd)`, so a test can drive it with a temporary directory and no subprocess. This follows GUD-002.
- **ALT-005: Print the JSON greeting as an array of greetings when `--times` is greater than 1.** Rejected. D-03 keeps the exact JSON shape `{"greeting": "..."}` with the greeting repeated inside it.
- **ALT-006: Treat an empty `--name` as the default `world`.** Rejected. D-05 makes an empty name a usage error, exit 2.

## 7. Dependencies

- **DEP-001**: Node.js built-ins only: `node:test`, `node:assert`, `node:child_process`, `node:path`, `node:fs`. No package is added to `package.json`.

## 8. Files

New:
- `src/options.js`: defaults, the language table, the argument parser, the merge and the greeting resolution.
- `src/config.js`: the config file reader.
- `test/options.test.js`: unit tests for the parser, the merge and the resolution.
- `test/config.test.js`: tests for the config reader against a temporary directory.
- `test/cli.test.js`: tests that run `bin/greet.js` as a process and check stdout, stderr and the exit code.

Changed:
- `bin/greet.js`: use the parser, the config reader and `render`; handle usage errors with one stderr line and exit 2.
- `test/greet.test.js`: unchanged; its three tests must keep passing.
- `package.json`: unchanged; no dependency is added.

Not part of this feature:
- `scripts/seed-red.sh` writes `test/zz-seeded.test.js`, which asserts that `greet('  Ada  ')` returns `Hello, Ada`. That seeded trimming test contradicts REQ-017 and D-16, which require the name to be used exactly as given, and it is out of scope for this feature. The seeded test is not deleted by this feature and is not a target of it: the implementation must not add trimming to make it pass, and `npm test` is expected to fail on that seeded file while the feature is built.

## 9. Testing

Seams under test: the module seams `parseArgs(argv)`, `readConfig(cwd)`, `mergeSettings(flags, config)` and `resolveGreeting(settings)` from `src/options.js` and `src/config.js`, plus the process seam `bin/greet.js`, run as a child process so stdout, stderr and the exit code are observed. The unit tests assert that `parseArgs` throws the `UsageError` type, not a plain `Error`, so the no-stack-trace rule in REQ-042 has a unit-level guard as well as the process-level one in TEST-023.

The seeded `test/zz-seeded.test.js` from `scripts/seed-red.sh` is not one of these tests and is not a target of this feature (section 8). Its failure while the feature is built is expected.

- **TEST-001 (unit):** `parseArgs` accepts the space form and the equals form of `--name`, `--times`, `--lang` and `--format`, and both forms give the same parsed value.
- **TEST-002 (unit):** `parseArgs` takes the last occurrence of a repeated flag and reports no error.
- **TEST-003 (unit):** `parseArgs` raises the usage error for an unknown flag, a missing value, an empty name, a `--times` value that is not a base-10 integer (`0x2`, `1e1`, `2.5`, `" 3"`), an out-of-range `--times`, an unsupported `--lang` (including the case-variant `ES`), an unsupported `--format` (including the case-variant `JSON`) and a bare positional argument.
- **TEST-004 (unit):** `mergeSettings` takes the flag value for a key the flag covers and the config value for every other key, and falls back to the built-in default for a key neither covers.
- **TEST-005 (unit):** `mergeSettings` falls back to the built-in default for an invalid config value and keeps the other config values. The invalid values are: a config `name` of only whitespace, a config `name` that is not a string (for example `"name": 42` and `"name": true`, which fall back to the default `world`), a config `shout` that is not a boolean (including the strings `"true"` and `"false"`, which fall back to the default `false`), a config `times` that is not a whole number from 1 to 5, a config `lang` or `format` that is not a string, and a config `lang` or `format` whose trimmed, lower-cased string value is not one of the allowed values, such as `"de"` for `lang` or `"xml"` for `format` (REQ-034). In every one of these cases the other config values still apply.
- **TEST-006 (unit):** `resolveGreeting` returns `Hello, <name>` for `en`, `Hola, <name>` for `es` and `Bonjour, <name>` for `fr`, and upper-cases the whole greeting when `shout` is true.
- **TEST-007 (unit):** `readConfig` returns `{}` when the file is missing, returns `{}` for malformed JSON and returns the parsed object for a valid file. A file holding valid JSON that is not a JSON object, such as `[1, 2]`, `"hello"`, `42` or `null`, also returns `{}`, so `mergeSettings` never reads a property of a non-object (REQ-033).
- **TEST-008 (route / CLI):** running `bin/greet.js` with no arguments in a directory holding no `greet.config.json` prints `Hello, world` on stdout, nothing on stderr and exits 0.
- **TEST-009 (route / CLI):** running `bin/greet.js` with `--name Ada --lang es --times 2` prints `Hola, Ada` on two lines on stdout and exits 0.
- **TEST-010 (route / CLI):** running `bin/greet.js` with `--format json --name Ada` prints `{"greeting": "Hello, Ada"}` on one line on stdout and exits 0.
- **TEST-011 (route / CLI):** running `bin/greet.js` with a usage error prints nothing on stdout, exactly one usage line on stderr and exits 2.
- **TEST-012 (route / CLI):** running `bin/greet.js` in a directory holding a `greet.config.json` with `{"name": "Bob"}` prints `Hello, Bob`, and adding `--name Ada` prints `Hello, Ada`.
- **TEST-013 (route / CLI):** running `bin/greet.js` with `--shout --name Ada` prints `HELLO, ADA`, and with `--format json --shout --name Ada` prints `{"greeting": "HELLO, ADA"}`.
- **TEST-014 (route / CLI):** running `bin/greet.js` with a JSON-escaping name (`Ada "The Countess" Lovelace`) prints a line that `JSON.parse` reads back as `{"greeting": "Hello, Ada \"The Countess\" Lovelace"}`.
- **TEST-015 (unit):** `parseArgs` raises the usage error when a flag value is missing because the next argument is another flag (`--name --lang es`), and when the flag is the last argument (`--name`).
- **TEST-016 (unit):** `parseArgs` raises the usage error for `--shout=true` and for a bare `--` argument, and raises the usage error for a single-dash argument used as a flag (`-n`, `-x`).
- **TEST-017 (route / CLI):** running `bin/greet.js` with `--name Ada --format json --times 2` prints `{"greeting": "Hello, Ada\nHello, Ada"}` on one line, and the line parses as JSON.
- **TEST-018 (route / CLI):** running `bin/greet.js` in a directory holding a `greet.config.json` with an invalid `times` value falls back to one repetition, and one holding a config file with an unknown key leaves the run unaffected.
- **TEST-019 (unit):** `mergeSettings` resolves a config `name` of `""` to `world` and a config `name` of `  Ada  ` to `  Ada  `, untrimmed.
- **TEST-020 (route / CLI):** running `bin/greet.js` with a name containing a newline prints the name verbatim in text format, so stdout holds more lines than `--times`.
- **TEST-021 (route / CLI):** after a run, the working directory holds no new or changed files, and a `greet.config.json` in a parent directory is not read.
- **TEST-022 (route / CLI):** running `bin/greet.js` with no arguments in a directory holding no `greet.config.json` prints `Hello, world`, and in a directory holding `{"name": "Bob"}` prints `Hello, Bob`.
- **TEST-023 (route / CLI):** running `bin/greet.js` with a usage error writes exactly one line to stderr, the usage line from `USAGE`, and nothing else: no stack trace, no extra usage text and no partial greeting on stdout or stderr.
- **TEST-024 (route / CLI):** running `bin/greet.js` in a directory holding a config file with a `name` that contains a quote, a backslash or a control character prints that name literally, and the printed line never evaluates it.
- **TEST-025 (route / CLI):** running `bin/greet.js` with a malformed config file prints the built-in default greeting and exits 0, so the run does not crash on the config file.
- **TEST-026 (route / CLI):** running `bin/greet.js` with `--name "  Ada  "` prints `Hello,   Ada  ` on stdout, the name used untrimmed with its surrounding whitespace intact, and exits 0 (REQ-017). The equals form `--name=  Ada  ` prints the same line.
- **TEST-027 (unit):** `parseArgs` reads a `--times` value that matches `^[0-9]+$` as a base-10 integer, so `3` is 3, and raises the usage error for `0x2`, `1e1`, `2.5`, `+3`, `-3` and `" 3"` (REQ-011).
- **TEST-028 (route / CLI):** running `bin/greet.js` with `--name -x` prints `Hello, -x` on stdout and exits 0, so a value starting with a single dash is an ordinary value (REQ-005). Running it with `--name --shout` prints one usage line on stderr and exits 2.
- **TEST-029 (route / CLI):** running `bin/greet.js` in a directory holding a `greet.config.json` with `{"shout": true}` prints the upper-cased greeting, and no command-line flag turns it off (REQ-031).
- **TEST-030 (unit):** `mergeSettings` reads a config `lang` or `format` case-insensitively after trimming, so a config `"lang": "ES"` resolves to `es` and a config `"format": " JSON "` resolves to `json`, while a command-line `--lang ES` stays a usage error (REQ-034, Q-2).
- **TEST-031 (route / CLI):** running `bin/greet.js` in a directory holding a `greet.config.json` whose content is `null` prints `Hello, world` on stdout, writes nothing to stderr and exits 0, so a config file that is not a JSON object never crashes the run (REQ-033, SEC-004).

## 10. Risks & assumptions

- **RISK-001**: The config file lands in the working directory by accident and silently changes every run. Mitigation: the config file is optional and only `greet.config.json` is read (SEC-001); the file name is fixed and documented in §3.
- **RISK-002**: The upper-casing of the name under `--shout` surprises a user whose name is meant to stay as written. Accepted: D-14 fixes one rule for shout, applied to the final greeting.
- **RISK-003**: The upper bound of 5 for `--times` is a design choice, not something the brief names. The brief names an out-of-range `--times` as a usage error but not the range; the range 1 to 5 is now settled (Q-1), and it is stated in one place, REQ-012, and referenced from the parser and the config rule. If the user changes it, REQ-012 and `TIMES_MIN`/`TIMES_MAX` change with it.
- **RISK-004**: A config file that is huge is read into memory in full. Mitigation: the CLI reads one small file once; a read failure falls back to the defaults (SEC-004). No size cap is added, because the file is the user's own and the toy has no other file reading.
- **RISK-005**: A config file with `"shout": true` cannot be turned off from the command line, because a command-line flag overrides only its own key and there is no `--no-shout` flag (REQ-031). Accepted: adding a way to override it would add a flag the brief does not name, and the config file is optional, so the user can remove the key.
- **ASSUMPTION-001**: The user runs the CLI from the directory that holds `greet.config.json` when they want the config to apply (D-07).
- **ASSUMPTION-002**: Node.js 18 or newer is available, so `node --test` and the built-in `node:` modules work. The repo's `package.json` names no `engines` field today.

## 11. Settled questions

These three were open in v0.2 and are settled at the spec gate. The ids stay stable and are cited from the requirements.

- **Q-1 (settled)**: The valid range for `--times` is 1 to 5 inclusive. REQ-012 states it, `TIMES_MIN` (1) and `TIMES_MAX` (5) hold it, and the parser and the config rule both refer back to it.
- **Q-2 (settled)**: The command-line `--lang` and `--format` values stay case-sensitive, so `--lang ES` and `--format JSON` are usage errors. The config file stays case-insensitive and trimmed. The two sources differ on purpose; see REQ-013, REQ-014, TEST-003, TEST-030 and section 3.
- **Q-3 (settled)**: A `--name` value that starts with `--` is a missing value and therefore a usage error with exit code 2. A value that starts with a single `-` is an ordinary value. See REQ-005 and section 4.1.

## 12. Open questions

None. Every question raised at the spec gate is settled.
