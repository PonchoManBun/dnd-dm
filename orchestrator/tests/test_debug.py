"""Tests for the debug dashboard: DebugLogger, /debug/history, /debug/stats."""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import ASGITransport, AsyncClient

from orchestrator.main import app
from orchestrator.engine.debug_logger import (
    DebugLogger,
    DebugEntry,
    estimate_tokens,
    get_debug_logger,
    set_debug_logger,
)
from orchestrator.routes.action import set_game_state, set_ollama_client
from orchestrator.models import GameState
from orchestrator.engine.ollama_client import OllamaClient, OllamaConnectionError


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_debug_logger():
    """Ensure each test gets a fresh DebugLogger."""
    set_debug_logger(DebugLogger())
    yield
    set_debug_logger(None)


@pytest.fixture(autouse=True)
def reset_global_state():
    """Reset action route globals."""
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]
    yield
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]


@pytest.fixture
def fresh_state() -> GameState:
    """Create and install a fresh GameState."""
    state = GameState()
    state.character.name = "Aldric"
    state.location.location_name = "The Welcome Wench"
    set_game_state(state)
    return state


@pytest.fixture
def mock_ollama() -> OllamaClient:
    """Mock OllamaClient with a canned response."""
    client = MagicMock(spec=OllamaClient)
    client.generate_chat = AsyncMock(
        return_value=(
            "NARRATION: The fire crackles softly.\n"
            "CHOICES:\n"
            "1. Sit down\n"
            "2. Leave\n"
            "3. Talk\n"
        )
    )
    set_ollama_client(client)
    return client


# ---------------------------------------------------------------------------
# Unit tests: DebugLogger
# ---------------------------------------------------------------------------


class TestDebugLogger:
    """Unit tests for the DebugLogger ring buffer."""

    def test_log_creates_entry(self):
        dl = DebugLogger()
        entry = dl.log(action_type="look", target=None, latency_ms=42.5)
        assert entry.action_type == "look"
        assert entry.latency_ms == 42.5
        assert entry.timestamp != ""

    def test_log_truncates_narration(self):
        dl = DebugLogger()
        long_narration = "x" * 200
        entry = dl.log(action_type="look", narration_snippet=long_narration)
        assert len(entry.narration_snippet) == 120

    def test_get_history_returns_newest_first(self):
        dl = DebugLogger()
        dl.log(action_type="first")
        dl.log(action_type="second")
        dl.log(action_type="third")
        history = dl.get_history()
        assert history[0]["action_type"] == "third"
        assert history[2]["action_type"] == "first"

    def test_get_history_limit(self):
        dl = DebugLogger()
        for i in range(10):
            dl.log(action_type=f"action_{i}")
        history = dl.get_history(limit=3)
        assert len(history) == 3
        assert history[0]["action_type"] == "action_9"

    def test_ring_buffer_evicts_old_entries(self):
        dl = DebugLogger(max_entries=5)
        for i in range(10):
            dl.log(action_type=f"action_{i}")
        history = dl.get_history(limit=100)
        assert len(history) == 5
        # Oldest surviving entry should be action_5
        assert history[-1]["action_type"] == "action_5"

    def test_get_stats_empty(self):
        dl = DebugLogger()
        stats = dl.get_stats()
        assert stats["total_requests"] == 0
        assert stats["avg_latency_ms"] == 0.0
        assert stats["total_tokens_est"] == 0

    def test_get_stats_aggregation(self):
        dl = DebugLogger()
        dl.log(action_type="look", prompt_tokens_est=100, response_tokens_est=50, latency_ms=200)
        dl.log(action_type="speak", prompt_tokens_est=80, response_tokens_est=40, latency_ms=100)
        stats = dl.get_stats()
        assert stats["total_requests"] == 2
        assert stats["total_prompt_tokens_est"] == 180
        assert stats["total_response_tokens_est"] == 90
        assert stats["total_tokens_est"] == 270
        assert stats["avg_latency_ms"] == 150.0

    def test_get_stats_tracks_errors(self):
        dl = DebugLogger()
        dl.log(action_type="look", error="LLM down")
        dl.log(action_type="speak")
        stats = dl.get_stats()
        assert stats["total_errors"] == 1

    def test_clear_resets_everything(self):
        dl = DebugLogger()
        dl.log(action_type="look", prompt_tokens_est=100, latency_ms=50)
        dl.clear()
        assert dl.get_history() == []
        stats = dl.get_stats()
        assert stats["total_requests"] == 0

    def test_entry_to_dict(self):
        dl = DebugLogger()
        entry = dl.log(
            action_type="attack",
            target="Goblin",
            prompt_tokens_est=50,
            response_tokens_est=30,
            latency_ms=123.456,
            narration_snippet="You swing your sword.",
        )
        d = entry.to_dict()
        assert d["action_type"] == "attack"
        assert d["target"] == "Goblin"
        assert d["prompt_tokens_est"] == 50
        assert d["response_tokens_est"] == 30
        assert d["latency_ms"] == 123.46
        assert d["error"] is None


class TestEstimateTokens:
    """Tests for the estimate_tokens helper."""

    def test_basic(self):
        assert estimate_tokens("hello world") == max(1, len("hello world") // 4)

    def test_empty_string(self):
        assert estimate_tokens("") == 1  # min 1

    def test_long_string(self):
        text = "a" * 400
        assert estimate_tokens(text) == 100


# ---------------------------------------------------------------------------
# Integration tests: /debug/history and /debug/stats endpoints
# ---------------------------------------------------------------------------


class TestDebugEndpoints:
    """Tests for the GET /debug/history and GET /debug/stats endpoints."""

    @pytest.mark.asyncio
    async def test_history_empty(self):
        """Empty history returns an empty list."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/debug/history")
        assert response.status_code == 200
        data = response.json()
        assert data["entries"] == []
        assert data["count"] == 0

    @pytest.mark.asyncio
    async def test_stats_empty(self):
        """Stats with no requests returns zero values."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/debug/stats")
        assert response.status_code == 200
        data = response.json()
        assert data["total_requests"] == 0
        assert data["avg_latency_ms"] == 0.0

    @pytest.mark.asyncio
    async def test_history_after_action(self, fresh_state, mock_ollama):
        """After posting an action, /debug/history contains the entry."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                await client.post("/action", json={"action_type": "look"})
                response = await client.get("/debug/history")

        assert response.status_code == 200
        data = response.json()
        assert data["count"] == 1
        entry = data["entries"][0]
        assert entry["action_type"] == "look"
        assert entry["latency_ms"] > 0
        assert entry["prompt_tokens_est"] > 0
        assert entry["response_tokens_est"] > 0
        assert entry["error"] is None

    @pytest.mark.asyncio
    async def test_stats_after_action(self, fresh_state, mock_ollama):
        """After posting an action, /debug/stats reflects the request."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                await client.post("/action", json={"action_type": "look"})
                response = await client.get("/debug/stats")

        assert response.status_code == 200
        data = response.json()
        assert data["total_requests"] == 1
        assert data["avg_latency_ms"] > 0
        assert data["total_tokens_est"] > 0

    @pytest.mark.asyncio
    async def test_history_records_error(self, fresh_state):
        """When LLM fails, the debug entry records the error."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaConnectionError("Cannot connect")
        )
        set_ollama_client(client)

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                await ac.post("/action", json={"action_type": "look"})
                response = await ac.get("/debug/history")

        data = response.json()
        assert data["count"] == 1
        entry = data["entries"][0]
        assert entry["error"] is not None
        assert "LLM unavailable" in entry["error"]

    @pytest.mark.asyncio
    async def test_history_limit_query_param(self, fresh_state, mock_ollama):
        """The ?limit query parameter restricts how many entries are returned."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                for _ in range(5):
                    await client.post("/action", json={"action_type": "look"})
                response = await client.get("/debug/history", params={"limit": 2})

        data = response.json()
        assert data["count"] == 2

    @pytest.mark.asyncio
    async def test_history_with_target(self, fresh_state, mock_ollama):
        """Target is recorded in the debug entry for speak actions."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                await client.post("/action", json={
                    "action_type": "speak",
                    "target": "Barkeep",
                    "message": "Hello!",
                })
                response = await client.get("/debug/history")

        data = response.json()
        entry = data["entries"][0]
        assert entry["action_type"] == "speak"
        assert entry["target"] == "Barkeep"
