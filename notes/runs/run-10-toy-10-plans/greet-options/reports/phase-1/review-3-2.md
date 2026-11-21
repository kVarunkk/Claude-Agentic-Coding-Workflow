# phase-1/review-3-2.md

verdict: pending

Unit 3 (TASK-030, TASK-031) review in progress. Date: 2026-11-19.

## Findings so far

- F01 (candidate, P1): REQ-003 "no error is raised" broken for `--times`/`--lang`/`--format`.
  `greet --lang ES --lang fr` exits 2 with a usage error; the base returned `{lang:'fr'}`.
  Mutation 5 (validate only the last occurrence) stays GREEN: no test pins this.
