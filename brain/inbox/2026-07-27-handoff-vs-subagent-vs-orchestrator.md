# Candidate: handoff, subagent, and orchestrator are three different things — conflating them produces false "done" status

- **Date:** 2026-07-27
- **Source:** personal-dev-os, task "Adopt agent-orchestration model into devos-operate"
- **Proposed destination:** brain/standards/agent-orchestration.md
- **Verified how:** The distinction is documented in Burke Holland's orchestration
  material and Microsoft's orchestrator/subagent pattern page. Applying it to
  `devos-operate` exposed a concrete pre-existing defect: the skill listed
  `/devos-task open` in the same flat enumeration as `Explore` and `Plan`, and its
  status flow allowed every row to reach `done` — so a handed-off microtask would be
  reported complete by a run that had no way to verify it. Fixed in the same change.

## The lesson

Three delegation shapes get used interchangeably and should not be:

| Shape | Context | Control | Terminal status |
|---|---|---|---|
| **Subagent** | Isolated; parent's context stays clean | Spawned, reports back, parent resumes | `done` after verification |
| **Handoff** | Carries over; the conversation moves | Transfers permanently to the receiver | `handed off` — never `done` |
| **Orchestrator** | Coordinator stays deliberately thin | Decomposes and delegates, executes nothing | n/a |

The practical consequence is a status-reporting rule: **an orchestrator may only mark
a row `done` for work it can verify.** Handed-off work leaves its verification
obligation with the receiver, so the orchestrating run must terminate that row at
`handed off`. Resolving it to `done` claims a check that never happened.

Two supporting rules that follow from the same model:

- **Parallelism is decided by file overlap, not by judgement.** Two units of work may
  run concurrently when their file scopes are disjoint and neither needs the other's
  output; anything else is sequenced. Concurrent edits to one file lose writes silently
  and no verification catches it, because each agent sees its own write succeed.
- **Delegate outcomes, not methods.** A coordinator that has not read the files is not
  positioned to choose an approach, and current models follow instructions literally —
  so a prescribed method overrides a better fix the specialist can see.

## Evidence

Applying the taxonomy to `claude/skills/devos-operate/SKILL.md` found the flat tool list
and the unconditional `done` path described above. Both were real defects reachable in
normal use, not hypothetical.

<!-- Ineligible: unverified conclusions, ASSUMPTION-tagged notes, secrets, conversation logs. -->
<!-- Only Jonathan moves candidates out of inbox (accept / merge / reject). -->
