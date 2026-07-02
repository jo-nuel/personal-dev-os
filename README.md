# personal-dev-os

Personal AI-assisted development operating system: the source of truth for my
global Claude Code configuration, second brain, templates, and workflows.

## Layout

```
claude/                 DevOS-managed Claude Code config (source of truth)
  CLAUDE.md             global operating instructions -> synced to ~/.claude/CLAUDE.md
  settings-devos.json   DevOS-owned settings fields (model, effort, secret deny rules)
  skills/               devos-* skills -> synced to ~/.claude/skills/
brain/                  second brain (cross-project knowledge only)
  standards/            permanent personal standards
  playbooks/            symptom-indexed troubleshooting knowledge
  reviews/              weekly reviews
  inbox/                proposed memory candidates awaiting my approval
  projects.md           one-line index of all projects (detail lives in each repo)
templates/              ADR, task, playbook, inbox, review, repo CLAUDE.md, verify.ps1
docs/                   system documentation (secrets.md, decisions/)
sync.ps1                installs claude/ into ~/.claude — safe merge, see below
```

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

## Principles (short form)

- Project knowledge lives in the project repo; the brain holds only cross-project material.
- Nothing enters permanent memory without passing through `brain/inbox/` and my approval.
- Done = deterministic verify script passed, not model confidence.
- Sonnet by default; Fable only for deliberately escalated high-value work.
- Secret deny rules are a guardrail, not a security boundary — see `docs/secrets.md`.
