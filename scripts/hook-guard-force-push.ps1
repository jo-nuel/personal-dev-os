# PreToolUse hook (Bash/PowerShell) — forces a permission prompt for git force
# pushes, enforcing the DevOS "always ask before force-pushing" rule at the
# harness level. Reads the tool call JSON on stdin; emits an "ask" decision only
# when a force push is detected, otherwise stays silent (normal flow).
$ErrorActionPreference = 'SilentlyContinue'
$raw = [Console]::In.ReadToEnd()
if (-not $raw) { exit 0 }
try { $payload = $raw | ConvertFrom-Json } catch { exit 0 }
$cmd = [string]$payload.tool_input.command
if (-not $cmd) { exit 0 }

# Match a force flag in the same command segment as "git ... push".
if ($cmd -match 'git(\.exe)?\s+[^|;&]*push[^|;&]*(\s--force(-with-lease|-if-includes)?(\s|=|$)|\s-f(\s|$))') {
    $out = @{
        hookSpecificOutput = @{
            hookEventName            = 'PreToolUse'
            permissionDecision       = 'ask'
            permissionDecisionReason = 'DevOS guardrail: force-push always requires explicit approval (global CLAUDE.md safety rule).'
        }
    }
    Write-Output (ConvertTo-Json -InputObject $out -Depth 4 -Compress)
}
exit 0
