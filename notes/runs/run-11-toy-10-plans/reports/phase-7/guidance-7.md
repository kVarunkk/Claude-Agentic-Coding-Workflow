# Guidance for unit 7, fix round 4

The remaining P1 is in `plans/greet-options/reports/phase-7/review-7-4.md`:

> F01 [P1] test/greet.test.js:666 three spawnSync CLI runs skip the network spy, so a CLI
> that reaches for the network still stalls the suite (48 s) instead of failing, and the
> "every CLI run preloads the network spy" claim at
> plans/greet-options/feature-greet-options-tasks.md:269 is false

## What to do

1. Find every CLI launch in `test/greet.test.js` that spawns the greet script (the
   `spawnSync` call sites, around lines 666, 835 and 844) and make each of them preload
   the network spy, exactly as the other CLI launches already do. Do not leave any of
   them without the preload.

2. Correct the Differences entry that claims every CLI run preloads the network spy. Once
   step 1 is done that claim is true; make the wording match what the code actually does.

3. Prove the fix: with the network spy preloaded at every CLI launch, a mutation that
   makes the CLI reach for the network (for example a `globalThis.fetch` call, a
   `node:dns` lookup or a `child_process.spawn`) must turn the SEC-001 test red rather
   than stalling the suite. Report the before and after suite duration.

## Scope

The shipped code is not at fault and must not change: unit 7 changed no production file,
and `src/greet.js` and `bin/greet.js` import only `fs` and `path`. Only the test file
and the plan's Differences entries change.

Do not chase the items the review set aside: `fs.symlinkSync` is unpatched, `fs.watch` is
unpatched, and the net spy records an `FSNET` line merely on loading `node:http`. Those
are noted, not filed, and are out of scope.

Clean up any temporary directories your probes leave behind in the OS temp directory.

Do not stage or commit anything.
