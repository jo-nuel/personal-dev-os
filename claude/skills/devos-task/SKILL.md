---
name: devos-task
description: Open, check status of, or close a per-repo DevOS task file under .claude/tasks/. Classifies work as tiny/standard/high-risk per the global task-category rules.
argument-hint: "<open|status|close> [task name]"
disable-model-invocation: true
---

Parse `$ARGUMENTS`: the first word is the subcommand (`open`, `status`, or `close`); anything after it is the task name/description (only used by `open`).

## Preconditions (all subcommands)

1. Confirm the current directory is inside a Git repository (`git rev-parse --show-toplevel`). If not, stop and report.
2. Resolve the repo root from that command's output. All paths below are relative to it.

## `open <task name>`

1. List `.claude/tasks/*.md` at the repo root. If one is still active (no close summary was ever confirmed for it), do not overwrite it — report the active task and stop; the user must close it first or explicitly say to abandon it.
2. Classify the requested work as **tiny**, **standard**, or **high-risk** using the task-category definitions in the global DevOS `CLAUDE.md`. State the classification and a one-line reason.
3. **Tiny:** do not create a task file. Return a short checklist of concrete steps plus the exact verification command (`scripts/verify.ps1` / `verify.sh` if present in this repo, otherwise say none exists) that must pass before calling it done.
4. **Standard / high-risk:** create `.claude/tasks/YYYY-MM-DD-<slug>.md` (slug = kebab-case of the task name) using `templates/task.md` from the DevOS repo as the schema — goal, category, acceptance criteria, plan, rollback plan (high-risk), working notes, lessons. Fill in what's known now; leave the rest as placeholders.
5. **High-risk only**, additionally record: affected systems/data, the specific approval gate(s) required before implementation proceeds, the rollback plan, and which actions must stay read-only until approved.
6. Never write credentials, `.env` values, access tokens, or raw sensitive log output into the task file.

## `status`

1. Find the active task file under `.claude/tasks/` (if more than one exists, list them and ask which).
2. Report, read-only: task name, category, acceptance criteria with checked/unchecked state, completed steps, blocked items, the latest recorded verification result, and the next recommended action.
3. Make no file changes during this subcommand.

## `close`

1. Locate the active task file.
2. Confirm every acceptance criterion is either checked or explicitly explained as not applicable.
3. Confirm a verification command and its result are recorded in the file. If missing, stop — report exactly what verification is missing and do not close.
4. Confirm the review required for the task's category was performed (standard/high-risk require `/code-review`; high-risk also `/security-review` when security-relevant). If not recorded, stop and report.
5. List any unfinished work or known limitations plainly.
6. Read the file's "Lessons" section and split it into: temporary task detail (discard), project-specific fact (stays in the project's own docs, not copied to the brain), and general reusable lesson (candidate for the DevOS brain).
7. For each general reusable lesson, resolve the DevOS root: (a) the current repo, if it is itself the DevOS repo (contains `brain/inbox/` and `sync.ps1`), else (b) `~/Projects/personal-dev-os`. Verify the resolved path actually contains both `brain/inbox/` and `sync.ps1` before writing anything.
8. Write one candidate per lesson to `brain/inbox/YYYY-MM-DD-<slug>.md` using `templates/inbox-candidate.md` as the schema: source repository, source task, proposed destination, the lesson, supporting evidence, how it was verified, known limitations. Do not promote it further — that is `/devos-promote`'s job.
9. Show the full close summary (criteria, verification, review, unfinished work, lessons filed) and ask for explicit confirmation before deleting the task file.
10. Only after explicit confirmation, delete the task file.
11. Do not commit or push at any point in this skill.
