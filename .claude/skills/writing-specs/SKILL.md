---
name: writing-specs
description: Writes or updates a feature spec as plans/<feature>/feature-<feature>-spec.md. Use when the user asks for a spec, design doc, PRD or requirements; when a grilling session ends with decisions to write down; before building a non-trivial feature that has no spec; or when an existing spec needs changing. The task plan is written next with the writing-tasks skill.
---

# Writing specs

Every feature gets two markdown files in the repo:

| File | Holds | Written with |
|---|---|---|
| `plans/<feature>/feature-<feature>-spec.md` | what to build and why: requirements, contracts, alternatives, tests, risks | this skill, [templates/spec.md](templates/spec.md) |
| `plans/<feature>/feature-<feature>-tasks.md` | how to build it, test-first, in order, traced to the spec | the `writing-tasks` skill |

`<feature>` is short kebab-case (`chat-agent`). Always this format. A chat-only plan, a doc artifact or a single loose `SPEC.md` is not acceptable.

Write for an engineer who knows the language but has never seen this codebase or this conversation. They write good code once they know the exact names, values and tests. What they can't know is what was decided, and the spec holds those decisions.

## Workflow

```
- [ ] 1. Check plans/<feature>/. If the spec exists, update it (bump version and last_updated); don't start over.
- [ ] 2. Ground yourself. Read the code the feature touches, CLAUDE.md, sibling plans/ and the test setup. Note conventions, code to reuse and behaviour that must keep working.
- [ ] 3. Settle decisions. If `plans/<feature>/feature-<feature>-brief.md` exists, its decisions are agreed with the user and binding: build on them, cite their `D-` ids, never reopen them. Otherwise use what the conversation or your prompt already decided. Ask only questions whose answer changes what gets built, each with a recommended answer. With more than ~5 open, suggest the `aligning-requirements` skill first. As a subagent you can't ask: record each one under Open questions with your recommended answer.
- [ ] 4. Agree the test seams: the public interfaces the tests will drive. Prefer existing, high-level seams, and fewer of them. Confirm them with the user, or record them as a decision when you can't ask.
- [ ] 5. Research what you don't know (library APIs, limits, prices, prior art). Cite it in Alternatives or Risks.
- [ ] 6. Write the spec from templates/spec.md, in parts: one Write with the front matter and every section heading (requirements left as a placeholder line), then fill the sections with one Edit each, in order. Never draft requirements or sections in your reply: a reply cut off at the output limit loses them. If the spec file already exists without a FIX round (an earlier writer stopped part-way), continue it from the first unfilled section.
- [ ] 7. Re-read it once against the rules below and fix what you find. The full review is the `reviewing-plans` skill.
- [ ] 8. Hand over: the path, the key decisions, the open questions. The tasks file comes next, with `writing-tasks`.
```

## Writing the spec

- **Ids.** Number `REQ` in tens by area (001 chat, 010 memory, 020 …). Then come `SEC`, `CON` (hard constraints), `GUD` (guidelines), `PAT` (patterns), `ALT`, `DEP`, `TEST`, `RISK`, `ASSUMPTION` and `Q`. Declare each id exactly once (`- **REQ-001**: …`); reference it anywhere. Once the spec is shared, ids are stable. New ids go in the gaps, and a dropped id stays as `(removed in v0.2: reason)`.
- **One testable statement per requirement, with its exact value.** Write "1–4,000 characters (400 otherwise)", not "validate input". When a trigger or state matters, use an EARS shape: *When* <event>…, *While* <state>…, *If* <unwanted condition> *then*…. If you can't picture the test, rewrite the requirement. An implementation choice that no test can observe is not a REQ: make it a `PAT` or `GUD` ending in "Checked by code review." (conformance grades it by reading the code, without a warning). Never use that marker on REQ or SEC.
- **A negative requirement names its check** (R64). "Opens no network connection", "writes no file", "reads no secret" can never be proved in full at run time: a reviewer can always find one more API the spy misses, and run 11 spent four fix rounds and three hours chasing that for a greet CLI. Write the bounded check that proves it instead, as part of the id: "`src/` imports none of `node:net`, `node:http`, `node:https`, `node:dgram`, `node:child_process` and calls no `fetch` (a static test greps the source)", or "the only `fs` call is `readFileSync(<cwd>/greet.config.json)` (a test spies on `readFileSync` and `writeFileSync`)". The check is the requirement; nothing past it is in scope.
- **Size it to the feature.** The spec holds the decisions an implementer needs, not the brief again. A brief of a handful of flags gives a spec of a few pages; every extra REQ is another task, test and review. Don't split one behaviour into several ids to cover each wording.
- **Silence isn't permission.** For inputs the spec doesn't mention, a reasonable user's expectation still holds. Name the important ones (empty, huge, concurrent, timeout, malformed) instead of leaving them implied.
- **Concrete contracts.** Give real paths, signatures and the actual schema SQL or types. Give routes with request and response shapes and error codes, and config constant names with their values. Define each domain term once, then use one word per concept.
- **Reuse before adding.** Name the existing code to reuse or change. Each new abstraction names the requirement it serves and its current consumers. Shared infrastructure needs at least two consumers today.
- **Changing existing behaviour?** Fill in *Preserved behaviour* (what must keep working) and *Superseded behaviour* (`old → removed / replaced by REQ-0xx`). Then nobody restores the old path just to make an old test pass.
- **Alternatives are real decisions.** Say what each one was, then Rejected, Deferred or Not chosen for v1, and why, with evidence.
- **Tests by layer** (unit, DB, route, component, eval), each saying what it proves. Tests drive the agreed seams. Mock only at system boundaries: network, model, clock, external APIs.
- **Open questions** are answered by the user at the spec gate, never deferred to a task: a task cannot ask the user. Each one gives your recommended answer and the REQ and TEST ids that change with the answer.
- Use plain, short sentences. Lead with the point.

## Changing a spec later

When a decision changes, update the spec: bump `last_updated`, and bump `version` if a contract changed. The spec and tasks file never drift apart.
