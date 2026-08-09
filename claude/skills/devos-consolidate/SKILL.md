---
name: devos-consolidate
description: Maintenance pass over the second brain — find near-duplicate, contradicting, oversized, or stale memory and file consolidation proposals into brain/inbox/ for approval via /devos-promote.
argument-hint: "[area|filename]"
disable-model-invocation: true
---

`$ARGUMENTS` is either empty (consider everything the scan flags) or an area
(`standards`, `playbooks`, `inbox`) or a filename to restrict the pass to.

Every other brain ritual looks *outward* — `/devos-promote` judges new lessons arriving
from tasks. This one looks *inward* at memory that is already permanent: duplicates that
accumulated, two standards that now contradict each other, a playbook that outgrew its
file. It proposes; it never edits permanent memory. That gate stays with `/devos-promote`.

This skill only ever operates on the DevOS source repository, never the current project.

## 1. Resolve the DevOS root

(a) The current Git root, if it contains both `brain/inbox/` and `sync.ps1`; else
(b) `~/Projects/personal-dev-os`. Verify the resolved path actually has both before
writing anything. If neither resolves, stop without writing and report.

## 2. Scan (read-only, deterministic)

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Jonathan\Projects\personal-dev-os\scripts\brain-scan.ps1"
```

(Absolute path — `sync.ps1` installs only this skill directory to `~/.claude/skills/`;
the script stays in the source repo.)

Parse stdout as JSON. If the exit code is nonzero, the output does not parse, or
`schemaVersion` is not `1`: stop, report the failure verbatim, and propose nothing —
never consolidate memory from guessed state.

The scan reports `flags` (files worth opening) and `overlaps` (the top similarity pairs,
flagged or not, with their scores). A flag is not a verdict. It is a reason to read.

## 3. Read only what the flags name

Open both sides of each flagged pair and each flagged file — **nothing else**. Cap the
pass at 10 files; if the flags name more, take them in the step-4 priority order and say
in the summary which were deferred to the next run. Never load the whole brain.

## 4. Judge each flag

Work in this order — earlier kinds are cheaper to be sure about:

- **broken-link** — the link target does not exist. Propose the corrected path, or
  removing the link. Do not guess a target you have not confirmed exists on disk.
- **stale-candidate** — an inbox candidate has been waiting past the threshold. This is
  never a content problem: propose nothing, and report it in the summary as
  "`/devos-promote` is overdue". Do not judge, rewrite, or triage the candidate here.
- **near-duplicate** / **near-duplicate-title** — the default answer is **keep both**.
  Propose a merge only when the two files answer the *same question*; when they answer
  adjacent questions, keep both and say what distinguishes them in the summary. A high
  score on files with genuinely different subjects is a scan false positive — report it
  as such rather than manufacturing a merge to justify the flag.
- **oversize** — propose a split only if the file covers independent topics that would
  be found by different searches. A long file on one subject is fine.

Then, from the same scan data (not a flag — a judgement call):

- **harden** — a playbook with `revisions` ≥ 3 has been amended repeatedly, which is
  evidence it is load-bearing. Consider proposing it be lifted into `brain/standards/`.
  Only with the revision history as evidence.

**Contradictions** are the one thing the scan cannot detect; look for them in the pairs
you have already opened for another reason. Propose a resolution only when both files
make claims that cannot both hold, and quote both. Never resolve by preferring the newer
file — if the evidence does not settle it, file it with the resolution left open and say
plainly that it needs Jonathan's call.

## 5. Evidence gate

A proposal is eligible only if it can be checked **without trusting your summary**: it
must quote the specific lines from each target. A similarity score is not evidence — it
is only what made you look. If you cannot quote the conflict or the duplication, there is
no proposal.

Two hard limits:

- **Cap 5 proposals per run.** The bottleneck is Jonathan's review, not detection.
  Beyond five, file the strongest five and name the rest in the summary.
- **Writing nothing is a successful run.** A ritual obliged to produce output every time
  will produce noise, and noise in permanent memory is worse than a gap.

## 6. File the proposals

One file per proposal at `brain/inbox/YYYY-MM-DD-consolidate-<slug>.md`, following
`C:\Users\Jonathan\Projects\personal-dev-os\templates\consolidation-proposal.md` exactly
(absolute path — `templates/` stays in the source repo). Keep `Kind: consolidation` in
the frontmatter list: that is what tells `/devos-promote` to apply per-target approval
for a change that rewrites existing memory.

Fill in **What is lost** honestly. "Nothing" is valid only when every claim, caveat, and
source line in the targets survives into the destination.

## 7. Summarize

One short paragraph in chat: what the scan measured (file count, flag count), how many
proposals were filed and what each does, the most interesting *non*-finding (a flagged
pair you judged worth keeping separate, and why), and anything deferred. Point at the
filed candidates and note that `/devos-promote` applies them.

## Guardrails

Writes **only** new files in `brain/inbox/`. Never edits or deletes anything in
`brain/standards/`, `brain/playbooks/`, `brain/reviews/`, `brain/projects.md`,
`brain/connections.md`, or the global `CLAUDE.md` — a consolidation reaches permanent
memory through `/devos-promote` and Jonathan's per-target approval, or not at all.
Never deletes an inbox candidate, including a stale one. Never commits or pushes. Never
records raw scan output, conversation transcripts, or secrets in a proposal.
