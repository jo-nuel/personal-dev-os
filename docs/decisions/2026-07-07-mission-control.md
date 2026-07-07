# ADR-0001: Mission-control dashboard — hosted artifact, local URL state, disk-walk discovery

- **Date:** 2026-07-07
- **Status:** accepted
- **Category:** tooling

## Context

A single "what needs my attention" view across every project under
`C:\Users\Jonathan\Projects` was wanted: one bookmarkable private page showing git
state, STATUS.md freshness, active tasks, verify-script coverage, brain inbox, and
drift between `brain/projects.md` and the disk. Three forces shaped the design: the
Artifact tool mints a new URL per session unless the previous URL is passed back; the
`brain/projects.md` index was already stale (missing two real projects) when this was
built; and DevOS doctrine requires deterministic, repeatable checks over model judgment.

## Decision

1. **Hosted artifact with locally persisted URL.** The dashboard is published via the
   Artifact tool. Its URL and the generated HTML live in gitignored
   `.claude/mission-control.{json,html}` in this repo; each `/devos-mission-control`
   run passes the stored URL back so the bookmark stays stable across sessions.
2. **Disk-walk discovery, not the index.** `scripts/mission-control-scan.ps1` discovers
   projects by walking `C:\Users\Jonathan\Projects` one level (resolving nested repos),
   and treats `brain/projects.md` as display data to be *checked against* the disk —
   drift is a finding, never a filter.
3. **Attention flags computed in the scan script.** Staleness/dormancy/drift thresholds
   live in PowerShell, not in the rendering step, so two runs over the same disk state
   always produce the same flags; the skill's rendering is pure templating.

## Alternatives considered

- Local app / localhost server — ongoing maintenance cost for a solo dev; artifact
  hosting already provides a private stable URL with zero infrastructure.
- Committing the URL/state to the repo — the URL is a private capability URL (treated
  like `settings.local.json`), and committing would create a meaningless diff per run.
- Hardcoded project list (in the script or from `brain/projects.md`) — would recreate
  the exact staleness problem the dashboard exists to catch.
- Model-driven ad hoc scanning in the skill — coverage would vary run to run; rejected
  under the "done = deterministic check" principle.

## Consequences

Commits us to keeping the scan script read-only and its JSON schema versioned
(`schemaVersion`), and to the one-level-plus-nested discovery convention for project
layout. A fresh clone or new machine loses the URL and mints a new one on first run
(accepted). Revisit if the portfolio outgrows a single page, if scheduled refresh is
ever wanted (the manual-only refresh was a deliberate choice), or if the Artifact
URL-reuse contract changes.

<!-- ADRs are append-only. Never edit an accepted ADR; write a new one that supersedes it. -->
