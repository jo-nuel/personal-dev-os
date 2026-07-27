# ADR-0004: devos-operate coordinates but does not implement

- **Date:** 2026-07-27
- **Status:** accepted
- **Category:** architecture

## Context

`/devos-operate` had the shape of an orchestrator — decompose, delegate, track, verify —
but three gaps that only surface under load. It said nothing about which microtasks may
run concurrently, so everything implicitly serialized. It had no rule preventing two
subagents from editing the same file. And it listed `/devos-task open` in the same flat
enumeration as `Explore` and `Plan`, which are categorically different: the first
transfers control permanently, the others report back.

That last conflation was not cosmetic. The status flow let every row reach `done`, so a
handed-off microtask would be reported complete by a run that never saw it finish and
could not verify it.

## Decision

1. **Microtasks declare a file scope, and phases are derived from it.** Two microtasks
   share a phase only when their scopes are disjoint and neither needs the other's
   output. Phases run in order; within a phase all delegations go out in one message and
   run concurrently. Overlapping scope forces sequencing — never parallel edits to one
   file.
2. **Delegation is typed as `subagent` or `handoff`.** Subagent rows reach `done` after
   verification. Handoff rows terminate at `handed off` and never reach `done`, because
   the verification obligation moved with the work.
3. **The orchestrator does not open implementation files.** It holds the goal, the plan,
   and the status table. Everything needing file contents is delegated, including small
   edits. The narrow state read in step 1 (`STATUS.md`, task files) is the only
   exception.
4. **Delegations state outcomes, not methods.**

## Alternatives considered

- **Keeping "implementation → do it directly" for small edits** — cheaper per run and
  consistent with the EAD "cheapest tool" principle. Rejected because the cost is paid
  in the wrong currency: once the coordinator's context fills with source, it degrades
  at coordination, which is the only thing it does. Tiny goals already return at step 3
  before decomposition, so the genuinely small cases never reach this path.
- **"Don't implement" as a bare instruction** — rejected in favour of the narrower,
  checkable rule about not reading implementation files. It states its own reason and
  makes the outcomes-not-methods rule structural: a run that has not read the file
  cannot specify a method.
- **Inferring parallelism from judgement** rather than file overlap — rejected as
  non-deterministic. The overlap test gives the same answer every run.
- **An explicit "do not orchestrate this" test** for goals with strong sequential
  dependencies (per Microsoft's guidance, which describes DevOS's high-risk category
  closely). Deferred: the existing step-2 approval gate already stops that work before
  delegation, so a second test would be redundant today.

## Consequences

More subagent spawns per run, so orchestrated goals get slower and more expensive. That
is the deliberate trade for a coordinator that stays coherent across a long run, and it
does not touch tiny goals.

Every microtask must now have a nameable file scope. Where one cannot be named, the
microtask is underspecified — the skill directs an `Explore` first rather than guessing,
which adds a step to vaguer goals.

Dashboard rows can end in a state that is not `done` and not a failure. Anything reading
the dashboard must treat `handed off` as terminal-and-fine, not as incomplete.

Verification of this change is limited: `devos-operate` is a Markdown skill with no test
to run. The checks available are `sync.ps1 -WhatIf`, `scripts/verify.ps1`, and a
deliberate internal-consistency pass — the latter caught two real contradictions in this
change (step 7's status flow and step 9's `done` rule, both written before `handed off`
existed).

<!-- ADRs are append-only. Never edit an accepted ADR; write a new one that supersedes it. -->
