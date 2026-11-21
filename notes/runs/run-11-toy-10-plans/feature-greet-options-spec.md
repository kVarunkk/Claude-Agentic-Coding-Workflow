---
goal: Give the `greet` CLI options for name, case, repeat count, language and output format, with defaults loadable from a `greet.config.json` in the working directory.
version: 0.4
date_created: 2026-11-20
last_updated: 2026-11-20
owner: pipeline-toy
status: 'Approved'
tags: [feature, cli, options]
---

# Introduction

![Status: Approved](https://img.shields.io/badge/status-Approved-green)

The `greet` CLI today has one behaviour: it prints `Hello, <name>`, where `<name>` comes from a `--name` flag or defaults to `world`. That is enough for a demo and not enough for a tool. A project cannot set its own greeting style, cannot greet in another language, cannot repeat a greeting, and cannot get machine-readable output.

This feature gives `greet` five options: `--name NAME`, `--shout`, `--times N`, `--lang en|es|fr` and `--format text|json`. Defaults come from a `greet.config.json` file in the working directory, so a project can set its own greeting style once, and any command-line flag overrides only the key it names.

The CLI keeps a strict usage contract. Any usage error prints exactly one usage line to stderr, prints nothing to stdout, and exits with code 2. That way a script can tell a greeting apart from a mistake: stdout is either a greeting or empty.

The brief's success list shows the JSON output as `{"greeting": "Hello, world"}`, with a space after the colon. That is the human-readable rendering of the shape. The pinned output is the compact `JSON.stringify` form `{"greeting":"Hello, world"}`, with no space after the colon (REQ-055), confirmed at the spec gate. The shape and the key are the same in both renderings; only the spacing differs.

The stack stays as it is: Node.js 22, CommonJS, no new dependencies. The existing `greet(name)` export and its `Hello, ${name}` output stay intact, so the current unit test keeps passing.

The implementation is test-driven; see `plans/greet-options/feature-greet-options-tasks.md`.

## 1. Requirements & Constraints

### Functional

Options and defaults:

- **REQ-001**: The CLI accepts exactly five options: `--name NAME`, `--shout`, `--times N`, `--lang en|es|fr` and `--format text|json`. Every other argument is a usage error (REQ-074).
- **REQ-002**: The built-in default for `name` is `world`, for `shout` is `false`, for `times` is `1`, for `lang` is `en` and for `format` is `text`.
- **REQ-003**: The built-in default for `lang` `en` greets with the word `Hello`; `es` greets with `Hola`; `fr` greets with `Bonjour`. The greeting line is the greeting word, a comma, a space, then the name, in that order and with no other characters.
- **REQ-004**: When the `lang` value is `en`, the greeting line for the name `Ada` is exactly `Hello, Ada`.
- **REQ-005**: When the `lang` value is `es`, the greeting line for the name `Ada` is exactly `Hola, Ada`.
- **REQ-006**: When the `lang` value is `fr`, the greeting line for the name `Ada` is exactly `Bonjour, Ada`.

Name:

- **REQ-010**: When `--name NAME` is given, the greeting uses `NAME` in place of the default `world`.
- **REQ-011**: If `--name` is given with an empty value (`--name ""`), then the CLI treats it as a usage error whose reason is `empty value for --name` (REQ-070).
- **REQ-012**: The name is used exactly as given: it is not trimmed, lower-cased, title-cased or otherwise normalised.

Shout:

- **REQ-020**: When `--shout` is given, the whole assembled greeting line is upper-cased, so the name `Ada` in `en` yields `HELLO, ADA`.
- **REQ-021**: When `--shout` is given, the upper-casing applies to the entire line, including the greeting word, the comma and the name, and no other characters are added or removed.

Repeat count:

- **REQ-030**: When `--times N` is given, the CLI prints `N` greeting lines, one per line, in order.
- **REQ-031**: When `--times N` is given with `N` greater than 1, the CLI prints exactly `N` lines separated by `\n`, and the last line ends with a single `\n`. For example `--times 3` with the defaults prints `Hello, world\nHello, world\nHello, world\n`.
- **REQ-032**: When `--times N` is given, `N` must be a plain digit string holding an integer from 1 to 5 inclusive. A value of 0, a value of 6 or more, a negative value, a non-integer value such as `abc`, a fractional value such as `1.5`, a value with leading zeros such as `03` and a value with a leading `+` such as `+2` are usage errors (REQ-070).
- **REQ-033**: When `--times 1` is given, the output is identical to the output with no `--times` flag.

Language:

- **REQ-040**: `--lang` accepts exactly the three values `en`, `es` and `fr`. Any other value, including an empty value, is a usage error (REQ-070).
- **REQ-041**: The language value is matched exactly and is case-sensitive: `ES` and `Fr` are usage errors, `es` and `fr` are valid.

Output format:

- **REQ-050**: When `--format text` is given (the default), the CLI prints the greeting line or lines, each ending with `\n`.
- **REQ-051**: When `--format json` is given, the CLI prints exactly one line, the JSON object `{"greeting":"..."}` followed by `\n`, where `...` is the greeting value for the current options.
- **REQ-052**: When `--format json` is given and `--times` is 1, the JSON value is the single greeting line with no trailing newline inside the string, for example `{"greeting":"Hello, world"}`.
- **REQ-053**: When `--format json` is given and `--times` is greater than 1, the JSON value is the repeated greeting lines joined by `\n` with no trailing newline inside the string, for example `{"greeting":"Hello, world\nHello, world\nHello, world"}`.
- **REQ-054**: When `--format json` is given, the JSON object has exactly one key, `greeting`. No other key is ever added, in any combination of options.
- **REQ-055**: The JSON output is written with `JSON.stringify` on an object with the single key `greeting`, so the printed form is `{"greeting":"Hello, world"}` (no space after the colon) followed by `\n`.
- **REQ-056**: When `--format json` is given, the `greeting` value uses the same name, shout, language and count rules as the text format, so `--format json --shout` prints `{"greeting":"HELLO, ADA"}` for `--name Ada`.

Config file:

The ids below group the config rules. REQ-060 to REQ-069 were the first set; REQ-079 was added later, when the config `name` type needed a rule of its own, and takes the next free number in the spec. REQ-079 owns both the type of the config `name` value (a JSON string) and the non-empty constraint on it, so the empty string is covered by the same id.

- **REQ-060**: The CLI reads `greet.config.json` from the working directory once at startup, before it renders the greeting. If the file does not exist, the CLI uses the built-in defaults (REQ-002).
- **REQ-061**: `greet.config.json` may set `name`, `shout`, `times`, `lang` and `format`. A key that is not one of these five is ignored and does not cause an error.
- **REQ-062**: The values in `greet.config.json` are validated with the same rules as the flags, with three exceptions, because a flag has no value where the config has one. The exceptions are pinned by REQ-067, REQ-068 and REQ-079: the config `shout` value must be a JSON boolean, the config `times` value must be a JSON number that is an integer from 1 to 5, and the config `name` value must be a non-empty JSON string. An invalid value for any of the five known keys is a usage error: one usage line to stderr, nothing to stdout, exit code 2.
- **REQ-063**: A command-line flag overrides the config value for that key only. Every other key keeps its config value, or the built-in default when the config does not set it.
- **REQ-064**: The CLI reads only the working directory. It does not look in parent directories, and it does not look at a home directory or a user config directory.
- **REQ-065**: The config file is read once per process run and is not re-read when a flag overrides one of its keys.
- **REQ-066**: `greet.config.json` is a JSON object. A file whose top-level value is not an object, or which is not valid JSON, is a usage error (REQ-062).
- **REQ-067**: The `shout` key in `greet.config.json` is a JSON boolean. A non-boolean value for `shout` is a usage error (REQ-062).
- **REQ-068**: The `times` key in `greet.config.json` must be a JSON number that is an integer from 1 to 5. A JSON string such as `"3"`, a fractional number such as `2.5`, a number outside 1 to 5, and any other non-number type are usage errors (REQ-062).
- **REQ-069**: The whole config file is validated before the merge, whether or not a flag overrides the offending key. An invalid value for a config key is a usage error even when a command-line flag supplies a valid value for that same key (REQ-062).
- **REQ-079**: The `name` key in `greet.config.json` is a JSON string that is not empty. A non-string value for `name`, such as the JSON number `123` or the JSON boolean `true`, and the empty string `""`, are usage errors (REQ-062). The empty string is a usage error for the same reason as the empty flag value `--name ""` (REQ-011): an empty name has no sensible greeting. The usage line for the empty config value uses the reason `empty value for name`.

Usage errors:

- **REQ-070**: On any usage error the CLI writes exactly one line to stderr, writes nothing to stdout, and exits with code 2.
- **REQ-071**: The usage line starts with the fixed prefix `usage: greet [options]` and is followed by a space and a short reason, for example `usage: greet [options] unknown flag: --nmae`.
- **REQ-072**: The usage line ends with a single `\n`. Exactly one line is written, so stderr never holds more than one line.
- **REQ-073**: A successful run exits with code 0 and writes nothing to stderr.
- **REQ-074**: The following are all usage errors: an unknown flag such as `--nmae`, `--help` or `--version`, a stray positional argument such as `greet Ada`, a flag given without its value such as `greet --name` or `greet --times`, a flag whose value starts with `-` such as `greet --name -x`, a value for an unknown flag, an unsupported `--lang` value, an unsupported `--format` value, an empty `--name` value, and a `--times` value outside 1 to 5 or that is not an integer.
- **REQ-075**: When the same flag is given more than once, the last occurrence wins. `--name Ada --name Bob` greets `Bob`.
- **REQ-076**: When `--shout` is given more than once, it stays `true`. There is no `--no-shout` flag and no way to turn `--shout` off from the command line. A `shout: true` in `greet.config.json` cannot be turned off by a command-line flag either: a flag may only set `shout` to `true`, never to `false` (REQ-063).
- **REQ-077**: A flag given in `--flag=value` form is a usage error whose reason is `invalid flag syntax: <argument>`, for example `invalid flag syntax: --name=Ada`. Only the space-separated form is accepted.
- **REQ-078**: The `--` end-of-options marker is not supported. `greet --` is a usage error whose reason is `invalid argument: --`.

### Preserved & superseded behaviour

- Preserved: the `greet(name)` export from `src/greet.js` keeps its signature and returns exactly `Hello, ${name}` for a single call (REQ-004). The existing test `greet formats the name` keeps passing unchanged.
- Preserved: `greet` with no arguments prints exactly `Hello, world` on stdout and exits 0 (REQ-002, REQ-073), as long as the working directory holds no `greet.config.json`. The existing test `cli defaults to world` keeps passing unchanged.
- Preserved: `greet --name Ada` prints exactly `Hello, Ada` on stdout and exits 0 (REQ-010). The existing test `cli takes --name` keeps passing unchanged.
- Superseded: the ad-hoc `--name` lookup in `bin/greet.js` (find the index of `--name` and take the next argument, otherwise `world`) → removed, replaced by REQ-001 and the option parser in §4.1. The old lookup silently accepted `--name` with no value and fell back to `world`; the new parser makes both a usage error.
- Superseded: the CLI printing every greeting as plain text → replaced by REQ-050 and REQ-051, which add the `--format` option. With no flags and no config file the output is byte-for-byte what it is today.

### Security

- **SEC-001**: The CLI reads no secrets, opens no network connection and writes no file. `greet.config.json` is the only file it reads (REQ-060), and it is read from the working directory only (REQ-064).
- **SEC-002**: The name, the language, the format and the count come from untrusted input (command-line arguments and a JSON file in the working directory). They are used only to pick a greeting word and to build the output string; they are never passed to a shell, never used as a file path, and never evaluated as code.
- **SEC-003**: The name is inserted into the greeting line verbatim (REQ-012). It is not shell-escaped, because the output is written to stdout with `process.stdout.write`, not to a shell. A name containing shell metacharacters, quotes or newlines is echoed as given and changes nothing about how the process runs.
- **SEC-004**: The config file is read with `fs.readFileSync` and parsed with `JSON.parse`. A parse failure is reported as a usage error (REQ-066), so the file contents never appear in the error output. The usage line names the offending key or value, never the file contents.
- **SEC-005**: A usage error writes nothing to stdout (REQ-070), so a malformed config or a bad flag cannot inject partial output into a consuming script.
- **SEC-006**: The CLI reads at most one config file of a fixed name in the working directory. It does not glob or walk directories (REQ-064), so a config file in a parent directory is never found.

### Constraints & guidelines

- **CON-001**: The stack stays Node.js 22, CommonJS (`require` / `module.exports`), no new dependencies. Only the Node standard library is used.
- **CON-002**: The test command stays `npm test`, which runs `node --test`. Tests use `node:test` and `node:assert` as they do today.
- **CON-003**: The `greet(name)` export and its `Hello, ${name}` output stay intact. The feature is added alongside it, not through it.
- **CON-004**: The public CLI surface is the five options in REQ-001. No sixth option, no environment variable, no `--help` and no `--version` flag is added by this feature.
- **CON-005**: The working directory is the process working directory, `process.cwd()`. The CLI never takes a path to a config file.
- **CON-006**: The CLI is invoked as `node bin/greet.js ...` in tests and as `greet ...` when installed through the `bin` entry in `package.json`. Both forms take the same arguments.
- **GUD-001**: All logic lives in `src/greet.js` as plain exported functions, matching the existing one-file layout. No classes, no new dependencies, no new directories under `src/`. The config fixtures live in `test/fixtures/`, which is not part of the shipped package (§8).
- **GUD-002**: The option parser, the config loader, the option merger and the renderer are separate pure functions, so each can be unit tested without spawning a process.
- **GUD-003**: Greeting words live in one constant map in `src/greet.js`, keyed by language code. Adding a language later means adding one map entry.
- **GUD-004**: The usage line is built by one helper that takes the reason string, so every error path produces the same prefix and the same newline handling.
- **GUD-005**: Error messages are short and lowercase, in the form `unknown flag: --nmae`. They name the offending value, never a stack trace and never file contents.
- **PAT-001**: Functions that need the outside world take it as an argument: the config loader takes the working directory path, so a test can point it at a fixture directory instead of the real one. Checked by code review.

## 2. Architecture

```
process.argv.slice(2)
        |
        v
[1] parseOptions(args)          parse the command line, strict, last-wins
        |                        -> { name?, shout?, times?, lang?, format? }  or throws UsageError
        |
        v
[2] loadConfig(cwd)             read <cwd>/greet.config.json once, if it exists
        |                        -> { name?, shout?, times?, lang?, format? }  or throws UsageError
        |
        v
[3] mergeOptions(config, flags) config first, then flags overwrite their own key only
        |                        -> { name, shout, times, lang, format }
        |
        v
[4] buildGreeting(opts)         "Hello, Ada" style line, upper-cased when shout
        |                        -> { line, count }
        |
        v
[5] renderOutput(opts, greeting) text: N lines + "\n"  |  json: {"greeting":"..."} + "\n"
        |
        v
stdout.write(...), exit 0

any UsageError anywhere in [1]..[3]
        |
        v
stderr.write("usage: greet [options] <reason>\n"), exit 2, stdout untouched
```

Order matters: flags are parsed first, then the config is read, then the two are merged (REQ-060, REQ-063). Parsing and config loading never see each other's values, so each layer can be tested on its own.

## 3. Data model

There is no database. The feature has two data shapes: the option record and the config file.

### Option record

The resolved options after merging config and flags (REQ-002, REQ-063):

```js
{
  name:   'world',  // string, non-empty
  shout:  false,    // boolean
  times:  1,        // integer, 1 to 5
  lang:   'en',     // 'en' | 'es' | 'fr'
  format: 'text'    // 'text' | 'json'
}
```

### `greet.config.json`

A JSON object in the working directory (REQ-060, REQ-061, REQ-066, REQ-067, REQ-068, REQ-079). Every key is optional; unknown keys are ignored (REQ-061).

```json
{
  "name": "Ada",
  "shout": true,
  "times": 2,
  "lang": "es",
  "format": "json"
}
```

| Key | Type | Allowed values | Invalid value |
|---|---|---|---|
| `name` | string | any non-empty string; the empty string `""` is a usage error | usage error (REQ-062, REQ-079) |
| `shout` | boolean | `true`, `false` | usage error (REQ-062, REQ-067) |
| `times` | JSON number | an integer from 1 to 5 | usage error (REQ-062, REQ-032, REQ-068) |
| `lang` | string | `en`, `es`, `fr` | usage error (REQ-062, REQ-040) |
| `format` | string | `text`, `json` | usage error (REQ-062, REQ-050) |

Notes:
- The config file has the same lifecycle as the process: it is read once at startup and never written (REQ-065).
- The config file is never generated by the CLI and is not added to `.gitignore`; whether a project commits one is the project's choice.
- A `greet.config.json` in a parent directory is invisible to the CLI (REQ-064).

## 4. Components

### 4.1 `src/greet.js`: option parsing, config loading, merging and rendering

All new logic lives in `src/greet.js` as plain exported functions (GUD-001). The file keeps its existing `greet(name)` export unchanged (CON-003).

Exports:

```js
const {
  greet,             // unchanged: greet(name) -> `Hello, ${name}`
  DEFAULT_OPTIONS,   // the built-in defaults (REQ-002)
  GREETING_WORDS,    // { en: 'Hello', es: 'Hola', fr: 'Bonjour' } (REQ-003)
  UsageError,        // Error subclass carrying a reason string
  parseOptions,      // parseOptions(args) -> partial options
  loadConfig,        // loadConfig(cwd) -> partial options
  mergeOptions,      // mergeOptions(config, flags) -> full options
  buildGreeting,     // buildGreeting(options) -> { line, count }
  renderOutput,      // renderOutput(options, greeting) -> string
  formatUsage,       // formatUsage(reason) -> the usage line
} = require('../src/greet');
```

**`parseOptions(args)`** parses `process.argv.slice(2)`.

- Returns an object holding only the keys the user gave. A key the user did not give is absent, not `undefined` with a default.
- Recognises exactly `--name`, `--shout`, `--times`, `--lang`, `--format` (REQ-001).
- `--name`, `--times`, `--lang` and `--format` take the next argument as their value. If the next argument is missing, the result is a usage error (REQ-074).
- `--shout` takes no value. A following argument is not consumed by it.
- A value that starts with `-` is never consumed as a value: `--name --shout` is a usage error for a missing `--name` value, not a name of `--shout`, and `--name -x` is the same missing-value error (REQ-074).
- An argument that is not a recognised flag and not consumed as a value is a usage error (REQ-074, D-07).
- `--flag=value` is a usage error whose reason is `invalid flag syntax: <argument>`, for example `invalid flag syntax: --name=Ada` (REQ-077). The `--` marker is a usage error whose reason is `invalid argument: --` (REQ-078).
- The last occurrence of a flag wins (REQ-075, D-08). `--shout` set twice is still `true` (REQ-076).
- Validates as it parses: `--times` must be a plain digit string holding an integer from 1 to 5, so `03` and `+2` are usage errors (REQ-032), `--lang` must be one of `en`, `es`, `fr` (REQ-040, REQ-041), `--format` must be `text` or `json`, `--name` must be a non-empty string (REQ-011).
- Throws a `UsageError` with a short reason on any problem. It never returns a partially parsed object.

**`loadConfig(cwd)`** reads `<cwd>/greet.config.json`.

- If the file does not exist, returns `{}` (REQ-060, D-06).
- Reads it once with `fs.readFileSync` and parses it with `JSON.parse` (SEC-004, REQ-065).
- A JSON parse failure, or a file that cannot be read, throws a `UsageError` whose reason is `invalid greet.config.json` (REQ-066).
- A top-level value that is not a plain object throws a `UsageError` whose reason is `invalid greet.config.json` (REQ-066). An array, a JSON string, a JSON number, a JSON boolean and `null` are not objects. The check must reject `null` explicitly, because `typeof null === 'object'` in JavaScript and `Array.isArray(null) === false`, so a plain `typeof` or `Array.isArray` test alone lets `null` through and the next access throws a `TypeError` instead of a usage error.
- Reads only the five known keys and ignores every other key (REQ-061, D-15). Ignored keys are not validated.
- Validates each known key with the rules in §3 (REQ-062). An invalid value throws a `UsageError` whose reason names the key and the offending value, for example `invalid value for lang: de`. The one reason that does not follow this shape is the empty `name`, which uses `empty value for name` (REQ-079).
- The `name` value must be a JSON string that is not empty (REQ-079). A JSON number such as `123`, a JSON boolean and the empty string `""` are usage errors. The empty string uses the reason `empty value for name`, matching the flag reason `empty value for --name` (REQ-011) with the config key's own name.
- The `times` value must be a JSON number that is an integer from 1 to 5 (REQ-068). A JSON string such as `"3"` and a fractional number such as `2.5` are usage errors.
- Validates every known key in the file before the merge, whether or not a flag later overrides that key (REQ-069). An invalid config value is a usage error even when a flag supplies a valid value for the same key.
- Returns an object holding only the keys the file set.

**`mergeOptions(config, flags)`** combines the two.

- Starts from `DEFAULT_OPTIONS` (REQ-002).
- Applies the config values, then the flag values, so a flag overwrites only its own key (REQ-063, D-05).
- Returns a full option record with all five keys set.

**`buildGreeting(options)`** builds the greeting line.

- Picks the greeting word from `GREETING_WORDS[options.lang]` (REQ-003).
- Joins the word, `', '` and the name into one line (REQ-003, REQ-004, REQ-005, REQ-006).
- When `options.shout` is true, upper-cases the fully assembled line, so the word, the comma and the name are all upper-cased (REQ-020, REQ-021, D-01).
- Returns `{ line, count }` where `count` is `options.times` (REQ-030).

**`renderOutput(options, greeting)`** renders the final output. `greeting` is the object `buildGreeting` returned, holding `line` and `count`.

- For `format: 'text'`, returns the greeting line repeated `greeting.count` times, each followed by `\n` (REQ-050, REQ-031).
- For `format: 'json'`, returns `JSON.stringify({ greeting: value }) + '\n'`, where `value` is the single line when `greeting.count` is 1 and the lines joined by `\n` when `greeting.count` is greater than 1 (REQ-051, REQ-052, REQ-053, REQ-055).
- The JSON object always has exactly the one key `greeting` (REQ-054).

**`formatUsage(reason)`** returns the usage line.

- Returns `` `usage: greet [options] ${reason}` `` (REQ-071, D-10).
- The line ends with a single `\n` and is the only thing written to stderr (REQ-072, REQ-070).

### 4.2 `bin/greet.js`: the entry point

`bin/greet.js` is a thin shell around the functions above. It keeps its shebang and its `require('../src/greet')`.

```js
#!/usr/bin/env node
const {
  parseOptions, loadConfig, mergeOptions, buildGreeting, renderOutput, formatUsage, UsageError,
} = require('../src/greet');

try {
  const flags = parseOptions(process.argv.slice(2));
  const config = loadConfig(process.cwd());
  const options = mergeOptions(config, flags);
  const greeting = buildGreeting(options);
  process.stdout.write(renderOutput(options, greeting));
  process.exitCode = 0;
} catch (err) {
  if (err instanceof UsageError) {
    process.stderr.write(formatUsage(err.reason));
    process.exitCode = 2;
  } else {
    throw err;
  }
}
```

Behaviour:

- On success, stdout gets the rendered output and nothing is written to stderr; the exit code is 0 (REQ-073).
- On a usage error, stderr gets exactly one usage line, stdout gets nothing, and the exit code is 2 (REQ-070).
- An error that is not a `UsageError` is re-thrown, so an unexpected failure shows a stack trace and exits non-zero. It is not turned into a usage line.
- The process ends by falling off the end of the script, not by calling `process.exit`. `process.stdout` is asynchronous when it is a pipe or a socket, so `process.exit` right after a `write` can truncate the output; setting `process.exitCode` lets Node flush the stream before the process ends. The same applies to the stderr write on the usage-error path.

### 4.3 Usage-error contract

| Situation | stdout | stderr | exit |
|---|---|---|---|
| Unknown flag (`--nmae`) | empty | `usage: greet [options] unknown flag: --nmae\n` | 2 |
| Unknown flag (`--help`) | empty | `usage: greet [options] unknown flag: --help\n` | 2 |
| Unknown flag (`--version`) | empty | `usage: greet [options] unknown flag: --version\n` | 2 |
| Stray positional (`greet Ada`) | empty | `usage: greet [options] unexpected argument: Ada\n` | 2 |
| Missing value (`greet --name`) | empty | `usage: greet [options] missing value for --name\n` | 2 |
| Value that starts with `-` (`greet --name -x`) | empty | `usage: greet [options] missing value for --name\n` | 2 |
| `--flag=value` syntax (`greet --name=Ada`) | empty | `usage: greet [options] invalid flag syntax: --name=Ada\n` | 2 |
| End-of-options marker (`greet --`) | empty | `usage: greet [options] invalid argument: --\n` | 2 |
| Bad `--times` (`--times 0`) | empty | `usage: greet [options] invalid value for --times: 0\n` | 2 |
| Bad `--times` (`--times abc`) | empty | `usage: greet [options] invalid value for --times: abc\n` | 2 |
| Bad `--times` (`--times 03`) | empty | `usage: greet [options] invalid value for --times: 03\n` | 2 |
| Bad `--times` (`--times +2`) | empty | `usage: greet [options] invalid value for --times: +2\n` | 2 |
| Bad `--lang` (`--lang de`) | empty | `usage: greet [options] invalid value for --lang: de\n` | 2 |
| Bad `--format` (`--format xml`) | empty | `usage: greet [options] invalid value for --format: xml\n` | 2 |
| Empty `--name` (`--name ""`) | empty | `usage: greet [options] empty value for --name\n` | 2 |
| Bad config value (`{"lang": "de"}`) | empty | `usage: greet [options] invalid value for lang: de\n` | 2 |
| Empty config name (`{"name": ""}`) | empty | `usage: greet [options] empty value for name\n` | 2 |
| Wrong config name type (`{"name": 123}`) | empty | `usage: greet [options] invalid value for name: 123\n` | 2 |
| Config top level is not an object (`[1,2]`, `"x"`, `null`, `3`, `true`) | empty | `usage: greet [options] invalid greet.config.json\n` | 2 |
| Unreadable or malformed config | empty | `usage: greet [options] invalid greet.config.json\n` | 2 |
| Success | the greeting | empty | 0 |

The reason text after the prefix is the exact string in the table. The prefix and the reason are fixed strings in the code, not built from user data beyond the offending value itself. A flag reason names the flag with its `--` prefix (`invalid value for --lang: de`); a config reason names the config key without it (`invalid value for lang: de`), because the config has no flags. The empty-name reason follows the same rule on both sides: the flag form is `empty value for --name` and the config form is `empty value for name`.

The rows follow from the parsing rules in §4.1: an unknown flag yields `unknown flag:` with the offending flag; a flag that wants a value and finds none, or finds an argument that starts with `-`, yields `missing value for <flag>`; the `--flag=value` form yields `invalid flag syntax:` with the whole argument; the `--` marker yields `invalid argument: --`; a value that is not in the allowed set yields `invalid value for <flag>: <value>` with the offending value; an empty `--name` yields `empty value for --name`, and an empty config `name` yields `empty value for name`.

### 4.4 No API contracts

The CLI is the only public surface. There is no HTTP route, no server and no library API beyond the `src/greet.js` exports in §4.1.

## 5. Approach summary

The central idea is a two-layer option pipeline. Layer one is the command line, parsed strictly into a partial option record. Layer two is `greet.config.json`, read from the working directory into another partial option record. The two are merged with the flags on top, so a flag overrides only its own key. The merged record is then rendered into one greeting line, optionally upper-cased, repeated, and printed as text or JSON.

Every failure along the way is a `UsageError` carrying a short reason. The entry point catches it, writes one usage line to stderr, and exits 2. Nothing else in the CLI can write to stdout before the render step, so stdout is either a greeting or empty.

## 6. Alternatives

- **ALT-001: Upper-case only the greeting word (`HELLO, Ada`).** Rejected. The brief records "the whole greeting is upper-cased" (D-01), and "upper-case output" reads as the whole output. The spec upper-cases the assembled line (REQ-020).
- **ALT-002: A JSON array for repeated greetings (`{"greetings": [...]}`).** Rejected. It would introduce a second JSON shape alongside `{"greeting": "..."}` (D-03). The spec keeps one shape and joins the lines with `\n` (REQ-053).
- **ALT-003: A separate `greetings` key only when `--times` is greater than 1.** Rejected. It makes the JSON shape depend on the options, which is harder to consume (D-03). The spec always emits the single `greeting` key (REQ-054).
- **ALT-004: Walking up parent directories to find `greet.config.json`.** Rejected. The brief names the working directory (D-05), and a parent search would surprise a user who expects the file to be picked up only where they run the command (REQ-064).
- **ALT-005: Clamping an out-of-range `--times` to the nearest valid value.** Rejected. The brief names out-of-range `--times` as a usage error (D-11). The spec exits 2 (REQ-032).
- **ALT-006: An external argument parser such as `yargs` or `commander`.** Not chosen for v1. The brief constrains the stack to no new dependencies, and the surface is five options, which is small enough for a strict hand-written parser (CON-001). Revisit if the option count grows past roughly ten.
- **ALT-007: A `greet.config.js` file that exports an object.** Not chosen for v1. The brief names `greet.config.json` specifically, and JSON keeps the file declarative and safe to read without executing code (REQ-060, SEC-004).
- **ALT-008: A `--help` flag that prints the usage line to stdout and exits 0.** Deferred, not in scope. The brief's option list is exactly five options and does not mention `--help` (CON-004). The spec gate confirmed that `--help` and `--version` stay usage errors with exit code 2 in this feature (REQ-074).
- **ALT-009: Normalising the name (trimming whitespace, collapsing spaces).** Not chosen. The brief does not ask for it, and the existing `greet(name)` uses the name verbatim (REQ-012, CON-003).
- **ALT-010: A `--no-shout` flag to turn shouting off from the command line.** Not chosen. The brief lists `--shout` as a boolean flag and nothing else, and the brief records that there is no way to turn it off from the command line (REQ-076). The spec gate confirmed that a `shout: true` from `greet.config.json` also stays on: no command-line flag can turn it off (REQ-076).

## 7. Dependencies

- **DEP-001**: Node.js 22 or newer. `node --test` runs the suite (`npm test`).
- **DEP-002**: Node standard library only: `node:fs` (`readFileSync`, `existsSync`), `node:path` (`join`) and `node:process`. No new package is added to `package.json`.
- **DEP-003 (external)**: None. The CLI makes no network calls and needs no API key, service or environment variable.

## 8. Files

New:
- None. The feature adds no file to the shipped package.

Changed:
- `src/greet.js`: keeps `greet(name)` unchanged (CON-003) and adds `DEFAULT_OPTIONS`, `GREETING_WORDS`, `UsageError`, `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput` and `formatUsage` (§4.1).
- `bin/greet.js`: replaces the ad-hoc `--name` lookup with the parse, load, merge, build and render pipeline, and the usage-error exit path (§4.2).
- `test/greet.test.js`: keeps the three existing tests unchanged and adds tests for the new options, the usage-error contract and the config file (§9).
- `test/fixtures/`: new directory holding the config fixtures used by the config tests, one directory per case. Fixtures are committed, not generated at run time, so the tests do not depend on the order they run in. The directories needed are: one with no `greet.config.json` (TEST-005), one with `{}` (TEST-005), one with `{"name": "Ada", "unknownKey": 1}` (TEST-005), one with invalid JSON (TEST-006), one whose top level is a JSON array (TEST-006), one whose top level is `null` (TEST-006), one with an invalid `lang` (TEST-006, TEST-017), one with an invalid `shout` (TEST-006), one with `{"name": 123}` (TEST-006), one with `{"name": ""}` (TEST-006, TEST-024), one with `{"times": 0}` (TEST-006), one with `{"times": "3"}` (TEST-006), one with `{"times": 2.5}` (TEST-006), one with `{"times": 6}` (TEST-017), one with `{"name": "Ada", "lang": "es"}` (TEST-016), and one nested inside a directory that holds a `greet.config.json`, so the parent is present and the child is not (TEST-020).

Every fixture directory holds at least one file, so that it can be committed. The directory with no `greet.config.json` holds a `.gitkeep` file and nothing else, and every other directory holds its `greet.config.json`. Git does not track empty directories, so an empty fixture directory would be lost on a fresh clone and the test that needs it would fail.

`package.json` is not changed: no new dependency, no new script, and the `bin` entry stays `bin/greet.js`.

## 9. Testing

Seams under test:

1. **Process seam** (primary). The CLI is driven as a child process: `execFileSync(process.execPath, [bin, ...args], { encoding: 'utf8' })` for the default working directory and `execFileSync(process.execPath, [bin, ...args], { cwd, encoding: 'utf8' })` for a fixture directory. This is the seam that proves the stdout, stderr and exit-code contract, and the one the existing tests already use. `execFileSync` raises an error when the child exits with a non-zero status, so the helper catches that error and asserts on `err.status === 2`, `err.stdout === ''` and the exact `err.stderr` string for the usage-error cases.
2. **Unit seam** (secondary). The exported functions in `src/greet.js` (§4.1) are called directly: `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting`, `renderOutput`, `formatUsage`. This proves the parse, validation, merge and render rules without spawning a process.

Nothing is mocked. The only boundary the tests cross is the filesystem, and they cross it for real: the config tests point `cwd` at a committed fixture directory under `test/fixtures/`.

The test helper keeps its current signature. `test/greet.test.js` defines it today as:

```js
const run = (...args) => execFileSync(process.execPath, [bin, ...args], { encoding: 'utf8' });
```

`run` stays exactly as it is, so the three existing tests need no change (TEST-018). The config tests use a second helper, added next to it:

```js
const runIn = (cwd, ...args) => execFileSync(process.execPath, [bin, ...args], { cwd, encoding: 'utf8' });
```

`runIn` takes the working directory first and the CLI arguments after it, and passes `cwd` to `execFileSync` as the child's working directory. Both helpers return the child's stdout as a string and raise when the child exits with a non-zero status, so the usage-error tests catch that error and assert on `err.status === 2`, `err.stdout === ''` and the exact `err.stderr` string.

- **TEST-001 (unit):** `parseOptions([])` returns `{}` and `parseOptions(['--shout'])` returns `{ shout: true }`, proving a key the user did not give is absent (REQ-001, REQ-002).
- **TEST-002 (unit):** `parseOptions(['--name', 'Ada', '--times', '3', '--lang', 'es', '--format', 'json', '--shout'])` returns all five keys with those values, proving every option is recognised (REQ-001).
- **TEST-003 (unit):** `parseOptions(['--name', 'Ada', '--name', 'Bob'])` returns `{ name: 'Bob' }` and `parseOptions(['--shout', '--shout'])` returns `{ shout: true }`, proving last-wins and that a repeated boolean stays `true` (REQ-075, REQ-076).
- **TEST-004 (unit):** `parseOptions` throws a `UsageError` for `--nmae`, for `--help`, for the positional `Ada`, for `--name` with no value, for `--name` with a value that starts with `-`, for `--name` with an empty value, for `--name=Ada`, for `--`, for `--times 0`, for `--times 6`, for `--times abc`, for `--times 1.5`, for `--times 03`, for `--times +2`, for `--lang de`, for `--lang ES` and for `--format xml`, proving each strict rule (REQ-011, REQ-032, REQ-040, REQ-041, REQ-074, REQ-077, REQ-078).
- **TEST-005 (unit):** `loadConfig` on a fixture directory with no `greet.config.json` returns `{}`, `loadConfig` on a fixture with `{}` returns `{}`, and `loadConfig` on a fixture with `{"name": "Ada", "unknownKey": 1}` returns `{ name: 'Ada' }`, proving absent file, empty file and ignored keys (REQ-060, REQ-061, RISK-005).
- **TEST-006 (unit):** `loadConfig` throws a `UsageError` on a fixture with invalid JSON, on a fixture whose top level is an array, on a fixture whose top level is `null`, on a fixture with `{"lang": "de"}` or `{"shout": "yes"}` or `{"name": 123}` or `{"name": ""}` or `{"times": 0}` or `{"times": "3"}` or `{"times": 2.5}`, proving config validation (REQ-062, REQ-066, REQ-067, REQ-068, REQ-079).
- **TEST-007 (unit):** `mergeOptions({ name: 'Config', lang: 'es' }, { name: 'Flag' })` returns `name: 'Flag'`, `lang: 'es'` and the built-in defaults for the keys neither layer set, proving a flag overrides only its own key (REQ-002, REQ-063).
- **TEST-008 (unit):** `buildGreeting` returns `Hello, Ada` for `lang: 'en'`, `Hola, Ada` for `es` and `Bonjour, Ada` for `fr`, and `HELLO, ADA` when `shout` is true, proving the greeting words and the whole-line upper-casing (REQ-003, REQ-004, REQ-005, REQ-006, REQ-020, REQ-021).
- **TEST-009 (unit):** `renderOutput` returns `Hello, world\n` for the text format, `Hello, world\nHello, world\n` for `times: 2`, and `{"greeting":"Hello, world"}\n` for the json format, and `{"greeting":"Hello, world\nHello, world"}\n` for `times: 2` in json, proving the two formats and the joined JSON value (REQ-031, REQ-050, REQ-051, REQ-052, REQ-053, REQ-055).
- **TEST-010 (route, the CLI):** `greet` with no arguments prints `Hello, world\n` on stdout, nothing on stderr, and exits 0 (REQ-002, REQ-073).
- **TEST-011 (route, the CLI):** `greet --name Ada --shout` prints `HELLO, ADA\n`, proving the flags reach the output (REQ-010, REQ-020).
- **TEST-012 (route, the CLI):** `greet --lang es` prints `Hola, world\n` and `greet --lang fr` prints `Bonjour, world\n`, proving the language option (REQ-005, REQ-006).
- **TEST-013 (route, the CLI):** `greet --format json` prints exactly `{"greeting":"Hello, world"}\n` and `greet --name Ada --format json --shout` prints exactly `{"greeting":"HELLO, ADA"}\n`, proving the JSON shape, that stdout holds one line only, and that the JSON value follows the same name and shout rules as the text format (REQ-051, REQ-054, REQ-055, REQ-056).
- **TEST-014 (route, the CLI):** `greet --times 3` prints exactly three greeting lines, `greet --times 3 --format json` prints one line whose `greeting` value holds the three lines joined by `\n`, and `greet --times 1` prints the same bytes as `greet` with no arguments, proving the repeat count in both formats (REQ-030, REQ-031, REQ-033, REQ-053).
- **TEST-015 (route, the CLI):** `greet --times 0`, `greet --lang de`, `greet --nmae x`, `greet --help`, `greet --name` and `greet --name ""` each print nothing on stdout, exactly one line on stderr starting with `usage: greet [options]`, and exit with code 2, proving the usage-error contract end to end (REQ-070, REQ-071, REQ-072, REQ-074, SEC-005).
- **TEST-016 (route, the CLI):** with `cwd` set to a fixture directory holding a `greet.config.json` with `{"name": "Ada", "lang": "es"}`, `greet` prints `Hola, Ada\n`, and `greet --name Bob` in the same directory prints `Hola, Bob\n`, proving the config is used and a flag overrides only its own key (REQ-060, REQ-063, REQ-065).
- **TEST-017 (route, the CLI):** with `cwd` set to a fixture directory holding a `greet.config.json` with an invalid value, `greet` prints nothing on stdout, one usage line on stderr and exits 2, proving a broken config fails loudly (REQ-062, REQ-070).
- **TEST-018 (route, the CLI):** the three existing tests, `greet formats the name`, `cli defaults to world` and `cli takes --name`, keep passing unchanged, proving nothing that worked before broke (CON-003).
- **TEST-019 (route, the CLI):** `greet --name "Ada Lovelace"` prints `Hello, Ada Lovelace\n` and `greet --name "  Ada  "` prints `Hello,   Ada  \n`, proving the name is used exactly as given and is not trimmed or normalised (REQ-012, SEC-003).
- **TEST-020 (route, the CLI):** with `cwd` set to a fixture directory that has no `greet.config.json` but whose parent directory has one, `greet` prints `Hello, world\n`, proving the config is not looked up in parent directories (REQ-064, SEC-006).
- **TEST-021 (route, the CLI):** `greet --name "Bob; rm -rf /"` prints `Hello, Bob; rm -rf /\n` and exits 0, proving the name is echoed as given and is never passed to a shell (SEC-002).
- **TEST-022 (route, the CLI):** with `cwd` set to a fixture directory holding a `greet.config.json` with `{"times": 6}`, `greet --times 2` prints nothing on stdout, one usage line on stderr and exits 2, proving the config is validated in full even when a flag overrides the offending key (REQ-069, REQ-070).
- **TEST-023 (route, the CLI):** the stderr line is exactly `usage: greet [options] invalid flag syntax: --name=Ada\n` for `greet --name=Ada`, exactly `usage: greet [options] invalid argument: --\n` for `greet --`, exactly `usage: greet [options] empty value for --name\n` for `greet --name ""`, exactly `usage: greet [options] missing value for --name\n` for `greet --name -x`, exactly `usage: greet [options] invalid value for --times: 03\n` for `greet --times 03` and exactly `usage: greet [options] invalid greet.config.json\n` for a config file whose top level is not an object, proving the pinned reason strings of §4.3 (REQ-011, REQ-032, REQ-066, REQ-074, REQ-077, REQ-078).
- **TEST-024 (route, the CLI):** with `cwd` set to a fixture directory holding a `greet.config.json` with `{"name": ""}`, `greet` prints nothing on stdout, exactly one line on stderr reading `usage: greet [options] empty value for name\n`, and exits with code 2, proving the config `name` is not allowed to be empty and that the reason string matches the one pinned in §4.3 (REQ-070, REQ-079).

Layers covered: unit (TEST-001 to TEST-009), route/process (TEST-010 to TEST-024). No DB layer and no eval layer apply to this feature.

## 10. Risks & assumptions

- **RISK-001**: The strict parser turns previously tolerated input into a usage error. The old `bin/greet.js` silently ignored an unknown flag and fell back to `world` for a missing `--name` value. Mitigation: the change is documented in §1 "Preserved & superseded behaviour", and the three existing tests still pass (TEST-018).
- **RISK-002**: A `greet.config.json` in the repository root would change the behaviour of every test that runs with the repo root as its working directory. Mitigation: the config tests point `cwd` at a fixture directory, and the repo root has no `greet.config.json`. The file is never created by the tests.
- **RISK-003**: The JSON output is written with `JSON.stringify`, so it has no space after the colon. A reader who expects `{"greeting": "..."}` with a space would see a different byte sequence. The brief's success list shows the spaced form, which is the human-readable rendering of the same shape; the spec gate confirmed the compact form (§1). Mitigation: REQ-055 pins the exact form and TEST-013 asserts it. The shape and the key are what a consumer parses, and both are pinned.
- **RISK-004**: A hand-written parser can drift from the option list as it grows. Mitigation: the option list lives in one place in `src/greet.js` (GUD-001), and TEST-002 checks all five options in one call.
- **RISK-005**: A config file that is present but empty (`{}`) is valid and behaves like no config file. Mitigation: TEST-005 covers a fixture with an empty object, so the case is pinned rather than left to chance.
- **ASSUMPTION-001**: Node.js 22 is the runtime (DEP-001). The current `package.json` sets no `engines` field, so the spec relies on the brief's constraint rather than on a package field.
- **ASSUMPTION-002**: `process.cwd()` is the working directory the user means when they run `greet` (CON-005). A user who runs the CLI from another directory gets that directory's config, not the project's.
- **ASSUMPTION-003**: The name is plain text. A name that is not valid UTF-16, or that contains control characters, is echoed as given (REQ-012, SEC-003). The spec does not restrict the name's characters beyond "non-empty".
- **ASSUMPTION-004**: `times` is capped at 5 because the brief says so. The cap is a product rule, not a technical limit; raising it is a one-line change to the validation in `parseOptions`.

## 11. Answers from the spec gate

The seven questions below were put to the user at the spec gate and answered. The answers are binding and are already applied throughout this spec, so no question is left open.

- **Q-1**: Answered at the spec gate: `--times` accepts only a plain digit string. `--times 03` and `--times +2` are usage errors. Applied in REQ-032, §4.1, §4.3 and TEST-004.
- **Q-2**: Answered at the spec gate: a flag value that starts with `-` is never consumed as a value, so `--name -x` is a usage error for a missing `--name` value. Applied in REQ-074, §4.1, §4.3 and TEST-004.
- **Q-3**: Answered at the spec gate: `--help` and `--version` are not part of this feature. `--help` stays a usage error with exit code 2. Applied in REQ-074, CON-004 and ALT-008.
- **Q-4**: Answered at the spec gate: no command-line flag can turn off a `shout: true` that came from `greet.config.json`. It is left as it is. Applied in REQ-076 and ALT-010.
- **Q-5**: Answered at the spec gate: a `greet.config.json` whose top level is a JSON array, a JSON string, `null`, a number or a boolean is a usage error. Applied in REQ-066, §4.1, §4.3 and TEST-006.
- **Q-6**: Answered at the spec gate: an invalid value in `greet.config.json` names the key and the offending value in the usage line. Applied in §4.1 and §4.3.
- **Q-7**: Answered at the spec gate: the JSON output is the compact form `{"greeting":"Hello, world"}`, with no space after the colon. The brief's `{"greeting": "Hello, world"}` is the human-readable rendering of the same shape. Applied in REQ-055, §1, RISK-003, TEST-009 and TEST-013.

## 12. Open questions

None. Every question raised at the spec gate was answered, and the four items the brief left to the spec are settled in §4, §5 and §4.1.
