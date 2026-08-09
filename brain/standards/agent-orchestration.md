# Delegation shapes: subagent, handoff, orchestrator

- **Adopted:** 2026-07-27
- **Source:** personal-dev-os, task "Adopt agent-orchestration model into devos-operate"
- **Basis:** Taxonomy taken from Burke Holland's orchestration material and Microsoft's
  orchestrator/subagent pattern page — adopted as a convention, not independently
  derived. What was verified is the payoff: applying it to `devos-operate` exposed two
  real pre-existing defects (see Evidence).

Applies to any repo where work is delegated to another agent or tool. The mechanics of
how `devos-operate` implements this live in that repo's
`docs/decisions/2026-07-27-orchestration-model.md`, not here.

## The three shapes

Three delegation shapes get used interchangeably and should not be:

| Shape | Context | Control | Terminal status |
|---|---|---|---|
| **Subagent** | Isolated; parent's context stays clean | Spawned, reports back, parent resumes | `done` after verification |
| **Handoff** | Carries over; the conversation moves | Transfers permanently to the receiver | `handed off` — never `done` |
| **Orchestrator** | Coordinator stays deliberately thin | Decomposes and delegates, executes nothing | n/a |

## The rules that follow

**Only mark work `done` if you can verify it.** Handed-off work leaves its verification
obligation with the receiver, so the delegating run terminates that item at `handed off`.
Resolving it to `done` claims a check that never happened. `handed off` is a terminal
state and not a failure — anything reading a status summary must treat it as such.

**Parallelism is decided by file overlap, not by judgement.** Two units of work may run
concurrently when their file scopes are disjoint and neither needs the other's output;
anything else is sequenced. Concurrent edits to one file lose writes silently and no
verification catches it, because each agent sees its own write succeed.

**Delegate outcomes, not methods.** A coordinator that has not read the files is not
positioned to choose an approach, and models follow instructions literally — so a
prescribed method overrides a better fix the specialist can see.

**A subagent cannot see the delegating conversation.** Work that depends on the running
discussion has to be done in place or escalated by hand; it cannot be delegated, however
well it otherwise fits a subagent.

## Evidence

Applying the taxonomy to `claude/skills/devos-operate/SKILL.md` found two defects
reachable in normal use, not hypothetical: `/devos-task open` was listed in the same flat
enumeration as `Explore` and `Plan` — conflating a permanent transfer of control with a
report-back — and the status flow allowed every row to reach `done`, so a handed-off
microtask would be reported complete by a run that had no way to verify it. Both were
fixed in the same change.
