# Spec review (recheck): greet-options

- Target: `plans/greet-options/feature-greet-options-spec.md`
- Mode: spec (recheck)
- Date: 2026-11-21
- Previous report: `plans/greet-options/reports/spec/review-2.md`

## Recheck of previous findings

F04 [P1] feature-greet-options-spec.md:60 vs 192 **fixed**. TEST-008 (line 192) now asserts "the only `fs.` method call in `bin/greet.js` is `readFileSync(path.join(process.cwd(), 'greet.config.json'))`" and names the write/read methods it bans (`writeFileSync`, `writeFile`, `appendFileSync`, `appendFile`, `createWriteStream`, `readFile`, `readdirSync`, `readdir`, `statSync`, `stat`, `createReadStream`), so SEC-001(a)'s "only fs call" claim and CON-004's no-other-file/no-write constraint now have a bounded static check.

## New findings

F05 [P1] feature-greet-options-spec.md:192 The fix's banned-name list includes `readFile`, but the required (and only allowed) fs call is `readFileSync`, and `readFile` is a literal substring of `readFileSync`. A test written to the spec as stated (`none of ... `readFile` ... appears`) would fail against the very `readFileSync(path.join(process.cwd(), 'greet.config.json'))` call the same sentence mandates, so TEST-008 as worded is self-contradictory. Fix: ban the method form `fs.readFile(` (or use a word boundary), or drop `readFile` from the list since the "only `fs.` method call is `readFileSync(...)`" assertion already rules it out.

SUMMARY
verdict: fail
p0: 0
p1: 1
p2: 0
top:
- TEST-008's banned list includes `readFile`, a substring of the required `readFileSync`, so the test as worded bans its own allowed call.
report: plans/greet-options/reports/spec/review-3.md
