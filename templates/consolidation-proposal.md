# Consolidation: <the action, in one line>

- **Kind:** consolidation
- **Date:** YYYY-MM-DD
- **Filed by:** /devos-consolidate
- **Action:** merge | split | harden | fix-link | retire
- **Targets:** brain/... (every file this rewrites or deletes)
- **Destination:** brain/... (the file that holds the result)
- **Detected by:** <the deterministic signal, e.g. "brain-scan near-duplicate, similarity 0.31">

## Proposed change

What the brain looks like afterwards, stated plainly. For a merge: which file survives,
and what the merged content says.

## Evidence

Quoted lines from each target — enough that the claim can be checked without trusting
this summary. A similarity score is not evidence; it is only what made someone look.

### brain/<file A> (lines n–m)

> quoted

### brain/<file B> (lines n–m)

> quoted

## What is lost

Everything in the targets not carried into the destination. "Nothing" is only valid if
every claim, caveat, and source line survives the change — say so explicitly.

<!-- Unlike a lesson candidate, this proposes rewriting or deleting EXISTING brain
     content. /devos-promote requires per-target approval and will reject a proposal
     whose evidence is missing or whose "What is lost" section is unfilled. -->
