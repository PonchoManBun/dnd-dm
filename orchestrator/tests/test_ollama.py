"""Tests for OllamaClient — all HTTP calls are mocked via httpx."""

from __future__ import annotations

from unittest.mock import AsyncMock, patch

import httpx
import pytest

from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaModelNotFoundError,
    OllamaTimeoutError,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def client() -> OllamaClient:
    """Return an OllamaClient with default settings."""
    return OllamaClient()


# ---------------------------------------------------------------------------
# health_check
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_health_check_success(client: OllamaClient) -> None:
    """health_check returns True when the model is in the tag list."""
    mock_response = httpx.Response(
        200,
        json={"models": [{"name": "llama3.2:3b"}, {"name": "mistral:7b"}]},
        request=httpx.Request("GET", "http://localhost:11434/api/tags"),
    )

    with patch.object(
        httpx.AsyncClient, "get", new_callable=AsyncMock, return_value=mock_response
    ):
        result = await client.health_check()

    assert result is True


@pytest.mark.asyncio
async def test_health_check_model_not_found(client: OllamaClient) -> None:
    """health_check returns False when the model is NOT in the tag list."""
    mock_response = httpx.Response(
        200,
        json={"models": [{"name": "mistral:7b"}]},
        request=httpx.Request("GET", "http://localhost:11434/api/tags"),
    )

    with patch.object(
        httpx.AsyncClient, "get", new_callable=AsyncMock, return_value=mock_response
    ):
        result = await client.health_check()

    assert result is False


@pytest.mark.asyncio
async def test_health_check_connection_error(client: OllamaClient) -> None:
    """health_check raises OllamaConnectionError when Ollama is unreachable."""
    with patch.object(
        httpx.AsyncClient,
        "get",
        new_callable=AsyncMock,
        side_effect=httpx.ConnectError("Connection refused"),
    ):
        with pytest.raises(OllamaConnectionError):
            await client.health_check()


# ---------------------------------------------------------------------------
# generate_response
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_generate_response_success(client: OllamaClient) -> None:
    """generate_response returns text from a successful /api/generate call."""
    mock_response = httpx.Response(
        200,
        json={"response": "You enter a dimly lit tavern."},
        request=httpx.Request("POST", "http://localhost:11434/api/generate"),
    )

    with patch.object(
        httpx.AsyncClient, "post", new_callable=AsyncMock, return_value=mock_response
    ):
        result = await client.generate_response("Describe the tavern.")

    assert result == "You enter a dimly lit tavern."


@pytest.mark.asyncio
async def test_generate_response_with_system_prompt(client: OllamaClient) -> None:
    """generate_response passes system_prompt through to the payload."""
    mock_response = httpx.Response(
        200,
        json={"response": "Welcome, adventurer."},
        request=httpx.Request("POST", "http://localhost:11434/api/generate"),
    )

    with patch.object(
        httpx.AsyncClient, "post", new_callable=AsyncMock, return_value=mock_response
    ) as mock_post:
        result = await client.generate_response(
            "Hello", system_prompt="You are a friendly innkeeper."
        )

    assert result == "Welcome, adventurer."
    # Verify the system prompt was included in the payload.
    call_kwargs = mock_post.call_args
    payload = call_kwargs.kwargs.get("json") or call_kwargs[1].get("json")
    assert payload["system"] == "You are a friendly innkeeper."


@pytest.mark.asyncio
async def test_generate_response_timeout(client: OllamaClient) -> None:
    """generate_response raises OllamaTimeoutError on timeout."""
    with patch.object(
        httpx.AsyncClient,
        "post",
        new_callable=AsyncMock,
        side_effect=httpx.TimeoutException("timed out"),
    ):
        with pytest.raises(OllamaTimeoutError):
            await client.generate_response("Tell me a story.")


@pytest.mark.asyncio
async def test_generate_response_connection_refused(client: OllamaClient) -> None:
    """generate_response raises OllamaConnectionError when Ollama is down."""
    with patch.object(
        httpx.AsyncClient,
        "post",
        new_callable=AsyncMock,
        side_effect=httpx.ConnectError("Connection refused"),
    ):
        with pytest.raises(OllamaConnectionError):
            await client.generate_response("Hello?")


@pytest.mark.asyncio
async def test_generate_response_model_not_found(client: OllamaClient) -> None:
    """generate_response raises OllamaModelNotFoundError on 404."""
    mock_response = httpx.Response(
        404,
        json={"error": "model not found"},
        request=httpx.Request("POST", "http://localhost:11434/api/generate"),
    )

    with patch.object(
        httpx.AsyncClient, "post", new_callable=AsyncMock, return_value=mock_response
    ):
        with pytest.raises(OllamaModelNotFoundError):
            await client.generate_response("Hello?")


# ---------------------------------------------------------------------------
# generate_chat
# ---------------------------------------------------------------------------

@pytest.mark.asyncio
async def test_generate_chat_success(client: OllamaClient) -> None:
    """generate_chat returns the assistant message content."""
    mock_response = httpx.Response(
        200,
        json={"message": {"role": "assistant", "content": "Roll for initiative!"}},
        request=httpx.Request("POST", "http://localhost:11434/api/chat"),
    )

    messages = [
        {"role": "system", "content": "You are a D&D Dungeon Master."},
        {"role": "user", "content": "I kick the door open."},
    ]

    with patch.object(
        httpx.AsyncClient, "post", new_callable=AsyncMock, return_value=mock_response
    ):
        result = await client.generate_chat(messages)

    assert result == "Roll for initiative!"


@pytest.mark.asyncio
async def test_generate_chat_timeout(client: OllamaClient) -> None:
    """generate_chat raises OllamaTimeoutError on timeout."""
    with patch.object(
        httpx.AsyncClient,
        "post",
        new_callable=AsyncMock,
        side_effect=httpx.TimeoutException("timed out"),
    ):
        with pytest.raises(OllamaTimeoutError):
            await client.generate_chat([{"role": "user", "content": "Hello"}])


# ---------------------------------------------------------------------------
# Token estimation helpers
# ---------------------------------------------------------------------------

def test_estimate_tokens_short(client: OllamaClient) -> None:
    """estimate_tokens returns a sensible value for short text."""
    # "Hello" = 5 chars → 5 // 4 = 1
    assert client.estimate_tokens("Hello") == 1


def test_estimate_tokens_longer(client: OllamaClient) -> None:
    """estimate_tokens returns ~25% of character count."""
    text = "The quick brown fox jumps over the lazy dog."  # 44 chars
    tokens = client.estimate_tokens(text)
    assert tokens == 11  # 44 // 4


def test_estimate_tokens_empty(client: OllamaClient) -> None:
    """estimate_tokens returns 1 for empty string (minimum)."""
    assert client.estimate_tokens("") == 1


def test_is_within_budget_true(client: OllamaClient) -> None:
    """is_within_budget returns True when text fits."""
    # 20 chars → ~5 tokens, budget=10 → fits
    assert client.is_within_budget("A" * 20, budget=10) is True


def test_is_within_budget_false(client: OllamaClient) -> None:
    """is_within_budget returns False when text exceeds budget."""
    # 100 chars → ~25 tokens, budget=10 → does not fit
    assert client.is_within_budget("A" * 100, budget=10) is False


def test_is_within_budget_exact(client: OllamaClient) -> None:
    """is_within_budget returns True when tokens exactly equal budget."""
    # 40 chars → 10 tokens, budget=10 → exactly fits
    assert client.is_within_budget("A" * 40, budget=10) is True
