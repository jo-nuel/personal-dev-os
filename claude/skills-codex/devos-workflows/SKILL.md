---
name: devos-workflows
description: DevOS procedures and file templates — task files, ADRs, brain inbox candidates, weekly reviews. Use when opening or closing a task, recording an architectural decision, capturing a durable lesson, or writing any DevOS-format file.
---

# DevOS workflows (Codex)

The operating rules live in `~/.codex/AGENTS.md`. This file adds the **procedures and
file formats** those rules refer to.

## Propose, never write

Codex does not honour the `disable-model-invocation` flag that keeps these workflows
manual under Claude Code — verified by experiment on 2026-07-27, where a flagged skill
was auto-invoked from a plain question. So every workflow here is **proposal-only**:

> Produce the file content and the path it belongs at, show it, and stop. Do not create
> or modify the file. Jonathan applies it.

This matters most for `brain/` — nothing reaches permanent memory without his explicit
approval, and an autonomous write would route around the only gate that exists.

Reading is unrestricted. Read `brain/`, `docs/decisions/`, and `docs/STATUS.md` freely
to ground your work; just don't write to them.

## Task files

Standard and high-risk tasks get a file at `<repo>/.claude/tasks/<name>.md` (gitignored).

```markdown
# Task: <name>

- **Opened:** YYYY-MM-DD
- **Category:** tiny | standard | high-risk
- **Branch:** <branch-name>

## Goal
One sentence: what "done" delivers.

## Acceptance criteria
- [ ] criterion (verifiable)
- [ ] `scripts/verify.ps1` exits 0

## Plan
Steps, kept current as they change.

## Rollback plan (high-risk only)
How to undo the risky step.

## Working notes
Running scratchpad. Mark anything unverified as `ASSUMPTION: ...`.

## Lessons (candidates for brain/inbox)
Only verified, durable, cross-project lessons.
```

On close: confirm every criterion is checked or explained, confirm a verification
command and its result are recorded, then propose any durable lesson as an inbox
candidate (below). The task file is deleted at close — assumptions must not outlive it.

## ADRs

Architectural decisions go in the **current repo's** `docs/decisions/`, named
`YYYY-MM-DD-<slug>.md`. Append-only: never edit an accepted ADR, write a new one that
supersedes it.

```markdown
# ADR-000N: <title>

- **Date:** YYYY-MM-DD
- **Status:** accepted
- **Category:** architecture | tooling | process

## Context
The forces that made this a decision.

## Decision
What was decided, numbered.

## Alternatives considered
What else was on the table and why it lost.

## Consequences
What this commits us to, including the costs. State what is unverified.
```

Check `docs/decisions/` for the highest existing number first.

## Brain inbox candidates

A durable, cross-project lesson becomes a candidate at
`personal-dev-os/brain/inbox/YYYY-MM-DD-<slug>.md`. It does **not** go straight into
`brain/standards/` or `brain/playbooks/` — only Jonathan promotes candidates.

```markdown
# Candidate: <one-line lesson>

- **Date:** YYYY-MM-DD
- **Source:** <repo/task where this was learned>
- **Proposed destination:** brain/standards/... | brain/playbooks/...
- **Verified how:** the concrete evidence — a passing test, a reproduced fix, observed behaviour

## The lesson
State it fully, as it should appear in permanent memory.

## Evidence
Why we believe this. Summarise; no raw terminal dumps.
```

Ineligible: unverified conclusions, `ASSUMPTION`-tagged notes, secrets, conversation
logs, and anything project-specific (that belongs in the project's own repo).

## What stays Claude Code only

`/devos-promote` (writes into permanent memory), `/devos-consolidate` (proposes rewriting
existing memory), `/devos-mission-control` (publishes a hosted dashboard), and
`/devos-operate` (multi-agent orchestration) have no Codex equivalent. If work needs one,
say so and hand it back rather than improvising a substitute.
