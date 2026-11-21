---
feature: greet-options
date: 2026-11-19
status: agreed
---

# Brief: greet-options

## Goal

Extend the `greet` CLI with real option parsing so it can greet a named person, in a chosen language, in a chosen format, repeated a bounded number of times, with defaults supplied by an optional config file. The CLI stays a small teaching-quality toy: the plain `greet` command keeps printing `Hello, world` and exiting 0, and every usage error fails loudly with one usage line on stderr and exit 2.

## Success looks like

- `greet` prints `Hello, world` on stdout and exits 0.
- `greet --name Ada --lang es --times 2` prints `Hola, Ada` on two lines and exits 0.
- `greet --format json --name Ada` prints `{"greeting": "Hello, Ada"}` on stdout and exits 0.
- `greet --times 9` prints nothing on stdout, prints the usage line on stderr and exits 2.
- A `greet.config.json` in the process working directory supplies defaults; `greet --name Ada` with `{"name": "Bob"}` in the config prints `Hello, Ada`.

## In scope

- Five long flags: `--name NAME`, `--shout`, `--times N`, `--lang en|es|fr`, `--format text|json`.
- Both `--name Ada` and `--name=Ada` forms.
- `greet.config.json`, read once at startup from the process working directory, supplying defaults for `name`, `shout`, `times`, `lang` and `format`.
- Each command-line flag overrides only its own key; every other value still comes from the config file, then from the built-in default.
- Usage errors: unknown flag, missing value, empty `--name`, non-numeric or out-of-range `--times`, unsupported `--lang`, unsupported `--format`, any bare positional argument.
- Language-specific greeting words: `Hello` (en), `Hola` (es), `Bonjour` (fr).
- JSON output shape `{"greeting": "..."}`.
- Text output: one line per repetition when `--times N` is greater than 1.
- `--shout` upper-cases the whole greeting, including the name, in both text and JSON formats.

## Out of scope

- Trimming whitespace from the name: the name is used exactly as given. The seeded `scripts/seed-red.sh` trimming test is not part of this feature.
- Short flags (`-n`, `-h`): long flags only.
- The `--` separator and positional arguments: there are none, a bare word is an unknown argument.
- Reading the config file from any directory other than the process working directory.
- Searching for a config file in parent directories, or any other config discovery rule.
- Config file formats other than `greet.config.json`.
- Any behaviour beyond the five named flags.

## Decisions

| Id | Question | Decision | Why | By |
|---|---|---|---|---|
| D-01 | How should repeated `--name` or `--times` flags behave? | Last one wins, no error | Standard CLI convention, simplest to implement and test | user |
| D-02 | What should `--times N` output look like in text format? | One line per repetition | Reads naturally in a terminal and stays one greeting per line | user |
| D-03 | What should JSON output contain when `--times` is greater than 1? | A single object `{"greeting": "..."}` with the greeting repeated | Keeps the exact JSON shape the requirement states | user |
| D-04 | How should a missing, malformed or invalid config file be treated? | Missing is fine, invalid values fall back to built-in defaults | A config file is optional; a bad value should not break the run | user |
| D-05 | Should `--name ""` (empty value) be accepted? | Usage error, exit 2 | An empty name is malformed input | user |
| D-06 | How should unknown keys in the config file be treated? | Ignored silently | Forward-compatible: the config may carry extra settings later | user |
| D-07 | Which directory is the config file read from? | The process working directory | Matches the requirement's wording exactly | user |
| D-08 | What exactly is the single usage line printed to stderr? | `Usage: greet [--name NAME] [--shout] [--times N] [--lang en|es|fr] [--format text|json]` | One line listing every flag and its values | user |
| D-09 | Should the `--name=Ada` (equals) form be supported? | Yes, both `--name Ada` and `--name=Ada` | Modern CLI convention, forgiving to users | user |
| D-10 | Should the `--` separator or positional arguments be supported? | No, any bare word is an unknown argument, exit 2 | The requirement names only flags | user |
| D-11 | Are there short forms for any flags? | No, long flags only | Exactly the five flags the requirement names | user |
| D-12 | How should an empty `name` in the config file be treated? | Ignored, falls back to the built-in default | The config is treated the same as any other invalid value | user |
| D-13 | Does `--shout` apply in JSON format? | Yes, the greeting inside the JSON is upper-cased | `--shout` is a property of the greeting, not of the output format | user |
| D-14 | Does `--shout` upper-case the name too? | Yes, the whole greeting including the name | One rule for shout, applied to the final greeting | user |
| D-15 | Should `--lang` change the greeting word as well as the name? | Yes, the whole greeting is translated (`Hola, Ada`, `Bonjour, Ada`) | The language selects the greeting, the name is interpolated into it | user |
| D-16 | Is trimming whitespace from the name part of this feature? | No, out of scope | Keeps the feature to the five flags and the config file | user |

## Approaches considered

- Flag parsing by hand in `bin/greet.js`: chosen. The CLI has five flags and no dependency is present in `package.json`; a hand-written parser keeps the toy dependency-free and makes the usage-error rules explicit and testable.
- A third-party argument parser: rejected, it adds a dependency to a project that deliberately has none and hides the exact error messages the requirement specifies.

## Constraints

- Node.js, CommonJS, no runtime dependencies. `npm test` runs `node --test`.
- The existing `greet(name)` export in `src/greet.js` and the existing three tests keep working.
- Plain `greet` prints `Hello, world` and exits 0.
- Every usage error: exactly one usage line on stderr, nothing on stdout, exit 2.
- `greet.config.json` is read once at startup, not per flag.

## Left to the spec

- The exact wording of the usage line beyond the string agreed in D-08, if the spec wants a second line: recommended one line only, as D-08 says.
- Whether the config file is parsed as JSON strictly (throwing on malformed JSON, caught and ignored) or defensively: recommended strict parse wrapped in a catch that falls back to defaults.
- How `--times` accepts its value: recommended the same two forms as `--name`, `--times 3` and `--times=3`.
- Whether `--shout` in the config file is read as a boolean only, or also accepts the strings `"true"` and `"false"`: recommended boolean only, other types ignored.
- Whether `--lang` in the config file may be uppercase (`"ES"`): recommended case-insensitive matching, trimmed.
- Whether `--format json` output ends with a newline: recommended yes, one JSON object per line, matching the text format.
