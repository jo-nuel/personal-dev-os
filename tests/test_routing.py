"""Routing tests. Fully mocked — no API key, no network."""

from types import SimpleNamespace
from unittest.mock import MagicMock

import anthropic
import pytest

from agent import routing


def _text_response(text: str, stop_reason: str = "end_turn", **usage: int):
    """Mimic a Message: content blocks with .type/.text, plus .usage."""
    return SimpleNamespace(
        content=[SimpleNamespace(type="text", text=text)],
        stop_reason=stop_reason,
        usage=SimpleNamespace(
            input_tokens=usage.get("input_tokens", 0),
            output_tokens=usage.get("output_tokens", 0),
            cache_creation_input_tokens=usage.get("cache_creation_input_tokens", 0),
            cache_read_input_tokens=usage.get("cache_read_input_tokens", 0),
        ),
    )


@pytest.fixture
def client(monkeypatch):
    """Patch the lazy client factory so no real credential is ever needed."""
    fake = MagicMock()
    monkeypatch.setattr(routing, "_get_client", lambda: fake)
    return fake


# --- model map ------------------------------------------------------------


def test_model_map_matches_spec():
    assert routing.MODEL_MAP == {
        "trivial": "claude-haiku-4-5-20251001",
        "standard": "claude-sonnet-5",
        "hard": "claude-opus-5",
    }


# --- classify_task --------------------------------------------------------


@pytest.mark.parametrize("label", ["trivial", "standard", "hard"])
def test_classify_returns_each_label(client, label):
    client.messages.create.return_value = _text_response(label)
    assert routing.classify_task("do a thing") == label


def test_classify_normalizes_whitespace_and_case(client):
    client.messages.create.return_value = _text_response("  HARD\n")
    assert routing.classify_task("migrate the database") == "hard"


def test_classify_falls_back_to_standard_on_junk(client):
    client.messages.create.return_value = _text_response("difficulty: medium-ish")
    assert routing.classify_task("something") == "standard"


def test_classify_falls_back_to_standard_on_api_error(client):
    client.messages.create.side_effect = anthropic.APIError(
        message="boom", request=MagicMock(), body=None
    )
    assert routing.classify_task("something") == "standard"


def test_classify_uses_haiku_and_never_sends_effort(client):
    """`output_config.effort` errors on Haiku 4.5 — it must not be sent."""
    client.messages.create.return_value = _text_response("trivial")
    routing.classify_task("rename a variable")

    _, kwargs = client.messages.create.call_args
    assert kwargs["model"] == "claude-haiku-4-5-20251001"
    assert "output_config" not in kwargs
    assert kwargs["max_tokens"] == 16


# --- run_task: live path --------------------------------------------------


def test_run_task_routes_classified_tier_to_its_model(client):
    client.messages.create.side_effect = [
        _text_response("hard"),  # classifier
        _text_response("answer"),  # the task itself
    ]
    result = routing.run_task("redesign auth")

    assert result.tier == "hard"
    assert result.model == "claude-opus-5"
    assert result.text == "answer"
    assert result.queued is False

    _, kwargs = client.messages.create.call_args
    assert kwargs["model"] == "claude-opus-5"


def test_explicit_tier_skips_the_classifier(client):
    client.messages.create.return_value = _text_response("answer")
    result = routing.run_task("tiny fix", tier="trivial")

    assert result.model == "claude-haiku-4-5-20251001"
    assert client.messages.create.call_count == 1  # no classifier round-trip


def test_system_prompt_is_marked_cacheable(client):
    client.messages.create.return_value = _text_response("answer")
    routing.run_task("do it", tier="standard")

    _, kwargs = client.messages.create.call_args
    block = kwargs["system"][0]
    assert block["cache_control"] == {"type": "ephemeral"}
    assert block["text"] == routing.SYSTEM_PROMPT


def test_system_prompt_carries_no_per_request_text(client):
    """Any task-specific byte in the cached prefix would invalidate the entry."""
    client.messages.create.return_value = _text_response("answer")
    routing.run_task("UNIQUE-TASK-MARKER", tier="standard")

    _, kwargs = client.messages.create.call_args
    assert "UNIQUE-TASK-MARKER" not in kwargs["system"][0]["text"]
    assert kwargs["messages"][0]["content"] == "UNIQUE-TASK-MARKER"


def test_refusal_is_visible_not_silently_empty(client):
    """A safety refusal returns no text; the caller must be able to tell."""
    client.messages.create.return_value = SimpleNamespace(
        content=[], stop_reason="refusal", usage=SimpleNamespace()
    )
    result = routing.run_task("something disallowed", tier="standard")

    assert result.text == ""
    assert result.stop_reason == "refusal"
    assert result.complete is False


def test_truncated_output_is_visible(client):
    client.messages.create.return_value = _text_response(
        "half an ans", stop_reason="max_tokens"
    )
    result = routing.run_task("write a book", tier="hard")

    assert result.complete is False
    assert result.stop_reason == "max_tokens"


def test_normal_completion_is_complete(client):
    client.messages.create.return_value = _text_response("done")
    assert routing.run_task("x", tier="standard").complete is True


def test_usage_surfaces_cache_counters(client):
    client.messages.create.return_value = _text_response(
        "answer", input_tokens=10, cache_read_input_tokens=900
    )
    result = routing.run_task("do it", tier="standard")

    assert result.usage["cache_read_input_tokens"] == 900
    assert result.usage["input_tokens"] == 10


# --- run_task: batch path -------------------------------------------------


def test_non_interactive_goes_to_batch_not_live(client):
    client.messages.create.return_value = _text_response("classifier-unused")
    client.messages.batches.create.return_value = SimpleNamespace(id="msgbatch_123")

    result = routing.run_task("nightly digest", interactive=False, tier="trivial")

    assert result.queued is True
    assert result.batch_id == "msgbatch_123"
    assert result.text is None
    client.messages.create.assert_not_called()


def test_batch_request_carries_model_and_cached_system(client):
    client.messages.batches.create.return_value = SimpleNamespace(id="msgbatch_1")
    routing.run_task("summarize", interactive=False, tier="hard")

    _, kwargs = client.messages.batches.create.call_args
    params = kwargs["requests"][0]["params"]
    assert params["model"] == "claude-opus-5"
    assert params["system"][0]["cache_control"] == {"type": "ephemeral"}


def test_fetch_batch_returns_none_while_processing(client):
    client.messages.batches.retrieve.return_value = SimpleNamespace(
        processing_status="in_progress"
    )
    assert routing.fetch_batch("msgbatch_1") is None


def test_fetch_batch_keys_by_custom_id_and_skips_failures(client):
    client.messages.batches.retrieve.return_value = SimpleNamespace(
        processing_status="ended"
    )
    client.messages.batches.results.return_value = iter(
        [
            SimpleNamespace(
                custom_id="b",
                result=SimpleNamespace(
                    type="succeeded", message=_text_response("second")
                ),
            ),
            SimpleNamespace(
                custom_id="a",
                result=SimpleNamespace(
                    type="succeeded", message=_text_response("first")
                ),
            ),
            SimpleNamespace(custom_id="c", result=SimpleNamespace(type="errored")),
        ]
    )

    # Results arrive out of order; keying by custom_id must not depend on position.
    assert routing.fetch_batch("msgbatch_1") == {"a": "first", "b": "second"}
