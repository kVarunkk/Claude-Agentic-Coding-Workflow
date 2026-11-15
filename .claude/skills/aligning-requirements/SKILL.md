---
name: aligning-requirements
description: Interviews the user about a new feature or requirement in rounds of questions with recommended answers until both sides agree on what gets built, then records the agreement as plans/<feature>/feature-<feature>-brief.md. Use before writing a spec, when a requirement is vague, or when /build-feature starts a feature with no approved brief.
argument-hint: "<feature> [requirement]"
---

# Aligning on requirements

Target: **$ARGUMENTS**. First word is `<feature>` (kebab-case); the rest is the requirement.

Goal: you and the user hold one understanding of what gets built and why, written down, before anyone writes a spec. You find the facts; the user makes the decisions. Write no spec, tasks or code here.

## 1. Ground yourself

- Read what the requirement touches: the code, `plans/`, docs, files the user named. For anything wider than a quick read, use an `Explore` subagent and keep only its conclusions.
- Play the requirement back in 3 to 5 sentences: what, for whom, why (as far as said), and anything you found that changes the picture (a constraint, a conflict, a cheaper path).
- If the why is missing, ask it first as one open question in plain text, with no options. The user's own words carry the intent.

## 2. Map the decisions

The root is goal, users, success and scope (including non-goals). Branches, where they apply: behaviour and edge cases, data, interfaces, failure modes, security, limits and performance, how it is tested, how it is built.

The **frontier** is every decision whose prerequisites are settled. Ask only the frontier.

## 3. Ask in rounds

- Use `AskUserQuestion` for decisions with named choices: up to 4 questions per call, your recommended option first and marked "(Recommended)", the trade-off in each description. Use plain text for open questions (why, examples, what failure looks like).
- **Facts are your job.** Look up whether X exists, what an API allows, how the code behaves today. Never ask the user a fact you can find.
- Push vague words ("fast", "simple", "handle", "should") down to a number, an example or a limit.
- Walk the cases the user has not: empty, huge, concurrent, repeated, malformed, offline, the dependency down or slow.
- When the question is how to build it, give the 2 to 3 real approaches with their trade-offs and recommend one.
- State every default you would fill in, so the user can reject it.
- When a choice looks wrong, say so once with your reason, then go with the user's call. Quote an earlier answer back when a new one contradicts it.
- After each round, recompute the frontier. Every few rounds, play back what is settled in one short paragraph and ask what is wrong or missing.
- If the user says "you decide" or "enough", record your recommendation for the rest as **delegated** decisions and move to step 4.

## 4. Write the brief

Done when the frontier is empty: every branch visited, nothing silently assumed. Write `plans/<feature>/feature-<feature>-brief.md` from [templates/brief.md](templates/brief.md). Keep it to decisions, not prose. Each decision gets an id `D-01`, `D-02`, … that the spec can cite.

## 5. Reach consensus

Show the brief path and its Decisions table. Ask with `AskUserQuestion`: "Is this what we are building?" with options **Agree** / **Change something** / **Stop**.

- **Agree:** run `bash .claude/scripts/approve.sh plans/<feature> brief`. Only on this explicit answer in this session. The script also sets `status: agreed` in the brief's front matter; do not commit the brief before it ran.
- **Change something:** take the user's text, go back to step 3 for the affected branch, update the brief, ask again.
- **Stop:** leave the brief as written and unapproved.

Never answer this question yourself. The spec is written only from an approved brief.
