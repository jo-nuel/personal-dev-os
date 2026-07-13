# ADR-0002: Weekly review becomes a skill with a session nudge; cadence stays manual

- **Date:** 2026-07-13
- **Status:** accepted
- **Category:** workflow

## Context

The weekly review existed only as `templates/weekly-review.md`; `brain/reviews/` had
been empty since the template was created — a defined ritual with nothing driving it.
Comparing DevOS against Nate Herk's AIS-OS framework (Four Cs: Context, Connections,
Capabilities, Cadence; recurring `/audit` and `/level-up` skills) showed that DevOS was
strong on context, capabilities, and governance but had no cadence mechanism at all,
no registry of connected systems, and no leverage-hunting ritual. ADR-0001 had already
deliberately rejected scheduled/automated refresh for mission control.

## Decision

1. **`/devos-weekly-review` skill** drives the ritual: deterministic gather (reusing
   `scripts/mission-control-scan.ps1`), a dated review in `brain/reviews/YYYY-Www.md`
   from the existing template, inbox triage that defers to `/devos-promote`, and a short
   level-up interview whose output is filed as a `brain/inbox/` candidate — promotion
   governance applies unchanged.
2. **Cadence is a nudge, not a scheduler.** `scripts/hook-session-start.ps1` gains a
   third read-only check: if the newest `brain/reviews/*.md` is absent or older than
   7 days, it suggests the skill. No cron, no cloud routine, no autonomous execution —
   consistent with ADR-0001's manual-only stance.
3. **`brain/connections.md`** registers reachable systems (MCP connectors, CLIs) as a
   one-line-per-entry index like `brain/projects.md`; the weekly review's drift checks
   keep it honest. Names and purposes only, never credentials.
4. **EAD triage in `/devos-operate`**: decomposition now applies Eliminate → Automate →
   Delegate before splitting, and each microtask carries an explicit autonomy level
   (do-and-report / propose-and-wait; high-risk always the latter).

## Alternatives considered

- Scheduled cloud routine generating the review draft automatically — rejected: reviews
  exist to make Jonathan look, and ADR-0001 already established manual-only cadence;
  an unread auto-generated review is noise.
- Separate `/devos-audit` and `/devos-level-up` skills mirroring AIS-OS — rejected:
  both collapse into the weekly review at this portfolio size; two more skills would
  fragment one ritual.
- Letting the level-up interview write directly into `brain/standards/` — rejected:
  bypasses the inbox → `/devos-promote` governance that everything else obeys.

## Consequences

Commits us to keeping `brain/reviews/` filenames in `YYYY-Www` form (the hook and the
one-file-per-week rule depend on it) and to maintaining `brain/connections.md` as
connections change. The nudge fires in every session once a review is overdue; if that
proves noisy, tune the 7-day threshold rather than removing the check. Revisit scheduled
cadence only under ADR-0001's own revisit conditions.

<!-- ADRs are append-only. Never edit an accepted ADR; write a new one that supersedes it. -->
