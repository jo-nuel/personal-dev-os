---
name: devos-decision
description: Record an architectural or process decision as an ADR in the current project's docs/decisions/, checking for duplicates or supersession first.
argument-hint: "[decision summary]"
disable-model-invocation: true
---

`$ARGUMENTS` is the decision summary in the user's own words.

1. Confirm the current directory is inside a Git repository. If not, stop and report.
2. The **current project repository** is the source of truth for this decision — never write project decisions into the DevOS brain.
3. List existing files under `docs/decisions/` in this repo.
4. Search their titles/context for a decision covering the same subject as `$ARGUMENTS`.
5. If a likely duplicate, or a decision this would supersede, already exists, report which file and why it looks related, and stop — ask the user how to proceed instead of creating a new file.
6. Otherwise create `docs/decisions/YYYY-MM-DD-<slug>.md` (slug = kebab-case of the summary) using `templates/adr.md` from the DevOS repo as the schema: title, date, status, context, decision, alternatives considered, positive and negative consequences, security and operational implications, verification or evidence, and the conditions that would trigger revisiting it.
7. Set status to `Proposed` unless the user's message explicitly states the decision is already accepted — only then use `Accepted`.
8. Never edit an existing accepted ADR's context/decision/consequences. If this is a change to a prior decision, create a new ADR that states it supersedes the old one, and update only the old ADR's status line to point at the new one.
9. Do not commit or push.
