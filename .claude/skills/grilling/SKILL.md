---
name: grilling
description: Relentless interview about a new requirement, feature idea or plan, in rounds of numbered questions with recommended answers, until every design decision is settled. Run as /grilling <requirement>.
disable-model-invocation: true
argument-hint: "[requirement, feature idea or plan]"
---

# Grilling

Requirement: **$ARGUMENTS**

Interview the user relentlessly until you both hold one understanding of what gets built and why. You find the facts; the user makes the decisions. The grilling produces decisions only: code, specs and scaffolding wait until it is over.

## 1. Ground yourself

- Read what the requirement touches: the code, `plans/`, docs, any file the user pointed at. Keep reading until you can explain how the relevant parts work today and what this change would touch.
- Play the requirement back in 3–5 sentences: what they want, who it is for, why (as far as they've said), and anything you found that changes the picture: a constraint, a conflict, a cheaper path.
- If the *why* is missing, it is Q1: one open question in their own terms, with no options attached. Options steer; their own words carry the intent.

## 2. Map the design tree

Every decision branches into the decisions that hang off it. The root is goal, users, success and scope (including non-goals). The branches are whichever apply: behaviour and edge cases, data, interfaces, failure modes, security, limits and performance, testing (which seams prove it works), rollout, and how it gets built.

The **frontier** is every decision whose prerequisites are settled: the questions you can ask now without guessing at answers you haven't heard.

## 3. Ask in rounds

Ask the whole frontier in one round, numbered across the session:

```
❓ **Q4 — <title>**: <the question; the trade-off or finding that makes it matter; the named choices, if there are any>

➡️ <your recommended answer, with the reason in one line>

---
```

- Word each question so "yes" accepts the recommendation. Tell the user they can answer by number: "4 yes, 5 no — use Postgres".
- A question that depends on another question still open in this round belongs to a later round.
- After posting the round, stop and wait for the answers.

**Facts are your job.** When a question needs a fact (does X exist, what does the API allow, what does it cost, how does the code behave today), look it up. Use an Explore subagent for anything wider than a quick read. Ask the rest of the frontier while it runs; only the questions downstream of the lookup wait for it.

## 4. Grill

- Push every vague word ("fast", "simple", "smart", "handle", "should") down to a number, an example or a limit.
- Walk the cases the user hasn't: empty, huge, concurrent, repeated, malformed, offline, the second time, a year later, the dependency down, slow or returning garbage.
- Quote an earlier answer back when a new one contradicts it.
- Ask what is out of scope, what would make this a failure even if it technically works, and how you would test that it is done.
- When the decision is how to build it, lay out the 2–3 real approaches with what each trades off, and recommend one. These become the spec's Alternatives.
- State every default you would fill in, so the user can reject it.
- When a choice looks wrong, say so once with your reason, then go with the user's call.

After each round, recompute the frontier: settled answers unblock new questions, and moot ones drop silently. Every few rounds, play back the part that is now settled in one short paragraph and ask what is wrong or missing.

## 5. Finish

The grilling is done when the frontier is empty: every branch visited, nothing silently assumed. Then post:

```
## Decisions
| # | Decision | Answer | Why |
|---|---|---|---|

## Approaches considered
## Out of scope
## Still open — and what settles it
```

Ask the user to confirm this is the shared understanding. Once they confirm, offer to write the spec and tasks with the `writing-specs` skill, and start only on their yes.
