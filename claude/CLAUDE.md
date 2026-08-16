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
| High | `opus` | `/model opus`, or delegate to a pinned agent (below) |
| Exceptional | `fable` | `/model fable` — draws usage credits; deliberate escalation only |

Fable is not the normal high tier. Reach for it only when Opus has genuinely
failed at the work, not as the default escalation. When Claude usage credits
are the scarce resource and the work is bulk rather than subtle, consider
handing it to Codex instead (see **Choosing a tool for the work**).

## Routing individual tasks to a tier

A running session cannot change its own model — `/model` is manual, and the
`model` setting only applies at session start. Automatic tiering therefore
happens by **delegation**: the session stays on its own model and hands
tier-High work to an agent pinned to Opus.

| Agent | Model | For |
|---|---|---|
| `deep-decision` | `opus` | Architecture, tradeoffs, migration planning, hard debugging |
| `heavy-implementation` | `opus` | Large but cleanly-isolable coding work |

Delegate when a piece of work meets a High trigger *and* can be stated without
this conversation's history — subagents run in an isolated context and cannot
see the transcript. Work that genuinely needs the running context is escalated
by hand with `/model opus`, or by pinning `"model": "opus"` in that project's
`.claude/settings.json` (as `skipbin` does).

Default to Sonnet. Escalate on the trigger, not on the hunch.

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

None of these transfer to Codex — and since 2026-08-16 DevOS installs no
instructions there either, so `AGENTS.md` is not loaded on that side at all
(`docs/decisions/2026-08-16-drop-codex-integration.md`). Work handed to Codex
runs with no DevOS rules of any kind. Restate the ones that matter in the
handoff itself.

## Skills

Eight manual-only `devos-*` skills (`disable-model-invocation: true`) — they
never auto-fire and only run when the slash command is typed. Claude cannot
invoke them via the Skill tool; when a task calls for one, replicate its
documented steps by hand and say that the substitution happened (see
`brain/standards/manual-only-skills.md`).

Two of them maintain the brain, and the split between them matters:
`/devos-promote` judges *new* lessons arriving in `brain/inbox/`;
`/devos-consolidate` looks *inward* at memory already made permanent and files
merge/split/retire proposals back into `brain/inbox/`. Neither the brain's own
maintenance nor anything else writes to permanent memory without Jonathan's
per-item approval.
