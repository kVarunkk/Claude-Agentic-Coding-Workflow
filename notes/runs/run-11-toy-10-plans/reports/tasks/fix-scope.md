# Fix the Files column format in the tasks file

Source: `bash .dostuff/scripts/stage-unit.sh plans/greet-options 1` exited 1 with

```
unit 1: changed files outside its Files column and not logged under Differences:
  src/greet.js
  test/greet.test.js
nothing staged
```

## Cause

The P2 round's F10 fix annotated every Files cell with a parenthetical, for example
`src/greet.js (adds DEFAULT_OPTIONS, GREETING_WORDS, OPTION_SPECS and parseOptions)`.
`stage-unit.sh` matches the Files column entries as literal paths (it compares the
changed path to each entry with an exact string match), so an annotated entry never
matches and every changed source file is reported as stray. This blocks every unit.

## Fix

Restore the Files column to bare, comma-separated paths, so each entry is a path the
staging script can match. Keep the detail about what each task adds, but move it out of
the Files cell, for example into the task text itself, so nothing is lost.

Every Files cell must contain only paths such as `src/greet.js`, `bin/greet.js`,
`test/greet.test.js`, `test/fixtures/<case>/greet.config.json`. No parentheses, no
descriptions inside the cell.

Change nothing else.
