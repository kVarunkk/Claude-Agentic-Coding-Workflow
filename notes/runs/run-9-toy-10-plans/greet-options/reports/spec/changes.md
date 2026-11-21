# P2 notes to fix in the spec

Source: `plans/greet-options/reports/spec/review-6.md` (verdict: pass, p2: 6).
Fix all six. Change nothing else in the spec.

- **F03** spec:191 cites "D-024", which does not exist (brief decisions end at D-20). Cite D-07 (the config validation rules) instead.
- **F04** spec:53,168 empty `--opt=` values are unspecified. Add a sentence to REQ-032 stating that an empty `--opt=` value counts as a missing value (a usage error).
- **F05** spec:188 `loadConfig` does not say what happens when the directory or file cannot be read. State that any read error, including a missing directory or an unreadable file, yields `{}`.
- **F06** spec:81,269,281 TEST-011 needs exit-code and stderr assertions that the existing `execFileSync` helper cannot give (it throws on a non-zero exit). State that the usage-error test uses `spawnSync`, or catches the `execFileSync` error and reads `error.status`, `error.stdout` and `error.stderr`.
- **F07** spec:287 vs :52,172 RISK-001 tells the test to match the reason prefix, which would not check REQ-031's exact wording. Narrow RISK-001 to the usage-summary part of the line, and state that the reason text itself is asserted exactly.
- **F08** spec:46,193 the empty `name` (an empty string in the config, or `--name ""`) has no defined result. State what an empty name does.
