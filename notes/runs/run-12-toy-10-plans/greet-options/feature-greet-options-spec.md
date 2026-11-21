---
goal: Let users control the greet CLI's name, casing, repetition, language and output format via flags and an optional greet.config.json.
version: 0.3
date_created: 2026-11-21
last_updated: 2026-11-21
owner: pipeline-toy
status: 'Approved'
tags: [feature, cli, greet]
---

# Introduction

![Status: Approved](https://img.shields.io/badge/status-Approved-green)

The `greet` CLI prints one greeting today and takes only `--name`. Anyone running the `greet` binary cannot yet choose a different language, upper-case the result, repeat it, or get machine-readable output, and there is no way to set personal defaults.

This feature adds five flags (`--name`, `--shout`, `--times`, `--lang`, `--format`) and an optional `greet.config.json` read once at startup that supplies defaults for those same five keys. Each command-line flag overrides only its own config key, so a config of `{"name":"Ada","shout":true}` plus `--name Bob` yields `Hello, Bob` in upper case. A config of `{"lang":"fr"}` plus `--times 2` yields `Bonjour, world` twice.

The solution is a small set of pure functions in `src/greet.js` (parse options, merge config, format one or many greetings) and a thin `bin/greet.js` that parses argv, loads the config, prints, and exits. It is Node.js, CommonJS, no new dependencies, with CLI tests driving the `bin/greet.js` binary and unit tests driving `src/greet.js`. The implementation is test-driven; see `plans/greet-options/feature-greet-options-tasks.md`.

## 1. Requirements & Constraints

### Functional

Defaults and per-key override:

- **REQ-001**: With no config and no flags, `greet` prints `Hello, world` followed by one newline to stdout and exits 0.
- **REQ-002**: `--name NAME` sets the greeting name. With no other options, `greet --name Ada` prints `Hello, Ada\n`. The default name is `"world"`.
- **REQ-003**: `--shout` upper-cases the final greeting text. `greet --name Ada --shout` prints `HELLO, ADA\n`. The default is no shout (mixed case).
- **REQ-004**: `--times N` repeats the greeting N times, once per line, for integers N in the range 1-5 inclusive. `greet --times 3` prints `Hello, world\nHello, world\nHello, world\n`. The default is 1.
- **REQ-005**: `--lang LANG` selects the greeting word, one of `en` (`Hello`), `es` (`Hola`), `fr` (`Bonjour`), with `en` the default. `greet --lang es` prints `Hola, world\n`; `greet --lang fr` prints `Bonjour, world\n`.
- **REQ-006**: `--format FORMAT` selects the output shape, one of `text` (the greeting plus a newline) or `json` (a single JSON object). The default is `text`.
- **REQ-007**: `greet.config.json` in the working directory, when present and valid, supplies defaults for exactly the keys `name`, `shout`, `times`, `lang` and `format`. A key omitted from the config falls back to the default in REQ-001 through REQ-006.
- **REQ-008**: Each command-line flag overrides only its own config key. With config `{"name":"Ada","shout":true}` and `--name Bob`, the name is `Bob` and `shout` stays `true`.

JSON output:

- **REQ-010**: `--format json` prints one JSON object whose key is `greeting` (D-01). `greet --format json` prints `{"greeting":"Hello, world"}` followed by one newline.
- **REQ-011**: When `--format json` and `--times N` (N > 1) are both set, the `greeting` value is an array of N greeting strings in one JSON object (D-01). `greet --format json --times 2` prints `{"greeting":["Hello, world","Hello, world"]}\n`.
- **REQ-012**: The JSON string uses double quotes, no spaces, and encodes the greeting exactly as the text form would produce it (including the upper-casing from `--shout`). `greet --format json --shout --name Ada` prints `{"greeting":"HELLO, ADA"}\n`.

Config validation:

- **REQ-020**: `greet.config.json` is read once at startup, before argv is applied. If the file is missing, no config is applied and no error occurs.
- **REQ-021**: If `greet.config.json` cannot be parsed as JSON, is not a JSON object, or any of its values is invalid (an unknown key, a `name` that is not a string, a `shout` that is not a boolean, a `times` that is not an integer 1-5, a `lang` outside `en`/`es`/`fr`, or a `format` outside `text`/`json`), the program treats it as a usage error per REQ-030 (D-02). Unknown keys are rejected rather than ignored (D-02).

Usage errors:

- **REQ-030**: A usage error is any of: an unknown flag, a missing value for `--name`/`--times`/`--lang`/`--format`, an out-of-range `--times` (non-integer or outside 1-5), an unsupported `--lang`, an unsupported `--format`, a stray non-flag argument (D-03), or an invalid `greet.config.json` (D-02). On a usage error the program prints one usage line to stderr, prints nothing to stdout, and exits 2.
- **REQ-031**: The usage line is a single line to stderr, exactly: `Usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json]`. It ends with one newline.
- **REQ-032**: When a usage error occurs, stdout must be empty, and `--shout` and `--format` are never applied to the error path.

### Preserved & superseded behaviour

- Preserved: `greet` with no flags still prints `Hello, world\n` and exits 0 (REQ-001); `greet --name Ada` still prints `Hello, Ada\n` (REQ-002). The existing `src/greet.js` export `greet(name)` keeps working for its current callers.
- Superseded: the manual `process.argv` scan in `bin/greet.js` that only recognises `--name` → replaced by the argv parser in §4; `bin/greet.js` no longer hard-codes `'world'` as the fallback name, it comes from the merged options.

### Security

- **SEC-001**: `greet.config.json` is read from the working directory only, and its contents are never executed. Checked by a static test (TEST-008) that reads `bin/greet.js` and `src/greet.js` and asserts: (a) the only `fs` call in `bin/greet.js` is `readFileSync(path.join(process.cwd(), 'greet.config.json'))`; (b) neither file contains `process.env`, `path.isAbsolute`, `eval`, `Function(`, `child_process`, `exec`, `spawn`, `fork`, or `execFile`; (c) every `require` argument in `bin/greet.js` is one of `'node:util'`, `'node:fs'`, `'node:path'`, `'../src/greet'`. The contents are parsed with `JSON.parse` and validated before use, so malformed content never reaches the formatter (REQ-021, REQ-030).
- **SEC-002**: The greeting name comes from a flag or config and is printed verbatim only as the greeting text; it is never passed to a shell, `eval`, or the filesystem, and it never changes which file is read. Checked by a static test (TEST-008): `src/greet.js` and `bin/greet.js` import/call none of `node:child_process` (`exec`, `execFile`, `spawn`, `fork`), `eval`, or `Function`; the name value is only concatenated in `buildGreeting` and passed to `console.log`; and the config path is the fixed `path.join(process.cwd(), 'greet.config.json')` built without the name.

### Constraints & guidelines

- **CON-001**: Node.js, CommonJS (`require`/`module.exports`), no new dependencies. Parsing uses the built-in `node:util` `parseArgs`.
- **CON-002**: Tests run with `npm test`, i.e. `node --test`.
- **CON-003**: `bin/greet.js` is the entry point; `src/greet.js` holds the option and formatting logic. `bin/greet.js` does console I/O and exit codes; `src/greet.js` stays free of `process`, `console` and `fs`.
- **CON-004**: The only file read at runtime is `<cwd>/greet.config.json`, read once (REQ-020); no other file is read and no file is written.
- **GUD-001**: Keep the formatting and merge logic as pure functions of the options object, so unit tests cover them without spawning a process or touching the filesystem.

## 2. Architecture

```
argv (process.argv.slice(2))
  │
  ▼
[1] bin/greet.js ── parseArgs (node:util) ──► cli overrides or usage error
  │
  ▼
[2] read <cwd>/greet.config.json once (JSON.parse + validate)  ──► config defaults or usage error
  │
  ▼
[3] merge: config defaults, then cli overrides per key  ──► final options object
  │
  ▼
[4] src/greet.js format(options) ──► greeting text (text) or {"greeting": ...} (json)
  │
  ▼
[5] print to stdout, exit 0        (usage errors branch to [1]/[2] → stderr, exit 2)
```

Order of steps matters: the config is read before argv is merged (REQ-020), and a usage error from either argv or the config stops the program before any formatting or stdout output (REQ-030, REQ-032).

## 3. Data model (`greet.config.json` and the merged options)

The runtime "options" object that flows from step [3] into the formatter:

```
{
  name:   string,        // default "world"; from --name or config
  shout:  boolean,       // default false; from --shout or config
  times:  integer 1..5,  // default 1; from --times or config
  lang:   'en'|'es'|'fr',// default 'en'; from --lang or config
  format: 'text'|'json'  // default 'text'; from --format or config
}
```

`greet.config.json` is an object with an optional subset of exactly those five keys, with the same types and ranges as above:

```json
{ "name": "Ada", "shout": true, "times": 2, "lang": "es", "format": "json" }
```

Notes:
- A missing file is fine (no config). A present file must be a JSON object and its values must pass validation; any failure is a usage error (REQ-021, D-02).
- Merge is per key: a key present in argv wins over the same key in config; keys not in argv keep their config value; keys in neither use the defaults. No key is ever dropped or reset by another flag (REQ-008).

## 4. Components

### 4.1 `src/greet.js`: greeting and option logic

CommonJS. Keeps its current export `greet(name)` working (REQ-002's preserved behaviour) and adds the pure functions below. It must not use `process`, `console` or `fs` (CON-003), so it takes the already-parsed values as arguments and returns strings.

- `greet(name)` → `"Hello, <name>"`. Existing signature, unchanged.
- `helloFor(lang)` → `"Hello"` for `en`, `"Hola"` for `es`, `"Bonjour"` for `fr`; any other value is a usage error handled by the caller.
- `formatText(greeting, times)` → the greeting repeated `times` times, each followed by `\n` (REQ-004).
- `formatJson(value, times)` → one JSON object string plus `\n`, built with `JSON.stringify` and the `greeting` key. `value` is a single greeting string when `times` is 1 and an array of `times` greeting strings when `times` > 1; `times` selects the value shape. It produces the exact bytes for both cases without hand-written JSON: `formatJson('Hello, world', 1)` → `{"greeting":"Hello, world"}\n` (REQ-010, REQ-012) and `formatJson(['Hello, world','Hello, world'], 2)` → `{"greeting":["Hello, world","Hello, world"]}\n` (REQ-011).
- `buildGreeting({name, shout, lang})` → the base greeting `"<word>, <name>"`, upper-cased with `.toUpperCase()` when `shout` is true (REQ-003).
- `applyOverrides(config, cli)` → a new options object: the defaults, then `config` keys, then `cli` keys, per key (REQ-008).
- `validateConfig(value)` → returns the config as an options-shaped object or throws when the file is not a JSON object or any value is invalid (REQ-021).

Exact text output shape:

```
Hello, world
```

Exact JSON output shape (text form is the same greeting, wrapped by `JSON.stringify`):

```
{"greeting":"Hello, world"}
{"greeting":["Hello, world","Hello, world"]}
```

### 4.2 `bin/greet.js`: entry point

CommonJS. Replaces the current manual `--name` scan with `require('node:util').parseArgs` configured so unknown options, missing option values, and stray positionals raise usage errors (REQ-030). It then:

1. Parse argv with `parseArgs` using `options.strict = true` (unknown flag and positional rejection) and `options.allowPositionals = false` (D-03). Map the parsed values to the `cli` overrides.
2. Read and validate `<cwd>/greet.config.json` once (REQ-020, REQ-021); a missing file yields `{}`.
3. Merge with `applyOverrides` (§4.1).
4. Build and print via `formatText`/`formatJson` (or `buildGreeting`), then exit 0.
5. On any usage error, print the single usage line from REQ-031 to stderr and `process.exit(2)`, with nothing on stdout (REQ-032).

`--name`, `--times`, `--lang`, `--format` take one value; `--shout` is boolean. `--times` is range-checked here after parsing (REQ-030).

## 5. Approach summary

One merge rule (config then cli, per key) and one formatter that already knows the text, casing, repetition and JSON shapes are enough; no separate formatter modules are needed because every output shape is a single small function in `src/greet.js`.

## 6. Alternatives

- **ALT-001: `node:util` `parseArgs`.** Chosen (D brief "Approaches considered"). It handles flags and values consistently, is in the standard library, and its `strict`/`allowPositionals` options map directly to REQ-030 and D-03. Rejected alternatives: manual `process.argv` parsing (more edge cases to re-derive) and a new CLI library (violates CON-001).
- **ALT-002: one formatter function vs separate modules.** Chosen: one `src/greet.js` with small pure functions. The output shapes (text and JSON, with repetition and casing) are each one line of logic, so module-per-formatter would add files without new behaviour.

## 7. Dependencies

- **DEP-001**: Node.js built-ins only: `node:util` (`parseArgs`), `node:fs` (`readFileSync` for the config), `node:path` (to resolve `<cwd>/greet.config.json`), and `JSON`. No third-party packages; `package.json` changes only if a `bin` map entry is missing (it is already present).
- **DEP-002 (runtime)**: `greet.config.json` in the working directory, optional, user-supplied. Its schema is §3.

## 8. Files

New:
- `src/greet.js` already exists; its new functions go there (no new source file is required).

Changed:
- `src/greet.js`: add `helloFor`, `buildGreeting`, `formatText`, `formatJson`, `applyOverrides`, `validateConfig` (§4.1); keep `greet(name)`.
- `bin/greet.js`: replace the manual `--name` scan with `parseArgs`, add config read/validate/merge and the formatter dispatch, wire the exit codes (§4.2).
- `test/greet.test.js`: extend with the cases in §9; keep the existing three tests passing.

## 9. Testing

Seams under test: the `bin/greet.js` binary (spawned with `node --test` via `execFileSync`, as today) for end-to-end flag, config and exit-code behaviour, and the exported `src/greet.js` functions for pure formatting/merge/validation behaviour.

- **TEST-001 (unit):** `greet('Ada')` returns `Hello, Ada` (kept from the existing suite).
- **TEST-002 (unit):** `buildGreeting({name:'Ada', shout:true, lang:'en'})` returns `HELLO, ADA`.
- **TEST-003 (unit):** `helloFor` maps `en`/`es`/`fr` to `Hello`/`Hola`/`Bonjour`.
- **TEST-004 (unit):** `formatText('Hello, world', 3)` returns `Hello, world\nHello, world\nHello, world\n`.
- **TEST-005 (unit):** `formatJson('Hello, world', 1)` returns `{"greeting":"Hello, world"}\n`; `formatJson('HELLO, ADA', 1)` returns `{"greeting":"HELLO, ADA"}\n`; `formatJson(['Hello, world','Hello, world'], 2)` returns `{"greeting":["Hello, world","Hello, world"]}\n`.
- **TEST-006 (unit):** `applyOverrides({name:'Ada', shout:true}, {name:'Bob'})` returns an object with `name:'Bob'` and `shout:true` (per-key override, REQ-008).
- **TEST-007 (unit):** `validateConfig` accepts a valid config and throws for: a non-object, an unknown key, a non-string `name`, a non-boolean `shout`, a non-integer or out-of-range `times`, an unsupported `lang`, and an unsupported `format`.
- **TEST-008 (static):** read `bin/greet.js` and `src/greet.js` and assert none of `process.env`, `path.isAbsolute`, `eval`, `Function(`, `child_process`, `exec`, `spawn`, `fork`, or `execFile` appears in either; assert every `require(` argument in `bin/greet.js` is one of `'node:util'`, `'node:fs'`, `'node:path'`, `'../src/greet'`; assert the only `fs.` method call in `bin/greet.js` is `readFileSync(path.join(process.cwd(), 'greet.config.json'))`, and none of `writeFileSync`, `writeFile`, `appendFileSync`, `appendFile`, `createWriteStream`, `readFile(`, `readdirSync`, `readdir`, `statSync`, `stat`, `createReadStream` appears in `bin/greet.js`; and assert that in `src/greet.js` `name` appears only inside `buildGreeting`, and in `bin/greet.js` the name value is passed only to `buildGreeting` (never to `fs`, `child_process` or `eval`) (SEC-001, SEC-002).
- **TEST-010 (CLI):** `run()` prints `Hello, world\n` and exits 0 (REQ-001).
- **TEST-011 (CLI):** `run('--name','Ada')` prints `Hello, Ada\n`; `run('--shout','--name','Ada')` prints `HELLO, ADA\n`.
- **TEST-012 (CLI):** `run('--times','3')` prints three lines; `run('--lang','es')` prints `Hola, world\n`; `run('--lang','fr')` prints `Bonjour, world\n`.
- **TEST-013 (CLI):** `run('--format','json')` prints `{"greeting":"Hello, world"}\n`; `run('--format','json','--times','2')` prints the array form; `run('--format','json','--shout','--name','Ada')` prints `{"greeting":"HELLO, ADA"}\n`.
- **TEST-014 (CLI):** with a valid `greet.config.json` (a temp working directory), each flag overrides only its own key (config `{"name":"Ada","shout":true}` plus `--name Bob` → `HELLO, BOB\n`; config `{"lang":"fr"}` plus `--times 2` → two `Bonjour, world` lines).
- **TEST-015 (CLI):** each usage error (unknown flag, missing value, `--times 0`, `--times 6`, `--times abc`, unsupported `--lang`, unsupported `--format`, stray positional, malformed config, invalid config value) prints the exact REQ-031 usage line to stderr, prints nothing to stdout, and exits 2. The combined cases `run('--shout','--nope')` and `run('--format','json','--times','0')` also print the exact REQ-031 line (lowercase, not upper-cased and not JSON), print nothing to stdout, and exit 2 (REQ-032).
- **TEST-016 (CLI):** a missing `greet.config.json` behaves exactly like no config (no error), and the config file is read only when it exists.

## 10. Risks & assumptions

- **RISK-001:** `parseArgs` error messages differ across Node versions. Mitigation: the program maps any `parseArgs` `ERR_PARSE_ARGS` failure to the fixed usage line in REQ-031 rather than printing the parser's own message, so tests assert the fixed line and exit code.
- **RISK-002:** `--shout` is a boolean flag; a config or flag given an unexpected value must not crash the process with a raw stack trace. Mitigation: validate it as a boolean in REQ-021/REQ-030 and route failures through the usage-error path.
- **ASSUMPTION-001:** the working directory is writable by the caller and `greet.config.json`, when present, is the only config source. The program never reads config from a home directory or an environment variable.
- **ASSUMPTION-002:** the `greeting` value keeps its comma, e.g. `Hola, world` for Spanish, matching the brief's examples rather than a locale-specific greeting.
- **ASSUMPTION-003:** when `--format json` repeats, the `greeting` key holds the array (D-01), and a single repetition still uses a bare string, not a one-element array (REQ-010 vs REQ-011).

## 11. Open questions

All open questions were answered at the spec gate (2026-11-21); none remain open.

- **Q-1 (resolved):** `--format json` with `--times 1` uses a bare string, `{"greeting":"Hello, world"}` (REQ-010). A one-element array is not used.
- **Q-2 (resolved):** An unknown key in `greet.config.json` is rejected as a usage error and exits 2 (REQ-021, REQ-030).
- **Q-3 (resolved):** `--shout` upper-cases the greeting inside the JSON value too (REQ-012).
