# JSON from a PowerShell script fails to parse in the caller — but only on some machines

- **Applies to:** Windows PowerShell 5.1 — any script that reads text files and writes JSON to stdout for another process to parse
- **Last verified:** 2026-08-08
- **Source:** personal-dev-os, task "Brain consolidation pass (/devos-consolidate)" (`scripts/brain-scan.ps1`)

## Symptom

A script emits JSON that the caller cannot parse:

```
Invalid object passed in, ':' or '}' expected.
```

Inspecting the output shows a value terminating early, with a stray `"` or a replacement
character mid-string where the source file had an em dash or a curly quote.

The dangerous part: **it depends on the caller's console codepage, and the safe case is
the author's.** A session with `[Console]::OutputEncoding` at 65001 parses fine; the same
script run from `cmd.exe` (codepage 437) fails. A verification script that parses the JSON
therefore reports PASS for whoever wrote it and FAIL for everyone else.

## Cause

Two independent defects, which compound:

1. **`Get-Content` defaults to the ANSI codepage, not UTF-8.** A UTF-8 em dash (`—`,
   `E2 80 94`) decodes as three Windows-1252 characters, the last of which is U+201D.
2. **Non-ASCII on stdout is re-encoded using the *caller's* console codepage.** Under an
   OEM codepage, U+201D best-fit maps to a bare `"`. Inside a JSON string value that
   terminates the string early and the document becomes unparseable.

Either alone is survivable. Together they turn a correct-looking script into one that
works only where it was written.

## Fix

**Read as UTF-8.** Pass `-Encoding UTF8` on every `Get-Content` that may touch non-ASCII,
including `-Raw` and `-TotalCount` reads.

**Emit pure ASCII.** Escape every non-ASCII character as `\uXXXX` before writing — valid
JSON, and immune to whatever codepage the caller has:

```powershell
$sb = New-Object System.Text.StringBuilder
foreach ($ch in $json.ToCharArray()) {
    if ([int]$ch -gt 126) { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) }
    else { [void]$sb.Append($ch) }
}
Write-Output $sb.ToString()
```

The alternative is having the caller set `[Console]::OutputEncoding` to UTF-8. That works,
but it puts the fix in the wrong place: it has to be repeated by every present and future
caller, and forgetting it fails silently in the same environment-dependent way. Escaping
at the producer fixes it once, for all callers.

## Verification

Reproduced in both directions on the same input. Before the fix, the em dash in a brain
markdown file read as U+201D without `-Encoding UTF8`, and a cp437 cross-process capture
showed the corrupted title as `three different things ?" conflating them` — a raw quote
mid-value. `scripts/verify.ps1` exited 0 in a UTF-8 session and 1 under cp437 on identical
code. After the fix, the same invocation parses under 437 and 1252, the output contains
zero non-ASCII bytes, and the character round-trips as U+2014.

Found by `/code-review`, which ran the script rather than only reading it — a review that
had only read the source would not have caught it.

## Scope

Applies to every DevOS script matching this shape (reads markdown, emits JSON on stdout,
parsed by a skill).

Audited across `scripts/` on 2026-08-09 — three scripts had it, written at different
times. `brain-scan.ps1` and `mission-control-scan.ps1` both needed the two-part fix.
`mission-control-scan.ps1` had a third path the others do not: it reads git commit
subjects, and 5.1 decodes native command output using the console codepage, so it also
sets `[Console]::OutputEncoding` to UTF-8 before invoking git. `hook-session-start.ps1`
was reading JSON without `-Encoding`. All three are fixed.

`scripts/verify.ps1` now enforces this with a static AST check that fails on any
`Get-Content` in `scripts/` lacking `-Encoding`. Three instances written months apart is
the argument for the check over remembering — and a line-based regex is not enough, since
it also matches the literal inside the check's own name.

<!-- Only verified fixes enter playbooks. If the cause was never confirmed, it stays in inbox. -->
