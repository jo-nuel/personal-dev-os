# Candidate: a PowerShell 5.1 script emitting JSON on stdout must read as UTF8 and emit pure ASCII

- **Date:** 2026-08-08
- **Source:** personal-dev-os, task "Brain consolidation pass (/devos-consolidate)"
- **Proposed destination:** brain/playbooks/powershell-json-stdout-encoding.md
- **Verified how:** Reproduced both the failure and the fix on the same input. The
  identical `brain-scan.ps1` output parsed under console codepage 65001 and failed under
  437 with `Invalid object passed in, ':' or '}' expected`. After the fix, the same
  invocation parses under 437 and 1252, output contains zero non-ASCII bytes, and the
  affected character round-trips as U+2014 instead of the corrupted U+201D.

## The lesson

Two independent defects bite any PS 5.1 script that reads text files and writes JSON to
stdout for another process to parse.

**1. `Get-Content` defaults to the ANSI codepage, not UTF-8.** A UTF-8 em dash (`—`,
`E2 80 94`) is decoded as three Windows-1252 characters, the last of which is U+201D.
Always pass `-Encoding UTF8` when reading files that may contain non-ASCII — including
`-Raw` and `-TotalCount` reads.

**2. Non-ASCII on stdout is re-encoded with the *caller's* console codepage.** Under an
OEM codepage (437, the `cmd.exe` default) U+201D best-fit maps to a bare `"`. Inside a
JSON string value that terminates the string early and the document becomes unparseable.
Escape every non-ASCII character as `\uXXXX` before writing — valid JSON, and immune to
whatever codepage the caller has:

```powershell
$sb = New-Object System.Text.StringBuilder
foreach ($ch in $json.ToCharArray()) {
    if ([int]$ch -gt 126) { [void]$sb.AppendFormat('\u{0:x4}', [int]$ch) }
    else { [void]$sb.Append($ch) }
}
Write-Output $sb.ToString()
```

The dangerous property is that this is **environment-dependent, and the safe environment
is the developer's**. A session with `[Console]::OutputEncoding` at 65001 passes; the same
code fails from `cmd.exe`. A verification script that parses the JSON therefore reports
PASS for whoever wrote it and FAIL for everyone else.

## Evidence

Found by `/code-review` on the `feat/brain-consolidation` branch, which ran the script
rather than only reading it, and reproduced deliberately before fixing: the em dash in
`brain/inbox/2026-07-27-handoff-vs-subagent-vs-orchestrator.md` read as U+201D without
`-Encoding UTF8`, and the cp437 cross-process capture showed the corrupted title as
`three different things ?" conflating them` — a raw quote mid-value. `scripts/verify.ps1`
exited 0 in a UTF-8 session and 1 under cp437 on identical code.

Not yet audited: `scripts/mission-control-scan.ps1` has the same shape (reads markdown,
emits JSON on stdout, parsed by a skill) and may carry the same defect.
