# Review: unit 3 (TASK-301, TASK-302) recheck (83e91a7 -> staged)

Date: 2026-11-20
Unit: 3, tasks TASK-301 (`loadConfig`), TASK-302 (`mergeOptions`)
Base: 83e91a7c3a9f4170331d31a85af9afd72c7aaa2a (staged diff reviewed)
Recheck of: plans/greet-options/reports/phase-3/review-3.md

Findings: P0 0 · P1 0 · P2 1 · P3 1    Partitions reviewed: 4

### Index
1. [P2][Low]  F03 (carried over, still open): the "config file cannot be read" branch is still unguarded; the mutant stays green `src/greet.js:147`
2. [P3][Nit]  F04: `plans/greet-options/reports/phase-3/stray-3.md` is a transient artifact of a failed `stage-unit.sh` run and is now stale `plans/greet-options/reports/phase-3/stray-3.md:1`

### Recheck of the previous findings

| Previous | Status | Evidence |
|---|---|---|
| F01 [P1] `CONFIG_VALIDATORS[key]` hit `Object.prototype` members | **fixed** | `src/greet.js:170` now guards the lookup with `Object.hasOwn(CONFIG_VALIDATORS, key)`. Probe over every inherited member name returns only the known keys, no crash: `toString`/`constructor`/`valueOf`/`hasOwnProperty`/`isPrototypeOf`/`propertyIsEnumerable`/`toLocaleString` -> `{"name":"Ada"}`, lone `{"__proto__":1}` -> `{}`. Mutation removing the guard is red (2 tests fail). |
| F02 [P1] config `times` upper bound (1 to 5) unguarded | **fixed** | Fixture `test/fixtures/times-six/greet.config.json` (`{"times": 6}`) added and asserted in the count test (`test/greet.test.js`, `times-six` -> `invalid value for times: 6`). Mutation dropping `value > 5` is now red. |
| F03 [P2] unreadable `greet.config.json` untested | **still open** | The implementation is correct (EISDIR -> `UsageError` with reason `invalid greet.config.json`), but the mutation "any read error treated as file absent" is still green. Kept at P2: no task row or TEST id asks for this case. |

No new P0 or P1 was found in the lines the fixes touched, or elsewhere in the changed code.

### F03: the "config file cannot be read" branch is still unguarded
- Severity / confidence: P2 / Low
- Location: `src/greet.js:147` (the `err.code === 'ENOENT'` branch in `loadConfig`).
- Lens: tests
- Failure: spec §4.1 line 253 says "A JSON parse failure, or a file that cannot be read, throws a `UsageError` whose reason is `invalid greet.config.json` (REQ-066)." The implementation does this, but the only guard is the ENOENT branch: making any read error return `{}` instead of throwing leaves the whole suite green.
  ```
  mutation: any read error treated as "file absent" -> npm test green (47 pass, 0 fail)
  ```
  Reaching the branch needs a config path that exists but cannot be read (EACCES on POSIX, EISDIR when `greet.config.json` is a directory). The EISDIR case works today:
  ```
  EISDIR => THREW UsageError reason= "invalid greet.config.json"
  ```
  but nothing asserts it.
- Evidence: the mutation above, plus the EISDIR probe output.
- Fix: assert the behaviour directly in a unit test that points `loadConfig` at a directory containing a subdirectory named `greet.config.json`, or leave the branch as is since no task row or TEST id asks for this case.

### F04: `stray-3.md` is a stale transient artifact
- Severity / confidence: P3 / Nit
- Location: `plans/greet-options/reports/phase-3/stray-3.md:1`
- Lens: scope
- Failure: the file is the stdout of a failed `.dostuff/scripts/stage-unit.sh` run (it prints "unit 3: changed files outside its Files column and not logged under Differences:" followed by "nothing staged" and exits 1). It was staged because everything under the plan directory is "owned" by `stage-unit.sh`. It is now also inaccurate: it claims `test/fixtures/unknown-key-proto/greet.config.json` is not logged under Differences, but the third Differences entry in the tasks file logs exactly that file. The file says nothing about the code and no test reads it, so there is no behaviour impact.
- Evidence: `git diff --cached -- plans/greet-options/reports/phase-3/stray-3.md`; `.dostuff/scripts/stage-unit.sh:49-52`.
- Fix: delete the file before the commit (it is a pipeline byproduct, not a unit artefact). No prior unit has committed one.

### Tests
- The suite is now 47 tests (was 46). The new test `loadConfig ignores an unknown key that names an Object.prototype member` covers both the `toString`-beside-a-valid-`name` case and the lone `__proto__` case.
- No existing test was deleted, skipped or relaxed: `git diff --cached BASE -- test/greet.test.js` and `-- src/greet.js` contain no `-` lines, both files are purely additive.
- The `times` count test now pins four cases (`times-zero`, `times-string`, `times-fraction`, `times-six`), so the full 1-to-5 range is guarded.
- Still missing (F03): an unreadable config file.

### Guards
Scope: clean
Scope note: every changed file is listed in TASK-301's or TASK-302's Files column, or is logged under **Differences from the spec** in `plans/greet-options/feature-greet-options-tasks.md`:
- `test/fixtures/times-six/greet.config.json` is listed in TASK-602's Files column; the third Differences entry explains it belongs to TASK-301's validator and is reused by TASK-602.
- `test/fixtures/unknown-key-inherited/greet.config.json` and `test/fixtures/unknown-key-proto/greet.config.json` are outside the Files column; the second and third Differences entries name both.
The only edits to the tasks file are the two Status ticks (`[ ]` -> `[x]`) with the Done date, plus the three new Differences entries. No task text, spec id or fixture list was narrowed. No behaviour beyond the two tasks was added: `loadConfig` and `mergeOptions` are new exports, `bin/greet.js` is untouched, and no existing export changed behaviour.

Mutation results (all in a scratch copy of the staged tree, `npm test`, Node v22.20.0, 47 tests):
- mutation: own-property guard removed (prototype members treated as known keys) -> red (2 tests fail)
- mutation: config `times` upper bound (`value > 5`) removed -> red
- mutation: config `times` integer check removed -> red
- mutation: config `times` lower bound removed -> red
- mutation: config `name` type check removed -> red
- mutation: config empty-`name` check removed -> red
- mutation: config `lang` allowed list widened -> red
- mutation: config `shout` accepted a string -> red
- mutation: config `format` allowed list removed -> red
- mutation: explicit `null` top-level rejection dropped -> red
- mutation: top-level array allowed -> red
- mutation: `JSON.parse` failure swallowed -> red
- mutation: any read error treated as "file absent" -> green (F03, P2)
- mutation: `mergeOptions` lets a flag set `shout` to `false` -> red
- mutation: `mergeOptions` drops the config layer -> red
- mutation: `mergeOptions` drops the flag layer -> red
- mutation: `mergeOptions` does not start from `DEFAULT_OPTIONS` -> red
- mutation: `mergeOptions` applies the config spread after the flags -> red

### Checked and fine
- The `Object.hasOwn` own-key guard: every `Object.prototype` member name (`toString`, `constructor`, `valueOf`, `hasOwnProperty`, `isPrototypeOf`, `propertyIsEnumerable`, `toLocaleString`) is now ignored, and the valid `name` beside it still reaches the result. `JSON.parse` creates `__proto__` as an own data property and `Object.entries` sees it, so the lone-`__proto__` fixture really exercises the path (probe: `entries of parsed __proto__: [ [ '__proto__', 1 ] ]`).
- No prototype pollution through `mergeOptions`: the object spread uses `CreateDataProperty`, so a `__proto__` key in a config object does not set the prototype (probe: `polluted = undefined`).
- `mergeOptions` never mutates `DEFAULT_OPTIONS` (the spread copies) and returns exactly the five known keys.
- `mergeOptions` cannot turn a config `shout: true` off (REQ-076); the test pins all three directions, and a config `shout: false` with `--shout` still ends up `true`.
- `loadConfig` reads the file exactly once with `fs.readFileSync` and parses with `JSON.parse` (REQ-065, SEC-004).
- The top-level `null` rejection (the hole the task's Review focus #2 names) is correct and mutation-guarded; the same probe shows the other non-object top levels (`"hello"`, `42`, `true`, `false`) are all rejected with `invalid greet.config.json`.
- Every invalid value type reaches a `UsageError` with a sensible reason and never a `TypeError`: `name: true` -> `invalid value for name: true`, `name: null` -> `invalid value for name: null`, `shout: null`, `times: null`, `times: true`, `times: 6.0` -> `invalid value for times: 6`, `times: -1`, `lang: ""` -> `invalid value for lang: `, `format: ""`, `name: {"a":1}` -> `invalid value for name: [object Object]`.
- `Object.hasOwn` is available on Node 16.9+, so the Node 22 constraint (CON-001, DEP-001) holds.
- The `unknown-key` fixture (`{"name": "Ada", "unknownKey": 1}`) matches what TASK-702's Red text expects of it, so TASK-702 can reuse it without a change.

### Set aside
- The reason for a config `times` of `"3"` renders as `invalid value for times: 3`, indistinguishable from the number `3`. The number `3` is always valid, so there is no collision, and the spec pins the reason shape rather than a quoting rule.
- `mergeOptions` does not validate the config layer itself; the unit relies on `loadConfig` having validated first, which TASK-302's Green text states explicitly. A caller passing an unvalidated config could leak an unknown key into the option record, but no such caller exists and REQ-069 places the validation in `loadConfig`.
- `loadConfig(cwd)` with a `cwd` that does not exist returns `{}` (ENOENT), indistinguishable from "no config file". The spec does not distinguish these.
- The allowed `lang` and `format` values are written in three places (`GREETING_WORDS`, `OPTION_SPECS`, `CONFIG_VALIDATORS`). The duplication was already two-way at BASE; this unit adds the third site because the config path needs its own rules, which the spec asks for (§4.1). A shared constant would be tidier, but the spec's own design makes the duplication deliberate.

SUMMARY
verdict: pass
p0: 0
p1: 0
p2: 1
scope: clean
mutations: 18 run, 1 still green
top:
- F03 [P2] src/greet.js:147 the unreadable-config branch is still untested; the mutant stays green
report: plans/greet-options/reports/phase-3/review-3-2.md