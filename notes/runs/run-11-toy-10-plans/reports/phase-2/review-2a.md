# Review: unit 2a (TASK-201, TASK-202) (08910f6 -> staged)

Date: 2026-11-20
Unit: 2a, tasks TASK-201, TASK-202
Base: 08910f68eab3ae25981a4a2efcc082bc2c9e0d49
Spec: plans/greet-options/feature-greet-options-spec.md (v0.4)
Tasks: plans/greet-options/feature-greet-options-tasks.md

## Review: unit 2a (TASK-201, TASK-202) (08910f6 -> staged)

Findings: P0 0 · P1 0 · P2 0 · P3 0    Partitions reviewed: 5

### Index

No findings. The unit implements exactly what TASK-201 and TASK-202 specify, and every
behaviour each task claims to guard is proven to be guarded by a mutation that turns the
suite red.

### Partitions reviewed

1. **Greeting word selection** (`buildGreeting` reads `GREETING_WORDS[options.lang]`) — REQ-003/004/005/006.
2. **Whole-line upper-casing** (`options.shout`) — REQ-020/021, D-01, ALT-001.
3. **Name fidelity** (no trimming or normalisation) — REQ-012, SEC-003, ALT-009.
4. **Repeat count and exact bytes** (count carried from `options.times` to the renderer, exact repeat, single trailing `\n`) — REQ-030/031/033/050, TEST-008/009.
5. **Gate integrity and scope** (no test weakened or skipped, no behaviour beyond the two task rows, task-file edits limited to status/ticks).

### Tests

- `npm test` on the staged tree: 24 tests, 24 pass, 0 fail.
- The 7 new tests were replayed against the base tree (`scratch-copy.sh <dir> --base 08910f6`,
  new `test/greet.test.js` dropped in): **7 fail** (`buildGreeting greets in the language of the
  options`, `buildGreeting upper-cases the whole line when shout is true`,
  `buildGreeting uses the name exactly as given`,
  `renderOutput repeats the greeting line once per count in the text format`,
  `buildGreeting carries the count through to the renderer`,
  `renderOutput repeats the line exactly count times with no blank line at the end`,
  `renderOutput with a count of one prints the same bytes as no count`), 17 pass. The new
  tests are genuinely red at base and green after the change.
- No test was deleted, skipped (`.skip`/`xit`) or given a relaxed assertion. The only removed
  line in `test/greet.test.js` is the old destructuring import; the pre-existing
  `greet formats the name` test and every other pre-existing assertion are byte-identical.
- No lint, type, coverage or CI gate was touched (the repo has no lint config; `package.json`
  `test` script is unchanged).
- Weak-test probe: an implementation that returns `greeting.line + '\n'` once, ignoring the
  count, would pass the count-of-one guard but fails tests 21 and 23, so the guard set as a whole
  is sound.

### Guards

All mutations were run in a scratch copy (`scratch-copy.sh "${TMPDIR:-/tmp}/mut-2a"`), never in
the repo, with `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`.

- mutation: upper-case only the greeting word, leave the name as given (`HELLO, Ada` instead of `HELLO, ADA`) -> `buildGreeting upper-cases the whole line when shout is true` red
- mutation: drop the shout branch entirely (`line: line`) -> `buildGreeting upper-cases the whole line when shout is true` red
- mutation: trim the name (`String(options.name).trim()`) -> `buildGreeting uses the name exactly as given` red
- mutation: hard-code the greeting word to `Hello`, ignoring `options.lang` -> `buildGreeting greets in the language of the options` red
- mutation: `count` hard-coded to `1` instead of `options.times` -> `buildGreeting carries the count through to the renderer` red
- mutation: `count` returned as a string (`String(options.times)`) -> `buildGreeting carries the count through to the renderer` red
- mutation: repeat `greeting.count + 1` times -> 3 red (`renderOutput repeats the greeting line once per count in the text format`, `renderOutput repeats the line exactly count times with no blank line at the end`, `renderOutput with a count of one prints the same bytes as no count`)
- mutation: append one extra `\n` after the repeated block -> 3 red (same three `renderOutput` tests)

8 mutations run, 0 still green. Every behaviour the two task rows claim to guard turns the
suite red when broken.

One mutation was deliberately **not** counted as a defect: switching the repeat source from
`greeting.count` to `options.times` stays green. That is not a spec violation, because
`buildGreeting` sets `count` from `options.times` (spec §4.1, REQ-030), so the two are equal on
every path the spec defines, and the task row explicitly states that no second source of the
count is to be introduced. The implementation follows the row and uses `greeting.count`.

### Checked and fine

- `buildGreeting` assembly (`src/greet.js:39`): `${GREETING_WORDS[options.lang]}, ${options.name}`
  gives the word, a comma, a space, then the name, with no other characters, as REQ-003 requires.
- Upper-casing applies to the fully assembled line, so the word, the comma and the name are all
  upper-cased and nothing else is added or removed (REQ-020, REQ-021, D-01). This is exactly
  what ALT-001 rejected.
- The name is inserted verbatim: `buildGreeting({ ...DEFAULT_OPTIONS, name: '  Ada  ' })` yields
  `Hello,   Ada  `, with the surrounding spaces kept (REQ-012, ALT-009).
- `renderOutput` bytes for the text format were probed directly: for `times: 3` the output is
  `"Hello, world\nHello, world\nHello, world\n"`, three lines, a single trailing `\n`, no blank
  line at the end (REQ-030, REQ-031, REQ-050). For `count: 1` it is `"Hello, world\n"`, byte-identical
  to the no-count case (REQ-033).
- `greet(name)` and the `module.exports` shape are unchanged in behaviour; `greet` still returns
  `Hello, ${name}` (CON-003). Only the export list grew, with `buildGreeting` and `renderOutput`
  added (the spec's §4.1 export list names both).
- The `renderOutput(options, greeting)` signature takes `options` even though the text branch
  does not read it. That is the signature the spec pins and TASK-204's JSON branch will use it;
  not a defect here.
- `buildGreeting` with an out-of-range `lang` yields `undefined, world`. That is unreachable
  through the validated paths (`parseOptions` rejects a bad `--lang` per REQ-040, and `loadConfig`
  will reject a bad config `lang` per REQ-062 in TASK-301), so it is not a defect in this unit.

### Set aside

- `toUpperCase()` expands `ß` to `SS` (`straße` -> `STRASSE`). Considered against REQ-021's
  "no other characters are added or removed"; judged to be the standard, expected meaning of
  "upper-cased" in JavaScript, and the spec pins no locale or case-mapping rule. Not a finding.
- The count-of-one guard compares `renderOutput({ ...DEFAULT_OPTIONS, times: 1 }, ...)` with
  `renderOutput(DEFAULT_OPTIONS, ...)`, and `DEFAULT_OPTIONS.times` is already `1`, so the two
  option records are identical. The comparison is therefore vacuous on its own. It is the exact
  wording of the TASK-202 Guard row, and the sibling count-exactness tests (21, 23) do guard the
  real behaviour. Not a finding; noted for the author.

### Scope

Scope: clean

- Files changed: `src/greet.js`, `test/greet.test.js`, `plans/greet-options/feature-greet-options-tasks.md`.
  The first two are in the Files column of both TASK-201 and TASK-202. The tasks file is the
  plan itself: the diff is limited to the front-matter `status: 'Planned'` -> `'In progress'`,
  the matching status badge, and the Status/Done cells of the TASK-201 and TASK-202 rows.
  Verified mechanically: after stripping the trailing Status/Done cells, the task-row text is
  byte-identical to the base, so no requirement was silently reworded.
- No new entry was added to the Differences section for this unit, and none was needed: the
  implementation matches the task rows and the cited spec ids.
- No behaviour beyond the two task rows was added. `bin/greet.js` was not touched (it is not in
  either task's Files column), `loadConfig`/`mergeOptions`/`formatUsage` were not added (they
  belong to later phases), and the JSON branch of `renderOutput` was not added (TASK-204).

### Open questions

None.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
scope: clean
mutations: 8 run, 0 still green
top:
report: plans/greet-options/reports/phase-2/review-2a.md
