# Parallel review path

For large or risky changes: 2+ modules, >300 changed lines, a security boundary, or `--deep`. Offer it to the user with the planned number of reviewers before dispatching.

## Before dispatch

1. Finish scope, context and the partition list (SKILL.md §§ 1–3).
2. Write a **review packet** to the scratchpad: the diff command and its output, the changed-file list, the source-of-truth path (spec, task ids) or "none, judge stated intent only", the standards files, and one line of author intent. Every reviewer gets the packet path instead of a pasted diff.
3. If intent is unclear, ask the user now. Reviewers can't ask.

## Reviewers

Send them in one message, at most 8. Each prompt says: read-only, no repository edits, under 400 words, and return findings in the SKILL.md § 6 finding format.

| Reviewer | When | Brief |
|---|---|---|
| Correctness | always | Read the diff line by line, partition by partition (list them). Use lenses.md §§ 3, 7. |
| Test adversary | always | lenses.md § 1. May write and run probes only under the scratchpad or `$TMPDIR`. Return each probe: the wrong implementation it targets, the input, expected vs actual, and `defect` / `test gap` / `covered`. |
| Security | security boundary touched, or `--deep` | lenses.md § 4. Name the category for each finding, and list categories checked and clean. |
| Spec | a spec or task exists | lenses.md § 5. End with: `matches spec`, `partial: N gaps`, `exceeds spec: N items` or `no spec provided`. |
| Design / data shape | the change crosses a module boundary, adds to a shared structure, or `--deep` | lenses.md §§ 2, 6. |

Pass each reviewer its lens text verbatim (subagents can't load skills), and give it only its slots: no prior findings and no "edges to probe", which would anchor its search.

## Synthesis (you, not a subagent)

1. Merge and dedupe. A concern raised by two reviewers is **corroborated**: raise its confidence.
2. Run what can be run: the candidates with a concrete input that no probe confirmed yet.
3. Hunt the variants of each confirmed P0/P1 finding (SKILL.md § 4).
4. **Challenge pass.** Dispatch one devil's-advocate subagent with the packet and every finding that no run confirmed. For each, it returns `confirm`, `challenge` (why it may be wrong), `downgrade` or `escalate`, with its reasoning. It argues the author's side and searches for nothing new.
5. Rule on each challenge yourself. For a tie, read the lines, grep the callers or run the test. Ask the user about anything that hinges on intent.
6. Report per SKILL.md § 6. Add a line "Parallel path: <reviewers run>" and a short Challenge summary (raised / accepted / rejected).
