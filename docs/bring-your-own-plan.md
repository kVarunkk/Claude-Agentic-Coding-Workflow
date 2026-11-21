# Build from your own spec and tasks

Use this when you already have a spec and a task list and want the pipeline to build it. You skip the interview and the spec and task writing. You still get everything after that: verification, test-first implementer units, code review with mutation checks, phase conformance checks, the gates (or AFK) and the PR.

## In short

```
/build-feature <feature> --from <your-spec.md> <your-tasks.md>
```

The pipeline copies both files in and reformats them to its own format. It shows you a diff of every change it made to your text. You approve, and it builds.

## Before you start

- **Install the pipeline** in the project (`install.sh`, see the README). The project needs a git repo and `TEST_CMD` set in `.claude/pipeline.conf`.
- **Commit or stash** your work. The build runs on a new `feature/<feature>` branch, and every unit commit needs a clean tree.
- **Pick a feature name** in kebab-case, for example `csv-export`. Everything goes under `plans/<feature>/`, and that folder must not already hold a brief, spec or tasks file. An import never overwrites a plan.
- **Your files** can be anywhere, in any Markdown shape. They do not need ids, sections or the tasks table, because the pipeline adds those. What helps:
  - **Spec:** what the feature does, with examples, numbers, limits and error cases. Anything you leave out becomes an open question at the spec gate, not a guess.
  - **Tasks:** your phases in order, with tasks under each. Say which files a task touches if you know. Mark tasks you already finished as done; they are kept done and skipped.
- Run the session in **auto or accept-edits mode** if you plan to pick AFK at the tasks gate.

## Steps

### 1. Start the run

```
/build-feature csv-export --from docs/csv-export-spec.md docs/csv-export-tasks.md
```

The pipeline creates the branch `feature/csv-export`. It copies your files to `plans/csv-export/feature-csv-export-spec.md` and `-tasks.md` unchanged (your originals are not touched). It writes a short brief marked `source: imported`, which says that your files are the agreement.

### 2. Agree to the import

You get one question: **Build from these files?** Choose **Agree**.

The pipeline commits your files as they are and tags that commit `csv-export-imported`. Every diff you see later starts from this tag, so you can always see your own text next to the pipeline's changes.

### 3. Review the reformatted spec

The spec-writer brings your spec to the pipeline format: front matter, sections, and ids (`REQ-001`, `TEST-001`, ...) that the reviewers and conformance checks grade against. It keeps your requirements, examples and numbers, in your words where it can. It does not add or drop behaviour. Where the format needs something your text does not say, it writes an open question instead of a requirement.

The spec-verifier then reviews the spec. At the **spec gate** you see:

- `plans/csv-export/reports/spec/import-diff.md`: your text (`-` lines) next to the reformat (`+` lines), with a diffstat. Fix rounds after it are in `git diff csv-export-imported HEAD -- plans/csv-export/feature-csv-export-spec.md`.
- The verifier's report and its findings.
- The open questions, which you answer in the same question.

Choose **Approve**, **Request changes** (describe what to change; a new writer round applies it and the gate comes back), or **Stop**.

### 4. Review the reformatted tasks

The task-writer then reformats your tasks file. It keeps your phases, their order and each task's wording, and makes these changes:

- It numbers units `1`, `2`, ... and splits a phase with more than `MAX_UNIT_TASKS` tasks (default 5) into `2a`, `2b`.
- It orders each unit test-first.
- It fills the **Spec** column with the approved spec's ids and the **Files** column from your text and the code.
- It adds a task only where a spec requirement has none, and tells you which.

`check-plan.sh` and the task-verifier check the result. At the **tasks gate** you see the units in order, `plans/csv-export/reports/tasks/import-diff.md`, and the splits and added tasks. Choose:

- **Approve:** you approve each phase as it finishes.
- **Approve and run to the end (AFK):** no more gates until the final review.
- **Request changes**, or **Stop**.

### 5. The build

From here the run is the same as any `/build-feature` run. For each unit, an implementer writes the tests and code, and a code-reviewer checks them. A unit that fails review gets a fix round. A unit that passes is committed. At each phase end, a conformance check runs against the spec, followed by a phase report and a tag. Then come the final report, the final gate and an optional PR. The PR's "Why" comes from your spec's overview.

## Stopping and resuming

All state is in `plans/<feature>/` and git. Run `/build-feature <feature>` (without `--from`) to carry on. `status.sh` prints an `import:` line that tells the run where to continue:

| `import:` | Meaning |
|---|---|
| `none` | Not an imported plan. |
| `spec` | The spec reformat has not finished yet. |
| `tasks` | The spec is approved; the tasks reformat has not finished yet. |
| `done` | No reformat is due now. The run continues as usual. |

If you stopped at the **Build from these files?** question, rerunning shows it again.

## Good to know

- **Your file is already in the pipeline format.** The writer changes only what does not fit. The import diff then says "No changes", or lists only small fixes.
- **You want to change a requirement.** Use Request changes at the spec gate, not your original file. The pipeline works from its copy in `plans/<feature>/`.
- **The verifier finds gaps in your spec**, for example a requirement with no error case. In an imported plan, a gap the writer would have to invent behaviour for becomes an open question for you. It is never filled in silently.
- **You want to start over.** Delete `plans/<feature>/` (and the `<feature>-imported` tag, `git tag -d <feature>-imported`) before you import again. The pipeline never deletes or moves tags itself.
- **Under the hood**, `.claude/scripts/import-plan.sh` does the copy (`import-plan.sh <plan> <spec> <tasks>`) and writes each diff report (`import-plan.sh --diff <plan> spec|tasks`).
