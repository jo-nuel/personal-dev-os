# ADR-0003: Model routing agent — Python component, classify-per-task, explicit batch flag

- **Date:** 2026-07-18
- **Status:** accepted
- **Category:** architecture

## Context

DevOS needed model routing and cost optimization for agent tasks: a Haiku
classifier labelling work trivial/standard/hard, a tier→model map, a
prompt-cached shared system prompt, and a Batch API path for non-interactive
work.

Three forces shaped the design. First, personal-dev-os contained **no Python
and no API-calling code at all** before this change (167 Markdown, 6 JSON, 5
PowerShell files) — there was no existing "dev agent" to extend, so this is a
new component rather than a modification. Second, the real Claude call sites in
the wider portfolio (`skipbin`'s `ClaudeDispatcher` and `ClaudeVisionProvider`)
already encode difficulty as a per-provider class constant, which is free;
runtime classification is strictly more expensive than what those sites do
today. Third, several Claude API constraints make the naive implementation
silently wrong rather than loudly broken.

## Decision

1. **Python enters the repo as a top-level `agent/` package**, managed by `uv`
   with a root `pyproject.toml`. PowerShell remains the language for hooks and
   installer scripts; Python is confined to API-calling agent code.
2. **Classification runs on every task by default**, per Jonathan's explicit
   direction, accepting one extra Haiku round-trip (~300–800ms) per task. A
   `tier=` override skips it when the caller already knows the difficulty, so
   the cost is opt-out rather than mandatory.
3. **Classifier failures degrade to `standard`**, never raise. An API error or
   an unrecognized label both fall back to the middle tier, mirroring the
   `skipbin` providers' "never propagate" convention.
4. **Batch routing is an explicit `interactive=False` flag, not inferred from
   task text.** Misclassifying a user-facing request as batch work would put it
   in a queue for up to 24 hours; that failure is far worse than the
   convenience of sniffing.
5. **`output_config.effort` is never sent.** It errors on Haiku 4.5, which is
   both the classifier model and the trivial tier.
6. **Model IDs:** trivial → `claude-haiku-4-5-20251001`, standard →
   `claude-sonnet-5`, hard → `claude-opus-5`. The hard tier was specified as
   Opus 4.8; it was moved to Opus 5 before landing because the two are priced
   identically ($5/$25 per MTok), so the capability upgrade is free.

## Alternatives considered

- **Static tier per call site, no classifier** — cheaper and lower-latency, and
  it is what `skipbin` effectively does today. Rejected because it cannot route
  tasks whose difficulty is unknown until runtime, which is the case this
  module exists to serve.
- **Sniffing "nightly digest"/"summary" from task text to pick the batch path**
  — rejected as above; the cost of a false positive is a 24-hour delay on
  something a human is waiting for.
- **Opus 4.8 for the hard tier** — the originally specified model. Superseded
  by Opus 5 before landing (same price, higher capability). Opus 4.8 remains a
  valid pin if the hard tier's thinking-by-default behavior proves undesirable.
- **Structured outputs for the classifier** — would guarantee a valid label
  instead of normalizing a string. Rejected as disproportionate for a
  three-value enum with a safe fallback already in place.

## Consequences

**Routing fragments the prompt cache.** Caches are per-model, so a shared
system prompt spread across three tiers creates three cache entries, each
paying its own write. Routing and caching pull against each other; the more
evenly traffic spreads across tiers, the less caching returns.

**The hard tier now thinks by default.** Opus 5 runs adaptive thinking when the
`thinking` parameter is omitted, where Opus 4.8 ran without it. `max_tokens`
caps thinking and response text together, so a hard task can consume budget
reasoning before producing output. `TaskResult.complete` surfaces the resulting
`max_tokens` stop; raise `max_tokens` on that tier if truncation shows up.

**The cached system prompt is likely a no-op at current size.** The minimum
cacheable prefix is 512 tokens on Opus 5, 1024 on Sonnet 5, and 4096 on Haiku
4.5. `SYSTEM_PROMPT` is well under all three. Under-minimum prompts cache silently —
no error, `cache_creation_input_tokens` simply stays 0. `TaskResult.usage`
surfaces the cache counters so this is observable rather than assumed; the
`cache_control` marker is in place so caching begins working if the prompt
grows, without a code change.

**`run_task()` has two shapes of return.** Live calls populate `text`; batch
submissions populate `batch_id` and leave `text` as `None`. Callers must branch
on `TaskResult.queued`. This is inherent to the Batch API being asynchronous.

**Verification is mock-only.** The test suite runs with no API key and no
network, and payload shapes are checked against the installed SDK's TypedDicts,
but no request has ever been sent — this machine has no credential configured.
The first real call is unproven.

Revisit if: per-task classifier latency proves material in practice, the shared
prompt grows past the cache minimum (re-measure the cache counters then), or
the hard tier moves to Opus 5.

<!-- ADRs are append-only. Never edit an accepted ADR; write a new one that supersedes it. -->
