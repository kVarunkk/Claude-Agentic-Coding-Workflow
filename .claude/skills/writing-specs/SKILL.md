---
name: writing-specs
description: Writes or updates a feature spec and its test-first task plan as plans/<feature>/feature-<feature>-spec.md and feature-<feature>-tasks.md. Use when the user asks for a spec, plan, design doc, PRD, requirements or task breakdown; when a grilling session ends with decisions to write down; before building a non-trivial feature that has no spec; or when an existing spec or tasks file needs changing.
---

# Writing specs and tasks

Every feature gets two markdown files in the repo:

| File | Holds | Template |
|---|---|---|
| `plans/<feature>/feature-<feature>-spec.md` | what to build and why: requirements, contracts, alternatives, tests, risks | [templates/spec.md](templates/spec.md) |
| `plans/<feature>/feature-<feature>-tasks.md` | how to build it, test-first, in order, traced to the spec | [templates/tasks.md](templates/tasks.md) |

`<feature>` is short kebab-case (`chat-agent`). Always both files, always this format. A chat-only plan, a doc artifact or a single loose `SPEC.md` is not acceptable.

Write for an engineer who knows the language but has never seen this codebase or this conversation. They write good code once they know the exact names, values and tests. What they can't know is what was decided, and the two files hold those decisions.

## Workflow

```
- [ ] 1. Check plans/<feature>/. If it exists, update it (bump version and last_updated); don't start over.
- [ ] 2. Ground yourself. Read the code the feature touches, CLAUDE.md, sibling plans/ and the test setup. Note conventions, code to reuse and behaviour that must keep working.
- [ ] 3. Settle decisions. Use what the conversation or a grilling already decided. Ask only questions whose answer changes what gets built, each with a recommended answer. With more than ~5 open, suggest /grilling.
- [ ] 4. Agree the test seams: the public interfaces the tests will drive. Prefer existing, high-level seams, and fewer of them. Confirm the seams with the user.
- [ ] 5. Research what you don't know (library APIs, limits, prices, prior art). Cite it in Alternatives or Risks.
- [ ] 6. Write the spec from templates/spec.md.
- [ ] 7. Write the tasks file from templates/tasks.md.
- [ ] 8. Run `bash ${CLAUDE_SKILL_DIR}/scripts/check-plan.sh plans/<feature>`, then the self-review below. Fix everything they find.
- [ ] 9. If the spec has a data model, an API contract or 3+ modules, run the challenge pass.
- [ ] 10. Hand over: the two paths, the key decisions, the open questions, and the Challenged note if step 9 ran. Ask the user to review. Implementation starts after they approve.
```

## Writing the spec

- **Ids.** Number `REQ` in tens by area (001 chat, 010 memory, 020 …). Then come `SEC`, `CON` (hard constraints), `GUD` (guidelines), `PAT` (patterns), `ALT`, `DEP`, `TEST`, `RISK`, `ASSUMPTION` and `Q`. Declare each id exactly once (`- **REQ-001**: …`); reference it anywhere. Once the spec is shared, ids are stable. New ids go in the gaps, and a dropped id stays as `(removed in v0.2: reason)`.
- **One testable statement per requirement, with its exact value.** Write "1–4,000 characters (400 otherwise)", not "validate input". When a trigger or state matters, use an EARS shape: *When* <event>…, *While* <state>…, *If* <unwanted condition> *then*…. If you can't picture the test, rewrite the requirement.
- **Silence isn't permission.** For inputs the spec doesn't mention, a reasonable user's expectation still holds. Name the important ones (empty, huge, concurrent, timeout, malformed) instead of leaving them implied.
- **Concrete contracts.** Give real paths, signatures and the actual schema SQL or types. Give routes with request and response shapes and error codes, and config constant names with their values. Define each domain term once, then use one word per concept.
- **Reuse before adding.** Name the existing code to reuse or change. Each new abstraction names the requirement it serves and its current consumers. Shared infrastructure needs at least two consumers today.
- **Changing existing behaviour?** Fill in *Preserved behaviour* (what must keep working) and *Superseded behaviour* (`old → removed / replaced by REQ-0xx`). Then nobody restores the old path just to make an old test pass.
- **Alternatives are real decisions.** Say what each one was, then Rejected, Deferred or Not chosen for v1, and why, with evidence.
- **Tests by layer** (unit, DB, route, component, eval), each saying what it proves. Tests drive the agreed seams. Mock only at system boundaries: network, model, clock, external APIs.
- **Open questions** each name what settles them ("Decided in TASK-041").
- Use plain, short sentences. Lead with the point.

## Writing the tasks

- **Decisions taken** comes first: every choice the spec left open that an implementer would otherwise stop and ask about.
- **Review focus** comes next. List the ~5 inputs or failure modes the spec implies that are most likely to hurt a real user, most likely first. For each line, add its test to the task that owns the code.
- **Phases** start at 0 (scaffold and test infrastructure). Each has a `GOAL-00N`, a task table and a checkable **Done when:** line. Each phase leaves the build green and ends in something runnable.
- **Tasks are vertical slices.** Each task is one behaviour through every layer it needs (schema, logic, route, UI, tests), not one layer at a time. Additive work comes first and removals come last. A task is the smallest unit that has its own test cycle and could be accepted or rejected on its own.
- **Red → Green → Refactor in every task.** The description names the tests first, with the spec's exact values (`**Red:** … **Tests:** …`). Then it says what to build (`**Green:** …`): the file, the exact signature and the values. Within a task, work one test at a time: red, green, then the next test.
- **One name per thing.** When a later task uses something an earlier task makes, both use the same name (function, type, route), and so does the spec.
- **Every task decides something.** A task lets the implementer write exactly one reasonable thing. "Handle edge cases", "add validation" and "write tests" decide nothing: name the cases and the tests instead. Include a function body only when the signature and tests leave the algorithm open.
- A new field or entity lists every layer it crosses (schema, migration, query, API type, client type, UI, validation) in the same task.
- Mark `*(parallel)*` tasks that don't depend on the one before. Mark **Manual** tasks (real keys, a human, a browser) and say what to record from them.
- Use the table `Task | Description | Spec | Completed | Date`. Leave Completed and Date empty until the task is done. Task ids are `TASK-<phase><n>`.
- The **traceability** table covers every REQ and SEC id. Ranges like `REQ-011 – REQ-016` are fine.
- End with **Differences from the spec** set to "None yet."

## Self-review

Read the spec again with fresh eyes, then check the plan against it:

1. **Coverage.** Every REQ and SEC id has a task, and every task maps to a spec id. The script checks the ids mechanically, but check the meaning yourself.
2. **Task scan.** Every description allows one reasonable implementation. No line decides nothing, and no task is a transcript of the code.
3. **Name consistency.** Files, functions, types, constants and routes are spelled the same in both files and across tasks.
4. **Review focus.** Each line has a test in a named task.
5. **Proportion.** The plan is shorter than the code it describes, and its size fits the behaviour asked for. If a small change has grown shared infrastructure or unrelated behaviour, simplify it.
6. **No placeholders** (`<…>`, TODO, TBD) remain outside Open questions. The front-matter and status badge are filled in.

Fix what you find directly in the files.

## Challenge pass

When the spec has a data model, an API contract or 3+ modules, dispatch two read-only reviewers in parallel. Give each the two file paths:

- **Design review.** Checks architectural fit, module boundaries, the data model, API contracts, and whether the task order respects the dependencies.
- **Critical challenge.** Checks assumptions, missing cases, scope creep and unproven requirements, and proposes simpler alternatives.

Each returns at most five findings with evidence. Fold in the valid ones and record each rejected one with its reason. Report what changed in a short **Challenged** note at handover.

## During implementation

- When a task's tests pass, mark its row `✅` and fill in the date.
- Log each deviation under **Differences from the spec** as it happens, with the spec id and the reason.
- When a decision changes, update the spec as well: bump `last_updated`, and bump `version` if a contract changed. The two files never drift apart.
- Move the status badge through `Planned` (blue) → `In progress` (yellow) → `Completed` (brightgreen). `On Hold` (orange) and `Deprecated` (red) are also available.
- At the end of each phase, run the `checking-spec-conformance` skill.
