---
feature: greet-options
date: 2026-11-19
status: agreed
---

# Brief: greet-options

## Goal

Extend the `greet` CLI with real option parsing so it can be driven from scripts, not just typed by hand. It gains `--name`, `--shout`, `--times`, `--lang` and `--format`, plus a `greet.config.json` file in the working directory that supplies defaults. The point is repeatability: a script or a teammate runs `greet` in a directory and gets the same greeting without passing every flag.

## Success looks like

- `greet` with no arguments still prints `Hello, world` and exits 0.
- `greet --name Ada --shout --times 3` prints `HELLO, ADA` on three separate lines and exits 0.
- `greet --lang es` prints `Hola, world`; `greet --lang fr` prints `Bonjour, world`.
- `greet --format json` prints exactly `{"greeting": "Hello, world"}` and exits 0.
- A `greet.config.json` in the working directory sets defaults; any command-line flag overrides only its own key and leaves the rest from the config.
- Every usage error (unknown flag, missing value, out-of-range `--times`, unsupported `--lang` or `--format`) prints one line to stderr, prints nothing to stdout, and exits 2.

## In scope

- Option parsing for `--name NAME`, `--shout`, `--times N`, `--lang en|es|fr`, `--format text|json`, in both `--name Ada` and `--name=Ada` forms.
- `--shout` upper-cases the whole greeting.
- `--times N` repeats the greeting on N separate lines, N between 1 and 5 inclusive.
- `--lang` selects the greeting word: en `Hello`, es `Hola`, fr `Bonjour`.
- `--format text|json`; json prints `{"greeting": "<greeting>"}` as a single line.
- `greet.config.json` read once at startup from the working directory, supplying defaults for `name`, `shout`, `times`, `lang` and `format`.
- A single usage line on stderr, empty stdout, exit code 2 for every usage error.
- Keep `greet(name)` in `src/greet.js` working as it does now.

## Out of scope

- A `--help` or `--version` flag: not mentioned in the requirement, and adding one changes the usage-error contract.
- Subcommands or positional arguments: `greet` takes options only.
- Reading config from anywhere other than the working directory: the requirement names the working directory.
- Environment variable support: no such requirement, and it would add a third precedence layer.
- A global/shared option parser package: no new dependencies, the flag set is small and fixed.
- Pluralising the name ("Hello, world" stays "Hello, world" regardless of the name).

## Decisions

| Id | Question | Decision | Why | By |
|---|---|---|---|---|
| D-01 | What does `--shout` do? | Upper-cases the whole greeting, e.g. `HELLO, WORLD` | Simplest reading of "upper-case output" | user |
| D-02 | How is `--times 3` laid out? | One line per repetition | A repeat that collapses onto one line is not really a repeat | user |
| D-03 | What does `--times 3 --format json` print? | A single object `{"greeting": "..."}`; `--times` does not multiply JSON | The requirement pins the JSON shape to exactly one `greeting` key | user |
| D-04 | How is a missing or invalid `greet.config.json` handled? | Missing file: use built-in defaults. Malformed JSON, unknown keys, or invalid values in it: ignore the config and use built-in defaults | A config file must never break a run that worked without it | user |
| D-05 | Which flag syntaxes are accepted? | Both `--name Ada` and `--name=Ada` | Both are common; accepting both avoids a surprise | user |
| D-06 | What does the stderr usage line say? | One line naming the reason, e.g. `greet: unknown option --bogus`, with the usage summary on the same line | Requirement says "one usage line" | user |
| D-07 | How strictly are config values validated? | Same rules as the equivalent flags, but a failure downgrades to "ignore the config" rather than exiting 2 | Keeps one validation code path; the config is a convenience layer, not a contract | user |
| D-08 | Where is `greet.config.json` read from? | The working directory | The requirement says "in the working directory" | user |
| D-09 | What are the greeting words per language? | en `Hello`, es `Hola`, fr `Bonjour` | Given in the requirement | user |
| D-10 | Are unknown keys in `greet.config.json` an error? | No, silently ignored | Forward compatibility: a newer config should not break an older binary | user |
| D-11 | Does `--shout` affect the JSON value? | Yes, the value inside the JSON is upper-cased too | `--shout` is a property of the greeting, not of the output format | user |
| D-12 | How is a non-numeric `--times` handled? | Usage error, exit 2 | Same as out-of-range | user |
| D-13 | What is the existing `greet()` function's fate? | Kept as `greet(name)` in `src/greet.js`; new parsing lives in new modules | The existing test imports it; keeps the change additive | user |
| D-14 | What is the precedence order? | Built-in defaults < `greet.config.json` < command-line flags, resolved per key | The requirement says each flag overrides only its own key | delegated |
| D-15 | What is the JSON output format exactly? | One line, `{"greeting": "<value>"}`, keys in that order, no trailing newline beyond the single line's own | The requirement shows the exact shape | delegated |
| D-16 | Is `--times 0` allowed? | No. Valid range is 1 to 5 inclusive, so 0 and 6 are usage errors | The requirement says 1 to 5 | delegated |
| D-17 | What happens with a repeated flag, e.g. `--name A --name B`? | Last occurrence wins | Conventional for most CLI parsers; the requirement does not say | delegated |
| D-18 | Does `--shout` take a value? | No, it is a boolean flag | The requirement lists it without a value | delegated |
| D-19 | Is the config file read before or after flag parsing? | Before, once, then flags override | The requirement says "read once at startup" | delegated |
| D-20 | Is a config file that is not an object (e.g. an array or a number) an error? | No, ignored like any other invalid config | Consistent with D-04 and D-07 | delegated |

## Approaches considered

- Hand-written parser inside `bin/greet.js`: rejected, it would put parsing, config loading, formatting and I/O in one file and make it untestable in pieces.
- Small dedicated modules (`src/options.js` for parsing and defaults, `src/config.js` for loading, `src/greet.js` for the greeting): chosen, each is a plain function set that tests can call directly.
- A third-party CLI parsing library: rejected, no new dependency for five fixed flags.
- `src/greet.js` rewritten to take an options object: rejected, it breaks the existing public `greet(name)` signature and its test for no gain.

## Constraints

- Node v22, CommonJS, no new dependencies.
- `npm test` (node --test) is the test command and must stay green.
- The existing `greet('Ada') === 'Hello, Ada'` and `greet` CLI defaults must keep working.
- The config file is read once per process, not per option.

## Left to the spec

- Exact module and function names for parsing and config loading, and how the usage line is composed. Recommended: `src/options.js` exporting `parseArgs(argv)` and `resolveOptions(argv, config)`, `src/config.js` exporting `loadConfig(dir)`; usage text built by one helper so it stays one line.
- Whether the greeting word is produced by a language table in `src/greet.js` or a separate module. Recommended: keep the table in `src/greet.js` next to `greet(name)`.
- The precise shape of the usage line text, so long as it is one line and names the reason. Recommended: `greet: <reason> (usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json])`.
