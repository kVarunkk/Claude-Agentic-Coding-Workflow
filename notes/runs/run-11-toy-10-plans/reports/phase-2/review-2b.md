# Review: unit 2b (TASK-204) — the JSON rendering branch (d70d306 → staged)

Date: 2026-11-20
Unit: 2b / TASK-204 (Phase 2b, GOAL-003)
Files changed: `src/greet.js`, `test/greet.test.js`, `plans/greet-options/feature-greet-options-tasks.md` (tick only)

Findings: P0 0 · P1 0 · P2 0 · P3 0    Partitions reviewed: 6

### Index

No findings. The unit implements exactly what TASK-204 asks for, the tests are genuinely red on the base commit and green after, and every behaviour the unit claims is guarded by a mutation-verified test.

Partitions reviewed:
1. JSON branch selection (text vs json dispatch)
2. Exact byte shape of the JSON line (REQ-051, REQ-055)
3. Count handling and the joined value (REQ-052, REQ-053)
4. Object shape, exactly one key (REQ-054)
5. Interaction with `buildGreeting`: name, shout, lang (REQ-056)
6. Scope, tick, plan integrity, preserved text branch (REQ-050, REQ-002)

### Guards

Nine mutations run in a scratch copy (`/tmp/mut-2b`, deleted afterwards), each breaking one behaviour the unit claims, then `node --test test/greet.test.js` in the foreground.

- mutation: remove the `format: 'json'` branch entirely (json falls through to text) -> 4 new JSON tests red
- mutation: keep a trailing `\n` inside the JSON string -> 3 tests red
- mutation: put a space after the colon (`{"greeting": "..."}`, the brief's form) -> 3 tests red
- mutation: add a second key to the object (`count`) -> 4 tests red
- mutation: drop the trailing `\n` after the JSON object -> 3 tests red
- mutation: rename the key `greeting` to `message` -> 4 tests red
- mutation: nest the value (`greeting: { text: value }`) instead of a flat string -> 3 tests red
- mutation: use only the first line, no join -> 1 test red
- mutation: read the count from `options.times` instead of `greeting.count` -> **green (equivalent mutant, see below)**

Nine run, one still green. The one green mutant is equivalent, with reason below.

**Equivalent mutant (m5, count from `options.times` instead of `greeting.count`).** It stays green because it cannot change any output reachable in the product. The spec's entry point (§4.2) calls `const greeting = buildGreeting(options); process.stdout.write(renderOutput(options, greeting));` with the *same* `options` object, and `buildGreeting` sets `count: options.times` (spec §4.1, `buildGreeting` bullet; `src/greet.js:42`). So `greeting.count === options.times` holds on every production path, and substituting one for the other is a no-op. Verified by construction over the whole legal count range (1 to 5): `greeting.count === options.times` is `true` in every case. The implementation uses `greeting.count`, which is what the spec (§4.1 `renderOutput` bullet) and the TASK-204 Green text both name as the source of truth, so the code is right and the mutant is equivalent, not a gap.

**Red-then-Green confirmed.** Copying the new `test/greet.test.js` onto the base tree (`d70d306`) and running it gives 24 pass / 4 fail: exactly the four new JSON tests fail, the 24 pre-existing tests pass. The change is real test-first work, not tests written to fit the code.

### Scope: clean

- `src/greet.js` and `test/greet.test.js` are both named in TASK-204's Files column.
- The only edit to `src/greet.js` is the `format: 'json'` branch plus the comment move: the comment `// Each printed line ends with a single \n...` was above `renderOutput` and describes only the text branch, so moving it inside is a correct placement, not a refactor.
- The `text` branch is byte-identical to the base. Verified for counts 1 to 5: `Hello, world\n`, `Hello, world\nHello, world\n`, and so on, unchanged.
- `module.exports` is unchanged; no export was added, removed or renamed.
- The edit to `plans/greet-options/feature-greet-options-tasks.md` is the status tick only (`[ ]` → `[x]`, date `2026-11-20`).
- No Differences entry was added, and none was needed: the implementation matches the spec with no divergence.
- `bash .dostuff/scripts/check-plan.sh plans/greet-options` → `OK` (50 REQ/SEC ids, 15 tasks).
- No behaviour beyond the tasks was added.

### Checked and fine

- **REQ-051 (exactly one line).** For `times: 3` the JSON output holds exactly one real newline (the terminator); the inner separators are the two-character escape `\n`, so stdout is one physical line. Counted: `out.match(/\n/g).length === 1`, and `out.endsWith('\n') && !out.endsWith('\n\n')`.
- **REQ-052 (count 1).** `count: 1` yields `{"greeting":"Hello, world"}\n`, the single line with no trailing newline inside the string. The implementation uses one uniform `Array.from({ length: greeting.count }, () => greeting.line).join('\n')` rather than the two cases the task row describes; for count 1 a one-element join is the line itself, so the bytes are identical to the specified "single `greeting.line`" case.
- **REQ-053 (count > 1).** `count: 2` yields `{"greeting":"Hello, world\nHello, world"}\n` with no trailing newline inside the string.
- **REQ-054 (exactly one key).** `Object.keys(JSON.parse(out))` is `['greeting']` in all nine option combinations tried (count 1/2/3/5, shout on and off, each language, custom name). The mutation that added a `count` key was caught by the one-key test.
- **REQ-055 (compact form).** `JSON.stringify` on `{ greeting: value }` gives no space after the colon. The mutation that added the space was caught.
- **REQ-056 (same name, shout, language and count rules).** The shout rule lives in `buildGreeting` (spec architecture step 4), and `renderOutput` (step 5) emits `greeting.line` verbatim. Driving `buildGreeting` + `renderOutput` together, as the CLI will, gives `{"greeting":"HELLO, ADA"}\n` for `--name Ada --shout`, `{"greeting":"HOLA, ADA"}\n` for `es` + shout, `{"greeting":"Bonjour, Ada"}\n` for `fr`, and the upper-cased line repeated for `times: 3`. The unit test passes an already-uppercased `line`, which is the renderer's actual contract.
- **JSON validity with awkward names (REQ-012, SEC-003).** `JSON.stringify` escapes correctly. Names containing a double quote, a backslash and a real newline all round-trip: `JSON.parse(out).greeting === greeting.line` was `true` in every case, and every output parsed as valid JSON.
- **Unreachable inputs do not throw.** `Array.from({ length: n })` with a negative, fractional, `NaN` or `undefined` length returns an array rather than throwing. `count: 0` yields `{"greeting":""}\n`, valid JSON. `times` is validated to an integer 1 to 5 by `validateTimes` (REQ-032), so these are unreachable in production.
- **Existing behaviour preserved.** All 24 pre-existing tests pass unchanged (TASK-202's text-format tests, TASK-201's `buildGreeting` tests, TASK-101/102's parser tests, and the three original `greet`/CLI tests). No test was deleted, skipped, or given a relaxed assertion. The count of tests went 24 → 28, all additive.
- **Repo conventions.** No `CLAUDE.md`, no lint or format config; `npm test` (`node --test`) is the only gate and it passes 28/28. The new code follows the file's existing style (CommonJS, `const`, template literals, one comment above the branch explaining the pinned form).

### Open questions

None. No blocking questions.

### Set aside

- `count: 0` producing `{"greeting":""}\n` — unreachable: `times` is capped at 1 to 5 by REQ-032 and `validateTimes`.
- The one green mutation (count source) — equivalent mutant, reason given in Guards above; the code follows the spec's named source of truth.
- The CLI does not call `renderOutput` yet (`bin/greet.js` still uses the old ad-hoc `--name` lookup). That is Phase 4's job (TASK-401), not this unit's.

### Not checked

- The end-to-end CLI behaviour of `--format json` (TEST-013) and the config-driven path (REQ-060 to REQ-079), which belong to Phases 4 to 7 and are out of this unit's Files column.
- Whether `mergeOptions` (Phase 3) keeps `times` a number so `buildGreeting` sets a numeric `count`; the equivalent-mutant argument above holds as long as it does, and `parseOptions` already returns a number (`src/greet.js:14`).

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
scope: clean
mutations: 9 run, 1 still green
top:
- (none) no P0/P1/P2 findings; the single green mutation is an equivalent mutant (count source `options.times` vs `greeting.count`) and is explained in the Guards section
report: plans/greet-options/reports/phase-2/review-2b.md
