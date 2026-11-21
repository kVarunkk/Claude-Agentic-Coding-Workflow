# Spec changes: close the last two P2 notes

The spec passes with 0 P0 and 0 P1. This round closes the two remaining P2
notes from `plans/greet-options/reports/spec/review-4.md`. Nothing else changes.

## N05: the `{"name": ""}` fixture is tagged with only one of its two tests

The §8 fixture list tags the `{"name": ""}` directory "(TEST-006)" only, but
the new TEST-024 drives the same directory. Tag it "(TEST-006, TEST-024)" so a
reader can find every test that needs the fixture.

## N06: the §4.3 table has no row for a wrong-typed config `name`

The §4.3 table has no row for a wrong-typed config `name`, such as
`{"name": 123}`, although §4.1's general rule covers it. Add the row with the
reason the config side uses for a wrong type, following the reason shape §4.3
already pins for the other config keys.
