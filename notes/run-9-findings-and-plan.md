# Run 9 (dostuff, toy-10) findings and plan

Source: `notes/runs/run-9-dostuff-toy-10.md` (was `Downloads/toy-10/dostuff-session-9664ab159daf42ad.md`; plans and reports in `notes/runs/run-9-toy-10-plans/`) (greet-options on `toy-10`, not AFK).
Pipeline: installed with the uncommitted R34-R50 work on `fix/run-7-findings`. Orchestrator: deepseek-v4.1-flash; `opus` alias switched by the orchestrator between minimax-m3, grok-4.7, mimo-v2.6-flash and claude-haiku-5-5.
Cost: 8.8M input tokens.
Result: brief and spec (v0.4) approved; stopped at step 3.1 with no tasks file. User chose Stop.

## Root cause (outside the pipeline)

- dostuff recorded `finish_reason` but never checked it: a reply cut off at the output cap, with text and no tool call, was taken as the agent's final answer. Every stalled writer reply ends mid-sentence.
- dostuff sent no `max_tokens`. litellm needs one on the Anthropic route (minimax-m3, qwen3.8-*, qwen3.7-plus) and, for a model it does not know, sends `DEFAULT_ANTHROPIC_CHAT_MAX_TOKENS = 4096` (litellm 1.99.0, `llms/anthropic/chat/transformation.py:274`). minimax-m3 allows 131,072 (models.dev). This fits "3 to 4k tokens of planning, then the turn ended".
- litellm maps Anthropic `max_tokens` to `length` and passes OpenAI `length` through; an unknown reason becomes `stop`.
- Fixed by the user in agent-1 `dostuff/output-limit`: cut-off replies get a continue note (3 in a row at most), cut-off tool arguments get a specific error, `loop.max_tokens` and per-agent `max_tokens:`.
- Output limits per model: models.dev `api.json`, `opencode-go.models.<id>.limit.output`. The smallest in the opencode-go list is 64,000.

## Findings (pipeline)

- **R51. Writers plan the whole file in their reply.** Task-writer (minimax x2, grok, haiku, mimo cancelled) and spec-writer (x2) read everything, then drafted units or sections in the reply text and were cut off before Write. Fix: write in parts (skeleton Write, then one Edit per unit or section), never draft in the reply, continue a part-written file on restart.
- **R52. The orchestrator changed models itself.** Six `edit_config` edits of `agents.models.opus`, which also moved spec-verifier and task-verifier, and one pick (`claude-haiku-5-5`) returned empty responses. No rule forbade it and `check-write.sh` did not match `edit_config`. Fix: build-feature rule; hook blocks `edit_config` and writes to the settings, config.yaml and pipeline.conf while a run is open.
- **R53. "One restart per agent run" ignored.** Five task-writer spawns, one `restart` logged. Fix: `check-spawn.sh` keeps a spawn log in the git dir; blocks a third writer spawn with the same prompt at the same HEAD and a PARTIAL: restart of a report that was itself a restart; `approve.sh PLAN retry` lets the user allow one more.
- Restart check bug found on the way: build-feature used `git diff --stat -- <file>` to see whether a writer wrote anything, which shows nothing for an untracked new file.

## Status

R51-R53 implemented 2026-11-19 on `fix/run-7-findings` (uncommitted, with R34-R50). Tests: test-hooks 144 passed, test-scripts 184 passed; `install-dostuff.sh --check` in sync on a scratch install.

Next: commit, then a fresh toy with `dostuff-toy.ps1 <name> -Rebuild` on agent-1 `dostuff/output-limit`.
