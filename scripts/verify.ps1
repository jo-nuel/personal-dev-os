# Deterministic verification gate. Exit code 0 = the change may be called done.
# Chain the repo's real checks; add to this file as the repo gains checks.
$ErrorActionPreference = 'Stop'

# A check signals failure by throwing, NOT by calling exit: `exit` inside a
# scriptblock invoked with & terminates this whole script, which silently skipped
# every check placed after the first one that used it.
function Invoke-Check([string]$Name, [scriptblock]$Cmd) {
    Write-Host "== $Name ==" -ForegroundColor Cyan
    try {
        & $Cmd
    } catch {
        Write-Host "FAIL: $Name - $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
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
    if ($errors) {
        $errors | ForEach-Object { Write-Host $_ }
        throw "hook-session-start.ps1 has $(@($errors).Count) parse error(s)"
    }
}

# Get-Content defaults to the ANSI codepage in 5.1, silently mangling any
# non-ASCII it reads. It cost two scripts already, and the damage is invisible
# in a UTF-8 session, so require the flag rather than trusting review to catch it.
Invoke-Check "file-read encoding" {
    $offenders = @()
    foreach ($f in (Get-ChildItem -LiteralPath (Join-Path $repoRoot 'scripts') -Filter '*.ps1' -File)) {
        # AST, not a text match: a regex over lines also hits the literal inside
        # this check's own name and any mention in a comment.
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$null, [ref]$null)
        $calls = $ast.FindAll({
            param($n)
            $n -is [System.Management.Automation.Language.CommandAst] -and
            $n.GetCommandName() -eq 'Get-Content'
        }, $true)
        foreach ($c in $calls) {
            $hasEncoding = @($c.CommandElements | Where-Object {
                $_ -is [System.Management.Automation.Language.CommandParameterAst] -and
                $_.ParameterName -like 'Enc*'
            }).Count -gt 0
            if (-not $hasEncoding) {
                $offenders += "$($f.Name):$($c.Extent.StartLineNumber)  $($c.Extent.Text)"
            }
        }
    }
    if ($offenders.Count -gt 0) {
        $offenders | ForEach-Object { Write-Host "  $_" }
        throw "$($offenders.Count) Get-Content call(s) without -Encoding"
    }
}

# brain-scan.ps1 feeds /devos-consolidate and the weekly review, both of which
# refuse to act on unparseable output — so a broken scan fails silently as "no
# findings". Run it for real and assert the contract instead.
Invoke-Check "brain scan" {
    $scan = Join-Path $repoRoot 'scripts\brain-scan.ps1'
    $out = powershell -NoProfile -ExecutionPolicy Bypass -File $scan
    if ($LASTEXITCODE -ne 0) { throw "brain-scan exited $LASTEXITCODE" }
    try { $parsed = $out | ConvertFrom-Json } catch { throw "brain-scan output is not valid JSON: $_" }
    if ($parsed.schemaVersion -ne 1) { throw "brain-scan schemaVersion is '$($parsed.schemaVersion)', expected 1" }
    if ($null -eq $parsed.flags) { throw "brain-scan output has no flags field" }
    Write-Host "brain-scan: $($parsed.totals.files) files, $($parsed.analyzedCount) analyzed, $($parsed.flagCount) flags"
}

Write-Host "verify: ALL CHECKS PASSED" -ForegroundColor Green
exit 0
