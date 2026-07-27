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

Before splitting, triage each candidate piece with **Eliminate → Automate → Delegate**,
in that order: does it need doing at all (eliminate); can a deterministic script or
existing tool do it without a model (automate); only then decide who executes it
(delegate, per step 6). Eliminated pieces are named in the dashboard's big-picture line,
not silently dropped. Each surviving microtask also gets an explicit autonomy level —
**do-and-report** or **propose-and-wait** — recorded in its table row; high-risk items
are always propose-and-wait, per the gate in step 2.

### File scope and phases

Give every microtask a **file scope**: the files it may create or modify. If you cannot
name the scope, the microtask is not specified well enough to delegate — split it or
send an `Explore` first.

Group microtasks into **phases** using the file scopes:

- Two microtasks may share a phase when their scopes are **disjoint** and neither needs
  the other's output.
- Overlapping scope, or a data dependency, forces a later phase.

Phases run in order. Within a phase, issue every delegation in a **single message** so
they run concurrently. Never parallelize two microtasks that touch the same file —
concurrent edits to one file lose writes silently, and no verification step will catch
it because each subagent sees its own change succeed.

When scopes genuinely must overlap, pick one: sequence them into separate phases, or
give each agent a distinct subtree and a narrower scope.

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
   `devos-repo-brief` does, plus, when EAD triage eliminated any candidate pieces, a
   trailing one-line note of what was eliminated and why.
3. **Approval gates** — present only when high-risk items are awaiting plan approval.
   Make this visually prominent and first — it is the one thing that blocks progress, not
   a footnote in the table.
4. **Microtask table** — columns: phase, microtask, file scope, delegated-to (with its
   kind — see step 6: `subagent` or `handoff`), autonomy (do-and-report /
   propose-and-wait), status badge, verification result. Group rows by phase so the
   concurrent set is visible at a glance.
5. **Next recommended action** — one line, footer.

Status values are `pending`, `in-progress`, `done`, `blocked`, and `handed off`. A
handoff row ends at `handed off` and never reaches `done` — see step 6.

Theme-aware (`prefers-color-scheme` plus a `data-theme` override), fully self-contained,
and responsive (the table scrolls horizontally inside its own container, the page body
never does). Pick one favicon emoji for the run and keep it stable across redeploys.

## 6. Delegate

Delegation comes in two kinds, and they are not interchangeable:

**Subagents** — spawned in an isolated context, do the work, report back; this run
continues and owns the result. Rows reach `done` normally.

- Read-only research/investigation → `Explore` agent
- Design/architecture questions → `Plan` agent
- Implementation → `general-purpose` agent

**Handoffs** — control transfers permanently. The receiving skill owns the work from
that point; this run does not see it finish and cannot verify it.

- Standalone multi-step work worth tracking on its own → `/devos-task open`
- Multi-agent fan-out → `Workflow`, only if the user explicitly invokes it in the same
  turn. This skill never self-escalates into `Workflow` on its own.

A handoff row terminates at `handed off`, never `done` — marking it `done` would be
claiming a verification this run never performed. Say what was handed over and to whom.

### Keep the orchestrator's context clean

Do not open implementation files. This run holds the goal, the plan, and the status
table — nothing else. Anything that needs file contents is delegated, including small
edits: a coordinator whose context has filled with source degrades at the one job it
has. The state read in step 1 (`STATUS.md`, task files) is the exception, and it is
deliberately narrow.

### Delegate outcomes, not methods

State what the microtask must achieve and the constraints it must respect; leave the
approach to the specialist that can actually see the code.

- ✅ "Fix the infinite loop when SideMenu re-renders. Files: `src/SideMenu.tsx`."
- ❌ "Fix it by wrapping the selector in `useShallow`."

This is not a style preference. Having not read the files, this run is not positioned to
choose a method — and current models follow an instruction literally, so a prescribed
approach overrides a better fix the specialist can see and you cannot.

## 7. Update the dashboard as work reports back

As each microtask's delegated work completes, update its row with its verification
result, and redeploy the `Artifact` to the **same file path** so the URL stays the same.
Never create a second artifact for the same run.

- Subagent rows: `pending → in-progress → done/blocked`.
- Handoff rows: `pending → handed off`, at the moment control transfers. That is
  terminal for this run.

Redeploy once per phase rather than once per row — a phase's delegations finish close
together, and one update per phase keeps the dashboard readable. Do not start the next
phase until the current one has reported, or the file-scope guarantee is void.

## 8. Synthesize, don't relay

The chat reply is a 2-3 sentence merged status against the original goal, plus a link to
the dashboard. Do not paste raw subagent transcripts into chat.

## 9. Verification still applies

A microtask row only moves to `done` once its deterministic verification has actually
run and passed, per the global verification rules. No row goes to `done` on confidence
alone.

Handoff rows are not an exception to this — they are outside it. They stop at
`handed off` precisely because this run cannot verify them; the receiving skill carries
the verification obligation. Never resolve a handoff row to `done` to make the table
look finished.

Never write credentials, `.env` values, access tokens, or raw sensitive output into the
dashboard. This skill does not commit or push at any point.
