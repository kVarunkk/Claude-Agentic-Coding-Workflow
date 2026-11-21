---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: 0cfb3b7
tests: npm test: 32/32 (/tmp/greet-phase2-tests-2.log)
mode: phase 2
---

# Conformance: greet-options (phase 2)

**Summary:** 20 met · 0 untested · 0 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms

Phase 2 covers TASK-201, TASK-202, TASK-204 and the auto-fix unit 2c (TASK-205, TASK-206):
`buildGreeting` and `renderOutput` in `src/greet.js`, with their unit tests. `bin/greet.js` is
deliberately untouched; TASK-401/402 own the CLI in phase 4.

This is the second pass over phase 2. The earlier report (`reports/phase-2/conformance.md`,
commit feb393b) graded **REQ-056 🟡 Partial** (Major) and raised one coverage-smell Warning.
Unit 2c (commit 0cfb3b7) closed both. Every grade below was re-derived from the code and today's
test run, not carried over.

## Critical

None.

## Major

None. The earlier report's REQ-056 Major is closed: see "Closed findings".

## Warnings

None. The earlier report's coverage-smell Warning is closed: see "Closed findings".

## Closed findings

Both findings from the earlier phase-2 report are closed by unit 2c (TASK-205, TASK-206), and
both closures are proven by tests that ran today.

- **REQ-056 🟡 Partial → ✅ Met.** The earlier report found the JSON `greeting` value's name and
  language rules were Inspected only, because every JSON test passed a hand-written `line`
  literal into `renderOutput` and never composed `buildGreeting` with it. Unit 2c added four
  composed tests that drive one `options` object through `buildGreeting` and then `renderOutput`:
  `test/greet.test.js:193` › `the JSON value carries a named, non-English greeting built by
  buildGreeting` (`es` → `{"greeting":"Hola, Ada"}\n`, `fr` → `{"greeting":"Bonjour, Ada"}\n`),
  `:207` › `the JSON value carries the name exactly as given` (`{"greeting":"Hello,   Ada  "}\n`),
  `:215` › `the JSON value upper-cases the whole line when shout and a name are combined`
  (`{"greeting":"HOLA, ADA"}\n`), `:223` › `the JSON value joins the repeated lines inside the
  value` (`{"greeting":"Hello, Ada\nHello, Ada"}\n`). All four pass in today's run (tests 29–32).
- **Coverage smell → closed.** The earlier report flagged that all JSON tests shared the
  `{ ...DEFAULT_OPTIONS, format: 'json' }` setup with a hand-written `line`. The JSON seam is now
  exercised end to end: of the 9 JSON-related test blocks, 4 compose `buildGreeting` →
  `renderOutput` through a single `options` object and 5 still pass a literal (the literal ones
  are the ones that pin the renderer's own byte contract, which is their job). The
  `buildGreeting` → `renderOutput` seam is now covered, which is what the earlier report said
  would close it.
- The earlier report also flagged that `bin/greet.js` is untouched by phase 2, so the CLI still
  prints `Hello, world` and exits 0 for every argument. That remains true and remains correct for
  this phase: no phase-2 task row lists `bin/greet.js` in its Files column. TASK-401/402 own it
  in phase 4. Noted only so nobody reads the current CLI as the finished feature.

## Real run

`npm test` (`node --test`): 32 tests, 32 pass, 0 fail, 0 skipped, 0 todo, 0 cancelled.
Log: `/tmp/greet-phase2-tests-2.log`.

Live probe of the phase-2 functions against the real module (`node -e` against `src/greet.js`),
used as Verified evidence:

```
buildGreeting en / es / fr        -> "Hello, Ada" / "Hola, Ada" / "Bonjour, Ada"
buildGreeting shout               -> "HELLO, ADA"      (shout + es -> "HOLA, ADA")
buildGreeting name "  Ada  "      -> "Hello,   Ada  "  (verbatim, no trim)
buildGreeting name "Bob; rm -rf /"-> "Hello, Bob; rm -rf /"  (no shell, no escaping)
buildGreeting times 3             -> count 3
renderOutput text count 1 / 3     -> "Hello, world\n" / "Hello, world\nHello, world\nHello, world\n"
renderOutput json count 1 / 3     -> {"greeting":"Hello, world"}\n / {"greeting":"Hello, world\nHello, world\nHello, world"}\n
JSON.parse(json).keys            -> ["greeting"]
renderOutput json name:Ada lang:es -> {"greeting":"Hola, Ada"}\n      (REQ-056 name + language)
renderOutput json name:Ada fr     -> {"greeting":"Bonjour, Ada"}\n    (REQ-056 language)
renderOutput json name:"  Ada  "  -> {"greeting":"Hello,   Ada  "}\n  (REQ-056 name fidelity)
renderOutput json es + shout      -> {"greeting":"HOLA, ADA"}\n       (REQ-056 shout)
renderOutput json times 2         -> {"greeting":"Hello, Ada\nHello, Ada"}\n (REQ-056 count)
JSON escaping round-trip          -> JSON.parse(out).greeting === greeting.line  (quote/backslash/newline)
DEFAULT_OPTIONS                   -> {"name":"world","shout":false,"times":1,"lang":"en","format":"text"}
GREETING_WORDS                    -> {"en":"Hello","es":"Hola","fr":"Bonjour"}
```

The spec names no runnable CLI example for phase 2: the `--format json` end-to-end example
(`greet --format json`) is TEST-013, a route-level test owned by TASK-402 in phase 4, and
`bin/greet.js` still holds the old ad-hoc `--name` lookup, so it cannot produce JSON output yet.
The unit seam is the phase-2 seam and it was probed directly.

## Attention

Read as an outsider; this work was not done by me.

- `decisions.tsv` row `2026-11-20T10:28:07Z` (phase-2 add-unit): the REQ-056 Major finding was
  turned into an **added unit** (2c) rather than a reopened task, and unit 2c was then committed.
  A conformance finding answered by a new committed unit is fine, but the new unit was appended
  to the tasks file *after* the phase-2 conformance report had already graded the phase as
  `verdict: fail` (p1=1), so the phase's verdict changed after the fact. Whoever reads the phase
  gate should look at both reports: `conformance.md` (the original, p1=1) and this one (p0=0,
  p1=0), and know that the second supersedes the first because unit 2c closed the finding.
- `decisions.tsv` row `2026-11-20T10:35:00Z` (phase-2 fix-round): five P2 findings from
  `fix-unit-review.md` about the new unit's own scope (F01 relabel TASK-206 as **Guard:**, F02
  drop `src/greet.js` from TASK-206's Files column, F03 cite TEST-013 not TEST-009, F04 add a
  composed count case, F05 add the traceability rows) were closed by editing the **tasks file**
  after the unit was written, so the task rows were reworded to match the implementation rather
  than the other way round. The rewordings are accurate and the unit does what the current rows
  say (verified: F01 the row is `**Guard:**`; F02 the Files column is `test/greet.test.js` only;
  F03 the rows cite TEST-013; F04 the composed `times: 2` case exists at `test/greet.test.js:223`;
  F05 the traceability rows at tasks:191-193 and tasks:206 now list TASK-206). Nothing was left
  unapproved, but a user reading the original task rows in git history sees four different
  wordings of the same task.
- `decisions.tsv` row `2026-11-20T10:20:36Z` (unit-2b gate-reason): one mutation stayed green,
  reading the count from `options.times` instead of `greeting.count`. Judged an equivalent mutant,
  because spec §4.2 calls `buildGreeting(options)` and `renderOutput(options, greeting)` with the
  same options object and `buildGreeting` sets `count: options.times`, so
  `greeting.count === options.times` on every production path. The shipped code reads
  `greeting.count` in both branches (`src/greet.js:50` and `:54`), so the mutation would be caught
  today; the recorded judgement is about a mutation, not about the shipped code. The same mutant
  recurred in unit 2c's review (`review-2c.md`), also judged equivalent. Nothing to accept.
- `decisions.tsv` rows `2026-11-20T10:14:19Z`, `2026-11-20T10:20:37Z` and
  `2026-11-20T10:40:51Z`: units 2a, 2b and 2c were each reviewed clean and committed.
  `review-2a.md`, `review-2b.md` and `review-2c.md` all carry verdict pass with p0=0 p1=0 p2=0.
  No unit was committed with an open finding.
- `decisions.tsv` row `2026-11-20T10:00:36Z` (unit-1, carried from phase 1): the Decisions row's
  `/^[0-9]+$/` for `--times` was corrected to `/^[1-9][0-9]*$/` by the implementing unit, and the
  tasks file logs the same under **Differences from the spec** (tasks:236). It tightens the rule
  to match the spec's own REQ-032 and Q-1 wording, so nothing is left unapproved, but the spec's
  §11 Q-1 text was edited by an implementation unit rather than at the gate. Already flagged in
  the phase-1 report; unchanged here.
- No phase-2 task was skipped, no phase-2 unit was added without a spec id behind it, and no
  phase-2 finding was closed by dropping or narrowing a test. The unit 2c diff is 38 added lines
  and 0 removed lines in `test/greet.test.js` (`git diff feb393b..HEAD -- test/greet.test.js`).

## Not in the spec

- None. The phase-2 source diff adds exactly the two exports §4.1 lists for this layer,
  `buildGreeting` (`src/greet.js:38`) and `renderOutput` (`src/greet.js:46`), and the
  `module.exports` block gained only those two names. Unit 2c added four tests and no code. No
  new file, no new dependency, no `package.json` change, no env var, no route and no CLI surface.
  `OPTION_SPECS` and `parseTimes` are unchanged from phase 1 and are already recorded in the
  phase-1 report.

## Contracts (data model, API, config)

- Option record (§3): `buildGreeting` returns `{ line, count }` exactly as §4.1 specifies, with
  `count` taken from `options.times` (`src/greet.js:42`). `DEFAULT_OPTIONS` is unchanged and still
  the spec's five-key record with `times` as a number, matching the phase-1 Difference log
  (tasks:237).
- Greeting words (§3, GUD-003): `GREETING_WORDS` (`src/greet.js:3`) is the single map
  `{ en: 'Hello', es: 'Hola', fr: 'Bonjour' }`; `buildGreeting` reads only this map
  (`src/greet.js:39`), so adding a language is one entry (REQ-003, GUD-003).
- `renderOutput` text branch: `${greeting.line}\n` repeated `greeting.count` times
  (`src/greet.js:54`), so every line ends with a single `\n` and there is no blank line at the end
  (REQ-050, REQ-031).
- `renderOutput` JSON branch: `JSON.stringify({ greeting: value }) + '\n'` from an object literal
  with exactly one key, so the printed form has no space after the colon (REQ-055; GUD-004's
  single-helper rule does not apply here, `formatUsage` is phase 4). The value is the lines joined
  by `\n` with no trailing newline inside the string (REQ-052, REQ-053).
- `greet(name)` (`src/greet.js:33-35`) is unchanged and still returns `Hello, ${name}` (CON-003);
  the pre-existing test `greet formats the name` still passes.
- §4.4 "no API contracts" and §3's `greet.config.json` table are untouched by this phase:
  `loadConfig`, `mergeOptions` and `formatUsage` do not exist yet (phases 3 and 4).
- CommonJS, Node standard library only, no new dependency, `npm test` still `node --test`
  (CON-001, CON-002). `package.json` unchanged.
- One note for the config phase, not a phase-2 gap: `buildGreeting` reads
  `GREETING_WORDS[options.lang]` with no fallback, so an invalid `lang` reaching it would render
  `"undefined, world"`. That path is unreachable today (`parseOptions` rejects any lang outside
  `en|es|fr`, phase 1) and the spec asks for no fallback at this layer (§4.1 states only "Picks the
  greeting word from `GREETING_WORDS[options.lang]`"). It matters only if phase 3's `loadConfig`
  lets an invalid `lang` through, which REQ-062/REQ-067 forbid.

## Tasks file

- TASK-201, TASK-202, TASK-204, TASK-205 and TASK-206 are all ticked with the date 2026-11-20,
  and each is evidenced: every Red-list and Guard-list assertion in those five rows has a matching
  named test in `test/greet.test.js:107-229`, and each Green step has its code in
  `src/greet.js:38-55`.
- No task outside phase 2 is ticked. Every other task row is still `[ ]`.
- The phase-2 diff touches only the files in the phase-2 rows' Files column (`src/greet.js`,
  `test/greet.test.js`) plus the plan's own front-matter status, the status badge, the three
  Status/Done cells, the pipeline-owned `decisions.tsv`, the three review reports and the
  conformance reports. The Green-step text of the phase-2 rows is unchanged from the base; only
  the two new unit 2c rows and the traceability rows are new.
- No divergence in phase 2 is missing from **Differences from the spec**. The two logged
  differences (tasks:236, tasks:237) both map to phase-1 tasks. The unit 2c rows are labelled
  **Guard:** and the plan's own Introduction says a Guard is not logged as a difference, so no
  Differences entry is owed for them.
- Phase 1's findings do not carry into this phase: the phase-1 report recorded no Critical, Major
  or Warning, and `git diff --stat 6d426a5..HEAD -- src/ bin/ test/` shows only the phase-2
  `buildGreeting`/`renderOutput` code and the phase-2 tests.

## All ids

Met: REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-012, REQ-020, REQ-021, REQ-030, REQ-031,
REQ-033, REQ-050, REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, REQ-056, TEST-008, TEST-009, TEST-013

| Id | Status | Tier | Test |
|---|---|---|---|
| (all above) | ✅ Met | Tested | see the grade notes below |

Grade notes for the ids phase 2 owns only in part (the rest is later work, not a gap):

- REQ-002: the JSON-default slice TASK-204 owns (`DEFAULT_OPTIONS.format === 'text'`, so the text
  branch is the default). The built-in defaults as a whole are TASK-101 (phase 1, Met there) and
  the merge into a full record is TASK-302 (phase 3).
- REQ-012: the slices TASK-201 and TASK-206 own, the name inserted verbatim into the line, proven
  in both the text seam (`buildGreeting uses the name exactly as given`) and the JSON seam (`the
  JSON value carries the name exactly as given`). The CLI-level echo is TASK-701 (phase 7).
- REQ-020: the slices TASK-201, TASK-202 and TASK-206 own, the assembled line upper-cased whole,
  proven in the text seam and the composed JSON seam. The CLI level is TASK-401 (phase 4).
- REQ-021: the upper-casing covers the word, the comma and the name with nothing added or removed
  (`src/greet.js:41`), proven by `buildGreeting upper-cases the whole line when shout is true` and
  by the probe output `HELLO, ADA` and `HOLA, ADA`.
- REQ-030, REQ-031, REQ-033: the renderer slice TASK-202 owns, the count reaching the renderer and
  driving exactly `count` lines each ending with a single `\n`, no blank line at the end, and a
  count of one rendering the same bytes as no count. The CLI level is TASK-401 (phase 4).
- REQ-050: the renderer slice TASK-202 owns (the text branch prints the line or lines, each ending
  with `\n`) and TASK-204's slice (the `text` branch stays as it is when the JSON branch is added).
  The CLI level is TASK-402 (phase 4).
- REQ-051, REQ-052, REQ-053, REQ-054, REQ-055: the renderer slice TASK-204 owns, each proven by a
  named test and by the probe. The CLI level is TASK-402 (phase 4).
- REQ-056: the slices TASK-204, TASK-205 and TASK-206 own. The name, language, shout and count
  rules of the JSON value are each proven over the composed `buildGreeting` → `renderOutput` seam:
  `test/greet.test.js:193` (name + language, `es` and `fr`), `:207` (name kept exactly as given),
  `:215` (shout applied to the whole assembled line with a name), `:223` (count over the seam). The
  route level is TASK-402 (phase 4).
- TEST-008: `buildGreeting greets in the language of the options` and `buildGreeting upper-cases
  the whole line when shout is true`.
- TEST-009: `renderOutput repeats the greeting line once per count in the text format`, `renderOutput
  repeats the line exactly count times with no blank line at the end`, `renderOutput prints the
  compact JSON form with one trailing newline` and `renderOutput joins the repeated lines inside
  the JSON value`.
- TEST-013: the unit-seam part phase 2 owns, the JSON shape, the compact form, the one-key object
  and the name/shout/language/count rules of the value, proven by the four JSON tests and the four
  composed tests. The route level is TASK-402 (phase 4).

Not started in this phase, owned by a later task (not a gap, and not graded here): REQ-010,
REQ-060 to REQ-069, REQ-079, REQ-070 to REQ-078, SEC-001 to SEC-006, CON-001 to CON-006,
GUD-001 to GUD-005, PAT-001, TEST-005 to TEST-007, TEST-010 to TEST-012, TEST-014 to TEST-024.
