---
goal: TDD task breakdown for the chat agent (web search, dated memory, claim re-verification)
version: 0.1
date_created: 2026-11-14
last_updated: 2026-11-14
owner: web-agent
status: 'Planned'
spec: plans/chat-agent/feature-chat-agent-spec.md
tags: [feature, ai-agent, chat, web-search, memory, tasks, tdd]
---

# Introduction

![Status: Planned](https://img.shields.io/badge/status-Planned-blue)

These tasks implement `plans/chat-agent/feature-chat-agent-spec.md` (v0.1) with test-driven development. Every task follows **Red → Green → Refactor**:

1. **Red:** write the listed tests first and confirm they fail for the right reason (an assertion about behaviour, not an import error or a missing mock).
2. **Green:** the minimum implementation that makes them pass.
3. **Refactor:** clean up with the tests green, then `npx eslint <changed files>` and `npx tsc --noEmit`.

Rules:
- Tests never call the network, a model or Tavily (CON-004). Use `test/utils/db.ts` (a fresh `:memory:` database per test), `test/utils/ai.ts` (`MockLanguageModel*` helpers) and `test/utils/search.ts` (a fake `SearchProvider`).
- Tasks marked **Manual** need real keys and are run by hand; record what was observed in the task's description and, where it changes the plan, under Differences.
- The system prompt and tool definitions stay constant (REQ-040). Any task that touches `lib/agent/` keeps TEST-003 green.
- Tick the task and fill in the date when it's done. Tasks run in order inside a phase unless marked *(parallel)*.
- Task IDs use `TASK-`. The **Spec** column maps each one to the spec's ids.

## Decisions taken for these tasks

Settled up front so work can start. Revisit in TASK-094 if any turns out wrong.

| Decision | Taken |
|---|---|
| App layout | Next.js App Router at the repo root (`app/`, `components/`, `lib/`), no `src/`. npm, Node ≥ 20. |
| Database file | `data/agent.db` (directory created on first open, gitignored). `DB_PATH` env overrides it. One `Database` instance per process, cached on `globalThis` so dev hot reload doesn't open a new handle each time. |
| When the turn is saved | Inserted with `status = 'pending'` before streaming, so the question is on record even if the stream fails. |
| Background work | Extraction runs in `after()` from `next/server` (runs once the response is finished). No queue. The eval runner awaits it directly. |
| Search result format for the model | A text block, not JSON: `<search_results>` with numbered results (`[1] title — url — published — content`). Easier for the model to cite, and stable to serialize. |
| What the UI receives | The AI SDK UI message stream, unchanged. Tool parts are rendered as a status line, not as raw results. |
| Timezone | Sent by the browser on conversation creation. Validated with `Intl.DateTimeFormat(undefined, { timeZone })` in a try/catch; invalid → `UTC`. |
| Eval judge | `EVAL_JUDGE_MODEL` env, defaulting to `LLM_MODEL`. The judge returns `{ pass: boolean, reason: string }` per rubric line through `generateObject`. |
| Seed values | Synthetic and labelled `[seed]` in the conversation titles. One Postgres price is deliberately outdated so E3 can observe a `changed` status. |
| Markdown | `react-markdown` + `remark-gfm` (tables), links with `target="_blank" rel="noreferrer"`. |

---

## Phase 0: Scaffold and test infrastructure

- **GOAL-000**: A clean clone runs `npm install && npm run dev`, and `npm test` runs fast, isolated tests.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-000 | Scaffold the Next.js app (TypeScript, App Router, ESLint) in the repo root. Scripts: `dev`, `build`, `start`, `lint`, `test` (`vitest run`), `test:watch`, `seed` (`tsx scripts/seed.ts`), `eval` (`tsx scripts/eval.ts`). Add `.gitignore` (`.env`, `data/`, `.next/`, `node_modules/`) and `.env.example` with every key from spec REQ-053 plus `TAVILY_API_KEY`, `FAKE_NOW`, `ALLOW_CLOCK_OVERRIDE`, `DB_PATH`, `EVAL_JUDGE_MODEL`, each with a one-line comment. | CON-003, SEC-001 | | |
| TASK-001 | Add `vitest.config.mts` with the `@/` alias and two projects: `node` for `*.test.ts`, `jsdom` for `*.test.tsx`. Add `test/setup.ts` (jest-dom matchers; a mock of `next/server`'s `after` that collects callbacks, with `flushAfter()` in `test/utils/after.ts`). A smoke test in each project. | CON-004 | | |
| TASK-002 | Install `better-sqlite3`; add it to `serverExternalPackages`. `test/utils/db.ts` exports `testDb()` (a fresh `:memory:` database with the schema applied, once TASK-011 exists). A contract test creates an `fts5` table and runs a `MATCH` with `bm25()`, so a binary without FTS5 fails fast. If the install fails on Windows, try `node:sqlite` with the same test and record the outcome under RISK-003 / Differences. | DEP-003, RISK-003 | | |
| TASK-003 | Install `ai`, `@ai-sdk/react`, `@ai-sdk/openai-compatible`, `zod`. `npm ls ai` shows one copy. `test/utils/ai-sdk-contract.test.ts` pins what later tasks rely on: the `MockLanguageModel*` version that matches the provider's models (from `ai/test`), `simulateReadableStream`, `streamText` with `tools` + `stopWhen: stepCountIs()`, `generateObject`, `usage.cachedInputTokens` on the result type, and `toUIMessageStreamResponse`. `test/utils/ai.ts` holds the helpers (a text reply; a tool call then a text reply). Record any API name differences under Differences. | DEP-002, CON-001 | | |
| TASK-004 | **Manual:** `scripts/check-provider.ts` lists `GET {LLM_BASE_URL}/models`, then for each candidate model runs one `streamText` with a dummy `web_search` tool and a prompt that needs it, reporting whether it called the tool with valid input and how long it took. Pick `LLM_MODEL` (reliable tool calls) and `LLM_EXTRACT_MODEL` (small, fast, structured output). Resolves Q-1 and Q-2; write the answers into the spec. | RISK-001, Q-1, Q-2 | | |
| TASK-005 | **Red → Green:** `lib/env.ts` (zod schema over `process.env`, required keys and URL format) and `lib/config.ts` (spec §4.1). **Tests:** a missing `LLM_API_KEY` throws an error naming it; a bad `LLM_BASE_URL` is rejected; optional keys default. | SEC-001, GUD-001 | | |

**Done when:** `npm run dev` serves a placeholder page, `npm test` passes, eslint and tsc are clean, and the two models are chosen.

---

## Phase 1: Database

- **GOAL-001**: The schema in spec §3, with FTS5 kept in sync by triggers.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-010 | **Red:** `lib/db/index.test.ts`: `openDb(":memory:")` creates all tables, the FTS table and the triggers; running the schema twice is a no-op; `foreign_keys` is on; a turn insert is findable by `MATCH`; updating `tags` makes the turn findable by a tag word and no longer by a removed one; deleting a turn removes it from FTS; deleting a conversation cascades to turns and claims; a bad `status` is rejected. | REQ-010, §3 | | |
| TASK-011 | **Green:** `lib/db/schema.sql` exactly as spec §3, and `lib/db/index.ts` (`openDb`, pragmas, `getDb()` cached on `globalThis`, `data/` created if missing). | §3, CON-003 | | |

**Done when:** the schema tests pass and `npm run dev` creates `data/agent.db` on first request.

---

## Phase 2: Pure core

- **GOAL-002**: Time, recall parsing, formatting and prompt building as pure, fully tested modules.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-020 | *(parallel)* **Red → Green:** `lib/clock.ts` `getNow({ override, env })`. **Tests:** override used in dev; ignored in production unless `ALLOW_CLOCK_OVERRIDE=true`; `FAKE_NOW` used when there's no override; invalid ISO → real time; real time otherwise (fake timers). | REQ-050, SEC-005 | | |
| TASK-021 | *(parallel)* **Red → Green:** `lib/memory/dates.ts` `resolveWindow`, `widen`. **Tests** (now = Sat 2026-11-14 10:00 `Asia/Kolkata`): "last Tuesday" → 11-10; "on Monday" → 11-09; "3 November" → 11-03, never 2027; "yesterday"; "last week" → the previous Mon–Sun; "on 3 Nov" at 00:30 local in `America/Los_Angeles` maps to the right UTC bounds; the `label` text; `widen(…, 2)`. | REQ-012, TEST-001 | | |
| TASK-022 | *(parallel)* **Red → Green:** `lib/memory/detect.ts` `detectRecall`. **Tests:** each cue (case, word boundaries: "I asked" yes, "Basked" no); a date alone triggers; "thanks!" and "what's the weather in Pune?" don't; the matched date text is returned for exclusion from the FTS query. | REQ-011, TEST-001 | | |
| TASK-023 | *(parallel)* **Red → Green:** `lib/memory/fts-query.ts` `buildFtsQuery`. **Tests:** "Last Tuesday I asked you about Postgres hosting" → `"postgres" OR "hosting"`; quotes, hyphens, colons, `*`, `AND`/`NOT`/`NEAR` never produce FTS syntax; duplicates removed; only stopwords → null; a query built from hostile input runs against `testDb()` without an error. | SEC-003, TEST-001 | | |
| TASK-024 | **Red → Green:** `lib/memory/format.ts` `formatRecalled`. **Tests** (exact string snapshots): a full match with two turns and claims; an excerpt cut at 1,500 chars on a word boundary with `…`; a date-only result (no excerpts); `match="none"`; XML-special characters in user text escaped. | REQ-016, TEST-002 | | |
| TASK-025 | **Red → Green:** `lib/agent/messages.ts` `buildSessionBlock`, `buildContextBlock`, `buildModelMessages`. **Tests:** exact output for each block; the session block is prefixed to the first user message only; past turns render as user + assistant text; the window rule (41 turns → 20 kept; then stable until 40 again). **TEST-003:** three simulated turns; request N+1's messages start with request N's through its last user message (deep-equal and identical `JSON.stringify`). | REQ-017, REQ-041 – REQ-043, TEST-002, TEST-003 | | |
| TASK-026 | **Red → Green:** `lib/agent/system-prompt.ts`. **Tests:** it's a `string` constant with no `${`, no date-like text and no `{{`; the sections of spec §4.2 appear in order; the SEC-002 sentence is present. Write the prompt with the rules REQ-004, REQ-005, REQ-030 – REQ-032. | REQ-040, SEC-002 | | |

**Done when:** `lib/memory/*` (pure parts) and `lib/agent/messages.ts` have full branch coverage.

---

## Phase 3: Persistence and recall

- **GOAL-003**: Conversations, turns and claims stored as specified, and the recall ladder working against a real (in-memory) database.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-030 | **Red → Green:** `lib/db/conversations.ts`. **Tests:** `createConversation` stores the timezone, `started_at`, and a `session_block` built from `buildIndex` (only conversations active in the last 30 days, max 50, newest first, multi-day ranges shown as `a → b`); the stored block never changes after later title updates; `listConversations` ordering; `touchConversation`; `setTitle`. | REQ-002, REQ-017 | | |
| TASK-031 | **Red → Green:** `lib/db/turns.ts`. **Tests:** `insertTurn` → `pending`; `setAnswer` → `answered`; `setTurnError`; `listTurns` in id order; `searchTurns` ranks a tag match above an answer-only match (weights 2/1/3), applies the window, excludes the current conversation and non-`done` turns, respects the limit; `turnsInWindow` ordering and limit. | REQ-010, REQ-014, REQ-015, TEST-004 | | |
| TASK-032 | *(parallel)* **Red → Green:** `lib/db/claims.ts`. **Tests:** `insertClaim`; `confirmClaim` changes only `last_verified_at`; `supersedeClaim` inserts the new row and links the old one in one transaction; `currentClaimsForTurns` returns only `superseded_by is null`. | REQ-021, TEST-004 | | |
| TASK-033 | **Red → Green:** `lib/memory/recall.ts` `recall`. **Tests** on a fixture DB (TEST-005): no reference → skipped; exact; widened (record a day later); topic-only (no date given); date-only (no topic terms); date + topic with nothing in the window but a topic match elsewhere → topic-only; none; the current conversation excluded; limits 5 / 20; claims attached per turn. | REQ-011 – REQ-016, TEST-005 | | |

**Done when:** the recall ladder tests pass on a database built only through the persistence functions.

---

## Phase 4: Search

- **GOAL-004**: A `web_search` tool that is fast, compact and never crashes a turn.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-040 | *(parallel)* `lib/search/types.ts` (`SearchProvider`, `SearchResult`) and `test/utils/search.ts`: a fake provider with queued results, per-query errors and an artificial delay. | §4.3 | | |
| TASK-041 | **Red → Green:** `lib/search/tavily.ts`. **Tests** (`fetch` mocked): request URL, headers and body (`search_depth`, `max_results`, `topic`, `start_date` only when `since` is set); response mapping; a non-200 → thrown error with no key in the message. **Manual:** one real call with `start_date` to settle Q-3; if rejected, filter by `published_date` locally and record it. | REQ-003, SEC-001, Q-3 | | |
| TASK-042 | **Red → Green:** `lib/agent/tools.ts` `createTools({ search })`. **Tests:** schema rejects 0 or 6 queries and a 201-char query; queries run in parallel (fake delays: total ≈ the slowest, not the sum); duplicates by URL removed; content cut at 1,500 chars; output wrapped in `<search_results>` with numbered results; one query timing out (8 s, fake timers) still returns the others; all failing → `{ error }`; the tool definition JSON is identical across two `createTools` calls. | REQ-003, REQ-006, GUD-002, SEC-006, TEST-006 | | |

**Done when:** the tool tests pass and a manual Tavily call returns mapped results.

---

## Phase 5: Chat pipeline and routes

- **GOAL-005**: `/api/chat` streams answers built from the cached layout, with turns saved and usage logged.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-050 | **Red → Green:** `lib/agent/pipeline.ts` `prepareTurn(db, { conversationId, message, now })` → `{ turnId, messages }`: loads the conversation (null → not found), runs `recall`, builds the context block, inserts the turn, builds the model messages. **Tests:** no recall for a plain question (context block is only `<ctx>`); a recall block for a back-reference; the turn row holds exactly the context block used; a second call replays the first turn from storage (TEST-003 again, through the DB). | REQ-010, REQ-042 | | |
| TASK-051 | **Red:** `app/api/chat/route.test.ts` with `MockLanguageModel*` and the fake search: 400 for an empty or 4,001-char message; 404 for an unknown conversation; the turn exists before the first stream chunk; a tool-call round-trip (the model calls `web_search`, gets the results, answers); `onFinish` saves `assistant_msg`, sets `answered` and touches the conversation; usage logged with `cachedInputTokens`; extraction scheduled via `after()`; a model error → turn `error`, generic message, no provider text in the response. | REQ-001, REQ-044, SEC-004, SEC-006, TEST-007 | | |
| TASK-052 | **Green:** the route per spec §4.8 (`streamText` with `SYSTEM_PROMPT`, `createTools`, `stopWhen: stepCountIs(MAX_STEPS)`, `consumeStream()`, `toUIMessageStreamResponse`). | REQ-001, CON-001 | | |
| TASK-053 | *(parallel)* **Red → Green:** `/api/conversations` GET/POST and `/api/conversations/[id]` GET. **Tests:** create with a valid / invalid timezone (→ `UTC`); list ordering; get returns turns without `context_block`; unknown id → 404. | REQ-002, API §4.8 | | |
| TASK-054 | **Manual:** with real keys, a 3-turn conversation through `curl`. Check the streamed answer cites sources; check the server log shows `cachedInputTokens` growing from turn 2. Record the numbers under Differences (RISK-002). | REQ-041, REQ-044, RISK-002 | | |

**Done when:** route tests pass and a real conversation streams with citations.

---

## Phase 6: Extraction and claims

- **GOAL-006**: Every answered turn gets tags, a refined conversation title and append-only claims, without slowing the response.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-060 | **Red:** `lib/memory/extract.test.ts` with a mocked model: tags and `done` written to the turn; title written to the conversation; a `new` claim inserted with `as_of` = the turn's date; `confirms` updates only `last_verified_at`; `supersedes` inserts and links; a `prior_claim_id` not shown in this turn's context → stored as `new`; more than 20 claims rejected by the schema; a model error → `done`, no tags, logged; the FTS index finds the turn by a tag afterwards. | REQ-020 – REQ-023 | | |
| TASK-061 | **Green:** `extractTurn` and `scheduleExtraction`. Claim ids shown in a turn are parsed from its `context_block` (`[c<id>]`). Settle Q-4: if the extraction model doesn't support structured output, use JSON-in-prompt plus zod parsing and record it. | REQ-020 – REQ-023, Q-4 | | |
| TASK-062 | **Manual:** run two real conversations a "day" apart (`?now=`), ask a pricing question, then "has it changed?". Inspect `claims` in the DB: the second turn confirms or supersedes the first turn's claims. | REQ-021, REQ-032 | | |

**Done when:** extraction tests pass and the manual run shows linked claims.

---

## Phase 7: UI

- **GOAL-007**: A clean, fast chat UI that shows what the agent is doing.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-070 | **Red → Green:** `ChatShell` + `ConversationSidebar`. **Tests** (RTL, `fetch` mocked): creates a conversation with the browser timezone when none exist; lists conversations; selecting one loads its turns; "New chat" creates one. | REQ-002 | | |
| TASK-071 | **Red → Green:** `ChatPane`, `Message`, `SearchStatus`. **Tests** (`useChat` mocked): markdown text and GFM tables render; links open in a new tab; a `web_search` part in progress shows its queries, a finished one shows the source count; an error shows a readable message; Enter sends, Shift+Enter adds a line; Stop shows while streaming. | REQ-001, TEST-009 | | |
| TASK-072 | *(parallel)* **Red → Green:** `ClockBanner` and the empty state. **Tests:** the banner shows the override time when `?now=` is set and hides otherwise; the `now` value is sent with each chat request and conversation creation; three suggested prompts send on click. | REQ-050 | | |
| TASK-073 | **Manual:** browser QA at desktop and phone width: streaming, search status, tables, long answers, switching conversations mid-stream. | REQ-001 | | |

**Done when:** component tests pass and the manual QA list is clean.

---

## Phase 8: Seed and evals

- **GOAL-008**: Graders can test "last Tuesday" today, and behaviour is measured, not assumed.

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-080 | **Red → Green:** `scripts/fixtures/seed.ts` and `scripts/seed.ts` (`--yes` required to reset). **Tests:** seeding `testDb()` creates the three conversations with the planned dates, tags and claims; `recall` with now = 2026-11-14 finds the 11-10 turn for "last Tuesday … Postgres" and the 11-03 turn for "3 November". | REQ-051 | | |
| TASK-081 | `scripts/fixtures/scenarios.ts` (E1 – E15 from spec TEST-008: messages, `now`, seed or empty DB, rubric lines, and checks the runner can do in code, such as "no `web_search` call" or "one call with ≥ 3 queries") and `scripts/eval.ts` (runs each through `prepareTurn` + `streamText` + awaited extraction, judges with `generateObject`, prints a table, exits non-zero on failure). E13 swaps in a failing `SearchProvider`. **Test:** the runner with a mocked model and judge produces the table and exit code. | REQ-052, TEST-008 | | |
| TASK-082 | **Manual:** `npm run eval` with real keys. Fix prompt or recall issues until all scenarios pass, or record the remaining failures and why under Differences. Note the pass rate and cost per run for DESIGN.md. | TEST-008, REQ-030 – REQ-032 | | |

**Done when:** `npm run eval` passes (or remaining failures are explained), and `npm run seed` + `?now=2026-11-14` demonstrates E3 in the browser.

---

## Phase 9: Ship

| Task | Description | Spec | Completed | Date |
|------|-------------|------|-----------|------|
| TASK-090 | `README.md`: what it is, three-step setup (keys → `npm install` → `npm run dev`), where to get free keys, `npm run seed` + `?now=` to try the memory questions, `npm test` / `npm run eval`. | CON-003, ASSUMPTION-003 | | |
| TASK-091 | `DESIGN.md`, one page: how it works (the pipeline and the memory model), why (the test examples, LongMemEval / Zep / Mem0 / ChatGPT vs Claude memory), considered and rejected (spec §6), the caching layout and what was observed (TASK-054), eval results (TASK-082), and what we'd do with another week. | Brief | | |
| TASK-092 | **Verify:** `npx eslint .`, `npx tsc --noEmit`, `npm test`. Then a clean clone in a new folder: `npm install`, copy `.env.example` to `.env`, fill keys, `npm run dev`, ask E3 after seeding. Windows and one Unix-like environment if available. | CON-003, CON-005 | | |
| TASK-093 | Create the public GitHub repo and push (only with the owner's go-ahead). Check that no `.env`, `data/` or key appears in the history. | SEC-001 | | |
| TASK-094 | Review the decisions table and fill in Differences. Update the spec's status and answers to Q-1 – Q-4. | — | | |

## Requirement traceability

| Requirement | Tasks |
|---|---|
| REQ-001 | TASK-051, TASK-052, TASK-071, TASK-073 |
| REQ-002 | TASK-030, TASK-053, TASK-070 |
| REQ-003, REQ-006 | TASK-041, TASK-042 |
| REQ-004, REQ-005 | TASK-026, TASK-082 |
| REQ-010 | TASK-010, TASK-031, TASK-050 |
| REQ-011 – REQ-016 | TASK-021 – TASK-024, TASK-031, TASK-033 |
| REQ-017 | TASK-025, TASK-030 |
| REQ-020 – REQ-023 | TASK-060, TASK-061, TASK-062 |
| REQ-030 – REQ-032 | TASK-026, TASK-062, TASK-082 |
| REQ-040 | TASK-026, TASK-042 |
| REQ-041 – REQ-043 | TASK-025, TASK-050, TASK-054 |
| REQ-044 | TASK-051, TASK-054 |
| REQ-050 | TASK-020, TASK-072 |
| REQ-051 | TASK-080 |
| REQ-052 | TASK-081, TASK-082 |
| REQ-053 | TASK-000, TASK-004, TASK-005 |
| SEC-001 | TASK-000, TASK-005, TASK-041, TASK-093 |
| SEC-002 | TASK-026, TASK-042 |
| SEC-003 | TASK-023 |
| SEC-004 | TASK-051 |
| SEC-005 | TASK-020 |
| SEC-006 | TASK-042, TASK-051 |
| CON-003 | TASK-000, TASK-011, TASK-092 |
| CON-004 | TASK-001 – TASK-003 |

## Differences from the spec

None yet. Record each deviation here as it happens, with the spec id and the reason.
