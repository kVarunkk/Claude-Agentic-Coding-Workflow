---
feature: greet-options
date: 2026-11-21
status: agreed
---

# Brief: greet-options

## Goal

Extend the `greet` CLI so users can control the greeting's name, casing, repetition, language and output format via command-line flags, with defaults supplied by an optional `greet.config.json` read once at startup. Built for anyone running the `greet` binary.

## Success looks like

- Plain `greet` prints `Hello, world` and exits 0.
- `greet --name Ada` prints `Hello, Ada`.
- `greet --shout` prints the greeting in upper case.
- `greet --times 3` prints the greeting 3 times, once per line.
- `greet --lang es` prints `Hola, <name>`; `--lang fr` prints `Bonjour, <name>`.
- `greet --format json` prints `{"greeting": "<greeting>"}`.
- A `greet.config.json` supplies defaults for `name`, `shout`, `times`, `lang` and `format`; each command-line flag overrides only its own key.
- Any usage error prints one usage line to stderr, nothing to stdout, and exits 2.

## In scope

- Command-line flags:
  - `--name NAME` (default `"world"`, unchanged)
  - `--shout` (upper-case output)
  - `--times N` (repeat 1-5 times)
  - `--lang en|es|fr` (`Hello`/`Hola`/`Bonjour`, default `en`)
  - `--format text|json` (`json` prints `{"greeting": "..."}`)
- `greet.config.json` in the working directory, read once at startup, supplying defaults for `name`, `shout`, `times`, `lang` and `format`.
- Per-key override: each command-line flag overrides only its own config key.
- Usage errors: unknown flag, missing value, out-of-range `--times`, unsupported `--lang`. A usage error prints one usage line to stderr, prints nothing to stdout and exits 2.

## Out of scope

- Positional arguments are not accepted; a stray non-flag argument is a usage error.

## Decisions

| Id | Question | Decision | Why | By |
|---|---|---|---|---|
| D-01 | What should `--times` do when `--format json` is set? | The `greeting` value is an array of N greetings in one JSON object. | JSON needs one value per invocation; an array preserves all repetitions. | user |
| D-02 | What happens when `greet.config.json` is malformed or has invalid values? | Treat it as a usage error: one usage line to stderr, nothing to stdout, exit 2. | Invalid config is a user error, same as a bad flag. | user |
| D-03 | Is a stray non-flag argument a usage error? | Yes, any unexpected positional argument exits 2. | `greet hello` is ambiguous and should be rejected. | user |

## Approaches considered

- Node.js built-in `util.parseArgs` / manual `process.argv` parsing: parseArgs chosen, because it handles flags and values consistently and is in the standard library.
- Separate formatter modules vs a single function: a small formatter function, because the output shape is simple.

## Constraints

- Node.js, CommonJS (`require`), no new dependencies.
- Tests run with `npm test` (`node --test`).
- `bin/greet.js` is the entry point; `src/greet.js` holds the formatting logic.

## Left to the spec

- The exact usage line text and which field the JSON object uses when `--format json` repeats (the `greeting` key is the requirement's own example).
