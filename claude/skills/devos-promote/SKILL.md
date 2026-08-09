---
name: devos-promote
description: Review brain/inbox/ candidates one at a time and, on explicit approval, promote them into the permanent DevOS second brain.
argument-hint: "[candidate filename|all]"
disable-model-invocation: true
---

`$ARGUMENTS` is either empty (review all candidates), a specific filename under `brain/inbox/`, or the literal `all`.

This skill only ever operates on the DevOS source repository, never the current project.

1. Resolve the DevOS root: (a) the current Git root, if it contains both `brain/inbox/` and `sync.ps1`; else (b) `~/Projects/personal-dev-os`. Verify the resolved path actually has both before writing anything. If neither resolves, stop without writing and report.
2. List candidates in `brain/inbox/`. If `$ARGUMENTS` names one file, restrict to it; otherwise process every candidate — but one at a time, even when invoked as `all`.
3. For each candidate, validate it contains: a proposed destination, source information, evidence, verification information, and no credentials/sensitive values. Note anything missing.
3a. A candidate carrying **`Kind: consolidation`** (filed by `/devos-consolidate`) is handled differently from a lesson candidate, because it proposes rewriting or deleting brain content that is *already permanent* — which no other candidate does. For those:
   - Read every file listed under `Targets:` before recommending anything.
   - Return it for more evidence if it does not quote the specific lines it relies on, or if **What is lost** is unfilled or left as the template text. A similarity score is not evidence.
   - Show Jonathan the concrete before/after for each target — the lines being replaced and what replaces them — and take approval **per target, never batched**. A single "yes" covers one file.
   - Never delete a target whose content is not carried into an approved destination. If the destination write is only partial, the target stays as it is.
   - The standard reject reasons in step 4 still apply, except "duplicates existing brain content" — for a consolidation proposal, that duplication is the point.
4. Recommend **reject** or **return for more evidence** when the candidate:
   - is only an assumption / lacks confirmed verification;
   - duplicates existing brain content;
   - is project-specific and belongs in that project's own repo instead;
   - is a raw transcript, terminal dump, or conversation log;
   - contains secrets or personal credentials.
5. Otherwise present one recommendation: **accept as new file**, **merge into an existing file**, **return for more evidence**, or **reject** — with the specific target file and reasoning.
6. Do not change any file until the user gives an explicit choice for that candidate.
7. Valid destinations are limited to `brain/standards/`, `brain/playbooks/`, `brain/reviews/`, `brain/projects.md` (index update only), and `brain/connections.md` (index update only). Never write project architecture, requirements, or ADRs into the brain — those stay in the project repo. Deleting or rewriting an existing file in those directories is permitted **only** via an approved `Kind: consolidation` candidate under step 3a.
8. Never modify the global `claude/CLAUDE.md` automatically. If a lesson seems important enough to load in every session, say so as a separate recommendation for the user to apply themselves.
9. On acceptance: write/merge the content into the destination, preserving the source and verification metadata from the candidate, then delete the inbox candidate — only after the destination write succeeds.
10. On rejection: delete the candidate only after the user explicitly confirms.
11. Do not commit or push.
