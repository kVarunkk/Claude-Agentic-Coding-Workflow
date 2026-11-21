---
feature: greet-options
date: 2026-11-20
status: agreed
---

# Brief: greet-options

## Goal

Extend the `greet` CLI with option parsing so it can greet a chosen name, optionally in upper case, optionally repeated, in one of three languages, and in text or JSON. Defaults come from a `greet.config.json` file in the working directory so a project can set its own greeting style, while command-line flags override only the keys they name. The CLI keeps a strict usage contract: any usage error prints one usage line to stderr, prints nothing to stdout, and exits 2.

## Success looks like

- `greet` with no arguments prints `Hello, world` and exits 0.
- `greet --name Ada --shout` prints `HELLO, ADA` and exits 0.
- `greet --lang es` prints `Hola, world` and exits 0.
- `greet --format json` prints `{"greeting": "Hello, world"}` and exits 0.
- `greet --times 3` prints 3 greeting lines and exits 0.
- `greet --times 0`, `greet --lang de`, `greet --nmae x`, and `greet --name` each print exactly one usage line to stderr, print nothing to stdout, and exit 2.
- With a `greet.config.json` in the working directory, `greet` uses its values, and any command-line flag overrides only its own key.

## In scope

- `--name NAME`: the name to greet. Default `world`.
- `--shout`: print the greeting in upper case.
- `--times N`: repeat the greeting N times. N is an integer from 1 to 5.
- `--lang en|es|fr`: the greeting word. `en` is `Hello`, `es` is `Hola`, `fr` is `Bonjour`. Default `en`.
- `--format text|json`: `text` prints the greeting line(s), `json` prints `{"greeting": "..."}`. Default `text`.
- `greet.config.json` in the working directory, read once at startup, supplying defaults for `name`, `shout`, `times`, `lang` and `format`.
- A usage-error contract: one usage line to stderr, nothing to stdout, exit 2.

## Out of scope

- Reading `greet.config.json` from parent directories: only the working directory is searched.
- Requiring `greet.config.json` to exist: an absent file is normal and the built-in defaults apply.
- Adding new languages beyond `en`, `es` and `fr`.
- Adding new output formats beyond `text` and `json`.
- Any change to the existing `greet(name)` function's `Hello, ${name}` formatting for a single call.
- Reordering or otherwise changing the existing `Hello, ${name}` word order.

## Decisions

| Id | Question | Decision | Why | By |
|---|---|---|---|---|
| D-01 | What does `--shout` output look like? | The whole greeting is upper-cased: `Hello, Ada` becomes `HELLO, ADA`. | Literal reading of "upper-case output". | user |
| D-02 | How are repetitions separated when `--times` is greater than 1? | One greeting per line. `--times 3` prints 3 lines. | Keeps each repetition a complete, copyable line. | user |
| D-03 | What is the JSON shape? | Always `{"greeting": "..."}`. With `--times` greater than 1 the value holds the repeated lines joined by `\n`. | The documented `{"greeting": "..."}` shape never changes, so there is one shape to document and parse. | user |
| D-04 | How is an invalid value inside `greet.config.json` handled? | It is a usage error: one usage line to stderr, nothing to stdout, exit 2. | A broken config should fail loudly rather than silently greet with a value nobody asked for. | user |
| D-05 | Where is `greet.config.json` looked up? | The working directory only. | The requirement says "in the working directory"; parent-directory search would surprise. | user |
| D-06 | What if `greet.config.json` is absent? | Not an error. The built-in defaults apply. | Plain `greet` must keep working with no config file. | user |
| D-07 | How strict is flag parsing about unknown flags and stray positional arguments? | Strict. An unknown flag or a stray positional argument is a usage error (exit 2). | Catches typos like `--nmae`, which would otherwise be silently ignored. | user |
| D-08 | What happens if the same flag is given twice, e.g. `--name Ada --name Bob`? | Last one wins. | Standard last-wins parsing, and no case in the requirement needs it to be an error. | user |
| D-09 | How is `shout` expressed in `greet.config.json`? | A boolean: `{"shout": true}`. | Matches the flag's boolean nature and avoids stringly-typed truthiness. | user |
| D-10 | What does the usage error line say? | One line starting with `usage: greet [options]`, followed by the reason. | Names both the correct usage and what was wrong, in a single line. | user |
| D-11 | What happens for an out-of-range `--times`, such as 0 or 6? | A usage error: exit 2. | The requirement names out-of-range `--times` as a usage error. | user |
| D-12 | Which key names does `greet.config.json` use? | The same names as the flags: `name`, `shout`, `times`, `lang`, `format`. | One vocabulary for both the file and the flags. | user |
| D-13 | What happens for a non-integer `--times`, e.g. `--times abc`? | A usage error: exit 2. | A count that is not a number cannot be honoured; fail rather than guess. | user |
| D-14 | What happens for an empty `--name`, e.g. `greet --name ""`? | A usage error: exit 2. | An empty name has no sensible greeting; fail rather than print `Hello, `. | user |
| D-15 | How are unknown keys in `greet.config.json` treated? | Ignored. Only the five known keys are read. | Keeps a config file forward-compatible with future keys. | user |

## Approaches considered

- Whole-greeting upper case for `--shout`, rather than upper-casing only the greeting word: chosen, because "upper-case output" reads as the whole output.
- JSON array for repeated greetings (`{"greetings": [...]}`): rejected, because it would introduce a second JSON shape alongside the specified `{"greeting": "..."}`.
- Separate `greetings` key only when `--times` is greater than 1: rejected, because it makes the JSON shape depend on the options, which is harder to consume.
- Walking up parent directories to find `greet.config.json`: rejected, because the requirement names the working directory.
- Clamping an out-of-range `--times` to the nearest valid value: rejected, because the requirement names out-of-range `--times` as a usage error.

## Constraints

- Stack stays as it is: Node.js 22, CommonJS, no new dependencies.
- The existing `greet(name)` export and its `Hello, ${name}` output stay intact.
- `greet` with no arguments prints exactly `Hello, world` and exits 0.
- The test command stays `npm test` (`node --test`).

## Left to the spec

- The exact wording of the usage line and of the reason text that follows it. Recommended: a fixed `usage: greet [options]` prefix followed by a short reason such as `unknown flag: --nmae`.
- Whether the CLI reads and validates the config file before or after parsing flags. Recommended: parse flags first, then read and apply the config, so the two layers stay independent.
- Whether the greeting word, the name, or the separator is upper-cased first under `--shout`. Recommended: upper-case the fully assembled greeting line.
- The internal module split between option parsing, config loading, and greeting rendering. Recommended: keep them in `src/greet.js` as plain functions, matching the existing one-file layout.
