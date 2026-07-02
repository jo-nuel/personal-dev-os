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

# Examples — replace with this repo's real commands:
# Invoke-Check "lint"      { npm run lint }
# Invoke-Check "typecheck" { npx tsc --noEmit }
# Invoke-Check "tests"     { npm test }

Write-Host "verify: ALL CHECKS PASSED" -ForegroundColor Green
exit 0
