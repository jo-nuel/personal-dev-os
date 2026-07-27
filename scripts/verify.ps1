# Deterministic verification gate. Exit code 0 = the change may be called done.
# Chain the repo's real checks; add to this file as the repo gains checks.
$ErrorActionPreference = 'Stop'

function Invoke-Check([string]$Name, [scriptblock]$Cmd) {
    Write-Host "== $Name ==" -ForegroundColor Cyan
    & $Cmd
    if ($LASTEXITCODE -ne 0) {
        Write-Host "FAIL: $Name (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

$repoRoot = Split-Path -Parent $PSScriptRoot

# Agent routing tests. Fully mocked — needs no ANTHROPIC_API_KEY and no network.
Invoke-Check "agent tests" { uv run --project $repoRoot pytest -q }

# The SessionStart hook runs on every session open; a parse error there is
# silent (ErrorActionPreference = SilentlyContinue), so syntax-check it here.
Invoke-Check "hook syntax" {
    $hook = Join-Path $repoRoot 'scripts\hook-session-start.ps1'
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($hook, [ref]$null, [ref]$errors) | Out-Null
    if ($errors) { $errors | ForEach-Object { Write-Host $_ }; exit 1 }
    exit 0
}

Write-Host "verify: ALL CHECKS PASSED" -ForegroundColor Green
exit 0
