"""Integration tests for POST /action and GET /state endpoints."""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch, MagicMock

from httpx import ASGITransport, AsyncClient

from orchestrator.main import app
from orchestrator.models import GameState, PlayerAction, ActionType, DmArchetype
from orchestrator.routes.action import (
    parse_llm_response,
    set_game_state,
    set_ollama_client,
    get_game_state,
    _fallback_narration,
    _fallback_choices,
)
from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaTimeoutError,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_global_state():
    """Reset the module-level game state and ollama client before each test."""
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]
    yield
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]


@pytest.fixture
def fresh_state() -> GameState:
    """Create and install a fresh GameState with a named character."""
    state = GameState()
    state.character.name = "Aldric"
    state.character.current_hp = 28
    state.character.max_hp = 34
    state.location.location_name = "The Welcome Wench"
    state.location.map_type = "tavern"
    set_game_state(state)
    return state


@pytest.fixture
def mock_ollama() -> OllamaClient:
    """Create a mock OllamaClient with a canned structured response."""
    client = MagicMock(spec=OllamaClient)
    client.generate_chat = AsyncMock(
        return_value=(
            "NARRATION: The tavern is dimly lit. You see a barkeep polishing glasses.\n"
            "CHOICES:\n"
            "1. Approach the barkeep\n"
            "2. Look around the room\n"
            "3. Sit at a table\n"
        )
    )
    set_ollama_client(client)
    return client


# ---------------------------------------------------------------------------
# Tests: parse_llm_response
# ---------------------------------------------------------------------------


class TestParseLlmResponse:
    """Tests for the parse_llm_response helper."""

    def test_parse_structured_response(self):
        """NARRATION: + CHOICES: format is parsed correctly."""
        raw = (
            "NARRATION: The goblin snarls and lunges forward.\n"
            "CHOICES:\n"
            "1. Dodge to the side\n"
            "2. Counter-attack\n"
            "3. Flee\n"
        )
        narration, choices = parse_llm_response(raw)
        assert narration == "The goblin snarls and lunges forward."
        assert choices == ["Dodge to the side", "Counter-attack", "Flee"]

    def test_parse_no_format(self):
        """Plain text with no markers treated as narration, empty choices."""
        raw = "You stand in an empty room. Nothing happens."
        narration, choices = parse_llm_response(raw)
        assert narration == raw
        assert choices == []

    def test_parse_narration_only(self):
        """NARRATION: with no CHOICES: section."""
        raw = "NARRATION: The door creaks open, revealing darkness beyond."
        narration, choices = parse_llm_response(raw)
        assert narration == "The door creaks open, revealing darkness beyond."
        assert choices == []

    def test_parse_empty(self):
        """Empty string returns empty narration and no choices."""
        narration, choices = parse_llm_response("")
        assert narration == ""
        assert choices == []

    def test_parse_choices_with_paren_numbering(self):
        """Choices using ')' instead of '.' as delimiter."""
        raw = (
            "NARRATION: A crossroads lies before you.\n"
            "CHOICES:\n"
            "1) Go left\n"
            "2) Go right\n"
            "3) Turn back\n"
        )
        narration, choices = parse_llm_response(raw)
        assert narration == "A crossroads lies before you."
        assert choices == ["Go left", "Go right", "Turn back"]


# ---------------------------------------------------------------------------
# Tests: POST /action with mocked Ollama
# ---------------------------------------------------------------------------


class TestActionEndpoint:
    """Tests for the POST /action endpoint."""

    @pytest.mark.asyncio
    async def test_action_look(self, fresh_state, mock_ollama):
        """LOOK action returns a valid DmResponse with narration and choices."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "look",
                })
            assert response.status_code == 200
            data = response.json()
            assert "narration" in data
            assert "choices" in data
            assert isinstance(data["choices"], list)
            assert data["narration"] != ""
            assert data["error"] is None

    @pytest.mark.asyncio
    async def test_action_attack(self, fresh_state, mock_ollama):
        """ATTACK action returns combat_log and state_delta."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "attack",
                    "target": "Goblin",
                    "extra": {"target_ac": 13},
                })
            assert response.status_code == 200
            data = response.json()
            assert data["combat_log"] is not None
            assert len(data["combat_log"]) >= 1
            assert data["state_delta"] is not None
            assert "attack_hit" in data["state_delta"]["custom"]

    @pytest.mark.asyncio
    async def test_action_speak(self, fresh_state, mock_ollama):
        """SPEAK action with target and message is processed."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "speak",
                    "target": "Barkeep",
                    "message": "What news from the road?",
                })
            assert response.status_code == 200
            data = response.json()
            assert data["narration"] != ""
            assert data["error"] is None

    @pytest.mark.asyncio
    async def test_action_ollama_down(self, fresh_state):
        """When Ollama raises OllamaConnectionError, fallback narration is used."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaConnectionError("Cannot connect")
        )
        set_ollama_client(client)

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post("/action", json={
                    "action_type": "look",
                })
            assert response.status_code == 200
            data = response.json()
            assert "LLM unavailable" in data["error"]
            assert len(data["narration"]) > 0  # template fallback produces text
            assert data["fallback"] is True
            assert len(data["choices"]) == 3

    @pytest.mark.asyncio
    async def test_action_ollama_timeout(self, fresh_state):
        """When Ollama raises OllamaTimeoutError, fallback narration is used."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaTimeoutError("Request timed out")
        )
        set_ollama_client(client)

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post("/action", json={
                    "action_type": "look",
                })
            assert response.status_code == 200
            data = response.json()
            assert "LLM unavailable" in data["error"]
            assert "OllamaTimeoutError" in data["error"]

    @pytest.mark.asyncio
    async def test_action_updates_turn(self, fresh_state, mock_ollama):
        """Turn number increments after each action."""
        assert fresh_state.narrative.turn_number == 0

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                await client.post("/action", json={"action_type": "look"})

            state = get_game_state()
            assert state.narrative.turn_number == 1

            async with AsyncClient(transport=transport, base_url="http://test") as client:
                await client.post("/action", json={"action_type": "look"})

            assert state.narrative.turn_number == 2

    @pytest.mark.asyncio
    async def test_action_updates_history(self, fresh_state, mock_ollama):
        """History gets a new exchange after each action."""
        assert len(fresh_state.narrative.history) == 0

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                await client.post("/action", json={
                    "action_type": "speak",
                    "target": "Barkeep",
                    "message": "Hello there!",
                })

            state = get_game_state()
            assert len(state.narrative.history) == 1
            entry = state.narrative.history[0]
            assert entry["turn"] == 1
            assert "speak" in entry["action"]
            assert "Barkeep" in entry["action"]
            assert '"Hello there!"' in entry["action"]
            assert entry["compressed"] is False

    @pytest.mark.asyncio
    async def test_action_attack_without_target(self, fresh_state, mock_ollama):
        """ATTACK without a target skips rules resolution."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "attack",
                })
            assert response.status_code == 200
            data = response.json()
            # No target means no rules resolution
            assert data["combat_log"] is None
            assert data["state_delta"] is None


# ---------------------------------------------------------------------------
# Tests: GET /state
# ---------------------------------------------------------------------------


class TestStateEndpoint:
    """Tests for the GET /state endpoint."""

    @pytest.mark.asyncio
    async def test_get_state(self, fresh_state):
        """GET /state returns the current GameState as JSON."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/state")
        assert response.status_code == 200
        data = response.json()
        assert data["character"]["name"] == "Aldric"
        assert data["character"]["current_hp"] == 28
        assert data["location"]["location_name"] == "The Welcome Wench"
        assert data["version"] == 1

    @pytest.mark.asyncio
    async def test_get_state_default(self):
        """GET /state creates a default GameState if none exists."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.get("/state")
        assert response.status_code == 200
        data = response.json()
        assert "character" in data
        assert "location" in data
        assert "narrative" in data


# ---------------------------------------------------------------------------
# Tests: Fallback functions
# ---------------------------------------------------------------------------


class TestFallbackFunctions:
    """Tests for _fallback_narration and _fallback_choices (now delegates to template_fallback)."""

    def test_fallback_narration_basic(self):
        """Fallback narration for a simple action returns non-empty text."""
        action = PlayerAction(action_type=ActionType.LOOK)
        result = _fallback_narration(action, None)
        assert isinstance(result, str)
        assert len(result) > 0

    def test_fallback_narration_with_target(self):
        """Fallback narration includes the target."""
        action = PlayerAction(action_type=ActionType.ATTACK, target="Goblin")
        result = _fallback_narration(action, None)
        assert "Goblin" in result

    def test_fallback_narration_with_rules_result(self):
        """Fallback narration includes the rules result."""
        action = PlayerAction(action_type=ActionType.ATTACK, target="Goblin")
        rules = "d20(15)+5=20 vs AC 13 HIT!"
        result = _fallback_narration(action, rules)
        assert rules in result

    def test_fallback_choices(self):
        """Fallback choices return a list of three options."""
        action = PlayerAction(action_type=ActionType.LOOK)
        result = _fallback_choices(action)
        assert len(result) == 3
        assert all(isinstance(c, str) and len(c) > 0 for c in result)
