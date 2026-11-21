# Review: unit 3 (TASK-301, TASK-302) (83e91a7 -> staged)

Date: 2026-11-20
Unit: 3, tasks TASK-301 (`loadConfig`), TASK-302 (`mergeOptions`)
Base: 83e91a7c3a9f4170331d31a85af9afd72c7aaa2a (staged diff reviewed)

Findings: P0 0 · P1 2 · P2 1 · P3 0    Partitions reviewed: 4

### Index
1. [P1][High] F01: `loadConfig` treats `Object.prototype` member names as known config keys, so an unknown key such as `toString`, `constructor` or `__proto__` crashes with an uncaught `TypeError` or a garbage usage reason `src/greet.js:168`
2. [P1][Med]  F02: the config `times` upper bound (1 to 5) is unguarded: dropping `value > 5` from the validator leaves the whole suite green `src/greet.js:129`
3. [P2][Low]  F03: an unreadable `greet.config.json` is untested; the read-error branch only distinguishes ENOENT `src/greet.js:147`

### F01: `loadConfig` treats `Object.prototype` member names as known config keys
- Severity / confidence: P1 / High
- Location: `src/greet.js:168` (`loadConfig`, the `CONFIG_VALIDATORS[key]` lookup). Also affects `src/greet.js:117` (the `CONFIG_VALIDATORS` literal) and `src/greet.js:172` (`throw new UsageError(problem)`).
- Lens: correctness | security | spec
- Failure: `CONFIG_VALIDATORS` is a plain object literal, so it inherits `Object.prototype`. The lookup at line 168 therefore finds a truthy "validator" for a key that is not one of the five known keys, and the code calls it as a function:
  - `{"__proto__": 1}` -> `validate` is `Object.prototype`, not a function -> uncaught `TypeError: validate is not a function`.
  - `{"valueOf": 1}` / `{"hasOwnProperty": 1}` -> the inherited method returns `undefined`, which is falsy, so `config[key] = value` runs and the inherited value reaches the option record; the template-literal coercion in the reason path throws `TypeError: Cannot convert undefined or null to object`.
  - `{"toString": 1}` -> `validate(value)` returns the string `"[object Undefined]"`, truthy -> throws `UsageError` whose `reason` is `"[object Undefined]"`, so the usage line would read `usage: greet [options] [object Undefined]`.
  - `{"constructor": 1}` -> `Object(1)` returns a `Number` wrapper object, truthy -> throws `UsageError` whose `reason` is the number `1`, so the usage line would read `usage: greet [options] 1`.
  A config with a perfectly valid `name` plus an unknown key, e.g. `{"name": "Ada", "toString": 1}`, also fails: the whole file is rejected, so the valid `name` never reaches the output.
- Evidence: probe in a scratch copy of the staged tree:
  ```
  toString       => threw UsageError reason= "[object Undefined]"
  constructor    => threw UsageError reason= 1
  __proto__      => threw TypeError reason= undefined msg= validate is not a function
  valueOf        => threw TypeError reason= undefined msg= Cannot convert undefined or null to object
  hasOwnProperty => threw TypeError reason= undefined msg= Cannot convert undefined or null to object
  {"name": "Ada", "toString": 1} => THREW UsageError reason= "[object Undefined]"
  ```
  This breaks three cited requirements:
  - REQ-061: "A key that is not one of these five is ignored and does not cause an error." Here an unknown key causes an error, and the `TypeError` variants are not a usage error at all.
  - REQ-062 / REQ-070: "An invalid value for any of the five known keys is a usage error: one usage line to stderr, nothing to stdout, exit code 2." An uncaught `TypeError` produces a stack trace on stderr and a non-2 exit code.
  - SEC-004: "A parse failure is reported as a usage error (REQ-066), so the file contents never appear in the error output." The `toString` and `constructor` variants put the offending value (`1`) into the reason as a bare, unlabeled token.
  It also defeats the point of the task file's own Review focus #2: "A config file that is present but broken (`null` at the top level, or `{"times": "3"}`) makes the CLI crash with a `TypeError` stack trace instead of a usage line, because `typeof null === 'object'`. Test in TASK-301." The `null` hole is plugged, but the same crash class survives for a different reason, so TASK-301 does not deliver the guarantee it claims.
  Spec §4.1 states the intent plainly: "Reads only the five known keys and ignores every other key (REQ-061, D-15). Ignored keys are not validated."
- Fix: make the known-key lookup own-property only. Either build the map with a null prototype,
  ```js
  const CONFIG_VALIDATORS = Object.assign(Object.create(null), { name: ..., shout: ..., times: ..., lang: ..., format: ... });
  ```
  or keep the literal and guard the lookup with an own-property test (available on Node 22, CON-001):
  ```js
  if (!Object.hasOwn(CONFIG_VALIDATORS, key)) { continue; }
  const validate = CONFIG_VALIDATORS[key];
  ```
  Add a fixture `test/fixtures/unknown-key-inherited/greet.config.json` holding `{"name": "Ada", "toString": 1}` with a test that `loadConfig` on it returns `{ name: 'Ada' }`, and one that a fixture holding `{"__proto__": 1}` returns `{}`.

### F02: the config `times` upper bound (1 to 5) is unguarded
- Severity / confidence: P1 / Med
- Location: `src/greet.js:129` (the `times` validator in `CONFIG_VALIDATORS`). The missing test belongs in `test/greet.test.js` (the `loadConfig` count test, currently at line 298).
- Lens: tests | spec
- Failure: REQ-068 (cited in TASK-301's Spec column) says the config `times` "must be a JSON number that is an integer from 1 to 5. ... a number outside 1 to 5 ... are usage errors." The implementation is correct, but the test suite does not pin the upper bound. TASK-301's Red list covers `{"times": 0}`, `{"times": "3"}` and `{"times": 2.5}`, never `{"times": 6}`; the `times-six` fixture belongs to TASK-602's Files column, so at this unit the config validator's range check has no test.
- Evidence: mutation in a scratch copy of the staged tree, dropping the `value > 5` clause from the `times` validator:
  ```
  mutation: config times upper bound (value > 5) removed -> npm test green (46 pass, 0 fail)
  ```
  and the mutant really changes the behaviour:
  ```
  MUTANT loadConfig times:6 -> {"times":6}
  ORIGINAL loadConfig times:6 -> UsageError invalid value for times: 6
  ```
  So the guard test does not guard the behaviour, and a green mutation breaks behaviour a cited REQ states.
- Fix: add a fixture `test/fixtures/times-six/greet.config.json` holding `{"times": 6}` (the directory name is already reserved in the task file's Decisions row and in TASK-602's Files column) and one assertion in the existing count test:
  ```js
  ['times-six', 'invalid value for times: 6'],
  ```
  Note that TASK-602 will then also reference the same fixture directory, which is fine and keeps the two units consistent.

### F03: an unreadable `greet.config.json` is untested
- Severity / confidence: P2 / Low
- Location: `src/greet.js:147` (the `err.code === 'ENOENT'` branch in `loadConfig`).
- Lens: tests
- Failure: spec §4.1 says "A JSON parse failure, or a file that cannot be read, throws a `UsageError` whose reason is `invalid greet.config.json` (REQ-066)." The implementation does this correctly, but the only guard is the ENOENT branch: making any read error return `{}` instead of throwing leaves the whole suite green.
  ```
  mutation: any read error treated as "file absent" -> npm test green (46 pass, 0 fail)
  ```
  Reaching the branch needs a config path that exists but cannot be read (EACCES on POSIX, EISDIR when `greet.config.json` is a directory). The EISDIR case works today:
  ```
  EISDIR threw UsageError invalid greet.config.json
  ```
  but nothing asserts it.
- Evidence: the mutation above, plus the probe output for the EISDIR path.
- Fix: either add a fixture whose `greet.config.json` is a directory (not portable to a plain-file fixture layout), or assert the behaviour directly in a unit test that points `loadConfig` at a directory containing a subdirectory named `greet.config.json`. If the fixture is judged too awkward, the branch can be left as is, since no task row or TEST id asks for this case.

### Tests
- The eleven invalid-value fixtures and the two top-level fixtures cover REQ-066, REQ-067, REQ-079 and the REQ-062 rules for `name`, `shout`, `lang` and `format`; each of those rules is individually mutation-guarded (see Guards).
- Missing: a config `times` above 5 (F02), an unknown key whose name is an `Object.prototype` member (F01), and an unreadable config file (F03).
- The `mergeOptions` tests are adequate for TASK-302: the flag-overrides-only-its-own-key rule, the all-defaults case and the "shout never off" rule are all guarded, and the two natural regressions (config dropped, flags dropped) both turn the suite red.
- The `loadConfig` "ignores an unknown key" test uses only a safe key name (`unknownKey`), which is why F01 slipped through.

### Guards
Scope: clean
Scope note: every changed file is listed in TASK-301's or TASK-302's Files column. The only change to `plans/greet-options/feature-greet-options-tasks.md` is the Status tick (`[ ]` -> `[x]`) plus the Done date; no task text, spec id or fixture list was narrowed. No behaviour beyond the two tasks was added: `loadConfig` and `mergeOptions` are new exports, `bin/greet.js` is untouched, and no existing export changed behaviour.

Mutation results (all in a scratch copy, `npm test`, Node 22):
- mutation: explicit `null` top-level rejection dropped -> red (`loadConfig rejects a top level that is not a plain object`)
- mutation: unknown config keys no longer ignored -> red (`loadConfig ignores an unknown key`)
- mutation: config `times` upper bound (`value > 5`) removed -> green  (F02)
- mutation: config `name` type check removed -> red (`loadConfig rejects a name that is not a string`)
- mutation: config empty-`name` check removed -> red (`loadConfig rejects an empty name`)
- mutation: config `lang` allowed list widened -> red (`loadConfig rejects an unsupported language`)
- mutation: config `shout` accepted a string -> red (`loadConfig rejects a shout value that is not a boolean`)
- mutation: config `format` allowed list removed -> red (`loadConfig rejects an unsupported format`)
- mutation: config `times` integer check removed -> red (`loadConfig rejects a count that is not an integer from 1 to 5`)
- mutation: config `times` lower bound removed -> red (`loadConfig rejects a count that is not an integer from 1 to 5`)
- mutation: top-level array allowed -> red (`loadConfig rejects a top level that is not a plain object`)
- mutation: `JSON.parse` failure swallowed -> red (`loadConfig rejects a top level that is not a plain object`)
- mutation: any read error treated as "file absent" -> green  (F03)
- mutation: `mergeOptions` lets a flag set `shout` to `false` -> red (`mergeOptions never turns a shout off`)
- mutation: `mergeOptions` drops the config layer -> red (two merge tests)
- mutation: `mergeOptions` drops the flag layer -> red (two merge tests)
- mutation: `mergeOptions` applies the config spread after the flags -> green, but equivalent (the flag loop re-applies the flags, so the output is identical for every input; not counted as a gap)

### Checked and fine
- The explicit `null` rejection for a top-level `null` config, which is the specific hole the task's Review focus #2 names: the check `parsed === null || typeof parsed !== 'object' || Array.isArray(parsed)` is correct and is mutation-guarded.
- The invalid-JSON path (`JSON.parse` failure -> `invalid greet.config.json`) and the top-level array, string, number and boolean paths: all produce the pinned reason.
- The empty-file case (`""` -> `invalid greet.config.json`): correct, since an empty file is not valid JSON.
- `mergeOptions` never mutates `DEFAULT_OPTIONS` (the spread copies) and returns exactly the five known keys.
- `mergeOptions` cannot turn a config `shout: true` off, which is REQ-076; the test pins all three directions.
- `loadConfig` reads the file exactly once with `fs.readFileSync` and parses with `JSON.parse`, which is REQ-065 and SEC-004.
- `loadConfig` returns only the five known keys, so an unknown key cannot leak into the option record once F01 is fixed.
- The config `name` reason wording (`empty value for name`, `invalid value for name: 123`) matches the pinned strings in spec §4.3 and REQ-079.

### Set aside
- The reason for a config `times` of `"3"` renders as `invalid value for times: 3`, which is indistinguishable from the number `3`. The number `3` is always valid, so there is no collision in practice, and the spec pins the reason shape rather than a quoting rule.
- `mergeOptions` does not validate the config layer itself; the unit relies on `loadConfig` having validated first, which TASK-302's Green text states explicitly. Not a finding.
- `loadConfig(cwd)` with a `cwd` that does not exist returns `{}` (ENOENT), which is indistinguishable from "no config file". The spec does not distinguish these.

SUMMARY
verdict: fail
p0: 0
p1: 2
p2: 1
scope: clean
mutations: 17 run, 2 still green
top:
- F01 [P1] src/greet.js:168 CONFIG_VALIDATORS[key] hits Object.prototype members, so an unknown key crashes with TypeError
- F02 [P1] src/greet.js:129 the config times upper bound (value > 5) has no test; the mutant stays green
- F03 [P2] src/greet.js:147 the unreadable-config branch is untested; the mutant stays green
report: plans/greet-options/reports/phase-3/review-3.md
