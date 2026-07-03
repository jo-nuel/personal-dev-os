# `scripts/verify.ps1` fails to run directly due to default PowerShell execution policy

- **Applies to:** Windows 11, PowerShell 5.1 (this machine's configuration only — not confirmed universal across other PowerShell versions or execution-policy settings)
- **Last verified:** 2026-07-03
- **Source:** devos-skill-test, task "Validate the DevOS task lifecycle"

## Symptom

Running a repo-local verification script directly:

```
powershell -File scripts/verify.ps1
```

fails with an `UnauthorizedAccess` error: "running scripts is disabled on this system."
This happens even when the script itself is correct.

## Cause

On this machine, the default PowerShell execution policy blocks unsigned `.ps1` scripts,
including repo-local verification scripts like `scripts/verify.ps1`.

## Fix

Run the script with the execution policy bypassed for that invocation only:

```
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/verify.ps1
```

This does not alter the persistent execution policy — it only affects the single
invocation — so it's safe to use routinely when a DevOS repo's `verify.ps1` needs to be
executed as part of task verification.

## Verification

Reproduced once in `devos-skill-test`: the plain invocation (`powershell -File
scripts/verify.ps1`) failed with the execution-policy error; the `-ExecutionPolicy
Bypass` invocation succeeded and printed `verify.ps1: PASS` with exit code 0.

## Limitation

Verified on Windows 11 with PowerShell 5.1 only. Do not present this as universal
behavior across all PowerShell versions or execution-policy configurations — other
machines may have a different default policy (e.g. `RemoteSigned` or `Unrestricted`)
where the plain invocation succeeds without the bypass flag.

<!-- Only verified fixes enter playbooks. If the cause was never confirmed, it stays in inbox. -->
