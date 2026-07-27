@AGENTS.md

# Claude Code specifics

Everything above applies to every agent tool. This section is the Claude Code
mapping and the guardrails that exist only on this side.

Source of truth: `C:\Users\Jonathan\Projects\personal-dev-os`. Edit there and
run `sync.ps1` — never edit the copies under `~/.claude` directly.

## Effort tiers → models

The tiers in **Effort routing** map to:

| Tier | Model | How |
|---|---|---|
| Low | `haiku` | `/model haiku` |
| Default | `sonnet` | `/model sonnet` — the standing default |
| High | `fable` | `/model fable` — draws usage credits, so escalate deliberately |

Fable is the expensive tier. When Claude usage credits are the scarce resource
and the work is bulk rather than subtle, consider handing it to Codex instead
(see **Choosing a tool for the work**).

## Reviews

Standard and high-risk tasks run `/code-review` before commit or PR; high-risk
work also runs `/security-review` when security-relevant. These are Claude Code
skills with no Codex equivalent — on the Codex side, that review step is a
deliberate re-read of the diff, not a command.

## Guardrails that exist only here

- **Secret deny rules** (`permissions.deny` in settings) block this tool's file
  operations against `.env*`, `secrets/**`, `~/.ssh`, `~/.aws`, and the Claude
  Code credential file.
- **SessionStart hook** — surfaces active task files and staleness nudges.
- **PreToolUse hook** — forces a prompt on `git push --force`.

None of these transfer to Codex. When work is handed there, the Safety rules
above are enforced by instruction only.

## Skills

Seven manual-only `devos-*` skills (`disable-model-invocation: true`) — they
never auto-fire and only run when the slash command is typed. Claude cannot
invoke them via the Skill tool; when a task calls for one, replicate its
documented steps by hand and say that the substitution happened (see
`brain/standards/manual-only-skills.md`).
