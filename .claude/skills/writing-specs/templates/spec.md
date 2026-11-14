---
goal: <one sentence: what this feature does for the user>
version: 0.1
date_created: <YYYY-MM-DD>
last_updated: <YYYY-MM-DD>
owner: <repo or team>
status: 'Draft'
tags: [feature, <area>, <area>]
---

# Introduction

![Status: Draft](https://img.shields.io/badge/status-Draft-lightgrey)

<2–4 short paragraphs. The problem and who it's for. The examples or test cases that shape the design. The core idea of the solution and why. The stack in one sentence. End with: "The implementation is test-driven; see `plans/<feature>/feature-<feature>-tasks.md`.">

## 1. Requirements & Constraints

### Functional

<Group by area with a one-line lead-in. Number groups in tens. Use an EARS shape where a trigger or state matters.>

<Area one>:

- **REQ-001**: <one testable behaviour with its exact limits and values>
- **REQ-002**: When <event>, <the system> <does exactly this>.
- **REQ-003**: If <unwanted condition>, then <the system> <responds this way>.

<Area two>:

- **REQ-010**: …

### Preserved & superseded behaviour

<Only when the feature changes existing behaviour. Delete otherwise.>

- Preserved: <existing behaviour that must keep working, tied to something observable>
- Superseded: <old behaviour> → removed / replaced by REQ-0xx

### Security

- **SEC-001**: <secrets: where keys live, how they're validated, never sent to the client>
- **SEC-002**: <untrusted input: user text, web content, files, model output: how it is contained>
- **SEC-003**: <error leakage, input limits, authorization>

### Constraints & guidelines

- **CON-001**: <hard constraint: framework, API, runtime, "tests never call the network">
- **GUD-001**: <guideline: where tunables live, output sizes, conventions>
- **PAT-001**: <pattern to follow, e.g. pure functions that take db/now as arguments>

## 2. Architecture

```
<ASCII diagram of the request/data flow; number the steps where order matters>
```

## 3. Data model (`<path to schema>`)

```sql
<the real schema or types>
```

Notes:
- <lifecycles, indexes, migrations>

## 4. Components

### 4.1 <Component> — `<path>`

<Signatures, behaviour, edge cases. Use tables for tools and routes, and code blocks for exact output formats.>

### 4.N API contracts

| Route | Method | Request | Response |
|---|---|---|---|
| `/api/…` | POST | `{ … }` | `{ … }`; 400 / 404 as `{ error }` |

## 5. <Model / approach summary>

<Optional: a short recap of the central idea when §4 is long. Delete otherwise.>

## 6. Alternatives

- **ALT-001: <option>.** Rejected. <why, with evidence>
- **ALT-002: <option>.** Deferred. <why; when to revisit>

## 7. Dependencies

- **DEP-001**: <packages>
- **DEP-00N (external)**: <APIs, keys, services>

## 8. Files

New:
- `<path>`

Changed:
- `<path>` — <what changes>

## 9. Testing

Seams under test: <the public interfaces the tests drive, agreed with the user>.

- **TEST-001 (unit):** <what it proves>
- **TEST-002 (DB):** …
- **TEST-003 (route):** …
- **TEST-00N (evals / manual):** <scenario table with pass criteria when behaviour depends on a model or a human>

## 10. Risks & assumptions

- **RISK-001:** <risk>. Mitigation: <…>
- **ASSUMPTION-001:** <…>

## 11. Open questions

- **Q-1:** <question>. Decided in TASK-<id>.
