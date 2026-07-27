<#
.SYNOPSIS
    Installs DevOS-managed Claude Code configuration into ~/.claude, safely.

.DESCRIPTION
    Merges the DevOS-owned settings fragment (claude/settings-devos.json) into
    ~/.claude/settings.json without disturbing any key or permission entry that
    DevOS does not own. Also installs claude/CLAUDE.md and devos-* skills.

    Safety guarantees:
      - Timestamped backup of settings.json before any write.
      - Only DevOS-owned fields are modified (top-level keys present in the
        fragment, plus the DevOS block of permissions.deny entries).
      - A semantic-preservation check aborts the run if any non-DevOS key or
        value would change (formatting/ordering may change; meaning may not).
      - Merged JSON is re-parsed for validity before writing.
      - Assets (CLAUDE.md, skills) are tracked in ~/.claude/.devos-manifest.json;
        the script never overwrites or deletes an asset it did not install.
      - -WhatIf shows the full diff and planned actions without writing anything.
      - Without -Force, an interactive confirmation is required before applying.

.PARAMETER WhatIf
    Show the proposed changes and exit without writing.

.PARAMETER Force
    Apply without the interactive confirmation prompt (use only after
    reviewing -WhatIf output).
#>
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Force,
    # Test hook: operate on a different .claude directory (never needed in normal use).
    [string]$TargetDir = ''
)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------- paths -----
$RepoRoot         = Split-Path -Parent $MyInvocation.MyCommand.Path
$DevosFragment    = Join-Path $RepoRoot 'claude\settings-devos.json'
$DevosClaudeMd    = Join-Path $RepoRoot 'claude\CLAUDE.md'
$DevosSkillsDir   = Join-Path $RepoRoot 'claude\skills'
$ExternalSkillsDir = Join-Path $RepoRoot 'claude\skills\external'
$UserClaudeDir    = if ($TargetDir) { $TargetDir } else { Join-Path $env:USERPROFILE '.claude' }
$UserSettings     = Join-Path $UserClaudeDir 'settings.json'
$UserClaudeMd     = Join-Path $UserClaudeDir 'CLAUDE.md'
$UserSkillsDir    = Join-Path $UserClaudeDir 'skills'
$DevosAgentsMd    = Join-Path $RepoRoot 'claude\AGENTS.md'
$UserAgentsMd     = Join-Path $UserClaudeDir 'AGENTS.md'
# Codex reads ~/.codex/AGENTS.md natively. Only written when Codex is actually
# installed — we create the file inside an existing ~/.codex, never the dir.
$CodexDir         = Join-Path $env:USERPROFILE '.codex'
$CodexAgentsMd    = Join-Path $CodexDir 'AGENTS.md'
$ManifestPath     = Join-Path $UserClaudeDir '.devos-manifest.json'
$BackupDir        = Join-Path $UserClaudeDir 'backups'
$Utf8NoBom        = New-Object System.Text.UTF8Encoding($false)

# ------------------------------------------------------------- helpers ------
function Read-JsonFile([string]$Path) {
    if (-not (Test-Path $Path)) { return New-Object PSObject }
    $raw = [System.IO.File]::ReadAllText($Path)
    return ($raw | ConvertFrom-Json)
}

function Copy-Deep($Obj) {
    if ($null -eq $Obj) { return New-Object PSObject }
    return ($Obj | ConvertTo-Json -Depth 50 | ConvertFrom-Json)
}

# Recursively sort object keys so serialization is order-independent.
function ConvertTo-Canonical($Obj) {
    if ($Obj -is [System.Management.Automation.PSCustomObject]) {
        $sorted = New-Object PSObject
        foreach ($name in ($Obj.PSObject.Properties.Name | Sort-Object)) {
            $sorted | Add-Member -NotePropertyName $name -NotePropertyValue (ConvertTo-Canonical $Obj.$name)
        }
        return $sorted
    }
    if (($Obj -is [System.Collections.IEnumerable]) -and ($Obj -isnot [string])) {
        return ,@($Obj | ForEach-Object { ConvertTo-Canonical $_ })
    }
    return $Obj
}

function Get-CanonicalJson($Obj) {
    return (ConvertTo-Canonical $Obj | ConvertTo-Json -Depth 50 -Compress)
}

# Return a copy of $Settings with every DevOS-owned element removed:
# top-level keys named in the fragment, and deny entries that are either in
# the fragment or were previously installed per the manifest.
function Remove-DevosOwned($Settings, $Devos, [string[]]$ManifestDeny) {
    $copy = Copy-Deep $Settings
    foreach ($name in $Devos.PSObject.Properties.Name) {
        if ($name -eq 'permissions') { continue }
        if ($copy.PSObject.Properties[$name]) { $copy.PSObject.Properties.Remove($name) }
    }
    $devosDeny = @()
    if ($Devos.permissions -and $Devos.permissions.deny) { $devosDeny += @($Devos.permissions.deny) }
    if ($ManifestDeny) { $devosDeny += $ManifestDeny }
    if ($copy.permissions -and $copy.permissions.PSObject.Properties['deny']) {
        $remaining = @($copy.permissions.deny | Where-Object { $devosDeny -notcontains $_ })
        if ($remaining.Count -eq 0) { $copy.permissions.PSObject.Properties.Remove('deny') }
        else { $copy.permissions.deny = $remaining }
    }
    if ($copy.PSObject.Properties['permissions'] -and (@($copy.permissions.PSObject.Properties).Count -eq 0)) {
        $copy.PSObject.Properties.Remove('permissions')
    }
    return $copy
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

# ------------------------------------------------------------ load state ----
if (-not (Test-Path $DevosFragment)) { throw "DevOS fragment not found: $DevosFragment" }
$devos    = Read-JsonFile $DevosFragment
$current  = Read-JsonFile $UserSettings
$manifest = Read-JsonFile $ManifestPath
if (-not $manifest.PSObject.Properties['denyRules']) { $manifest | Add-Member -NotePropertyName denyRules -NotePropertyValue @() }
if (-not $manifest.PSObject.Properties['claudeMd'])  { $manifest | Add-Member -NotePropertyName claudeMd  -NotePropertyValue $false }
if (-not $manifest.PSObject.Properties['agentsMd'])      { $manifest | Add-Member -NotePropertyName agentsMd      -NotePropertyValue $false }
if (-not $manifest.PSObject.Properties['codexAgentsMd']) { $manifest | Add-Member -NotePropertyName codexAgentsMd -NotePropertyValue $false }
if (-not $manifest.PSObject.Properties['skills'])    { $manifest | Add-Member -NotePropertyName skills    -NotePropertyValue @() }

# ---------------------------------------------------------------- merge -----
$merged = Copy-Deep $current

# 1. Top-level DevOS-owned keys (everything in the fragment except permissions).
foreach ($name in $devos.PSObject.Properties.Name) {
    if ($name -eq 'permissions') { continue }
    if ($merged.PSObject.Properties[$name]) {
        $merged.$name = $devos.$name
    } else {
        $merged | Add-Member -NotePropertyName $name -NotePropertyValue $devos.$name
    }
}

# 2. permissions.deny: keep every user entry; drop stale DevOS entries the
#    manifest installed that are no longer in the fragment; append fragment
#    entries not already present. User entries and their order are preserved.
$devosDeny = @()
if ($devos.permissions -and $devos.permissions.deny) { $devosDeny = @($devos.permissions.deny) }
if (-not $merged.PSObject.Properties['permissions']) {
    $merged | Add-Member -NotePropertyName permissions -NotePropertyValue (New-Object PSObject)
}
if (-not $merged.permissions.PSObject.Properties['deny']) {
    $merged.permissions | Add-Member -NotePropertyName deny -NotePropertyValue @()
}
$staleDevos = @($manifest.denyRules | Where-Object { $devosDeny -notcontains $_ })
$kept    = @($merged.permissions.deny | Where-Object { $staleDevos -notcontains $_ })
$newOnes = @($devosDeny | Where-Object { $kept -notcontains $_ })
$merged.permissions.deny = @($kept + $newOnes)

# ------------------------------------------- semantic preservation check ----
$beforeStripped = Get-CanonicalJson (Remove-DevosOwned $current $devos @($manifest.denyRules))
$afterStripped  = Get-CanonicalJson (Remove-DevosOwned $merged  $devos @($manifest.denyRules))
if ($beforeStripped -ne $afterStripped) {
    Write-Host "ABORT: merge would alter settings DevOS does not own." -ForegroundColor Red
    Write-Host "before(non-DevOS): $beforeStripped"
    Write-Host "after (non-DevOS): $afterStripped"
    exit 1
}

# ------------------------------------------------------------- validate -----
$mergedJson = $merged | ConvertTo-Json -Depth 50
try { $null = $mergedJson | ConvertFrom-Json } catch {
    Write-Host "ABORT: merged settings failed JSON validation: $_" -ForegroundColor Red
    exit 1
}

# ------------------------------------------------------------ plan assets ---
$assetActions = @()
# Skill sources: DevOS-authored (claude\skills\devos-*) plus vendored third-party
# skills (claude\skills\external\*, any folder name — see external\SOURCES.md).
$skillSources = @{}
if (Test-Path $DevosSkillsDir) {
    Get-ChildItem -Directory $DevosSkillsDir | Where-Object { $_.Name -like 'devos-*' } | ForEach-Object {
        $skillSources[$_.Name] = $_.FullName
    }
}
if (Test-Path $ExternalSkillsDir) {
    Get-ChildItem -Directory $ExternalSkillsDir | ForEach-Object {
        $skillSources[$_.Name] = $_.FullName
    }
}
$repoSkills = @($skillSources.Keys)
foreach ($skill in $repoSkills) {
    $dest = Join-Path $UserSkillsDir $skill
    if ((Test-Path $dest) -and (@($manifest.skills) -notcontains $skill)) {
        $assetActions += "SKIP skill '$skill' - exists at $dest but was not installed by DevOS (never overwritten)"
    } else {
        $assetActions += "INSTALL/UPDATE skill '$skill' -> $dest"
    }
}
foreach ($skill in @($manifest.skills)) {
    if ($repoSkills -notcontains $skill) {
        $assetActions += "REMOVE skill '$skill' (DevOS-installed, no longer in repo)"
    }
}
if (Test-Path $UserClaudeMd) {
    if ($manifest.claudeMd) { $assetActions += "UPDATE CLAUDE.md -> $UserClaudeMd (DevOS-owned per manifest)" }
    else { $assetActions += "SKIP CLAUDE.md - $UserClaudeMd exists and was not installed by DevOS (never overwritten)" }
} else {
    $assetActions += "INSTALL CLAUDE.md -> $UserClaudeMd"
}
if (Test-Path $UserAgentsMd) {
    if ($manifest.agentsMd) { $assetActions += "UPDATE AGENTS.md -> $UserAgentsMd (DevOS-owned per manifest)" }
    else { $assetActions += "SKIP AGENTS.md - $UserAgentsMd exists and was not installed by DevOS (never overwritten)" }
} else {
    $assetActions += "INSTALL AGENTS.md -> $UserAgentsMd"
}
if (-not (Test-Path $CodexDir)) {
    $assetActions += "SKIP Codex AGENTS.md - $CodexDir does not exist (Codex not installed)"
} elseif (Test-Path $CodexAgentsMd) {
    if ($manifest.codexAgentsMd) { $assetActions += "UPDATE Codex AGENTS.md -> $CodexAgentsMd (DevOS-owned per manifest)" }
    else { $assetActions += "SKIP Codex AGENTS.md - $CodexAgentsMd exists and was not installed by DevOS (never overwritten)" }
} else {
    $assetActions += "INSTALL Codex AGENTS.md -> $CodexAgentsMd"
}

# ----------------------------------------------------------------- diff -----
$ts         = Get-Date -Format 'yyyyMMdd-HHmmss'
$backupPath = Join-Path $BackupDir "settings-$ts.json"

Write-Host "`n=== DevOS sync plan ===" -ForegroundColor Cyan
Write-Host "Settings file : $UserSettings"
Write-Host "Backup (before write): $backupPath"
Write-Host "DevOS-owned fields: $(( $devos.PSObject.Properties.Name | Where-Object { $_ -ne 'permissions' }) -join ', '), permissions.deny (DevOS block)"
Write-Host "`n--- settings diff (- current / + proposed) ---"
$beforeLines = ($current | ConvertTo-Json -Depth 50) -split "`r?`n"
$afterLines  = ($merged  | ConvertTo-Json -Depth 50) -split "`r?`n"
$diff = Compare-Object -ReferenceObject $beforeLines -DifferenceObject $afterLines
if ($diff) {
    foreach ($d in $diff) {
        if ($d.SideIndicator -eq '<=') { Write-Host ("- " + $d.InputObject) -ForegroundColor Red }
        else                            { Write-Host ("+ " + $d.InputObject) -ForegroundColor Green }
    }
} else { Write-Host "(no settings changes)" }
Write-Host "`n--- asset actions ---"
$assetActions | ForEach-Object { Write-Host $_ }
Write-Host "`nSemantic preservation check: PASSED (non-DevOS settings unchanged)" -ForegroundColor Green

# ---------------------------------------------------------------- apply -----
if ($WhatIf) {
    Write-Host "`n-WhatIf: nothing was written." -ForegroundColor Yellow
    exit 0
}
if (-not $Force) {
    try {
        $answer = Read-Host "`nApply these changes? (y/N)"
    } catch {
        Write-Host "Non-interactive session: review with -WhatIf, then re-run with -Force." -ForegroundColor Yellow
        exit 1
    }
    if ($answer -ne 'y') { Write-Host "Aborted by user; nothing written."; exit 0 }
}

if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir | Out-Null }
if (Test-Path $UserSettings) { Copy-Item $UserSettings $backupPath }
Write-Utf8NoBom $UserSettings $mergedJson
Write-Host "Wrote $UserSettings (backup: $backupPath)"

# Assets
if (-not (Test-Path $UserSkillsDir)) { New-Item -ItemType Directory -Path $UserSkillsDir | Out-Null }
$installedSkills = @()
foreach ($skill in $repoSkills) {
    $dest = Join-Path $UserSkillsDir $skill
    if ((Test-Path $dest) -and (@($manifest.skills) -notcontains $skill)) { continue }
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Copy-Item $skillSources[$skill] $dest -Recurse
    $installedSkills += $skill
    Write-Host "Installed skill: $skill"
}
foreach ($skill in @($manifest.skills)) {
    if ($repoSkills -notcontains $skill) {
        $dest = Join-Path $UserSkillsDir $skill
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force; Write-Host "Removed skill: $skill" }
    }
}
$claudeMdOwned = [bool]$manifest.claudeMd
if ((-not (Test-Path $UserClaudeMd)) -or $claudeMdOwned) {
    Copy-Item $DevosClaudeMd $UserClaudeMd -Force
    $claudeMdOwned = $true
    Write-Host "Installed CLAUDE.md"
}
$agentsMdOwned = [bool]$manifest.agentsMd
if ((-not (Test-Path $UserAgentsMd)) -or $agentsMdOwned) {
    Copy-Item $DevosAgentsMd $UserAgentsMd -Force
    $agentsMdOwned = $true
    Write-Host "Installed AGENTS.md"
}
# Same file, second consumer. Skipped entirely when Codex isn't installed.
$codexAgentsMdOwned = [bool]$manifest.codexAgentsMd
if (Test-Path $CodexDir) {
    if ((-not (Test-Path $CodexAgentsMd)) -or $codexAgentsMdOwned) {
        Copy-Item $DevosAgentsMd $CodexAgentsMd -Force
        $codexAgentsMdOwned = $true
        Write-Host "Installed Codex AGENTS.md"
    }
}

# Manifest
$newManifest = New-Object PSObject
$newManifest | Add-Member -NotePropertyName denyRules -NotePropertyValue $devosDeny
$newManifest | Add-Member -NotePropertyName claudeMd  -NotePropertyValue $claudeMdOwned
$newManifest | Add-Member -NotePropertyName agentsMd      -NotePropertyValue $agentsMdOwned
$newManifest | Add-Member -NotePropertyName codexAgentsMd -NotePropertyValue $codexAgentsMdOwned
$newManifest | Add-Member -NotePropertyName skills    -NotePropertyValue $installedSkills
$newManifest | Add-Member -NotePropertyName lastSync  -NotePropertyValue (Get-Date -Format 'o')
Write-Utf8NoBom $ManifestPath ($newManifest | ConvertTo-Json -Depth 10)
Write-Host "Updated manifest: $ManifestPath"
Write-Host "`nSync complete." -ForegroundColor Green
