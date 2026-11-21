# Spec changes: close the P2 notes and record the gate answers

Round 2 of the spec gate. The spec passes with 0 P0 and 0 P1. This round closes the
P2 notes listed below and records the answers the user gave to the spec gate's
open questions, so that later agents read a spec with nothing left dangling.

## Answers to the open questions (from the user, at the spec gate)

Apply these to the spec. Each replaces the "Recommended answer" wording in
§11 with the confirmed answer, and updates every REQ, TEST, table row and
section the answer touches. Remove each answered question from §11 or mark it
"answered at the spec gate" with the answer, and move it out of "Open questions".

- **Q-1**: `--times` accepts only a plain digit string. `--times 03` and
  `--times +2` are usage errors. (Recommended answer confirmed.)
- **Q-2**: A flag value that starts with `-` is never consumed as a value.
  `--name -x` is a usage error for a missing `--name` value. (Confirmed.)
- **Q-3**: `--help` and `--version` are not in this feature. `--help` stays a
  usage error with exit 2. (Confirmed.)
- **Q-4**: No command-line flag can turn off a `shout: true` that came from
  `greet.config.json`. Leave it as is. (Confirmed.)
- **Q-5**: A `greet.config.json` whose top level is a JSON array, a JSON string,
  `null`, a number or a boolean is a usage error. (Confirmed, matches REQ-066.)
- **Q-6**: An invalid value in `greet.config.json` names the key and the
  offending value in the usage line. (Confirmed, matches §4.3.)
- **Q-7**: The JSON output is compact: `{"greeting":"Hello, world"}` with no
  space after the colon. (Confirmed, matches REQ-055.) Because the brief's
  success list shows the human-readable rendering `{"greeting": "Hello, world"}`,
  note in §1 that the brief's rendering was the human-readable one and the
  pinned output is the compact `JSON.stringify` form. This closes F10.

## P2 notes to fix

### F06: the §4.3 table has no row for `--name=Ada` or `--`

§4.3 says the reason text after the `usage: greet [options] ` prefix is the
exact string in the table, but REQ-077 (`--name=Ada`) and REQ-078 (`--`) have no
row. Add rows for both, or state which existing reason they use. Note that
REQ-077 and REQ-078 are also now confirmed by Q-1 and Q-2's answers above:
`--name=Ada` and `--` are usage errors.

### F07: one required fixture directory cannot be committed to git

§8 says the fixtures are "committed, not generated at run time", but the
directory listed for TEST-005 ("one with no `greet.config.json`") has no
`greet.config.json` and nothing else in it. Git does not track empty
directories, so the fixture is lost on a fresh clone and TEST-005 fails. Say
that the directory holds a `.gitkeep` file (or a short README) so it can be
committed.

### F08: the new signature of the `run` helper is not pinned

§9 says the existing helper "gains an optional `cwd` argument, keeping its
current signature working for the existing tests". The current helper is
`run = (...args) => execFileSync(process.execPath, [bin, ...args], ...)`, where
every argument is a CLI argument, so an appended `cwd` parameter is
indistinguishable from a CLI argument. State the new signature explicitly, for
example `run(args = [], cwd)` or a separate `runIn(cwd, ...args)`.

### F09: the preserved-behaviour bullet is true only when the working directory
has no `greet.config.json`

"`greet` with no arguments prints exactly `Hello, world` on stdout and exits 0"
holds only in a directory without a config file. With one, `greet` prints the
config's greeting. Qualify the bullet with "and no `greet.config.json` in the
working directory".

### F11: the pinned reason for an empty `--name` ends with a trailing space

The §4.3 table pins `usage: greet [options] invalid value for --name: \n`, so
stderr carries a space before the newline. Use a reason such as
`empty value for --name` and update the table row to match.

### F12: GUD-001 says "no new directories", which §8 and §9 contradict

GUD-001 reads "All logic lives in `src/greet.js` as plain exported functions,
matching the existing one-file layout. No classes, no new dependencies, no new
directories." §8 adds a new `test/fixtures/` tree and §9 points the config
tests at it. Qualify GUD-001 as "no new directories under `src/`" or "no new
directories in the shipped package".

### N01: a config whose top level is not an object has no pinned reason string

§4.1 pins `invalid greet.config.json` only for a JSON parse failure or an
unreadable file. A non-object top level "throws a `UsageError` (REQ-066)"
without naming the reason, and §4.3 has no row for it. Name the reason in §4.1
(for example `invalid greet.config.json`) or add a row to the §4.3 table.

### N02: the config `name` type (string) comes only from the §3 table, not from
a requirement

REQ-062 says config values are validated "with the same rules as the flags",
and a flag `--name` value is always a string, so "the same rules" implies no
type check for the config. REQ-068 covers the `times` type, but nothing covers
`name`. Add a requirement in the shape of REQ-067: the `name` key in
`greet.config.json` is a JSON string, and a non-string value is a usage error.
