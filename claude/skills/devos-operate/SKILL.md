---
name: devos-operate
description: Chief-operator mode — take a broad goal, build a picture of current state, break it into microtasks, delegate each to the right tool, and track status on a live dashboard.
argument-hint: "<goal>"
disable-model-invocation: true
---

`$ARGUMENTS` is the goal, in the user's own words. Do not invent scope beyond it.

## 1. Big picture

Read, at most: `brain/projects.md` (index only, not the rest of `brain/`), the target
repo's `docs/STATUS.md` if it exists, and any active `.claude/tasks/*.md` in the target
repo. This is read-only context gathering — no other exploration yet.

## 2. Classify

Classify the goal as **tiny**, **standard**, or **high-risk** using the task-category
definitions in the global DevOS `CLAUDE.md` (the same rule `devos-task` applies). State
the classification and a one-line reason.

If any part of the goal is high-risk, stop before delegating any implementation work for
that part: it needs a written plan and Jonathan's explicit approval first, exactly as the
global rules require. Delegation must never be used as a way to route around that gate —
a microtask that touches migrations, auth/permissions, data deletion, deploy config,
payments, or external communications does not get farmed out until the plan for it is
approved.

## 3. Tiny goals — no decomposition, no dashboard

If the goal classifies as tiny, do not decompose it and do not render a dashboard. Return
the same kind of short plain-text checklist `devos-task open` would give a tiny item
(concrete steps + the verification command that must pass), and stop here.

## 4. Standard / high-risk — decompose

Break the goal into microtasks. Each microtask must have an independently verifiable
"done" condition — split only where that condition changes, not just for convenience.

## 5. Render the initial dashboard

Before writing anything, invoke the `artifact-design` skill to calibrate design weight —
this is a personal-utility status page, not a landing page; expect a light-to-medium
design pass. Only reach for the `dataviz` skill if a chart genuinely earns its place (e.g.
a progress bar); a status table with badges is usually enough on its own.

Write the dashboard HTML to the session's scratchpad temp directory as
`devos-operate-<slug>.html`, where `<slug>` is the kebab-case goal — reused for every
redeploy in this run so the URL stays stable. Do not write it into the repo: nothing here
commits generated HTML, and this is run-scoped state exactly like the rest of the
scratchpad.

Render every microtask with status `pending`. Sections, in order:

1. **Header** — the goal verbatim, a classification badge (standard/high-risk), and a
   last-updated timestamp.
2. **Big picture** — one or two lines on what state was actually read (which
   `STATUS.md`, which active task files), labeled **verified** vs **inferred** the way
   `devos-repo-brief` does.
3. **Approval gates** — present only when high-risk items are awaiting plan approval.
   Make this visually prominent and first — it is the one thing that blocks progress, not
   a footnote in the table.
4. **Microtask table** — columns: microtask, delegated-to (direct / Explore / Plan /
   general-purpose / devos-task / Workflow), status badge, verification result.
5. **Next recommended action** — one line, footer.

Theme-aware (`prefers-color-scheme` plus a `data-theme` override), fully self-contained,
and responsive (the table scrolls horizontally inside its own container, the page body
never does). Pick one favicon emoji for the run and keep it stable across redeploys.

## 6. Delegate

For each microtask, pick the cheapest tool that fits:

- Read-only research/investigation → `Explore` agent
- Design/architecture questions → `Plan` agent
- Implementation → do it directly, or `general-purpose` if it's cleanly isolable
- Standalone multi-step work worth tracking on its own → hand off via `/devos-task open`
- Multi-agent fan-out (`Workflow`) — only if the user explicitly invokes that in the same
  turn. This skill never self-escalates into `Workflow` on its own.

## 7. Update the dashboard as work reports back

As each microtask's delegated work completes, update its row
(`pending → in-progress → done/blocked`) with its verification result, and redeploy the
`Artifact` to the **same file path** so the URL stays the same. Never create a second
artifact for the same run.

## 8. Synthesize, don't relay

The chat reply is a 2-3 sentence merged status against the original goal, plus a link to
the dashboard. Do not paste raw subagent transcripts into chat.

## 9. Verification still applies

A microtask row only moves to `done` once its deterministic verification has actually
run and passed, per the global verification rules. No row goes to `done` on confidence
alone.

Never write credentials, `.env` values, access tokens, or raw sensitive output into the
dashboard. This skill does not commit or push at any point.
