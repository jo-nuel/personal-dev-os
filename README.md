# personal-dev-os

Personal AI-assisted development operating system: the source of truth for my
global Claude Code configuration, second brain, templates, and workflows.

## Layout

```
claude/                 DevOS-managed Claude Code config (source of truth)
  CLAUDE.md             global operating instructions -> synced to ~/.claude/CLAUDE.md
  settings-devos.json   DevOS-owned settings fields (model, effort, hooks, secret deny rules)
  skills/               devos-* skills -> synced to ~/.claude/skills/
  skills/external/      vendored third-party skills -> synced to ~/.claude/skills/
brain/                  second brain (cross-project knowledge only)
  standards/            permanent personal standards
  playbooks/            symptom-indexed troubleshooting knowledge
  reviews/              weekly reviews
  inbox/                proposed memory candidates awaiting my approval
  projects.md           one-line index of all projects (detail lives in each repo)
templates/              ADR, task, playbook, inbox, consolidation, review, repo CLAUDE.md, verify.ps1
scripts/                cross-cutting DevOS scripts (mission-control scan, brain scan, verify)
docs/                   system documentation (secrets.md, decisions/)
agent/                  Python: task classification + model routing (see below)
tests/                  pytest suite for agent/ — mocked, needs no API key
pyproject.toml          Python deps, managed with uv
sync.ps1                installs claude/ into ~/.claude — safe merge, see below
```

## Agent model routing (`agent/`)

`run_task()` classifies a task with Haiku, maps the label to a model, and either
makes a live call or queues a Batch API request:

| Tier | Model | Used for |
|---|---|---|
| trivial | `claude-haiku-4-5-20251001` | renames, typos, one-line fixes, lookups |
| standard | `claude-sonnet-5` | ordinary features, bug fixes, focused refactors |
| hard | `claude-opus-5` | architecture, migrations, tricky debugging |

```python
from agent import run_task

r = run_task("rename the config flag")          # classified, live call
r = run_task("nightly digest", interactive=False)  # queued via Batch API (50% off)
r = run_task("fix typo", tier="trivial")        # skips the classifier round-trip
```

Classification costs one extra Haiku call per task; pass `tier=` when the caller
already knows the difficulty. Check `r.complete` before trusting `r.text` — it is
False on a refusal or a `max_tokens` truncation. Rationale and the caching
caveats are in `docs/decisions/2026-07-18-agent-model-routing.md`.

Setup: `uv sync --extra dev`. Verify: `scripts/verify.ps1`.

## Installing / updating the config

```powershell
.\sync.ps1 -WhatIf    # show backup path, diff, and asset actions — writes nothing
.\sync.ps1            # interactive: shows the same, asks before applying
.\sync.ps1 -Force     # apply without prompting (after reviewing -WhatIf)
```

Guarantees: timestamped backup first; only DevOS-owned fields touched; semantic
preservation check aborts if any other setting would change; JSON validated
before writing; assets tracked in `~/.claude/.devos-manifest.json` and never
overwrite anything DevOS didn't install.

## Personal skills

Eight manual-only skills (`disable-model-invocation: true` — they never auto-fire,
only run when you type the command). `sync.ps1` installs them from
`claude/skills/devos-*` into `~/.claude/skills/`; a fresh Claude Code session is
required after the first install for them to appear.

| Command | Example | May write | Read-only? |
|---|---|---|---|
| `/devos-task` | `/devos-task open "Add profile editing"` | `.claude/tasks/*.md` in the current repo, `brain/inbox/*.md` on close | No |
| `/devos-decision` | `/devos-decision "Use PostgreSQL for prod"` | `docs/decisions/*.md` in the current repo | No |
| `/devos-promote` | `/devos-promote all` | `brain/standards/`, `brain/playbooks/`, `brain/reviews/`, `brain/projects.md` (only after explicit per-candidate approval) | No |
| `/devos-consolidate` | `/devos-consolidate playbooks` | `brain/inbox/*.md` only — proposals to merge/split/retire existing memory, applied via `/devos-promote` | No — but never touches permanent memory |
| `/devos-repo-brief` | `/devos-repo-brief "focus on deployment"` | nothing | Yes — runs in a forked `Explore` sub-agent with `Edit`/`Write`/`NotebookEdit` removed |
| `/devos-mvp-spec` | `/devos-mvp-spec "invoice reminder SaaS"` | `docs/product/*.md` and `docs/STATUS.md` in the current repo (only after explicit approval) | No |
| `/devos-operate` | `/devos-operate "ship the export feature"` | a scratchpad dashboard artifact (standard/high-risk goals only); delegates to `devos-task`/other skills, which own their own writes | No |
| `/devos-mission-control` | `/devos-mission-control` | only gitignored `.claude/mission-control.{json,html}` in this repo (artifact URL state + generated dashboard) | Read-only everywhere else — scan script never touches other repos |

None of these commit or push; that stays a manual, explicit step.

## External skills

Third-party skills (not authored by DevOS) are vendored into `claude/skills/external/`
so they're backed up and reproducible the same way as `devos-*` skills — `sync.ps1`
installs from both directories. Each vendored skill's origin repo, commit, and vendor
date is tracked in `claude/skills/external/SOURCES.md`; edit upstream and re-vendor
rather than modifying a vendored skill in place. Currently vendored: five skills from
[vercel-labs/agent-skills](https://github.com/vercel-labs/agent-skills) (`web-design-guidelines`,
`react-best-practices`, `composition-patterns`, `react-view-transitions`, `react-native-skills`),
plus `frontend-design` from [anthropics/skills](https://github.com/anthropics/skills).
Unlike the manual-only `devos-*` skills, these are model-invocable per their own
frontmatter — Claude may use them automatically when relevant.

## Hooks

Two DevOS-owned hooks are installed by `sync.ps1` (scripts live in `scripts/`,
config in `claude/settings-devos.json`):

- **SessionStart** (`hook-session-start.ps1`) — injects context at session open:
  active `.claude/tasks/*.md` in the current repo, and a nudge if mission-control
  data is more than 7 days old. Silent when there's nothing to say.
- **PreToolUse on Bash/PowerShell** (`hook-guard-force-push.ps1`) — detects
  `git push --force`/`-f`/`--force-with-lease` and forces a permission prompt,
  enforcing the "always ask before force-pushing" rule at the harness level
  instead of relying on the model remembering it.

## Principles (short form)

- Project knowledge lives in the project repo; the brain holds only cross-project material.
- Nothing enters permanent memory without passing through `brain/inbox/` and my approval —
  including the brain's own maintenance, which proposes rather than self-writes
  (`docs/decisions/2026-08-08-brain-consolidation.md`).
- Done = deterministic verify script passed, not model confidence.
- Sonnet by default; Fable only for deliberately escalated high-value work.
- Secret deny rules are a guardrail, not a security boundary — see `docs/secrets.md`.
