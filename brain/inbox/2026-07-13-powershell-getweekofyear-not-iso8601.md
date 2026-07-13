# Candidate: PowerShell/.NET `Calendar.GetWeekOfYear` is not ISO-8601 week numbering

- **Date:** 2026-07-13
- **Source:** personal-dev-os, task "Adopt AIS-OS lessons into DevOS" (devos-weekly-review skill)
- **Proposed destination:** brain/playbooks/powershell-iso-week-calculation.md
- **Verified how:** `/code-review` finder angle A ran the exact candidate one-liner against
  known boundary dates (2025-12-29, 2027-01-01, 2021-01-01, 2022-01-01) and a separate
  verifier agent independently re-ran it; both confirmed mismatches against true ISO
  week-years. A corrected Thursday-of-the-week algorithm was then written and tested
  against 7 boundary dates (including two 53-ISO-week years) with all passing, and cross-
  checked by hand-deriving the ISO week for 2026-07-13 from Jan 1 2026's weekday.

## The lesson

In Windows PowerShell 5.1 / .NET Framework, pairing
`$d.Year` with `[Globalization.Calendar]::GetWeekOfYear($d, FirstFourDayWeek, Monday)`
looks ISO-8601-ish but is **not** ISO week numbering — it can produce the wrong year or an
impossible week number near year boundaries (e.g. late-December dates land in the wrong
year's week 53, or January dates get the prior year's week 52/53 mislabeled as the new
year's). `System.Globalization.ISOWeek` (the correct, purpose-built API) does not exist in
.NET Framework, so it can't be used from Windows PowerShell 5.1 either. Get the correct
result with the Thursday-of-the-week method instead: shift the date to that week's
Thursday (ISO weeks are identified by the year their Thursday falls in), then compute the
week number from `(thursday - Jan1OfThursdaysYear).Days`. Watch for one adjacent trap:
constructing `Jan1` via `Get-Date -Year Y -Month 1 -Day 1` without an explicit
`-Hour 0 -Minute 0 -Second 0` inherits the *current* time-of-day, silently corrupting the
day-difference by a fractional day — construct it via `[datetime]::new($year, 1, 1)`
instead.

## Evidence

Tested one-liner (used in `claude/skills/devos-weekly-review/SKILL.md`):
```
$d=(Get-Date).Date; $dow=[int]$d.DayOfWeek; if ($dow -eq 0) { $dow = 7 }; $thu=$d.AddDays(4-$dow); $jan1=[datetime]::new($thu.Year,1,1); $wk=[int][math]::Ceiling((($thu-$jan1).Days+1)/7.0); '{0}-W{1:d2}' -f $thu.Year,$wk
```
Passed against 7 test dates spanning ordinary years, both 53-ISO-week years in the test
range (2020, 2026), and the current date.

<!-- Ineligible: unverified conclusions, ASSUMPTION-tagged notes, secrets, conversation logs. -->
<!-- Only Jonathan moves candidates out of inbox (accept / merge / reject). -->
