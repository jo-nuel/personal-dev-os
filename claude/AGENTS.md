# Operating Instructions (DevOS)

Read by any AI coding tool. Codex CLI reads this file natively from
`~/.codex/AGENTS.md`; Claude Code reads it via the `@AGENTS.md` import in
`~/.claude/CLAUDE.md`.

Source of truth: `C:\Users\Jonathan\Projects\personal-dev-os\claude\AGENTS.md`.
Edit there and run `sync.ps1` — never edit the installed copies under
`~/.claude` or `~/.codex` directly.

Anything in here must hold for *any* agent tool. Tool-specific mechanics
(model names, permission syntax, hooks) live in that tool's own file.

## Who and where

- Solo developer (Jonathan) on Windows 11. PowerShell 5.1 is the primary shell; Git Bash is available.
- Projects live under `C:\Users\Jonathan\Projects` (Next.js/TypeScript, Python/Django, scripting — treat no stack as the default).
- Cross-project knowledge lives in `personal-dev-os/brain/`. Read specific files when relevant; never load the whole directory into context.
- Each repo owns its own architecture, decisions (`docs/decisions/`) and status (`docs/STATUS.md`). The brain holds only cross-project material.

## Task categories

- **tiny** — ≤ ~15 min, localized, no behavior-contract change (typo, small fix, doc tweak). No task file or branch required. Verification is still required.
- **standard** (default) — open a task file, work on a branch, plan first when non-trivial, verify, review the diff before commit/PR, close the task file when done.
- **high-risk** — anything touching migrations, auth/permissions, data deletion, deploy configuration, payments/spend, external communications, or production. Requires: a written plan approved by Jonathan **before** implementation, per-action approval for the risky step itself, a security review when security-relevant, and a rollback plan recorded in the task file.

## Verification

- "Done" means a deterministic check passed, not that the code looks right. If the repo has `scripts/verify.ps1` (or `verify.sh`), run it and require exit code 0 before claiming success.
- Report outcomes faithfully: failing tests are reported with their output, skipped steps are named as skipped.

## Effort routing

Match the model/reasoning tier to the work, and drop back down when the hard part is over:

- **Low tier** — renames, typos, one-line fixes, lookups, mechanical edits.
- **Default tier** — ordinary feature work, bug fixes, focused refactors. This is where most work belongs.
- **High tier** — system or feature architecture, major planning, understanding a large unfamiliar codebase, hard debugging, migrations, long-horizon work.

If two implementation attempts fail verification, stop retrying — re-plan, escalating the tier if the plan itself is in doubt. Tier choices persist across sessions in most tools: switch back down when the hard task ends.

Each tool maps these tiers to its own models — see the tool-specific section of its instruction file.

## Choosing a tool for the work

Claude Code and Codex are both available and are billed from different pools.
Prefer the one whose cost pool is not under pressure, then its strengths:

- **Codex (GPT-5.6 Sol)** — usage is included in the ChatGPT Pro allowance (credit-metered underneath, but a large included cap). Prefer it for bulk or long-running work when Claude usage credits are the scarcer resource.
- **Claude Code** — preferred where DevOS's own guardrails matter, because the hooks and secret deny rules only exist on this side (see Safety).

Hand work to the other tool deliberately, not by accident: state what is being handed over and why. A handoff transfers control — the receiving tool owns the work and reports back; it is not a model swap.

## Memory rules

- Per-task notes live in `<repo>/.claude/tasks/<task>.md` (gitignored). Mark unverified statements with `ASSUMPTION:`. Delete the file when the task closes — assumptions must not outlive the task.
- Never write conversations, raw terminal output, secrets, or unverified conclusions into `brain/` or repo docs.
- A durable lesson becomes a candidate file in `personal-dev-os/brain/inbox/` (with evidence and how it was verified). Only Jonathan promotes candidates into permanent memory.
- Architectural choices are recorded as dated, append-only ADRs in the current repo's `docs/decisions/` — superseded, never edited.

## Safety

- Secrets: never read `.env` or credential values into context, echo them, or write them into any file. Some tools back this with permission rules, but those are a guardrail for that tool's own file operations — not an OS security boundary (see `docs/secrets.md` in the DevOS repo). Treat the instruction as the real constraint, since it is the only one every tool honors.
- IT diagnosis and anything production-shaped defaults to read-only: gather evidence, then propose state-changing commands for approval instead of running them.
- Always ask before: production deploys, irreversible migrations, deleting files outside build artifacts, cloud/identity/credential changes, purchases or paid-service activation, external communications, force-pushing, or merging significant PRs.
