# brain-scan.ps1 — read-only maintenance scan of brain/ for /devos-consolidate.
# Emits one JSON document to stdout: an inventory of every brain file plus a
# conservative set of flags (near-duplicate, oversize, stale candidate, broken
# link). PowerShell 5.1. Writes nothing, anywhere.
#
# Flags are deliberately conservative: they mark files worth *looking at*, never
# a verdict. Content age and revision count are reported but never flagged — an
# untouched standard that is still correct is not a defect.

[CmdletBinding()]
param(
    [string]$BrainRoot,
    [string]$RepoRoot,
    # Cosine-IDF similarity above which a pair is worth a human look. Calibrated
    # against a known paraphrased duplicate, not guessed — see
    # docs/decisions/2026-08-08-brain-consolidation.md for the measurements.
    [double]$OverlapThreshold = 0.12,
    # An inbox candidate older than this means the promote ritual is not running.
    [int]$StaleCandidateDays = 21,
    # Above this a memory file is probably covering more than one topic.
    [int]$MaxFileLines = 200,
    # How many highest-similarity pairs to report, flagged or not.
    [int]$TopOverlaps = 10
)

# 'Stop' would turn redirected native stderr (2>$null) into terminating
# NativeCommandErrors in 5.1 — keep 'Continue' and gate on $LASTEXITCODE.
$ErrorActionPreference = 'Continue'

# $PSScriptRoot is not populated when param defaults evaluate under -File in 5.1.
if (-not $RepoRoot) { $RepoRoot = Split-Path -Parent $PSScriptRoot }
if (-not $BrainRoot) { $BrainRoot = Join-Path $RepoRoot 'brain' }

if (-not (Test-Path -LiteralPath $BrainRoot -PathType Container)) {
    Write-Error "Brain root not found: $BrainRoot"
    exit 1
}

$BrainRoot = (Resolve-Path -LiteralPath $BrainRoot).ProviderPath.TrimEnd('\', '/')
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath.TrimEnd('\', '/')

# Every reported path is computed relative to $RepoRoot; a brain outside it would
# silently produce mangled paths, so fail loudly instead. The separator matters:
# a bare StartsWith would accept 'personal-dev-os-backup\brain' under
# 'personal-dev-os' and emit paths like '-backup/brain/...'.
$repoPrefix = $RepoRoot + [IO.Path]::DirectorySeparatorChar
if (-not $BrainRoot.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -and
    -not $BrainRoot.Equals($RepoRoot, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "Brain root ($BrainRoot) must live under repo root ($RepoRoot)"
    exit 1
}

$now = Get-Date

# Only lesson-bearing areas take part in similarity analysis. An explicit
# allowlist, so a new brain area does not silently join it. Excluded, and why:
#   reviews/       dated append-only logs, similar to each other by design
#   projects.md    registry of projects, not a lesson — kept in step by
#   connections.md /devos-repo-brief and the weekly-review drift checks
# Measured: brain/projects.md vs standards/stack-defaults.md scored 0.223 purely
# because both enumerate the same stacks. Never an actionable merge, and it sat
# high enough to crowd out real duplicates.
$lessonAreas = @('standards', 'playbooks', 'inbox')

# Common English plus DevOS's own vocabulary. Terms this frequent carry no signal
# about what a file is *about*, which is the only thing overlap is measuring.
$stopWords = @(
    'that','this','with','from','have','been','were','they','their','them','then','than',
    'when','what','which','while','will','would','could','should','shall','into','only',
    'also','because','before','after','about','above','below','same','such','some','more',
    'most','much','many','each','every','other','another','over','under','once','never',
    'always','here','there','where','does','done','doing','make','makes','made','like',
    'just','even','both','either','neither','instead','rather','without','within','across',
    'against','through','during','being','back','down','left','right','next','last','first',
    'file','files','line','lines','note','notes','case','cases','used','uses','using',
    'need','needs','work','works','thing','things','step','steps','part','parts','time',
    'times','onto','upon','yet','via','per','not','but','and','the','for','are','was'
) | ForEach-Object { $_ }
$stopSet = @{}
foreach ($w in $stopWords) { $stopSet[$w] = $true }

function Get-Terms {
    param([string]$Text)
    $set = @{}
    if ([string]::IsNullOrWhiteSpace($Text)) { return $set }
    foreach ($tok in ($Text.ToLowerInvariant() -split '[^a-z0-9]+')) {
        if ($tok.Length -lt 4) { continue }
        if ($tok -match '^\d+$') { continue }
        if ($stopSet.ContainsKey($tok)) { continue }
        $set[$tok] = $true
    }
    return $set
}

function Invoke-Git {
    param([string]$Path, [string[]]$GitArgs)
    $out = & git -C $Path @GitArgs 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function Get-RelativePath {
    param([string]$FullPath)
    $rel = $FullPath.Substring($RepoRoot.Length).TrimStart('\', '/')
    return ($rel -replace '\\', '/')
}

# --- Inventory -------------------------------------------------------------

$files = New-Object System.Collections.ArrayList
$termSets = @{}

foreach ($f in (Get-ChildItem -LiteralPath $BrainRoot -Recurse -Filter '*.md' -File | Sort-Object FullName)) {
    $rel = Get-RelativePath $f.FullName
    # Path relative to brain/, so the first segment is the area.
    $inBrain = $f.FullName.Substring($BrainRoot.Length).TrimStart('\', '/') -replace '\\', '/'
    $segments = @($inBrain -split '/')
    $area = if ($segments.Count -gt 1) { $segments[0] } else { 'root' }

    # -Encoding UTF8 is mandatory: 5.1's Get-Content default is the ANSI codepage,
    # which turns every em dash in a brain file into three mojibake characters —
    # one of which is U+201D, and that best-fit maps to a bare " under an OEM
    # console codepage, producing JSON no caller can parse.
    $raw = Get-Content -LiteralPath $f.FullName -Raw -Encoding UTF8
    if ($null -eq $raw) { $raw = '' }
    $lineArr = @(Get-Content -LiteralPath $f.FullName -Encoding UTF8)

    $title = $null
    foreach ($line in $lineArr) {
        if ($line -match '^#\s+(.+?)\s*$') { $title = $Matches[1]; break }
    }

    $revisions = $null
    $lastCommit = $null
    $log = Invoke-Git $RepoRoot @('log', '--format=%cI', '--', $rel)
    if ($null -ne $log) {
        $logLines = @($log)
        $revisions = $logLines.Count
        if ($revisions -gt 0) {
            $parsed = [datetimeoffset]::MinValue
            if ([datetimeoffset]::TryParse($logLines[0], [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                $lastCommit = [ordered]@{
                    date    = $logLines[0]
                    daysAgo = [int][math]::Floor(($now - $parsed.LocalDateTime).TotalDays)
                }
            }
        }
    }

    $wordCount = @($raw -split '\s+' | Where-Object { $_ -ne '' }).Count

    [void]$files.Add([ordered]@{
        path       = $rel
        area       = $area
        title      = $title
        lines      = $lineArr.Count
        words      = $wordCount
        revisions  = $revisions
        lastCommit = $lastCommit
    })

    if ($lessonAreas -contains $area) {
        $termSets[$rel] = Get-Terms $raw
    }
}

# Summed by hand: Measure-Object -Property reads PSObject properties and finds
# nothing on an [ordered] hashtable.
$totalLines = 0
$totalWords = 0
foreach ($f in $files) { $totalLines += $f.lines; $totalWords += $f.words }

$totals = [ordered]@{
    files = $files.Count
    lines = $totalLines
    words = $totalWords
}

$byArea = [ordered]@{}
foreach ($grp in ($files | Group-Object -Property { $_.area } | Sort-Object Name)) {
    $byArea[[string]$grp.Name] = $grp.Count
}

# --- Overlap: cosine similarity over IDF-weighted term vectors ---------------
# idf = log(N / documentFrequency), so a term present in every analyzed file
# weighs exactly zero. That is what keeps two unrelated playbooks from looking
# similar just because both quote the same PowerShell invocation. Cosine (rather
# than Jaccard) keeps the score from collapsing when one file is much longer
# than the other — a short candidate duplicating part of a long standard is
# exactly the case worth catching.

$docFreq = @{}
foreach ($key in $termSets.Keys) {
    foreach ($term in $termSets[$key].Keys) {
        if ($docFreq.ContainsKey($term)) { $docFreq[$term]++ } else { $docFreq[$term] = 1 }
    }
}

$analyzed = @($termSets.Keys | Sort-Object)
$n = $analyzed.Count

$idf = @{}
foreach ($term in $docFreq.Keys) { $idf[$term] = [math]::Log($n / [double]$docFreq[$term]) }

$norms = @{}
foreach ($key in $analyzed) {
    $sumSq = 0.0
    foreach ($term in $termSets[$key].Keys) { $sumSq += ($idf[$term] * $idf[$term]) }
    $norms[$key] = [math]::Sqrt($sumSq)
}

$pairs = New-Object System.Collections.ArrayList

for ($i = 0; $i -lt $n; $i++) {
    for ($j = $i + 1; $j -lt $n; $j++) {
        $aKey = $analyzed[$i]
        $bKey = $analyzed[$j]
        # A zero norm means every one of the file's terms is corpus-wide
        # boilerplate; there is no topic left to compare.
        if ($norms[$aKey] -le 0 -or $norms[$bKey] -le 0) { continue }

        $aSet = $termSets[$aKey]
        $bSet = $termSets[$bKey]
        # Iterate the smaller set — the intersection is the same either way.
        if ($aSet.Count -gt $bSet.Count) { $small = $bSet; $large = $aSet } else { $small = $aSet; $large = $bSet }

        $dot = 0.0
        $shared = New-Object System.Collections.ArrayList
        foreach ($term in $small.Keys) {
            if ($large.ContainsKey($term)) {
                $dot += ($idf[$term] * $idf[$term])
                [void]$shared.Add($term)
            }
        }
        if ($dot -le 0) { continue }

        # Rarest shared terms first — they say what the overlap actually is.
        $topShared = @($shared | Sort-Object { $docFreq[$_] }, { $_ } | Select-Object -First 8)

        [void]$pairs.Add([ordered]@{
            a               = $aKey
            b               = $bKey
            similarity      = [math]::Round($dot / ($norms[$aKey] * $norms[$bKey]), 3)
            sharedTermCount = $shared.Count
            sharedTerms     = $topShared
        })
    }
}

# Scriptblock, not -Property: Sort-Object -Property does not resolve keys on an
# [ordered] hashtable and silently returns insertion order instead.
$sortedPairs = @($pairs | Sort-Object -Property { $_.similarity } -Descending)
foreach ($p in $sortedPairs) { $p['flagged'] = ($p.similarity -ge $OverlapThreshold) }
$overlaps = @($sortedPairs | Select-Object -First $TopOverlaps)

# --- Broken links ----------------------------------------------------------
# Markdown link targets only. Backticked paths were tried first and were pure
# noise: brain/projects.md legitimately names paths inside *other* repositories
# (`docs/STATUS.md`, `docs/{architecture,cms}`), none of which exist here. A
# markdown link is the narrower signal — an actual assertion that a file sits at
# that relative path. Anything with a glob, brace set, ellipsis, or angle
# bracket is a documentation pattern, not a path, and is skipped.

$brokenLinks = New-Object System.Collections.ArrayList

function Test-RepoPath {
    param([string]$Candidate, [string]$FromDir)
    if ($Candidate -match '^[A-Za-z]:[\\/]') {
        return (Test-Path -LiteralPath $Candidate)
    }
    $fromRepo = Join-Path $RepoRoot ($Candidate -replace '/', '\')
    if (Test-Path -LiteralPath $fromRepo) { return $true }
    $fromFile = Join-Path $FromDir ($Candidate -replace '/', '\')
    return (Test-Path -LiteralPath $fromFile)
}

foreach ($f in (Get-ChildItem -LiteralPath $BrainRoot -Recurse -Filter '*.md' -File | Sort-Object FullName)) {
    $rel = Get-RelativePath $f.FullName
    $fromDir = $f.DirectoryName
    $lineNo = 0
    foreach ($line in @(Get-Content -LiteralPath $f.FullName -Encoding UTF8)) {
        $lineNo++
        $candidates = New-Object System.Collections.ArrayList

        foreach ($m in [regex]::Matches($line, '\]\(([^)\s]+)\)')) {
            [void]$candidates.Add($m.Groups[1].Value)
        }

        foreach ($c in $candidates) {
            $target = ($c -split '#')[0].Trim()
            if ($target -eq '') { continue }
            if ($target -match '^(https?:|mailto:|#)') { continue }
            if ($target -match '[*?<>|{}]' -or $target -match '\.\.\.') { continue }
            # Directory references are written with a trailing slash.
            $probe = $target.TrimEnd('/', '\')
            if ($probe -eq '') { continue }
            if (-not (Test-RepoPath -Candidate $probe -FromDir $fromDir)) {
                [void]$brokenLinks.Add([ordered]@{ file = $rel; line = $lineNo; target = $target })
            }
        }
    }
}

# --- Stale inbox candidates -------------------------------------------------

$staleCandidates = New-Object System.Collections.ArrayList
$inboxDir = Join-Path $BrainRoot 'inbox'
if (Test-Path -LiteralPath $inboxDir -PathType Container) {
    # -Recurse to match the inventory walk above; otherwise a candidate filed in an
    # inbox subdirectory is inventoried but never age-checked.
    foreach ($c in (Get-ChildItem -LiteralPath $inboxDir -Recurse -Filter '*.md' -File | Sort-Object FullName)) {
        $rel = Get-RelativePath $c.FullName
        $filed = $null
        $source = $null

        if ($c.Name -match '^(\d{4}-\d{2}-\d{2})-') {
            $parsed = [datetime]::MinValue
            if ([datetime]::TryParseExact($Matches[1], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                $filed = $parsed; $source = 'filename'
            }
        }
        if ($null -eq $filed) {
            foreach ($line in @(Get-Content -LiteralPath $c.FullName -TotalCount 20 -Encoding UTF8)) {
                if ($line -match '(?i)^\s*[-*]?\s*\*{0,2}Date\*{0,2}\s*[:：]\s*(\d{4}-\d{2}-\d{2})') {
                    $parsed = [datetime]::MinValue
                    if ([datetime]::TryParseExact($Matches[1], 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::None, [ref]$parsed)) {
                        $filed = $parsed; $source = 'date-line'
                    }
                    break
                }
            }
        }
        if ($null -eq $filed) { $filed = $c.LastWriteTime.Date; $source = 'mtime' }

        $age = [int][math]::Floor(($now.Date - $filed.Date).TotalDays)
        if ($age -ge $StaleCandidateDays) {
            [void]$staleCandidates.Add([ordered]@{
                path       = $rel
                filed      = $filed.ToString('yyyy-MM-dd')
                dateSource = $source
                daysWaiting = $age
            })
        }
    }
}

# --- Flags -----------------------------------------------------------------
# Each flag names the files to open and the signal that raised it. Nothing here
# is a conclusion; /devos-consolidate must read the files and quote evidence
# before proposing any change.

$flags = New-Object System.Collections.ArrayList

# $sortedPairs, not $overlaps: the latter is truncated to $TopOverlaps for
# reporting, and pair count grows O(n^2), so flagging from it would silently drop
# real duplicates as the brain grows.
foreach ($p in $sortedPairs) {
    if (-not $p.flagged) { continue }
    [void]$flags.Add([ordered]@{
        kind    = 'near-duplicate'
        targets = @($p.a, $p.b)
        detail  = "similarity $($p.similarity), $($p.sharedTermCount) shared terms: $(($p.sharedTerms) -join ', ')"
    })
}

# Title overlap catches a duplicate pair whose bodies diverged enough to fall
# below the body threshold — two files answering one question.
$titled = @($files | Where-Object { $_.title -and ($lessonAreas -contains $_.area) })
$titleTerms = @{}
foreach ($t in $titled) { $titleTerms[$t.path] = Get-Terms $t.title }

for ($i = 0; $i -lt $titled.Count; $i++) {
    for ($j = $i + 1; $j -lt $titled.Count; $j++) {
        $tA = $titleTerms[$titled[$i].path]
        $tB = $titleTerms[$titled[$j].path]
        if ($tA.Count -eq 0 -or $tB.Count -eq 0) { continue }
        $inter = 0
        foreach ($t in $tA.Keys) { if ($tB.ContainsKey($t)) { $inter++ } }
        $union = $tA.Count + $tB.Count - $inter
        if ($union -le 0) { continue }
        $sim = [math]::Round($inter / [double]$union, 3)
        if ($sim -ge 0.6) {
            [void]$flags.Add([ordered]@{
                kind    = 'near-duplicate-title'
                targets = @($titled[$i].path, $titled[$j].path)
                detail  = "title similarity $sim"
            })
        }
    }
}

foreach ($f in ($files | Where-Object { $_.lines -gt $MaxFileLines })) {
    [void]$flags.Add([ordered]@{
        kind    = 'oversize'
        targets = @($f.path)
        detail  = "$($f.lines) lines (threshold $MaxFileLines)"
    })
}

foreach ($s in $staleCandidates) {
    [void]$flags.Add([ordered]@{
        kind    = 'stale-candidate'
        targets = @($s.path)
        detail  = "waiting $($s.daysWaiting) days (filed $($s.filed), from $($s.dateSource))"
    })
}

foreach ($b in $brokenLinks) {
    [void]$flags.Add([ordered]@{
        kind    = 'broken-link'
        targets = @($b.file)
        detail  = "line $($b.line): $($b.target) does not exist"
    })
}

$result = [ordered]@{
    schemaVersion = 1
    generatedAt   = $now.ToString('yyyy-MM-ddTHH:mm:sszzz')
    brainRoot     = $BrainRoot
    thresholds    = [ordered]@{
        overlap            = $OverlapThreshold
        staleCandidateDays = $StaleCandidateDays
        maxFileLines       = $MaxFileLines
    }
    totals        = $totals
    byArea        = $byArea
    files         = @($files)
    analyzedCount = $analyzed.Count
    overlaps      = $overlaps
    brokenLinks   = @($brokenLinks)
    staleCandidates = @($staleCandidates)
    flags         = @($flags)
    flagCount     = $flags.Count
}

# -InputObject (not pipeline) preserves single-element arrays; default -Depth 2
# would silently stringify the nested objects.
$json = ConvertTo-Json -InputObject $result -Depth 6

# Emit pure ASCII, escaping every non-ASCII character as \uXXXX. Brain files are
# full of em dashes and curly quotes, and stdout crossing a process boundary is
# re-encoded using whatever console codepage the caller happens to have — under
# an OEM codepage those characters are best-fit mapped, and U+201D becomes a bare
# " that breaks the JSON. \uXXXX is valid JSON and codepage-independent, so the
# output parses identically for every caller.
$sb = New-Object System.Text.StringBuilder
foreach ($ch in $json.ToCharArray()) {
    if ([int]$ch -gt 126) { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) }
    else { [void]$sb.Append($ch) }
}

Write-Output $sb.ToString()
exit 0
