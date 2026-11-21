# Fix scope: the two remaining P1 findings in plans/greet-options/reports/spec/review-5.md

Fix only F20 and F17. Change nothing else in the spec.

## F20 (P1): the config `lang`/`format` validity rule has no type guard

At spec:237 the rule reads "valid when the trimmed, lower-cased value is one of the allowed values", with no type condition, unlike `name` (spec:234), `shout` (spec:235) and `times` (spec:236).

A config file holding `{"lang": 42}` makes `mergeSettings` call `.trim()` on a number, throw a TypeError that is not a `UsageError`, which spec:270 says `bin/greet.js` does not catch. The CLI dies with a stack trace, breaking REQ-033, SEC-004 and REQ-042.

Fix: add the same kind of type condition the other three keys have. The value must be a string AND its trimmed, lower-cased form must be one of the allowed values. Anything else (a number, a boolean, an array, an object, null) is invalid and falls back to the default, exactly like the other keys. Make the rule read the same way for `lang` and for `format`, and make sure the `mergeSettings` per-key rule in section 4 states the same condition.

## F17 (P1, residual): REQ-034's "a `name` that is not a non-empty string" branch has no TEST id

TEST-005 names only the whitespace-only name, TEST-019 names `""` and `"  Ada  "`, and TEST-007 covers a non-object config file. No test writes a non-string `name`, such as `"name": 42`.

Fix: extend TEST-005 (or add a new test id if that is cleaner) so a config `name` that is not a string (for example `"name": 42`, and a boolean) falls back to the default `world`, while the other config values in the same file still apply.

## Constraints

- Change nothing else in the spec. Do not add behaviour the brief does not ask for.
- Keep every id stable. Bump `last_updated` only if the date changed (today is 2026-11-19).
