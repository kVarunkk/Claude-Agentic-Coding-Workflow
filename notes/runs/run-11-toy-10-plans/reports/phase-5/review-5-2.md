# Review: unit 5 recheck (TASK-501, TASK-502) — greet CLI usage-error contract

Date: 2026-11-20
Base: `e41cadae3c6b475b7138d38f2f3eb80167409df4`
Unit: 5 — TASK-501, TASK-502
Recheck of: `plans/greet-options/reports/phase-5/review-5.md`
Spec: `plans/greet-options/feature-greet-options-spec.md` v0.4

Findings: P0 0 · P1 0 · P2 0 · P3 0    Partitions reviewed: 5

## Index

No open P0 or P1. The one P1 from the previous review (F01) is **fixed**.

## What the fix round did

The staged diff (`git diff --cached e41cadae3c6b475b7138d38f2f3eb80167409df4`) is the previous unit's diff plus the fix round:

- `src/greet.js:184-190` — new `oneLine` helper (`text.replace(/[\r\n]+/g, ' ')`) and `formatUsage` now returns `` `usage: greet [options] ${oneLine(reason)}\n` ``. This is the production change that closes F01.
- `test/greet.test.js:516-522` — new route test `cli keeps the usage line on one line when the offending value holds a newline` (5 assertions: `--lang 'de\nX'`, `--times '03\nX'`, positional `'Ada\nBob'`, `'--name=A\nB'`, `--lang 'de\rX'`).
- `test/greet.test.js:524-530` — new unit test `formatUsage keeps the usage line on one line for a reason holding a newline` (the config-path reason shape).
- `plans/greet-options/feature-greet-options-tasks.md:254-257` — 3 new Differences entries (TASK-501, TASK-502, TASK-502/TEST-023 deferral, and the shared `formatUsage` entry).
- `plans/greet-options/decisions.tsv:46` — one `fix-round` decision row ("fix round started").

Baseline in a scratch copy: **78 tests, 78 pass, 0 fail**.

## F01: fixed

- Previous report: `plans/greet-options/reports/phase-5/review-5.md` F01 — "a value containing a newline makes stderr hold more than one line, contradicting REQ-070 and REQ-072".
- Status: **fixed**.

### Evidence that the defect is gone

Base tree (`--base e41cada` scratch copy), `node bin/greet.js --lang $'de\nX'`:

```
0000000   u   s   a   g   e   :       g   r   e   e   t       [   o
0000020   p   t   i   o   n   s   ]       i   n   v   a   l   i   d       v
0000040   a   l   u   e       f   o   r       -   -   l   a   n   g   :
0000060       d   e  \n   X  \n
0000066
```

Two `\n`, so stderr held two lines. On the staged tree the same input gives:

```
usage: greet [options] invalid value for --lang: de X\n
```

One `\n`. The two new tests fail on the base tree and pass on the staged tree (see Guards), so the fix is load-bearing, not a coincidental green.

### Coverage of the fix

Probed every line-break encoding through `formatUsage` (`\n`, `\r`, `\r\n`, `\n\r`, `\v`, `\f`, U+0085, U+2028, U+2029, U+000B, U+000C): every one yields **exactly one `\n` and no `\r`**. Probed the flag path, the positional path, the `--flag=value` path, the unknown-flag path (a newline inside the *flag* name, e.g. `--na\nme`) and the config path (`{"lang": "de\nX"}`, `{"format": "xml\nX"}`): all hold one line, empty stdout, exit code 2.

The config path is covered by the unit-level `formatUsage` call at `test/greet.test.js:524-530` rather than end to end. That is sufficient: `bin/greet.js:15` is the only `process.stderr.write` in the codebase (`grep -rn "stderr" src/ bin/` returns that one line), so `formatUsage` is the single writer of stderr on every path (spec §4.1 line 284, GUD-004). The end-to-end config route needs the `runIn(cwd, ...)` helper, which belongs to TASK-601; the deferral is already logged in Differences.

### The stdout path was deliberately left alone

A valid `--name` holding a newline still echoes as given (`--name $'A\nB'` → stdout `Hello, A\nB\n`, exit 0). That is spec-intended (REQ-012, SEC-003) and is not part of the stderr contract. Set aside, as in the previous review.

## New P0/P1 problems in the lines the fix touched

None found. Checked specifically:

- **The 18 pinned §4.3 reason strings are still byte-exact.** Probed every flag row of the spec's §4.3 table (`--nmae`, `--help`, `--version`, `Ada`, `--name`, `--name -x`, `--name=Ada`, `--`, `--times 0/abc/03/+2/6/1.5`, `--lang de`, `--lang ES`, `--format xml`, `--name ""`) against the expected stderr: all byte-exact, empty stdout, exit 2. The `oneLine` collapse cannot touch a reason that holds no line break.
- **No gate was loosened.** The test diff has 0 deleted lines (the single `-` match is the `--- a/test/greet.test.js` header), no `.skip` / `only` / `.todo` / `xit`, no relaxed assertion, and no lint, type, CI, coverage or timeout config touched.
- **The fix is at the right layer.** `oneLine` is applied inside `formatUsage`, the single stderr writer, so one change covers the flag path and the config path alike. `parseOptions` and `loadConfig` still produce the reasons spec §4.1 and §4.3 describe, so no other pinned output changed.
- **The previous round's guards got stronger, not weaker.** Every guard mutation from `review-5.md` still turns the suite red, with a higher failure count than before (the new tests added pinning):

| mutation | before (review-5) | now |
|---|---|---|
| prefix `usage: greet [options] ` → `usage: greet [opts] ` | 18 red | **20 red** |
| exit code `process.exitCode = 2` → `1` | 18 red | **19 red** |
| trailing `\n` removed from the usage line | 18 red | **20 red** |
| stdout leak on the usage path | 18 red | **19 red** |
| reason `invalid flag syntax:` → `bad flag syntax:` | 2 red | **3 red** |
| reason `invalid argument: --` → `invalid arg: --` | 2 red | **2 red** |
| reason `unexpected argument:` → `stray argument:` | (not run) | **3 red** |
| reason `invalid value for ${arg}:` → `bad value for ${arg}:` | (not run) | **5 red** |
| reason `missing value for ${arg}` → `no value for ${arg}` | (not run) | **7 red** |

- **The new fix-round tests are load-bearing.** Removing `oneLine` from `formatUsage` turns 2 tests red (`test/greet.test.js:516` and `:524`); replacing the collapse with `''` turns 2 red; dropping `\r` from the character class turns 1 red; changing the replacement from `' '` to `''` turns 2 red.

## Scope

`Scope: clean` — every changed file is in the unit's Files column (`src/greet.js`, `test/greet.test.js`, both named in TASK-501 and TASK-502) or is the plan bookkeeping that carries the ticks, the Differences log and the decision trail (`plans/greet-options/feature-greet-options-tasks.md`, `plans/greet-options/decisions.tsv`, and the staged previous review report `plans/greet-options/reports/phase-5/review-5.md`). No fixture directory was created or changed. No behaviour beyond the two task rows and the closing of F01 was added.

### Differences entries checked

- TASK-501 / TASK-502 "the Red cases pass as soon as they are written, so the end-to-end layer only needed the tests" — **accurate** for the pre-fix state; verified against the base tree (the 17 route cases pass on base production code) and the new tests fail on base (so they are Guard tests against the fix, as intended).
- TASK-501 "the prefix mutation fails 18 tests, the exit code mutation fails 18 tests, and each reason mutation fails the tests that pin that reason" — **accurate as written** for the pre-fix tree; the counts are now 20 / 19 / per-reason, which is a consequence of the two new tests, not a contradiction.
- TASK-502 (TEST-023) deferral of the config half to TASK-602 — **accurate** (TASK-602's Red list names the `top-level-array` route case; `runIn` belongs to TASK-601).
- The shared `formatUsage` entry — **accurate**. Verified against the spec text: §4.1 line 283 does say `` Returns `usage: greet [options] ${reason}` ``, and the entry correctly names REQ-070 and REQ-072 as the absolute requirements that win over it, correctly states that every §4.3 pinned reason stays byte-for-byte the same (verified by the 18-row probe above), and correctly states that the stdout path is untouched (REQ-012, SEC-003). The spec is silent on what a newline-bearing value should look like in a reason, so this is a documented gap-fill, not a contradiction of a pinned output.

### One deliberate spec deviation, logged and correct

`formatUsage` no longer returns the reason verbatim as §4.1 line 283 states. That is a real deviation from one descriptive sentence in §4.1, but it makes REQ-070 and REQ-072 (both absolute: "writes exactly one line", "stderr never holds more than one line") hold in more cases, leaves the REQ-071 prefix and the reason shape unchanged, and leaves all 21 §4.3 table rows byte-identical. The deviation is logged under Differences with the reason and the choice made. Logging a deviation is not by itself authorisation, so I checked the cause myself: the cause is real (REQ-070/REQ-072 are absolute and the spec is silent on newline values), and the resulting behaviour is now tested at both the unit and route level. Accepted.

## Guards

All mutations ran in scratch copies (`/tmp/mut-5r` for the staged tree, `/tmp/mut-5r-base` for the base tree), never in the repo, with `TEST_CMD="npm test"` from `.dostuff/pipeline.conf`. Both copies and all probe scripts were deleted afterwards; no process was left running. Mutation count: 11.

- mutation: `formatUsage` drops `oneLine`, `reason` interpolated raw -> test red (2 failed)
- mutation: `oneLine` replaces the break with `''` instead of `' '` -> test red (2 failed)
- mutation: `oneLine` character class loses `\r` -> test red (1 failed)
- mutation: `oneLine` `+` quantifier dropped (`[\r\n]+` → `[\r\n]`) -> test green (equivalent, see below)
- mutation: usage prefix `usage: greet [options] ` → `usage: greet [opts] ` -> test red (20 failed)
- mutation: usage line trailing `\n` removed in `formatUsage` -> test red (20 failed)
- mutation: exit code `process.exitCode = 2` → `1` in `bin/greet.js` -> test red (19 failed)
- mutation: usage path also writes `LEAK` to stdout in `bin/greet.js` -> test red (19 failed)
- mutation: reason `invalid flag syntax: ${arg}` → `bad flag syntax: ${arg}` -> test red (3 failed)
- mutation: reason `invalid argument: --` → `invalid arg: --` -> test red (2 failed)
- mutation: reason `unexpected argument: ${arg}` → `stray argument: ${arg}` -> test red (3 failed)
- mutation: reason `invalid value for ${arg}: ${value}` → `bad value for ${arg}: ${value}` -> test red (5 failed)
- mutation: reason `missing value for ${arg}` → `no value for ${arg}` -> test red (7 failed)

mutations: 11 run, 1 still green

**The one green mutant is equivalent.** `[\r\n]+` → `[\r\n]` changes the output only for a value holding *consecutive* line breaks (`de\n\nX` renders as `de X` under `+` and `de  X` without it). It cannot change the one-line guarantee (both forms still remove every `\r` and `\n`), the fixed prefix, the exit code, or any reason string pinned by §4.3, TEST-015 or TEST-023, because no cited REQ, SEC or TEST id in this unit's Spec column (REQ-011, REQ-032, REQ-040, REQ-070, REQ-071, REQ-072, REQ-074, SEC-005, TEST-015, TEST-023) constrains the reason for a value with consecutive line breaks. No test uses consecutive line breaks (`grep` over `test/greet.test.js` finds none). It is therefore equivalent on every output a cited requirement constrains, and it is not a P1 test gap.

## Open questions

Q01 (carried from the previous review, now resolved by the fix): "Does the spec want a value containing a newline to be rejected with a fixed reason (Option A) or to have its newline collapsed (Option B)?" — the fix took Option B (collapse to a space) and logged the choice under Differences. The spec still does not state a preference; the choice is consistent with REQ-070/REQ-072 and leaves every pinned reason unchanged, so it does not block this unit. Blocking: no.

## Set aside

- The `oneLine` collapse maps *consecutive* breaks to one space, so `de\n\nX` renders as `de X`. A per-break mapping would render `de  X`. Neither is pinned by any spec id; not a defect.
- `oneLine` leaves a trailing space when the whole value is a line break (`--lang $'\n'` → `invalid value for --lang:  `). Cosmetic; the line is still one line.
- The new test at `test/greet.test.js:516` bundles five assertions in one `node:test` case, so a failure in the first stops the rest. Test-design nit, not a defect.
- `assertUsageError`'s `err.stderr.split('\n').length === 2` assertion is redundant with the exact-string comparison on the line above. P3 nit, not reported.
- The config path's one-line rule is proven at the unit seam (`formatUsage`) rather than end to end. Sufficient, because `formatUsage` is the only stderr writer (see "Coverage of the fix").
- A valid `--name` holding a newline echoes to stdout with an embedded newline. Spec-intended (REQ-012, SEC-003); the stdout path is out of the stderr contract.
- `decisions.tsv` carries only the "fix round started" row; the closing row is added at commit time, matching the unit-4 pattern (`53f32ec` logged both). Not a defect.

## Checked and fine

- Gate integrity: 0 deleted test lines; no `.skip` / `only` / `.todo` / `xit`; no relaxed assertion; no lint, type or CI config touched; no coverage or timeout threshold lowered.
- Task-row fidelity: all 17 required route cases present with the exact reason strings each row names (7 for TASK-501, 10 for TASK-502), checked one by one against the task text.
- `oneLine` is private to `src/greet.js` and not exported, so it adds no public surface (CON-004).
- The fix touches one function plus one helper; `parseOptions`, `loadConfig`, `mergeOptions`, `buildGreeting` and `renderOutput` are byte-identical to the base.
- `check-plan.sh plans/greet-options` passes: "50 REQ/SEC ids, 19 tasks. OK".
- Tick format matches the file's convention (`[x]` plus the ISO date 2026-11-20); TASK-601 and TASK-602 remain `[ ]`.
- No fixture directory was created, changed or deleted; `test/fixtures/` is untouched.
- The repository working tree was not modified by this review: only `plans/greet-options/reports/phase-5/review-5-2.md` was written. Both scratch copies were deleted.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 0
scope: clean
mutations: 11 run, 1 still green
top:
- (none: F01 from review-5.md is fixed and no new P0/P1 was found)
report: plans/greet-options/reports/phase-5/review-5-2.md
