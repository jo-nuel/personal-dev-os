# ISO week number is wrong near year boundaries in Windows PowerShell 5.1

- **Applies to:** Windows PowerShell 5.1 / .NET Framework (any script computing ISO-8601 week numbers)
- **Last verified:** 2026-07-13
- **Source:** personal-dev-os, task "Adopt AIS-OS lessons into DevOS" (devos-weekly-review skill)

## Symptom

A week-numbering expression that looks ISO-8601 correct returns the wrong week, or the
wrong *year*, for dates near a year boundary — late-December dates land in the following
year's week, or early-January dates get labelled with the new year while carrying the
prior year's week 52/53. No error is raised; the value is just wrong.

The expression that produces it pairs `$d.Year` with `GetWeekOfYear`:

```
[Globalization.Calendar]::GetWeekOfYear($d, FirstFourDayWeek, Monday)
```

## Cause

`Calendar.GetWeekOfYear` is not ISO-8601 week numbering, even with `FirstFourDayWeek` and
`Monday`. ISO weeks belong to the year their **Thursday** falls in, and `GetWeekOfYear`
has no notion of that — so pairing its result with `$d.Year` mislabels every date whose
ISO week-year differs from its calendar year.

`System.Globalization.ISOWeek`, the purpose-built API that would be correct, does not
exist in .NET Framework and so is unavailable from Windows PowerShell 5.1.

## Fix

Use the Thursday-of-the-week method: shift the date to that week's Thursday, then compute
the week number from Jan 1 of *the Thursday's* year.

```
$d=(Get-Date).Date; $dow=[int]$d.DayOfWeek; if ($dow -eq 0) { $dow = 7 }; $thu=$d.AddDays(4-$dow); $jan1=[datetime]::new($thu.Year,1,1); $wk=[int][math]::Ceiling((($thu-$jan1).Days+1)/7.0); '{0}-W{1:d2}' -f $thu.Year,$wk
```

One adjacent trap to avoid: construct Jan 1 with `[datetime]::new($year, 1, 1)`, **not**
`Get-Date -Year Y -Month 1 -Day 1`. The latter inherits the current time-of-day unless
`-Hour 0 -Minute 0 -Second 0` is passed explicitly, silently corrupting the day-difference
by a fractional day.

## Verification

`/code-review` ran the original candidate one-liner against known boundary dates
(2025-12-29, 2027-01-01, 2021-01-01, 2022-01-01) and a separate verifier agent
independently re-ran it; both confirmed mismatches against true ISO week-years. The
corrected Thursday-of-the-week algorithm above was then tested against 7 boundary dates
spanning ordinary years and both 53-ISO-week years in range (2020, 2026), all passing,
and cross-checked by hand-deriving the ISO week for 2026-07-13 from Jan 1 2026's weekday.

In use in `claude/skills/devos-weekly-review/SKILL.md`, which needs the review filename to
be exact at year boundaries.

<!-- Only verified fixes enter playbooks. If the cause was never confirmed, it stays in inbox. -->
