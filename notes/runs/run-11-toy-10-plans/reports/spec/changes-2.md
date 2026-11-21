# Spec changes: close the last two P2 notes

The spec passes with 0 P0 and 0 P1. This round closes the two remaining P2
notes from `plans/greet-options/reports/spec/review-3.md`. Nothing else changes.

## N03: REQ-062 says "the two exceptions" but there are three

REQ-062 says config values are validated "with the same rules as the flags",
naming "the two exceptions". The config `shout` type (REQ-067) is a third
deviation from "the same rules as the flags", because the `--shout` flag has no
value to type-check. The behaviour is correct; only the wording is wrong.
Reword REQ-062 so it names all three exceptions (the `name` type, the `shout`
type and the `times` type), or reword it so it does not count them, and keep
the requirement ids it references accurate.

## N04: REQ-079 omits the non-empty constraint, so `{"name": ""}` is unpinned

REQ-079 pins the config `name` type as a JSON string, but it does not carry the
non-empty constraint that the §3 table holds. So `{"name": ""}` has no pinned
rule, no fixture and no test. Make the rule explicit and consistent across the
sections that state it: the §3 table, §4.1, the requirement, the fixture list
in §8 and the TEST ids that cover it. The flag side already has a pinned
reason for an empty value (`empty value for --name`); decide and state whether
the config side uses the same reason wording for `{"name": ""}`, and add the
fixture and the TEST case for it.
