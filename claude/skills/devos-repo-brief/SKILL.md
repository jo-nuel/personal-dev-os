---
name: devos-repo-brief
description: Produce a read-only technical brief of the current repository — stack, structure, commands, docs, git state, and risks — without changing anything.
argument-hint: "[optional focus area]"
disable-model-invocation: true
context: fork
agent: Explore
disallowed-tools: Edit, Write, NotebookEdit
---

`$ARGUMENTS` is an optional focus area (e.g. "deployment and testing") — bias the brief toward it, but still cover every section below at least briefly.

This is a read-only investigation. Do not modify files, install packages, run migrations, start deployments, read real `.env` files, call external network services, change Git state, or create commits.

Inspect only what's needed to answer the brief:

- README and other project documentation
- `git status` / `git log` (recent history) — read-only
- package/dependency manifests (package.json, pyproject.toml, requirements.txt, etc.)
- source-directory structure and entry points
- test configuration
- lint/typecheck configuration
- CI workflow files
- `.env.example` (never the real `.env`)
- database schema/migration files, without connecting to a live database
- deployment configuration, without executing it

Produce a concise brief with these sections, in order:

1. Project purpose
2. Verified technology stack
3. Important directories and entry points
4. Available commands: run, lint, typecheck, test, build
5. Data-storage approach
6. External-service integrations (inferred only from safe config names, never from real credentials)
7. Existing documentation
8. Current Git state
9. Quality and security observations
10. Unknowns and assumptions
11. Recommended first three actions

Label every claim as **verified** (read directly) or **inferred** (guessed from indirect signals) — never blend the two without saying which.
