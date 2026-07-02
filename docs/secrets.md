# Secret protection in DevOS

## What the deny rules do — and do not do

The DevOS settings install `Read`/`Edit` deny rules for `.env` files, `secrets/`
directories, SSH/AWS credential folders, and the Claude Code credential file
(see `claude/settings-devos.json`).

**Enforced:** Claude Code's built-in file tools (`Read`, `Edit`, `Write`) and
recognized file-reading shell commands are blocked by the harness when a rule
matches. Deny beats allow at every settings scope, so a project's allow list
cannot override these rules.

**Not enforced — this is not an OS-level security boundary:**

- Arbitrary subprocesses (Python scripts, Node programs, custom binaries)
  launched via the shell run with your full OS permissions and can read any
  file indirectly. The rules constrain Claude Code's tool calls, not the
  operating system.
- New or unusual shell constructs may not be recognized as file reads.

## Consequences for how we work

1. **Real production credentials stay outside working repositories** where
   practical — in the hosting provider's secret store, a credential manager,
   or at minimum outside any folder Claude Code operates in. A gitignored
   `.env` is a convenience for local dev values, not a vault.
2. **Instructions back up the rules:** the global CLAUDE.md forbids reading,
   echoing, or persisting secret values regardless of what the rules catch.
3. **`.env.example` stays readable by design.** The rules enumerate real
   secret variants (`.env`, `.env.local`, `.env.development`, `.env.production`)
   instead of using a broad `.env.*` wildcard, because deny is absolute — a
   wildcard would permanently block the harmless example files.
4. **Nested directories are covered** via `./**/`-prefixed patterns, since
   several projects keep apps in subfolders.

## Rule maintenance

- Empirical test results and known gaps are tracked below; re-test after
  Claude Code upgrades that change permission behavior.
- New secret locations (e.g. a `terraform.tfvars`, cloud config folders) are
  added to `claude/settings-devos.json` and rolled out via `sync.ps1`.

## Fresh-session test procedure

Deny rules must be validated in a session that started **after** the rules were
in place (see test log: mid-session enforcement of a newly created settings
file does not occur). After applying `sync.ps1` (or in any repo carrying the
committed `.claude/settings.json`), open a fresh Claude Code session and run:

1. Create fakes (never real values):
   `.env` -> `FAKE_API_KEY=fake-123`, `.env.example` -> `FAKE_API_KEY=your-key-here`,
   `nested/app/.env` -> `FAKE_NESTED=fake-456`, `secrets/key.txt` -> `FAKE=fake-789`.
2. Ask Claude to read each file with the Read tool. Expected:
   `.env` DENIED · `nested/app/.env` DENIED (validates `**`) ·
   `secrets/key.txt` DENIED · `.env.example` ALLOWED.
3. Ask Claude to `cat .env` (Bash) and `Get-Content .env` (PowerShell).
   Record whether command-level reads are recognized and blocked.
4. Delete the fakes; record results in the log below; fix any gap in
   `claude/settings-devos.json` and re-run.

## Test log

| Date | Test | Result |
|---|---|---|
| 2026-07-02 | Deny rule (exact `./` match) added to newly created project `.claude/settings.json`, Read attempted mid-session | NOT enforced — settings file created after session start is not loaded mid-session (VS Code extension 2.1.198). Not a pattern failure. |
| 2026-07-02 | Same for `~/`-path rule targeting scratchpad fake `.env` | NOT enforced — same reload limitation |
| 2026-07-02 | Enforcement + `**` nesting + `.env.example` allowance + Bash/PowerShell command coverage | DEFERRED to fresh-session test (procedure above) — must pass before the rules are trusted |
<!-- Filled by future re-tests. -->
