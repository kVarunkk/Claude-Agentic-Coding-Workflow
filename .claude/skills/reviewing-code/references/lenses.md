# Review lenses

What to look for in each lens. Every finding still needs a failure scenario and evidence (SKILL.md § 5).

## Contents
1. Tests
2. Data shape
3. Correctness
4. Security
5. Spec alignment
6. Design and standards (smell baseline)
7. Performance and operations

## 1. Tests

For each test that covers changed behaviour, ask: **what wrong implementation would still pass it?** For each answer, write the distinguishing input: one where the right and the wrong implementation give different results. Run it as a probe in the scratchpad or `$TMPDIR` with the project's own runner, and leave repository files untouched.

- Wrong result → a defect. Right result, but no test checks it → a test gap.
- **Behaviour changed with no test**: new public functions, routes, business rules, transformations and error paths need tests. Config, docs and pure markup usually don't. Treat it as at least P1.
- **Tautological**: the expected value is computed the way the code computes it (`expect(add(a,b)).toBe(a+b)`). Expected values come from an independent source: a literal, a worked example or the spec.
- **Implementation-coupled**: the test mocks internal collaborators, tests private functions, asserts call counts or order, or verifies through a side channel (querying the DB instead of using the interface). It breaks on a refactor while the behaviour stays the same.
- **Golden-path only**: no failure, boundary or empty case.
- **Mocks in the wrong place**: mock only at system boundaries (network, model, clock, external APIs). Use a real in-memory DB where the project already does.

## 2. Data shape

Review structures before logic, starting with those that cross a boundary: a public interface, an API payload, a stored row, a queued message or a file format. Run three tests, each needing its stated evidence:

1. **Invalid states.** Can the declared shape hold a state the domain forbids (e.g. `status: 'done'` with `answer: null`)? Evidence: the invalid state and the ordinary operations that produce it. Existing guard code is evidence for the finding, not against it.
2. **Replicated information.** Is the same fact stored in two places (a column and a cached field, two units, a payload and the receiver's copy) and kept equal by separate writes? Evidence: a sequence of ordinary operations after which the copies disagree. A deliberate snapshot (price at purchase) is fine; name it.
3. **Extension cost.** Add a realistic new case (a new status, variant or kind). Which edit sites must change, and how would you find each one: compiler error, failing test, one dispatch table, or only grep? Flag the sites only grep finds.

Say what shape would remove the failure, and stop there. Changing a shape touches every consumer.

## 3. Correctness

- Off-by-one, wrong operator, wrong default, inverted condition.
- null / undefined / empty / zero / NaN; huge inputs; unicode; whitespace.
- Dates and times: timezones, DST, midnight, "last Tuesday", ISO parsing, server vs client clock.
- Errors: unhandled rejections, swallowed `catch {}`, errors that lose their cause, partial writes with no rollback.
- Concurrency: races, shared mutable state, double submits, retries that duplicate work (idempotency), the order of awaited operations.
- Resources: unclosed handles, listeners never removed, timers never cleared, unbounded caches.
- State that isn't reset between requests, turns or tests.
- Contracts: callers not updated after a signature or return-type change; stale comments that now lie.

## 4. Security

Apply when the change parses untrusted input, makes an access or policy decision, or handles secrets.

- **Injection**: user or external text reaching SQL, shell, HTML, file paths, regexes, FTS `MATCH` or a template without parameterising or escaping.
- **Secrets**: keys in code, logs, error messages, client bundles or committed files; env read on the client.
- **Access control**: missing authz checks; ids taken from the client and trusted (IDOR).
- **Error leakage**: raw provider errors or stack traces sent to the client.
- **Limits**: missing size, count, rate or timeout limits on input and on outbound calls.
- **LLM-specific**: web content, files or tool output reaching the model as instructions instead of delimited data; model output used without validation (parsed JSON, URLs, SQL, code); prompt content built from untrusted text.
- **Supply chain**: new dependencies (are they needed, maintained, pinned?), install scripts, lockfile churn.
- **Fail closed**: on error, the safe path is taken.

## 5. Spec alignment

Against a spec you have read (or the stated intent, if there's none):

- required behaviour that is missing or partial;
- behaviour nobody asked for (scope creep);
- behaviour that contradicts a requirement, a CON/GUD/PAT or a Decisions-taken row;
- a deviation with no entry under **Differences from the spec**.

Quote the spec line for each finding. For a whole-feature audit, use the `checking-spec-conformance` skill instead.

## 6. Design and standards

Documented project rules come first and win over the baseline below. Each baseline smell is a judgement call; label it "possible …". Skip what tooling enforces.

| Smell | Looks like | Fix direction |
|---|---|---|
| Mysterious name | name doesn't say what it does or holds; missing units (`timeout` vs `timeoutMs`) | rename; if no honest name comes, the design is murky |
| Duplicated code | same logic shape in two hunks or files | extract once, call from both |
| Feature envy | function reaches into another object's data more than its own | move it to the data |
| Data clumps | the same fields travel together | one type |
| Primitive obsession | a string or number standing in for a domain concept | a small type |
| Repeated switches | the same `switch`/`if` chain on one type in several places | one map or dispatch both sites share |
| Shotgun surgery | one logical change scattered across many files | gather what changes together |
| Speculative generality | options, hooks or abstractions no current requirement uses | delete; inline until a real need appears |
| Middle man | a layer that only delegates | call the target directly |
| Hidden dependency | globals, singletons, env reads inside logic | pass it in |
| Dead code | unused exports, commented-out blocks, unreachable branches | delete |
| What-comments | comments narrating the code instead of the why | rename, or delete the comment |

Also check that new code follows the patterns already used in the same module.

## 7. Performance and operations

- N+1 queries, repeated scans, work inside loops that belongs outside.
- Blocking or synchronous work on a hot path; sequential awaits that could run in parallel.
- Unbounded growth: no pagination, no cap on results, memory, log size or retries.
- Missing timeouts on network calls; no cancellation when the client leaves.
- Failures that would be invisible: no log, metric or user-visible error where something can go wrong.
- Risky changes (migrations, schema changes, flag flips) without a rollback path.
