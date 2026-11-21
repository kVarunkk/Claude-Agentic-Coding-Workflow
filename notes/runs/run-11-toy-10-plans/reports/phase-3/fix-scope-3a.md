# fix-unit check failure for unit 3a

Command: `bash .dostuff/scripts/fix-unit.sh plans/greet-options check 3a`
Exit 1 with:

```
changed section: ## Differences from the spec
```

The check compares the tasks file with the version committed at HEAD and allows only
one new unit section, rows in "## Requirement traceability", and a new `last_updated`
date. The last writer round added a Differences entry for the new unit 3a, so the
"Differences from the spec" section changed and the check refuses it.

## What to do

Move the note about the widened TEST-006 fixture list and the three new fixture
directories out of the "## Differences from the spec" section and into the TASK-303 task
row itself (the task text), so the plan's Differences section stays byte-identical to
the version committed at HEAD.

Leave the traceability rows and the new unit section as they are.

Run `bash .dostuff/scripts/check-plan.sh plans/greet-options` and
`bash .dostuff/scripts/fix-unit.sh plans/greet-options check 3a` when you can.

Change nothing else.
