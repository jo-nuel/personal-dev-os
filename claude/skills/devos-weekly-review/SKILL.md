---
name: devos-weekly-review
description: Weekly review ritual — gather deterministic portfolio facts, draft the dated review in brain/reviews/, triage the inbox, and run a short level-up interview whose output lands in brain/inbox/ as a candidate.
disable-model-invocation: true
---

Takes no arguments. One invocation produces exactly one review file for the current ISO
week in `C:\Users\Jonathan\Projects\personal-dev-os\brain\reviews\`. If that file already
exists, offer to update it in place — never write a second file for the same week.

## 1. Gather (read-only)

Reuse `C:\Users\Jonathan\Projects\personal-dev-os\.claude\mission-control.json` +
`.html`'s underlying scan data only if `lastScanGeneratedAt` is less than 24 hours old.
Otherwise run a fresh scan:

```
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Jonathan\Projects\personal-dev-os\scripts\mission-control-scan.ps1"
```

Parse stdout as JSON; if the exit code is nonzero or `schemaVersion` is not `1`, stop and
report the failure verbatim — never draft the review from guessed portfolio state.

Also gather:

- `brain/inbox/` — list candidate filenames (may be empty).
- The current `/model` setting, if visible in session context.
- The brain's own health, from a second read-only scan:

  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\Jonathan\Projects\personal-dev-os\scripts\brain-scan.ps1"
  ```

  Parse stdout as JSON; same gate as above (nonzero exit or `schemaVersion` ≠ `1` — report
  the failure, do not guess). Take `flagCount` and the `flags` list. Do **not** open the
  flagged files or judge them here; that is `/devos-consolidate`'s job.

Compute the review filename deterministically. `Calendar.GetWeekOfYear` is **not**
ISO-8601 week numbering and gets the year wrong at year boundaries — use the
Thursday-of-the-week method instead, which is exact:

```
powershell -NoProfile -Command "$d=(Get-Date).Date; $dow=[int]$d.DayOfWeek; if ($dow -eq 0) { $dow = 7 }; $thu=$d.AddDays(4-$dow); $jan1=[datetime]::new($thu.Year,1,1); $wk=[int][math]::Ceiling((($thu-$jan1).Days+1)/7.0); '{0}-W{1:d2}' -f $thu.Year,$wk"
```

## 2. Draft the review

Write `brain/reviews/<YYYY-Www>.md` following
`C:\Users\Jonathan\Projects\personal-dev-os\templates\weekly-review.md` exactly (Shipped /
Inbox triage / Drift checks / Next week). Use the absolute path — `sync.ps1` installs only
`claude/` to `~/.claude/skills/`; `templates/` stays in the source repo and this skill can
run from any project's working directory. Rules:

- **Shipped / progressed** — one or two lines per project that had commits or STATUS.md
  movement this week, taken from the scan data. Label each claim **verified** (from the
  scan) or **inferred** (anything else), the way `devos-repo-brief` does. Skip projects
  with no activity rather than padding.
- **Inbox triage** — record the candidate filenames found. Do not promote anything here;
  if the inbox is non-empty, note "run `/devos-promote`" as the action.
- **Drift checks** — the template's checklist, plus two added lines:
  `- [ ] brain/connections.md still matches reality` and one reporting the brain scan's
  `flagCount` verbatim (e.g. `- [ ] brain health: 3 flags — run /devos-consolidate`,
  or `- [x] brain health: 0 flags`). Name the flag kinds, not conclusions about them.
  Check what is cheaply checkable
  (e.g. `/model` from session context, stale STATUS.md flags from the scan) and leave
  the rest unchecked for Jonathan rather than guessing. If a `connections.md` row is
  found stale, do not edit that file directly — file it as a `brain/inbox/` candidate
  (same as the level-up outcome below) so it goes through `/devos-promote` like every
  other brain update.
- **Next week** — ask Jonathan for the top 1–3 priorities; never invent them.

## 3. Level-up interview

Ask Jonathan, briefly (AskUserQuestion or plain chat, 2–3 questions max):

1. What ate the most time this week?
2. What did you do manually more than once?
3. (Optional follow-up) Should that be eliminated, automated, or delegated?

If a concrete automation or process idea comes out of it, file it as a candidate in
`brain/inbox/` using
`C:\Users\Jonathan\Projects\personal-dev-os\templates\inbox-candidate.md` (absolute path,
same reason as step 2) — evidence being Jonathan's own answer, marked as such. It enters
permanent memory only via `/devos-promote`, never directly from this skill. If nothing
comes up, write nothing.

## 4. Summarize

One short paragraph in chat: what shipped, the one most useful drift finding, and the
level-up outcome (candidate filed / nothing this week). Point at the review file.

## Guardrails

Read-only outside this repo. Writes only the week's file in `brain/reviews/` and, at
most, one candidate in `brain/inbox/`. Never edits `brain/standards/`, `brain/playbooks/`,
`brain/projects.md`, or the global `CLAUDE.md`. Never commits or pushes. Never records
conversation transcripts, raw terminal output, or secrets in the review.
