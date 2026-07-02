# Global Operating Instructions (DevOS)

Source of truth: `C:\Users\Jonathan\Projects\personal-dev-os`. Edit there and run
`sync.ps1` — never edit the copies under `~/.claude` directly.

## Who and where

- Solo developer (Jonathan) on Windows 11. PowerShell 5.1 is the primary shell; Git Bash is available.
- Projects live under `C:\Users\Jonathan\Projects` (Next.js/TypeScript, Python/Django, scripting — treat no stack as the default).
- Cross-project knowledge lives in `personal-dev-os/brain/`. Read specific files when relevant; never load the whole directory into context.
- Each repo owns its own architecture, decisions (`docs/decisions/`) and status (`docs/STATUS.md`). The brain holds only cross-project material.

## Task categories

- **tiny** — ≤ ~15 min, localized, no behavior-contract change (typo, small fix, doc tweak). No task file or branch required. Verification is still required.
- **standard** (default) — open a task file, work on a branch, plan first when non-trivial, verify, run `/code-review` before commit/PR, close the task file when done.
- **high-risk** — anything touching migrations, auth/permissions, data deletion, deploy configuration, payments/spend, external communications, or production. Requires: a written plan approved by Jonathan **before** implementation, per-action approval for the risky step itself, `/security-review` when security-relevant, and a rollback plan recorded in the task file.

## Verification

- "Done" means a deterministic check passed, not that the code looks right. If the repo has `scripts/verify.ps1` (or `verify.sh`), run it and require exit code 0 before claiming success.
- Report outcomes faithfully: failing tests are reported with their output, skipped steps are named as skipped.

## Model routing

- Default model is `sonnet`. Escalate to Fable (`/model fable`) only for: system/feature architecture, major planning, understanding a large unfamiliar codebase, hard debugging, migrations and long-horizon work.
- If two implementation attempts fail verification, stop retrying — re-plan (escalating the model if the plan itself is in doubt).
- Once a plan is written down, execution returns to `sonnet`. `/model` choices persist across sessions: switch back when the hard task ends.

## Memory rules

- Per-task notes live in `<repo>/.claude/tasks/<task>.md` (gitignored). Mark unverified statements with `ASSUMPTION:`. Delete the file when the task closes — assumptions must not outlive the task.
- Never write conversations, raw terminal output, secrets, or unverified conclusions into `brain/` or repo docs.
- A durable lesson becomes a candidate file in `personal-dev-os/brain/inbox/` (with evidence and how it was verified). Only Jonathan promotes candidates into permanent memory.
- Architectural choices are recorded as dated, append-only ADRs in the current repo's `docs/decisions/` — superseded, never edited.

## Safety

- Secrets: never read `.env` or credential values into context, echo them, or write them into any file. Permission deny rules back this up, but they are a guardrail for Claude Code's tools — not an OS security boundary (see `docs/secrets.md` in the DevOS repo).
- IT diagnosis and anything production-shaped defaults to read-only: gather evidence, then propose state-changing commands for approval instead of running them.
- Always ask before: production deploys, irreversible migrations, deleting files outside build artifacts, cloud/identity/credential changes, purchases or paid-service activation, external communications, force-pushing, or merging significant PRs.
