---
name: devos-mvp-spec
description: Turn a business idea into a right-sized MVP specification — staged discovery, focused questions, prioritised proposal, critical review, then project-owned planning docs on approval.
argument-hint: "[idea or focus]"
disable-model-invocation: true
---

`$ARGUMENTS` is the idea or focus, in the user's own words. If empty, ask what idea to spec before doing anything else.

## Ownership rules

- All generated product documents belong to the **current project repository**. Never write project product plans, requirements, or roadmaps into the DevOS brain.
- General reusable lessons reach the brain only through `brain/inbox/` and `/devos-promote` — never directly from this skill.
- When an architectural or product decision needs to be made, recommend recording it with `/devos-decision` instead of silently deciding it here.

## Stage 1 — Repository and context discovery

1. Confirm the current directory is inside a Git repository (`git rev-parse --show-toplevel`). If not, stop and report.
2. Read what already exists: the project's `CLAUDE.md`, `README`, `docs/STATUS.md`, and any existing product documents (e.g. `docs/product/`). Inspect application code only as needed to understand what is already built.
3. Never read `.env` values or other credentials.
4. Tag every piece of context as one of: **verified fact** (read directly from the repo), **user statement** (what Jonathan said), or **assumption** (unconfirmed). Never blend them without saying which.

## Stage 2 — Discovery questions

Ask only the highest-value questions that Stage 1 did not answer, drawn from:

- Who is the primary customer?
- What painful problem is being solved?
- What do they currently do instead?
- What outcome are they paying for?
- What evidence exists that the problem is real?
- What constraints apply (time, budget, skills, platform)?
- What is explicitly out of scope?

Ask in small batches — never dozens at once. Skip anything already answered.

## Stage 3 — MVP proposal

Produce a proposal with these sections, in order:

1. Target customer
2. Problem statement
3. Value proposition
4. Primary user journey
5. MVP success metric (measurable)
6. Assumptions and evidence (clearly separated)
7. Features, prioritised **Must / Should / Later / Excluded**
8. Risks — technical, business, and operational
9. Validation experiments (measurable; prefer tests that need no code)
10. Technical implications
11. Implementation milestones
12. Decisions requiring Jonathan's explicit approval

Scope ceiling: the MVP must be buildable by one developer. A Must list that cannot ship small is a scoping failure — cut scope, don't grow the MVP. Do not produce a vague startup essay.

## Stage 4 — Critical review

Before writing any file, challenge the Stage 3 proposal for:

- invented customer demand;
- feature creep;
- premature infrastructure;
- missing security/privacy concerns;
- unclear monetisation;
- dependencies on unverified assumptions;
- work that can be validated without writing code;
- simpler alternatives.

Revise the proposal accordingly and state what changed and why.

## Stage 5 — Project-owned outputs

1. Show the proposed file list and wait for explicit approval before writing anything.
2. Default candidates, project-relative — create only what this project justifies (a single `mvp-spec.md` is often enough):
   - `docs/product/mvp-spec.md`
   - `docs/product/validation-plan.md`
   - `docs/product/roadmap.md`
3. Update `docs/STATUS.md` only after explicit approval.
4. Do not commit or push.

## Safety rules

- Never invent market evidence; label every assumption as such.
- Do not claim product-market fit; do not state revenue estimates as fact.
- Do not install dependencies, modify application code, deploy, or run migrations.
- Do not contact customers or any external service.
- Never expose secrets.
- Keep the document set small and maintainable — a few living documents, not a binder.
- Prefer validation before implementation wherever possible.
