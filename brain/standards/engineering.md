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
