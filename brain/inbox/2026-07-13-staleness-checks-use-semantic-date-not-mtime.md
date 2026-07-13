# Candidate: staleness/freshness checks on dated files must parse the semantic date, not trust filesystem mtime

- **Date:** 2026-07-13
- **Source:** personal-dev-os, task "Adopt AIS-OS lessons into DevOS" (SessionStart hook
  weekly-review nudge)
- **Proposed destination:** brain/standards/engineering.md
- **Verified how:** `/code-review` (three independent finder angles — line-scan, altitude,
  cross-file tracer — converged on this before verification) plus a targeted verifier
  agent confirmed it by inspection. Fixed and re-tested directly: created a review file
  dated 3 weeks in the past but forced its `LastWriteTime` to "now" (simulating a fresh
  clone/checkout); the corrected hook still reported it 21 days stale, proving the fix no
  longer depends on mtime.

## The lesson

When a file's "age" or "freshness" has a semantic meaning encoded in its own content or
name (a dated filename like `YYYY-Www.md`, a `Updated:` field, a version string), compute
staleness from that semantic value — never from filesystem metadata like
`LastWriteTime`/mtime. mtime resets on any operation that rewrites the working tree (git
clone, checkout, stash pop, some sync/backup tools), decoupling it from the actual age the
check is supposed to measure, and can silently make a genuinely stale file look fresh (or
vice versa) with no error. This DevOS repo already had the correct pattern in
`scripts/mission-control-scan.ps1` (sorts reviews by filename, not mtime) sitting right
next to the bug — when adding a parallel/copy-pasted check, verify it's copying the right
half of an existing sibling implementation, not just its structural shape.

## Evidence

Before fix: `Sort-Object LastWriteTime -Descending` + `(Get-Date) - $latest.LastWriteTime`.
After fix: parse `YYYY-Www` from the filename, convert the ISO week back to its Monday via
the Thursday-of-week method, and diff against that. Reproduced the failure mode directly
(dummy file dated 3 weeks in the past, mtime forced to "now") and confirmed the fix is
immune to it.

<!-- Ineligible: unverified conclusions, ASSUMPTION-tagged notes, secrets, conversation logs. -->
<!-- Only Jonathan moves candidates out of inbox (accept / merge / reject). -->
