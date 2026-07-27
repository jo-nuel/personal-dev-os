# Candidate: routing one prompt across model tiers hits per-model API constraints that fail silently

- **Date:** 2026-07-27
- **Source:** personal-dev-os, task "Model routing + cost optimization" (agent/routing.py)
- **Proposed destination:** brain/playbooks/claude-api-model-tier-routing.md
- **Verified how:** Encountered while building a trivial/standard/hard tier router.
  Model IDs, parameter support, and cache minimums were checked against the `claude-api`
  skill's current model tables rather than recalled; the `stop_reason` gap was found by
  a review pass and fixed with tests.

## The lesson

A tier router sends the *same* request shape to different models, and the models do not
accept the same request shape. Three constraints, none of which raise a loud error:

1. **`output_config.effort` errors on Haiku 4.5.** Applying one effort setting uniformly
   across tiers 400s exactly the cheap tier the router exists to use. Don't send it, or
   send it per-tier.
2. **Prompt-cache minimums differ per model** — 512 tokens on Opus 5, 1024 on Sonnet 5,
   4096 on Haiku 4.5. Below the threshold, `cache_control` is a **silent no-op**: no
   error, `cache_creation_input_tokens` just stays 0. Also, caches are per-model, so
   routing across N tiers creates N cache entries each paying its own write — routing
   and caching work against each other.
3. **Thinking defaults differ.** Omitting `thinking` runs adaptive on Opus 5 and Sonnet
   5, but ran *without* thinking on Opus 4.8. Since `max_tokens` caps thinking and
   response text together, a tier whose default flipped can truncate mid-answer on a
   budget that used to be ample.

The cross-cutting rule: **surface `stop_reason` on any wrapper that returns text.** A
safety refusal returns empty content and a `max_tokens` truncation returns a clipped
string; neither is distinguishable from a genuinely short answer without it. Sonnet 5
and Opus 5 both run safety classifiers, so this is reachable on ordinary work.

## Evidence

Building `agent/routing.py` produced all three. The `stop_reason` omission was a real
defect caught in review and fixed with three regression tests. Verify each fact against
the `claude-api` skill's current tables rather than from memory — the per-model values
change between releases.

<!-- Ineligible: unverified conclusions, ASSUMPTION-tagged notes, secrets, conversation logs. -->
<!-- Only Jonathan moves candidates out of inbox (accept / merge / reject). -->
