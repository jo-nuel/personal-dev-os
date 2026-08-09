# ADR-0005: The brain consolidates itself by proposal, never by self-write

- **Date:** 2026-08-08
- **Status:** accepted
- **Category:** architecture

## Context

DevOS's memory loop only ever pointed outward. A task produces a lesson, the lesson
becomes a `brain/inbox/` candidate, `/devos-promote` accepts or rejects it. Nothing ever
looked back at memory that was already permanent — so two playbooks could converge on the
same fix, two standards could drift into contradiction, and a candidate could sit in the
inbox for a month, and no ritual would notice. The brain could only grow.

A survey of how self-improving agents are actually built (2026-08-08) sharpened what the
missing piece is and what it must not be:

- Reflexion-style verbal self-critique written to persistent memory is the mechanism
  almost everything else builds on, and DevOS already has it in the inbox flow.
- The systems that hold up gate every self-write behind a check that does not depend on
  the model's own judgement — Voyager verifies a skill by executing it, SICA accepts a
  self-edit only when a predefined metric improves. The ones that skip the gate can land
  *below* a no-memory baseline, because a bad memory does not cause one bad output, it
  poisons every session that later reads it.
- Letta/MemGPT's "sleep-time compute" is precisely the consolidation half we lack: a
  second pass, separate from task work, that merges duplicates and resolves
  contradictions in stored memory.

Sleep-time compute in its published form lets the consolidating agent edit core memory
directly. That is the one property DevOS cannot adopt: it routes around the only gate the
brain has.

## Decision

1. **A new ritual, `/devos-consolidate`, looks inward at `brain/` and files proposals.**
   It writes only new files in `brain/inbox/`. It never edits or deletes anything in
   `brain/standards/`, `brain/playbooks/`, the indexes, or `CLAUDE.md`.
2. **Detection is deterministic and separate from judgement.** `scripts/brain-scan.ps1`
   emits an inventory plus conservative flags as JSON; the skill reads only the files the
   flags name (capped at 10) and judges those. A flag is a reason to read, never a verdict.
3. **Consolidation proposals are a distinct candidate kind (`Kind: consolidation`).** They
   propose rewriting memory that is already permanent, which no lesson candidate does, so
   `/devos-promote` gains a matching rule: read every target, require quoted evidence and
   a filled-in "What is lost" section, show the before/after, and take approval **per
   target, never batched**.
4. **Evidence must be checkable without trusting the model.** A proposal quotes the lines
   it relies on. A similarity score is what made the model look, not why the change is
   right.
5. **Flags stay conservative, and a silent run is a success.** Content age and revision
   count are reported but never flagged — an untouched standard that is still correct is
   not a defect. Proposals are capped at 5 per run, because the binding constraint is
   Jonathan's review bandwidth, not detection. A ritual obliged to emit something every
   run will emit noise, and noise in permanent memory is worse than a gap.

## Alternatives considered

- **Letting consolidation edit `brain/` directly, as sleep-time compute does.** Rejected:
  it deletes the human gate, and deletion of memory is the least reversible operation the
  brain has. The measured cost of proposing instead is one extra `/devos-promote` pass.
- **Folding this into `/devos-weekly-review`.** Rejected: the review is a portfolio
  ritual, and a consolidation pass needs to open and quote brain files, which would drag
  the review's context toward memory maintenance. The review instead runs the scan and
  reports `flagCount` as a drift line — a nudge, not the work.
- **Reusing `templates/inbox-candidate.md` for proposals.** Rejected: it would silently
  widen `/devos-promote`'s authority from "write new content" to "rewrite and delete
  existing content" with no matching approval rule. A separate kind makes the escalation
  visible.
- **Backticked repo-relative paths as a broken-link signal.** Implemented, measured, and
  removed: it produced four false positives out of four on `brain/projects.md`, which
  legitimately names paths inside *other* repositories (`docs/STATUS.md`,
  `docs/{architecture,cms}`). Narrowed to markdown links only, which are an actual
  assertion that a file exists at a relative path. This yields nothing on today's brain —
  correct and quiet beats noisy.
- **Overlap analysis across the whole brain.** Rejected after measurement:
  `brain/projects.md` vs `standards/stack-defaults.md` scored 0.223 purely because both
  enumerate the same stacks, high enough to crowd out real duplicates and never an
  actionable merge. Similarity now runs only over lesson-bearing areas (`standards`,
  `playbooks`, `inbox`) as an explicit allowlist.
- **Weighted Jaccard with 1/df term weights.** Implemented first; it compressed every
  pair into 0.01–0.06, leaving no usable threshold. Replaced with cosine over
  IDF-weighted vectors.

## Consequences

Similarity is cosine over IDF-weighted term vectors, `idf = log(N/df)`, so a term present
in every analyzed file weighs exactly zero — which is what stops two unrelated playbooks
from matching on a shared PowerShell invocation. Cosine rather than Jaccard so a short
candidate duplicating part of a long standard still scores.

The threshold is calibrated, not guessed. Against the real brain with a known exact copy
and a hand-written paraphrase injected:

| Pair | Similarity |
|---|---|
| playbook vs exact copy of itself | 1.000 |
| playbook vs hand-written paraphrase (no copied wording) | 0.273 |
| two same-day PowerShell date lessons (genuinely adjacent) | 0.112 |
| highest unrelated pair | 0.080 |

Default threshold 0.12, which flags the paraphrase with room to spare and leaves today's
brain with zero similarity flags.

Known limits, all accepted:

- **The threshold drifts with the corpus.** IDF depends on N, so the same pair scored
  0.112 in the real brain and 0.127 in the 11-file calibration corpus — it crosses 0.12
  depending on what else exists. Mitigated by reporting the top pairs *with scores*
  whether flagged or not, so drift is visible in the output rather than silently hiding
  a pair, and by the skill defaulting to "keep both" on a near-duplicate flag.
- **Below three analyzed files, body similarity is structurally zero** (with N=2, a shared
  term's idf is `log(2/2) = 0`). Verified: two identical files produce no body pair. The
  title check catches that case, and the condition cannot recur once the brain has three
  lesson files.
- **Contradiction detection is not deterministic at all.** The scan cannot see it; the
  skill only finds contradictions in pairs it opened for some other reason. A pair of
  contradicting standards that share no vocabulary will not be found.
- **Lexical similarity is not semantic similarity.** Two files that say the same thing in
  entirely different words score low. This finds accumulated near-duplicates, not
  paraphrases with disjoint vocabulary.

The scan's output contract is **pure ASCII**, with every non-ASCII character escaped as
`\uXXXX`. This is not cosmetic. Brain files are full of em dashes; PowerShell 5.1's
`Get-Content` defaults to the ANSI codepage and decodes one into three mojibake
characters, of which U+201D best-fit maps to a bare `"` when stdout crosses a process
boundary under an OEM console codepage — producing JSON that no caller can parse. Found
in review, then reproduced: identical scan output parsed under codepage 65001 and failed
under 437, so `verify.ps1` passed for the author and failed for the reviewer. Both halves
are now fixed (`-Encoding UTF8` on every read, ASCII-escaped output) and the same
requirement applies to any future DevOS script that emits JSON on stdout —
`mission-control-scan.ps1` has the same shape and has not been audited for it.

Verification available for this change: `scripts/verify.ps1` now runs `brain-scan.ps1`
against the real brain and fails on a nonzero exit, unparseable output, or a
`schemaVersion` other than 1 — so a broken scan cannot ship. Edge cases were exercised
directly (empty brain, one file, two identical files, an empty file, no markdown at all):
all exit 0 with valid JSON. The skills themselves are Markdown with no test to run; the
checks available are `sync.ps1 -WhatIf`, that verify run, and a deliberate
internal-consistency pass.

<!-- ADRs are append-only. Never edit an accepted ADR; write a new one that supersedes it. -->
