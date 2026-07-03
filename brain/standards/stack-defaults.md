# Stack defaults

Verified environment facts, kept separate from preferences that haven't actually been decided yet.

## Environment (verified)

- OS: Windows 11
- Primary shell: PowerShell 5.1
- Secondary shell: Git Bash (available)
- Editor/integration: VS Code extension (Claude Code)

## Observed project stacks (verified from `brain/projects.md`, 2026-07-03)

- Next.js / TypeScript (with Prisma): Startup, thai kee checker
- Python / Django (Wagtail CMS): cambodian-welfare, cambodian-welfare-portfolio
- Java / Maven: Opal Management System
- Python + Node.js (mixed, no framework confirmed): job scraper
- PowerShell / Markdown / JSON (config, no app framework): personal-dev-os

No single language or framework dominates — treat "no stack as the default" per the global `CLAUDE.md`.

## Not yet standardised

These have not been explicitly decided across projects and must not be assumed:

- Preferred web framework beyond what each repo already uses
- Preferred database engine
- Preferred hosting/deployment provider
- Preferred testing library or test runner
- Preferred CI provider (Startup/others use whatever their repo already has: e.g. Azure Pipelines for Opal Management System)
