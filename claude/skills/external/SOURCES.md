# External skills — provenance

Skills in this directory are vendored (copied, not submoduled) from third-party
repositories so they're backed up, diffable, and reproducible via `sync.ps1` like
everything else in DevOS. They are **not** written or owned by DevOS — do not edit
their content in place; re-vendor from upstream instead (see "Updating" below).

Directory names below match the upstream folder name, which is not always the same
as the `name:` field inside each skill's `SKILL.md` frontmatter (Claude Code invokes
skills by the frontmatter name, not the folder name) — noted per entry.

## vercel-labs/agent-skills

- **Source:** https://github.com/vercel-labs/agent-skills
- **Vendored at commit:** `f8a72b9603728bb92a217a879b7e62e43ad76c81`
- **Vendored:** 2026-07-11
- **License:** check the upstream repo before redistributing

| Folder | SKILL.md `name:` | Purpose |
|---|---|---|
| `web-design-guidelines` | `web-design-guidelines` | Audits UI code against 100+ accessibility/performance/UX rules |
| `react-best-practices` | `vercel-react-best-practices` | React/Next.js performance optimization rules |
| `composition-patterns` | `vercel-composition-patterns` | React composition pattern guidelines |
| `react-view-transitions` | `vercel-react-view-transitions` | React View Transition API implementation guide |
| `react-native-skills` | `vercel-react-native-skills` | React Native-specific guidance |

Skipped from upstream (not vendored, judged not relevant to current projects):
`deploy-to-vercel`, `vercel-cli-with-tokens`, `vercel-optimize` (Vercel-deployment-specific
— revisit if a project actually deploys to Vercel), `writing-guidelines` (docs/prose review
— revisit if wanted later).

## anthropics/skills

- **Source:** https://github.com/anthropics/skills
- **Vendored at commit:** `9d2f1ae187231d8199c64b5b762e1bdf2244733d`
- **Vendored:** 2026-07-11
- **License:** per-skill `LICENSE.txt` included in the vendored folder

| Folder | SKILL.md `name:` | Purpose |
|---|---|---|
| `frontend-design` | `frontend-design` | Distinctive, intentional visual design guidance for new/reshaped UI — broader scope than Claude Code's bundled `artifact-design` skill (which is Artifacts-only) |

Anthropic's repo also has `.claude-plugin/marketplace.json` (it's a real plugin
marketplace, not just a plain skill collection like vercel-labs) with more skills
(`canvas-design`, `theme-factory`, `webapp-testing`, `mcp-builder`, etc.) — not
vendored, revisit if wanted later.

## Updating a vendored skill

1. Re-fetch the folder from upstream at a newer commit (sparse clone, same as initial vendor).
2. Diff against the current vendored copy before overwriting, in case local notes were
   ever added here (they shouldn't be — edit upstream, not this copy).
3. Update the commit SHA and "Vendored" date above.
4. Run `.\sync.ps1 -WhatIf` to confirm the update installs cleanly.
