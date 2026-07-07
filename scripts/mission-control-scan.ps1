# mission-control-scan.ps1 — read-only portfolio scan for /devos-mission-control.
# Walks every project under -ProjectsRoot and emits one JSON document to stdout.
# PowerShell 5.1. Reads only: directory listings, git plumbing, the first 30 lines
# of each repo's docs/STATUS.md, brain/projects.md, and brain inbox/review
# filenames. Never opens .env files or task-file contents.

[CmdletBinding()]
param(
    [string]$ProjectsRoot = 'C:\Users\Jonathan\Projects',
    [string]$DevosRoot
)

# 'Stop' would turn redirected native stderr (2>$null) into terminating
# NativeCommandErrors in 5.1 — keep 'Continue' and gate on $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

# $PSScriptRoot is not populated when param defaults evaluate under -File in 5.1.
if (-not $DevosRoot) { $DevosRoot = Split-Path -Parent $PSScriptRoot }

if (-not (Test-Path -LiteralPath $ProjectsRoot -PathType Container)) {
    Write-Error "Projects root not found: $ProjectsRoot"
    exit 1
}

function Invoke-Git {
    param([string]$RepoPath, [string[]]$GitArgs)
    $out = & git -C $RepoPath @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function Get-LineCount {
    param($Lines)
    if ($null -eq $Lines) { return 0 }
    # @() normalizes 5.1's bare-string single result to a one-element array;
    # without it .Count on a string counts characters.
    return @($Lines).Count
}

$now = Get-Date

function Get-ProjectInfo {
    param([string]$Name, [string]$Path, [string]$RepoPath, [bool]$Nested, [bool]$IsGitRepo)

    $info = [ordered]@{
        name           = $Name
        path           = $Path
        repoPath       = $RepoPath
        nested         = $Nested
        isGitRepo      = $IsGitRepo
        hasCommits     = $false
        branch         = $null
        detached       = $false
        dirtyCount     = 0
        lastCommit     = $null
        upstream       = $null
        ahead          = $null
        behind         = $null
        statusMd       = [ordered]@{ exists = $false; updatedLine = $null; updatedDate = $null; stale = $false }
        activeTasks    = @()
        hasVerifyPs1   = $false
        hasVerifySh    = $false
        attention      = @()
        attentionScore = 0
    }

    $flags = New-Object System.Collections.ArrayList
    $score = 0
    $daysAgo = $null
    $lastCommitDate = $null

    if ($IsGitRepo) {
        $head = Invoke-Git $RepoPath @('rev-parse', '--verify', '-q', 'HEAD')
        $info.hasCommits = ($null -ne $head)

        if ($info.hasCommits) {
            $branch = Invoke-Git $RepoPath @('symbolic-ref', '--short', '-q', 'HEAD')
            if ($null -eq $branch) {
                $info.branch = [string](Invoke-Git $RepoPath @('rev-parse', '--short', 'HEAD'))
                $info.detached = $true
            } else {
                $info.branch = [string]$branch
            }

            $logLine = Invoke-Git $RepoPath @('log', '-1', '--format=%cI%x09%s')
            if ($null -ne $logLine) {
                $parts = ([string]$logLine) -split "`t", 2
                $isoDate = $parts[0]
                $subject = if ($parts.Count -gt 1) { $parts[1] } else { '' }
                try {
                    $lastCommitDate = [datetimeoffset]::Parse($isoDate, [Globalization.CultureInfo]::InvariantCulture)
                    $daysAgo = [int][math]::Floor(($now - $lastCommitDate.LocalDateTime).TotalDays)
                } catch { $daysAgo = $null }
                $info.lastCommit = [ordered]@{ date = $isoDate; subject = $subject; daysAgo = $daysAgo }
            }

            # '@{u}' must stay quoted — bare @{ opens a hashtable literal in PS.
            $upstream = Invoke-Git $RepoPath @('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
            if ($null -ne $upstream) {
                $info.upstream = [string]$upstream
                $counts = Invoke-Git $RepoPath @('rev-list', '--left-right', '--count', '@{u}...HEAD')
                if ($null -ne $counts) {
                    $nums = ([string]$counts).Trim() -split '\s+'
                    if ($nums.Count -ge 2) {
                        $info.behind = [int]$nums[0]
                        $info.ahead = [int]$nums[1]
                    }
                }
            }
        }

        $porcelain = Invoke-Git $RepoPath @('status', '--porcelain')
        $info.dirtyCount = Get-LineCount $porcelain
    }

    $statusPath = Join-Path $RepoPath 'docs\STATUS.md'
    if (Test-Path -LiteralPath $statusPath -PathType Leaf) {
        $info.statusMd.exists = $true
        $head30 = Get-Content -LiteralPath $statusPath -TotalCount 30
        foreach ($line in @($head30)) {
            if ($line -match '(?i)^\s*\*{0,2}Updated\*{0,2}\s*[:：]\s*(.+)$') {
                $info.statusMd.updatedLine = $Matches[1].Trim()
                $parsed = [datetimeoffset]::MinValue
                if ([datetimeoffset]::TryParse($info.statusMd.updatedLine, [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                    $info.statusMd.updatedDate = $parsed.ToString('yyyy-MM-dd')
                    if ($null -ne $lastCommitDate -and $parsed.Date -lt $lastCommitDate.Date) {
                        $info.statusMd.stale = $true
                    }
                }
                break
            }
        }
    }

    $tasksDir = Join-Path $RepoPath '.claude\tasks'
    if (Test-Path -LiteralPath $tasksDir -PathType Container) {
        $info.activeTasks = @(Get-ChildItem -LiteralPath $tasksDir -Filter '*.md' -File | ForEach-Object { $_.Name })
    }

    $info.hasVerifyPs1 = Test-Path -LiteralPath (Join-Path $RepoPath 'scripts\verify.ps1') -PathType Leaf
    $info.hasVerifySh = Test-Path -LiteralPath (Join-Path $RepoPath 'scripts\verify.sh') -PathType Leaf

    # Attention flags — computed here so the dashboard renderer is pure templating.
    $dormant = ($null -ne $daysAgo -and $daysAgo -gt 30)
    if (-not $IsGitRepo) { [void]$flags.Add('not-a-git-repo'); $score += 3 }
    if ($dormant -and $info.dirtyCount -gt 0) { [void]$flags.Add('dormant-dirty'); $score += 5 }
    elseif ($dormant) { [void]$flags.Add('dormant'); $score += 1 }
    if ($IsGitRepo -and -not $info.statusMd.exists -and -not $dormant) { [void]$flags.Add('status-missing'); $score += 2 }
    if ($info.statusMd.stale) { [void]$flags.Add('status-stale'); $score += 3 }
    if ($null -ne $info.behind -and $info.behind -gt 0) { [void]$flags.Add('behind-upstream'); $score += 2 }
    if ($null -ne $info.ahead -and $info.ahead -gt 0) { [void]$flags.Add('ahead-unpushed'); $score += 1 }
    if ($IsGitRepo -and -not $dormant -and -not ($info.hasVerifyPs1 -or $info.hasVerifySh)) { [void]$flags.Add('no-verify-script'); $score += 1 }

    $info.attention = @($flags)
    $info.attentionScore = $score
    return $info
}

# --- Discovery: one-level walk; a non-repo dir holding repo children yields one
# --- project per child (covers "Opal Management System\opal-management" etc).
$projects = New-Object System.Collections.ArrayList

foreach ($dir in Get-ChildItem -LiteralPath $ProjectsRoot -Directory) {
    if (Test-Path -LiteralPath (Join-Path $dir.FullName '.git')) {
        [void]$projects.Add((Get-ProjectInfo -Name $dir.Name -Path $dir.FullName -RepoPath $dir.FullName -Nested $false -IsGitRepo $true))
        continue
    }
    $repoChildren = @(Get-ChildItem -LiteralPath $dir.FullName -Directory | Where-Object {
        Test-Path -LiteralPath (Join-Path $_.FullName '.git')
    })
    if ($repoChildren.Count -eq 0) {
        [void]$projects.Add((Get-ProjectInfo -Name $dir.Name -Path $dir.FullName -RepoPath $dir.FullName -Nested $false -IsGitRepo $false))
    } elseif ($repoChildren.Count -eq 1) {
        [void]$projects.Add((Get-ProjectInfo -Name $dir.Name -Path $dir.FullName -RepoPath $repoChildren[0].FullName -Nested $true -IsGitRepo $true))
    } else {
        foreach ($child in $repoChildren) {
            [void]$projects.Add((Get-ProjectInfo -Name ("{0}/{1}" -f $dir.Name, $child.Name) -Path $dir.FullName -RepoPath $child.FullName -Nested $true -IsGitRepo $true))
        }
    }
}

# --- Brain facts (DevOS repo) ---
$inboxDir = Join-Path $DevosRoot 'brain\inbox'
$reviewsDir = Join-Path $DevosRoot 'brain\reviews'
$inboxCandidates = @()
if (Test-Path -LiteralPath $inboxDir -PathType Container) {
    $inboxCandidates = @(Get-ChildItem -LiteralPath $inboxDir -Filter '*.md' -File | ForEach-Object { $_.Name })
}
$latestReview = $null
$reviewsCount = 0
if (Test-Path -LiteralPath $reviewsDir -PathType Container) {
    $reviewFiles = @(Get-ChildItem -LiteralPath $reviewsDir -Filter '*.md' -File | Sort-Object Name -Descending)
    $reviewsCount = $reviewFiles.Count
    if ($reviewsCount -gt 0) { $latestReview = $reviewFiles[0].Name }
}

# --- Drift between brain/projects.md and disk ---
$indexPath = Join-Path $DevosRoot 'brain\projects.md'
$indexedProjects = New-Object System.Collections.ArrayList
$missingFromIndex = @()
$inIndexNotOnDisk = @()

function Get-NormalizedPath { param([string]$p) return $p.TrimEnd('\', '/').ToLowerInvariant() }

if (Test-Path -LiteralPath $indexPath -PathType Leaf) {
    foreach ($line in Get-Content -LiteralPath $indexPath) {
        if ($line -notmatch '^\s*\|') { continue }
        $cells = @($line -split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        if ($cells.Count -lt 2) { continue }
        if ($cells[0] -match '^-+$' -or $cells[0] -eq 'Project') { continue }
        $rowPath = $null
        if ($cells[1] -match '`([^`]+)`') { $rowPath = $Matches[1] } else { $rowPath = $cells[1] }
        $lastReviewed = $null
        if ($cells.Count -ge 7) { $lastReviewed = $cells[6] }
        [void]$indexedProjects.Add([ordered]@{ name = $cells[0]; path = $rowPath; lastReviewed = $lastReviewed })
    }

    $indexedNorm = @($indexedProjects | ForEach-Object { Get-NormalizedPath $_.path })
    $diskNorm = @{}
    foreach ($p in $projects) {
        $diskNorm[(Get-NormalizedPath $p.path)] = $p.name
        $diskNorm[(Get-NormalizedPath $p.repoPath)] = $p.name
    }
    $missingFromIndex = @($projects | Where-Object {
        $indexedNorm -notcontains (Get-NormalizedPath $_.path) -and $indexedNorm -notcontains (Get-NormalizedPath $_.repoPath)
    } | ForEach-Object { $_.name })
    $inIndexNotOnDisk = @($indexedProjects | Where-Object {
        -not $diskNorm.ContainsKey((Get-NormalizedPath $_.path))
    } | ForEach-Object { $_.name })
}

$result = [ordered]@{
    schemaVersion = 1
    generatedAt   = $now.ToString('yyyy-MM-ddTHH:mm:sszzz')
    projectsRoot  = $ProjectsRoot
    projects      = @($projects)
    brain         = [ordered]@{
        inboxCandidates = $inboxCandidates
        latestReview    = $latestReview
        reviewsCount    = $reviewsCount
    }
    projectsIndexDrift = [ordered]@{
        indexPath        = $indexPath
        indexedProjects  = @($indexedProjects)
        missingFromIndex = $missingFromIndex
        inIndexNotOnDisk = $inIndexNotOnDisk
    }
}

# -InputObject (not pipeline) preserves single-element arrays; default -Depth 2
# would silently stringify the nested objects.
Write-Output (ConvertTo-Json -InputObject $result -Depth 6)
exit 0
