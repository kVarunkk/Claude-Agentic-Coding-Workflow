---
spec: plans/greet-options/feature-greet-options-spec.md
spec_version: 0.4
checked: 2026-11-20
commit: feb393b
tests: npm test: 28/28 (/tmp/greet-phase2-tests.log)
mode: phase 2
---

# Conformance: greet-options (phase 2)

**Summary:** 13 met · 0 untested · 1 partial · 0 missing · 0 diverge · 0 accepted · 0 outdated
**Verdict:** conforms with gaps

Phase 2 covers TASK-201, TASK-202 and TASK-204: `buildGreeting` and `renderOutput` in `src/greet.js`,
with their unit tests. `bin/greet.js` is deliberately untouched; TASK-401/402 own the CLI in phase 4.

## Major

- **REQ-056** 🟡 Partial: the id says the JSON `greeting` value uses "the same name, shout, language and count rules as the text format". Phase 2's own task row (TASK-204) asks for exactly that, and two of the four rules are tested: shout (`test/greet.test.js` › `renderOutput uses the same shout rule in the JSON format`) and count (`renderOutput joins the repeated lines inside the JSON value`). The **name** and **language** rules in the JSON value are not covered by any phase-2 test: every JSON test passes a literal `line` (for example `'Hello, world'`) into `renderOutput`, and no test composes `buildGreeting` with `renderOutput` for a non-default name or language, so the name and language parts of REQ-056 are Inspected only. The behaviour is in fact correct (`src/greet.js:50` copies `greeting.line` verbatim, and `buildGreeting` at `src/greet.js:38-44` is the single place the name and language are applied), confirmed by probe: `buildGreeting({name:'Ada', lang:'es'})` into the JSON branch gives `{"greeting":"Hola, Ada"}\n`. A test that renders a `buildGreeting` output for a named, non-English greeting through the JSON branch would close this.

## Warnings

- **Coverage smell (phase 2 only):** all four JSON tests in `test/greet.test.js:161-191` build their expectation from a hand-written `line` literal and the same `{ ...DEFAULT_OPTIONS, format: 'json' }` setup. The `buildGreeting` -> `renderOutput` seam is never exercised end to end in phase 2, which is what let the REQ-056 name/language gap above go unnoticed. This seam is exercised for real from phase 4 (TASK-401/402) once `bin/greet.js` calls the pipeline.

## Real run

`npm test` (`node --test`): 28 tests, 28 pass, 0 fail, 0 skipped. Log: `/tmp/greet-phase2-tests.log`.

Live probe of the phase-2 functions against the real module (`node -e` against `src/greet.js`), used as Verified evidence:

```
buildGreeting name:Ada lang:en   -> line "Hello, Ada"        count 1
buildGreeting name:Ada lang:es   -> line "Hola, Ada"          count 1
buildGreeting name:Ada lang:fr   -> line "Bonjour, Ada"       count 1
buildGreeting name:Ada shout:true-> line "HELLO, ADA"         count 1
buildGreeting name:"  Ada  "     -> line "Hello,   Ada  "
renderOutput text count 1/2/3    -> "Hello, world\n" / "...\nHello, world\n" / three lines, no blank line at the end
renderOutput json count 1         -> {"greeting":"Hello, world"}\n
renderOutput json count 2         -> {"greeting":"Hello, world\nHello, world"}\n
renderOutput json count 3         -> {"greeting":"Hello, world\nHello, world\nHello, world"}\n
renderOutput json shout           -> {"greeting":"HELLO, ADA"}\n
JSON.parse(json).keys             -> ["greeting"]
renderOutput json name:Ada lang:es-> {"greeting":"Hola, Ada"}\n        (REQ-056 name+language, no test)
renderOutput json name:Ada fr+shout -> {"greeting":"BONJOUR, ADA"}\n
JSON escaping of a quote/backslash/newline in the name round-trips: JSON.parse(out).greeting === greeting.line
DEFAULT_OPTIONS                   -> {"name":"world","shout":false,"times":1,"lang":"en","format":"text"}
GREETING_WORDS                    -> {"en":"Hello","es":"Hola","fr":"Bonjour"}
```

The spec names no runnable CLI example for phase 2: the `--format json` end-to-end example (`greet --format json`) is TEST-013, a route-level test owned by TASK-402 in phase 4, and `bin/greet.js` still holds the old ad-hoc `--name` lookup, so it cannot produce JSON output yet. The unit seam is the phase-2 seam and it was probed directly.

## Attention

- `decisions.tsv` row `2026-11-20T10:20:36Z` (unit-2b gate-reason): one mutation stayed green, reading the count from `options.times` instead of `greeting.count`. Judged an equivalent mutant, because spec §4.2 calls `buildGreeting(options)` and `renderOutput(options, greeting)` with the same options object and `buildGreeting` sets `count: options.times`, so `greeting.count === options.times` on every production path. The current code reads `greeting.count` in both branches (`src/greet.js:50` and `:54`), so the mutation would in fact be caught today; the recorded judgement is about a mutation, not about the shipped code. Nothing for the user to accept.
- `decisions.tsv` rows `2026-11-20T10:14:19Z` and `2026-11-20T10:20:37Z`: both phase-2 units were reviewed clean on the first review and committed. `plans/greet-options/reports/phase-2/review-2a.md` and `review-2b.md` both carry verdict pass with p0=0 p1=0 p2=0. No unit was committed with an open finding.
- `decisions.tsv` row `2026-11-20T10:00:36Z` (unit-1, carried from phase 1): the Decisions row's `/^[0-9]+$/` for `--times` was corrected to `/^[1-9][0-9]*$/` by the implementing unit, and the tasks file logs the same under **Differences from the spec** (tasks:223). It tightens the rule to match the spec's own REQ-032 and Q-1 wording, so nothing is left unapproved, but the spec's §11 Q-1 text was edited by an implementation unit rather than at the gate. Already flagged in the phase-1 report.
- `bin/greet.js` is untouched by phase 2, so `node bin/greet.js --format json` still prints `Hello, world` and exits 0. That is correct for this phase (neither TASK-201/202/204 lists `bin/greet.js` in its Files column) and is owned by TASK-401/402 in phase 4. Flagged only so nobody reads the current CLI as the finished feature.

## Not in the spec

- None. The phase-2 diff adds exactly the two exports the spec's §4.1 lists for this layer, `buildGreeting` (`src/greet.js:38`) and `renderOutput` (`src/greet.js:46`), and the `module.exports` block was extended with only those two names. No new file, no new dependency, no `package.json` change, no env var, no route and no CLI surface. `OPTION_SPECS` and `parseTimes` are unchanged from phase 1 and are already recorded in the phase-1 report.

## Contracts (data model, API, config)

- Option record (§3): `buildGreeting` returns `{ line, count }` exactly as §4.1 specifies, with `count` taken from `options.times` (`src/greet.js:42`). `DEFAULT_OPTIONS` is unchanged and still the spec's five-key record with `times` as a number, matching the phase-1 Difference log (tasks:224).
- Greeting words (§3, GUD-003): `GREETING_WORDS` (`src/greet.js:3`) is the single map `{ en: 'Hello', es: 'Hola', fr: 'Bonjour' }`; `buildGreeting` reads only this map, so adding a language is one entry (REQ-003, GUD-003).
- `renderOutput` text branch: `${greeting.line}\n` repeated `greeting.count` times (`src/greet.js:54`), so every line ends with a single `\n` and there is no blank line at the end (REQ-050, REQ-031).
- `renderOutput` JSON branch: `JSON.stringify({ greeting: value }) + '\n'` from an object literal with exactly one key, so the printed form has no space after the colon (REQ-055, GUD-004's single-helper rule does not apply here: `formatUsage` is phase 4). The value is the lines joined by `\n` with no trailing newline inside the string (REQ-052, REQ-053).
- `greet(name)` (`src/greet.js:33-35`) is unchanged and still returns `Hello, ${name}` (CON-003); the pre-existing test `greet formats the name` still passes.
- §4.4 "no API contracts" and §3's `greet.config.json` table are untouched by this phase: `loadConfig`, `mergeOptions` and `formatUsage` do not exist yet (phases 3 and 4).
- CommonJS, Node standard library only, no new dependency, `npm test` still `node --test` (CON-001, CON-002). `package.json` unchanged.

## Tasks file

- TASK-201, TASK-202 and TASK-204 are all ticked with the date 2026-11-20, and each is evidenced: every Red-list assertion in those three rows has a matching named test in `test/greet.test.js:107-191`, and each Green step has its code in `src/greet.js:38-55`.
- No task outside phase 2 is ticked. Every other task row is still `[ ]`.
- The phase-2 diff touches only the files in the phase-2 rows' Files column (`src/greet.js`, `test/greet.test.js`) plus the plan's own front-matter status, the status badge, the three Status/Done cells, and the pipeline-owned `decisions.tsv` and the two review reports. The task-row text itself is byte-identical to the base: no requirement was silently reworded while ticking.
- No divergence in phase 2 is missing from **Differences from the spec**. The two logged differences (tasks:223, tasks:224) both map to phase-1 tasks.
- Phase 1's findings do not carry into this phase: the phase-1 report recorded no Critical, Major or Warning, and `git diff --stat 6d426a5..feb393b` shows the phase-1 parser code and tests are unchanged.

## All ids

Met: REQ-002, REQ-003, REQ-004, REQ-005, REQ-006, REQ-012, REQ-020, REQ-021, REQ-030, REQ-031, REQ-033, REQ-050, REQ-051, REQ-052, REQ-053, REQ-054, REQ-055, TEST-008, TEST-009

| Id | Status | Tier | Test |
|---|---|---|---|
| REQ-056 | 🟡 Partial | Tested + Inspected | `test/greet.test.js` › `renderOutput uses the same shout rule in the JSON format`; name and language in the JSON value untested |

Grade notes for the ids that phase 2 owns only in part (the rest is later work, not a gap):

- REQ-002: Met for the JSON-default slice TASK-204 owns (`DEFAULT_OPTIONS.format === 'text'`, so the text branch is the default). The built-in defaults as a whole are TASK-101 (phase 1, graded Met there) and the merge into a full record is TASK-302 (phase 3).
- REQ-012: Met for the slice TASK-201 owns (the name is inserted verbatim into the line, no trimming or normalisation, `test/greet.test.js` › `buildGreeting uses the name exactly as given`). The CLI-level proof that the name is echoed unchanged to stdout is TASK-701 (phase 7).
- REQ-020: Met for the slice TASK-201 owns (the assembled line is upper-cased whole). The CLI-level proof that `--shout` reaches stdout is TASK-401 (phase 4).
- REQ-021: Met. The upper-casing covers the word, the comma and the name with nothing added or removed (`src/greet.js:41`), proven by `buildGreeting upper-cases the whole line when shout is true` and by the probe output `HELLO, ADA`.
- REQ-030: Met for the renderer slice TASK-202 owns (`count` reaches the renderer and drives the number of lines). The CLI-level `greet --times N` printing N lines is TASK-401 (phase 4).
- REQ-031: Met for the renderer slice TASK-202 owns (exactly `count` lines, each ending with a single `\n`, no blank line at the end). The CLI-level byte sequence is TASK-401 (phase 4).
- REQ-033: Met for the renderer slice TASK-202 owns (a count of one renders the same bytes as no count). The CLI-level byte-for-byte comparison with `greet` and no arguments is TASK-401 (phase 4).
- REQ-050: Met for the renderer slice TASK-202 owns (the text branch prints the line or lines, each ending with `\n`), and for TASK-204's slice (the `text` branch stays as it is when the JSON branch is added). The CLI-level output and the stderr/exit contract are TASK-402 (phase 4).
- REQ-051, REQ-052, REQ-053, REQ-054, REQ-055: Met for the renderer slice TASK-204 owns, each proven by a named test and by the probe. The CLI-level output of the same rules is TASK-402 (phase 4).
- TEST-008: Met. `test/greet.test.js` › `buildGreeting greets in the language of the options` and `buildGreeting upper-cases the whole line when shout is true`.
- TEST-009: Met. `test/greet.test.js` › `renderOutput repeats the greeting line once per count in the text format`, `renderOutput repeats the line exactly count times with no blank line at the end`, `renderOutput prints the compact JSON form with one trailing newline` and `renderOutput joins the repeated lines inside the JSON value`.
- TEST-013: Met for the unit-seam part phase 2 owns (the JSON shape, the compact form and the one-key object are proven by the four JSON tests). The route-level proof (`greet --format json` prints one line on stdout) is TASK-402 (phase 4).

Not started in this phase, owned by a later task (not a gap, and not graded here): REQ-010, REQ-060 to REQ-069, REQ-079, REQ-070 to REQ-078, SEC-001 to SEC-006, CON-001 to CON-006, GUD-001 to GUD-005, PAT-001, TEST-005 to TEST-007, TEST-010 to TEST-012, TEST-014 to TEST-024.

---
SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 1
top:
- REQ-056 🟡 Partial: JSON value follows the shout and count rules, but the name and language rules in the JSON value have no phase-2 test
- REQ-051 ✅ Met: the JSON branch prints exactly {"greeting":"..."} plus one trailing newline
- REQ-055 ✅ Met: JSON.stringify on a one-key object gives the compact form with no space after the colon
- REQ-031 ✅ Met: the text branch prints exactly count lines, each ending with a single newline
- REQ-021 ✅ Met: the assembled line is upper-cased whole, word, comma and name
report: plans/greet-options/reports/phase-2/conformance.md
