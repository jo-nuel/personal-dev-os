# Engineering standards

Cross-project principles, already established in DevOS. Project-specific conventions belong in that repo's own `CLAUDE.md`, not here.

- Deterministic verification beats AI self-certification: "done" means a verify script/test exited 0, not that the code looks right.
- Prefer the smallest coherent change that satisfies the acceptance criteria over speculative refactoring.
- No unrelated refactoring bundled into a task — a bug fix doesn't need surrounding cleanup.
- Secrets are excluded from prompts, documentation, and Git history — never read, echo, or persist `.env`/credential values.
- Each project repository owns its own architecture, decisions, and status; the brain holds only cross-project material.
- Risky and irreversible actions (migrations, deploys, deletions, credential/identity changes, external communications, force-pushes) require explicit approval before they run.
- A lesson only enters permanent memory after passing through `brain/inbox/` with evidence and verification, and only Jonathan promotes it (`/devos-promote`).
- Verification results and limitations are reported honestly — failing or skipped checks are named as such, not glossed over.
- Staleness and freshness on dated files are computed from the semantic date in the filename or content, never from filesystem mtime — mtime resets on clone, checkout, and stash pop, silently making a stale file look fresh with no error. (Verified 2026-07-13 in personal-dev-os by forcing a 3-week-old review file's `LastWriteTime` to "now"; the corrected check still reported it 21 days stale.)
- When adding a check parallel to an existing one, confirm it copies the sibling's logic and not merely its shape.
