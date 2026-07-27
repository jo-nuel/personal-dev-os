"""Task classification and model routing for DevOS agent work.

Flow: `run_task()` classifies the task with Haiku, maps the label to a model,
then either makes a live call (interactive) or queues a Batch API request
(non-interactive, 50% cheaper, results within 24h).

The shared system prompt is marked cacheable so repeat calls to the *same*
model read it at ~0.1x instead of paying full input price.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

import anthropic

Tier = Literal["trivial", "standard", "hard"]

# Difficulty tier -> model. Haiku's ID carries its date suffix; the Sonnet and
# Opus IDs are complete as-is and must not have one appended.
#
# Opus 5 runs adaptive thinking by *default* (unlike Opus 4.8, where omitting
# the `thinking` param meant no thinking). `max_tokens` caps thinking and
# response text together, so a hard task can spend budget reasoning before it
# writes anything — check `TaskResult.complete` for a `max_tokens` stop.
MODEL_MAP: dict[Tier, str] = {
    "trivial": "claude-haiku-4-5-20251001",
    "standard": "claude-sonnet-5",
    "hard": "claude-opus-5",
}

CLASSIFIER_MODEL = "claude-haiku-4-5-20251001"

# Fixed across every task, so it sits at the front of the prefix and is the
# only thing worth caching. Keep task-specific text out of it — prompt caching
# is a prefix match, and any per-request byte here would invalidate the entry.
SYSTEM_PROMPT = (
    "You are a development assistant operating inside DevOS, a personal "
    "engineering environment on Windows 11 (PowerShell 5.1 primary, Git Bash "
    "available). Projects live under C:\\Users\\Jonathan\\Projects and span "
    "Next.js/TypeScript, Python/Django, and scripting work — assume no default "
    "stack.\n\n"
    "Answer the task directly and concretely. Prefer a working answer over an "
    "exhaustive survey of options. State assumptions explicitly rather than "
    "asking a clarifying question you could reasonably resolve yourself. If a "
    "step is genuinely blocked, say what is blocked and why instead of "
    "silently narrowing scope."
)

_CLASSIFIER_SYSTEM = (
    "Classify the difficulty of a software development task.\n\n"
    "Reply with exactly one lowercase word and nothing else:\n"
    "trivial  - a rename, typo, small doc tweak, one-line fix, or lookup\n"
    "standard - ordinary feature work, a normal bug fix, a focused refactor\n"
    "hard     - architecture, migrations, tricky debugging, security-sensitive "
    "or cross-cutting changes\n\n"
    "Answer with only the word."
)

_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    """Lazily build the SDK client.

    Constructing `Anthropic()` raises when no credential is resolvable, so this
    is deferred rather than done at import — otherwise the module could not be
    imported (or tested) without a key on the machine.
    """
    global _client
    if _client is None:
        _client = anthropic.Anthropic()
    return _client


@dataclass
class TaskResult:
    """Outcome of a routed task.

    Live calls populate `text`. Batch submissions populate `batch_id` and leave
    `text` as None — the Batch API is asynchronous, so there is no result to
    return yet. Callers must check which one they got.
    """

    tier: Tier
    model: str
    text: str | None = None
    batch_id: str | None = None
    stop_reason: str | None = None
    usage: dict[str, int] = field(default_factory=dict)

    @property
    def queued(self) -> bool:
        return self.batch_id is not None

    @property
    def complete(self) -> bool:
        """False when the model refused or the output was cut off.

        A refusal yields empty `text` and a truncation yields a silently
        clipped string; neither is distinguishable from a genuinely short
        answer without checking `stop_reason`. Sonnet 5 and Opus 5 both run
        safety classifiers that can decline a request, so this is reachable on
        two of the three tiers. Opus 5 also thinks by default, which makes a
        `max_tokens` stop more likely on the hard tier.
        """
        return self.stop_reason not in ("refusal", "max_tokens")


def classify_task(task: str) -> Tier:
    """Label a task trivial / standard / hard using Haiku.

    Costs one extra round-trip per task. Any failure — API error, or a reply
    that is not one of the three labels — falls back to "standard" so work
    still proceeds on a mid-tier model rather than raising.

    Note: `output_config.effort` is deliberately not sent. It errors on
    Haiku 4.5.
    """
    try:
        response = _get_client().messages.create(
            model=CLASSIFIER_MODEL,
            max_tokens=16,
            system=_CLASSIFIER_SYSTEM,
            messages=[{"role": "user", "content": task}],
        )
    except anthropic.APIError:
        return "standard"

    label = "".join(
        block.text for block in response.content if getattr(block, "type", "") == "text"
    ).strip().lower()

    return label if label in MODEL_MAP else "standard"


def _system_blocks() -> list[dict]:
    """Shared system prompt, marked cacheable.

    Two caveats worth knowing, neither of which raises an error:

    1. Minimum cacheable prefix differs per model: 512 tokens on Opus 5, 1024
       on Sonnet 5, and 4096 on Haiku 4.5. A prompt under the threshold caches
       silently as a no-op — `usage.cache_creation_input_tokens` stays 0, with
       no error. The hard tier is therefore the first place caching will start
       working as this prompt grows.
    2. Caches are per-model. Routing across three tiers means three separate
       cache entries, each paying its own write.
    """
    return [
        {
            "type": "text",
            "text": SYSTEM_PROMPT,
            "cache_control": {"type": "ephemeral"},
        }
    ]


def run_task(
    task: str,
    *,
    interactive: bool = True,
    max_tokens: int = 16000,
    tier: Tier | None = None,
) -> TaskResult:
    """Classify a task, pick the model, and dispatch it.

    Args:
        task: The task text.
        interactive: False routes through the Batch API (50% cheaper, async,
            up to 24h). Pass False for nightly digests, batch summaries, and
            anything else with no one waiting on the reply. This is an explicit
            flag rather than sniffed from the task text — guessing wrong sends
            a user-facing request into a 24-hour queue.
        max_tokens: Output cap. Non-streaming, so kept under the SDK's HTTP
            timeout ceiling.
        tier: Skip classification and force a tier. Saves the classifier
            round-trip when the caller already knows the difficulty.

    Returns:
        TaskResult with `text` set (live) or `batch_id` set (queued).
    """
    resolved: Tier = tier if tier is not None else classify_task(task)
    model = MODEL_MAP[resolved]

    if not interactive:
        batch = _get_client().messages.batches.create(
            requests=[
                {
                    "custom_id": "task-1",
                    "params": {
                        "model": model,
                        "max_tokens": max_tokens,
                        "system": _system_blocks(),
                        "messages": [{"role": "user", "content": task}],
                    },
                }
            ]
        )
        return TaskResult(tier=resolved, model=model, batch_id=batch.id)

    response = _get_client().messages.create(
        model=model,
        max_tokens=max_tokens,
        system=_system_blocks(),
        messages=[{"role": "user", "content": task}],
    )
    text = "".join(
        block.text for block in response.content if getattr(block, "type", "") == "text"
    )
    usage = response.usage
    return TaskResult(
        tier=resolved,
        model=model,
        text=text,
        stop_reason=getattr(response, "stop_reason", None),
        usage={
            "input_tokens": getattr(usage, "input_tokens", 0),
            "output_tokens": getattr(usage, "output_tokens", 0),
            "cache_creation_input_tokens": getattr(
                usage, "cache_creation_input_tokens", 0
            ),
            "cache_read_input_tokens": getattr(usage, "cache_read_input_tokens", 0),
        },
    )


def fetch_batch(batch_id: str) -> dict[str, str] | None:
    """Collect a queued batch's results, or None if it is still processing.

    Results come back in arbitrary order, so they are keyed by `custom_id`
    rather than by position.
    """
    client = _get_client()
    if client.messages.batches.retrieve(batch_id).processing_status != "ended":
        return None

    out: dict[str, str] = {}
    for entry in client.messages.batches.results(batch_id):
        if entry.result.type != "succeeded":
            continue
        out[entry.custom_id] = "".join(
            block.text
            for block in entry.result.message.content
            if getattr(block, "type", "") == "text"
        )
    return out
