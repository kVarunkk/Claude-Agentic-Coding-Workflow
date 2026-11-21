# Spec changes requested at the spec gate

Fix the P2 findings F07 to F16 from plans/greet-options/reports/spec/review-3.md, and settle the three open questions below.

## Open question answers (binding)

- Q-1: the valid range for `--times` is 1 to 5 inclusive. Keep REQ-012, TIMES_MIN and TIMES_MAX as they are. No change needed beyond making the range stated in one place and referenced consistently.
- Q-2: command-line `--lang` and `--format` stay case-sensitive. `--lang ES` and `--format JSON` are usage errors. The config file stays case-insensitive and trimmed. Keep REQ-013, REQ-014 and TEST-003 as they are; make the asymmetry explicit in the text.
- Q-3: a `--name` value that starts with `--` is a missing value and therefore a usage error (exit 2). Keep REQ-005 as it is; make the rule explicit in the text.

## P2 findings to fix

- F07: GUD-002 says parsing, config reading and rendering live in separate modules, but section 4.1 puts `parseArgs`, `mergeSettings`, `resolveGreeting` and `render` in `src/options.js`. Make GUD-002 match the design in section 4.1.
- F08: the parenthetical "(process.argv.slice(2))" at spec:201 still reads as if `parseArgs` does the slicing. State clearly who slices and who parses.
- F09: section 8 does not mention `scripts/seed-red.sh` or the `test/zz-seeded.test.js` it seeds. Say that the seeded trimming test contradicts REQ-017 and D-16, and is not part of this feature.
- F10: REQ-020 and REQ-021 count lines while REQ-024 says a newline in the name makes the output span more than one line. Name REQ-024 as the exception to the line-count rules.
- F11: D-11 (no short flags) is never cited, and `greet --name -x` prints `Hello, -x` and exits 0. Cite D-11 and say in the spec that a value starting with a single dash is a valid name.
- F12: the spec never says how a `--times` value is read, so `0x2`, `1e1` and `" 3"` stay undecided. Say exactly how the value is parsed (recommended: a base-10 integer match only, so `0x2`, `1e1`, `" 3"` and `"2.5"` are usage errors) and make the command-line path as precise as the config path.
- F13: the usage-error mechanism is never named, so an implementer that throws a plain `Error` could print a stack trace. Name the mechanism (recommended: a dedicated error type that `bin/greet.js` catches, printing only the usage line to stderr and exiting 2) so REQ-042's no-stack-trace rule is guaranteed.
- F14: a config `name` that is only whitespace is neither empty (REQ-036) nor a valid name. Say what happens (recommended: treated as invalid, falling back to the default, consistent with D-12).
- F15: a config-set `shout: true` cannot be turned off from the command line. Say that plainly as the accepted consequence of "each command-line flag overrides only its own key" (D-08 scope), or name a way to override it.
- F16: `FORMATS` is exported but no part of the spec says who reads it. Either say who reads it or drop it from the stated exports.

## Constraints

- Change nothing else in the spec. Do not add behaviour the brief does not ask for.
- Keep every id stable. Bump `last_updated`.
