# Manual-only skills (`disable-model-invocation: true`) must be replicated by hand when a task calls for them

- **Source:** Startup repo, tasks "Prepare Startup repository for DevOS workflow" (M4A)
  and "Establish a minimal automated test foundation" (M4B), 2026-07-04
- **Verified how:** Encountered independently with three different skills
  (`devos-repo-brief` in M4A, `devos-decision` in M4B, `devos-promote` on 2026-07-07).
  Each attempt to invoke via the Skill tool failed with an explicit rejection citing
  `disable-model-invocation` — a deliberate structural restriction, not a runtime bug.

## The rule

A skill with `disable-model-invocation: true` can only be triggered by the user typing
the slash command — Claude cannot invoke it via the Skill tool under any circumstance,
even when a task's own written plan lists running it as a step.

When this blocks a task step, the accepted resolution (confirmed by Jonathan in the M4A
task) is:

1. Read the skill's own `SKILL.md` to learn its exact spec.
2. Manually perform the same steps by hand (same duplicate checks, same file-naming and
   template conventions, same guardrails).
3. Clearly flag in the task's working notes and final report that this substitution
   happened and why.

Do not silently skip the step, and do not repeatedly re-ask permission for the same
category of substitution within one session once the pattern has been approved.
