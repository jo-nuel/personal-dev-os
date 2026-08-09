# A model-tier router silently misbehaves: 400s on the cheap tier, caching that never caches, answers that stop early

- **Applies to:** Any code sending the same request shape to more than one Claude model (tier routers, fallback chains, cost optimizers)
- **Last verified:** 2026-07-27
- **Source:** personal-dev-os, task "Model routing + cost optimization" (`agent/routing.py`)

## Symptom

A router that works on one tier misbehaves on another, and mostly without errors:

- the cheapest tier 400s while the expensive ones succeed;
- `cache_control` is set correctly but nothing is ever cached — no error, just no savings;
- a response stops mid-answer on a `max_tokens` budget that used to be ample;
- a call returns empty or clipped text that reads like a genuinely short answer.

## Cause

A tier router sends the *same* request shape to different models, and the models do not
accept the same request shape. The failures are quiet because none of them raise.

## Fix

The durable rules — these hold regardless of which models are current:

- **Check per-model parameter support before sending a parameter uniformly.** Applying one
  setting across all tiers can 400 exactly the cheap tier the router exists to use. Send
  it per-tier, or not at all.
- **Below its minimum, `cache_control` is a silent no-op.** No error is raised;
  `cache_creation_input_tokens` simply stays 0. Assert on that field rather than assuming
  a cache write happened.
- **Caches are per-model, so routing and caching work against each other.** Routing across
  N tiers creates N cache entries, each paying its own write. Weigh the routing saving
  against the caching saving; they are not additive.
- **`max_tokens` caps thinking and response text together.** A model whose thinking
  default differs from the one you tested on can truncate on a budget that was previously
  ample.
- **Surface `stop_reason` on any wrapper that returns text.** A safety refusal returns
  empty content and a `max_tokens` truncation returns a clipped string; neither is
  distinguishable from a short answer without it. Frontier models run safety classifiers,
  so this is reachable on ordinary work, not just adversarial input.

## Per-model values — snapshot as of 2026-07-27, RE-VERIFY BEFORE USE

These change between releases. Read the current values from the `claude-api` skill's model
tables; do not use the numbers below as fact, and do not answer from memory.

| Constraint | Value at time of writing |
|---|---|
| `output_config.effort` | errored on Haiku 4.5 |
| Prompt-cache minimum | 512 tokens Opus 5 · 1024 Sonnet 5 · 4096 Haiku 4.5 |
| `thinking` when omitted | adaptive on Opus 5 and Sonnet 5; *off* on Opus 4.8 |

## Verification

All three constraints surfaced while building `agent/routing.py`. Model IDs, parameter
support, and cache minimums were checked against the `claude-api` skill's tables rather
than recalled. The `stop_reason` omission was a real defect caught in a review pass and
fixed with three regression tests, which still run under `scripts/verify.ps1`.

<!-- Only verified fixes enter playbooks. If the cause was never confirmed, it stays in inbox. -->
