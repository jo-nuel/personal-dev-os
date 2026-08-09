# SessionStart hook — injects DevOS context at session open: active task files in
# the current repo, mission-control data staleness, and weekly-review staleness.
# Emits nothing when there is nothing to say. Read-only.
$ErrorActionPreference = 'SilentlyContinue'
$lines = @()
$staleDays = 7

$repoRoot = git rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -eq 0 -and $repoRoot) {
    $tasksDir = Join-Path ($repoRoot -replace '/', '\') '.claude\tasks'
    if (Test-Path -LiteralPath $tasksDir) {
        $tasks = @(Get-ChildItem -LiteralPath $tasksDir -Filter '*.md' -File | ForEach-Object { $_.Name })
        if ($tasks.Count -gt 0) {
            $lines += "Active DevOS task file(s) in this repo: $($tasks -join ', '). Consider /devos-task status before starting new work."
        }
    }
}

$statePath = 'C:\Users\Jonathan\Projects\personal-dev-os\.claude\mission-control.json'
if (Test-Path -LiteralPath $statePath) {
    try {
        $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json
        $scanned = [datetimeoffset]::Parse($state.lastScanGeneratedAt, [Globalization.CultureInfo]::InvariantCulture)
        $days = ((Get-Date) - $scanned.LocalDateTime).TotalDays
        if ($days -gt $staleDays) {
            $lines += ("Mission-control dashboard data is {0} days old. Suggest /devos-mission-control for a fresh scan." -f [int][math]::Floor($days))
        }
    } catch { }
}

# Latest review is determined by filename (YYYY-Www, matching mission-control-scan.ps1's
# own convention), not filesystem mtime — mtime resets on every clone/checkout and would
# make a stale review look fresh.
$reviewsDir = 'C:\Users\Jonathan\Projects\personal-dev-os\brain\reviews'
if (Test-Path -LiteralPath $reviewsDir) {
    $latest = Get-ChildItem -LiteralPath $reviewsDir -Filter '*.md' -File |
        Sort-Object Name -Descending | Select-Object -First 1
    if ($null -eq $latest) {
        $lines += 'No weekly review on record. Suggest /devos-weekly-review when convenient.'
    } elseif ($latest.BaseName -match '^(\d{4})-W(\d{2})$') {
        $isoYear = [int]$Matches[1]
        $isoWeek = [int]$Matches[2]
        $jan4 = [datetime]::new($isoYear, 1, 4)
        $jan4Dow = [int]$jan4.DayOfWeek; if ($jan4Dow -eq 0) { $jan4Dow = 7 }
        $week1Monday = $jan4.AddDays(1 - $jan4Dow)
        $reviewMonday = $week1Monday.AddDays(($isoWeek - 1) * 7)
        $days = ((Get-Date).Date - $reviewMonday).TotalDays
        if ($days -gt $staleDays) {
            $lines += ("Last weekly review ({0}) is {1} days old. Suggest /devos-weekly-review." -f $latest.BaseName, [int][math]::Floor($days))
        }
    }
}

if ($lines.Count -gt 0) {
    $out = @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = ('DevOS: ' + ($lines -join ' '))
        }
    }
    Write-Output (ConvertTo-Json -InputObject $out -Depth 4 -Compress)
}
exit 0
