# SessionStart hook — injects DevOS context at session open: active task files in
# the current repo, and mission-control data staleness. Emits nothing when there
# is nothing to say. Read-only.
$ErrorActionPreference = 'SilentlyContinue'
$lines = @()

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
        $state = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        $scanned = [datetimeoffset]::Parse($state.lastScanGeneratedAt, [Globalization.CultureInfo]::InvariantCulture)
        $days = ((Get-Date) - $scanned.LocalDateTime).TotalDays
        if ($days -gt 7) {
            $lines += ("Mission-control dashboard data is {0} days old. Suggest /devos-mission-control for a fresh scan." -f [int][math]::Floor($days))
        }
    } catch { }
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
