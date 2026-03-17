"""Tests for template-based fallback when Ollama is unreachable."""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock, patch

from httpx import ASGITransport, AsyncClient

from orchestrator.main import app
from orchestrator.models import GameState, PlayerAction, ActionType
from orchestrator.models.enums import ActionType as AT
from orchestrator.routes.action import set_game_state, set_ollama_client
from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaTimeoutError,
    OllamaModelNotFoundError,
)
from orchestrator.engine.template_fallback import (
    generate_fallback_narration,
    generate_fallback_choices,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_global_state():
    """Reset module-level state before/after each test."""
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]
    yield
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]


@pytest.fixture
def fresh_state() -> GameState:
    """Install a fresh GameState with a named character."""
    state = GameState()
    state.character.name = "Aldric"
    state.character.current_hp = 28
    state.character.max_hp = 34
    state.location.location_name = "The Welcome Wench"
    state.location.map_type = "tavern"
    set_game_state(state)
    return state


# ---------------------------------------------------------------------------
# Tests: generate_fallback_narration
# ---------------------------------------------------------------------------


class TestGenerateFallbackNarration:
    """Tests for the template narration generator."""

    def test_returns_string(self):
        """Output is always a non-empty string."""
        result = generate_fallback_narration(AT.LOOK)
        assert isinstance(result, str)
        assert len(result) > 0

    def test_all_action_types_covered(self):
        """Every ActionType produces a valid narration (no KeyError)."""
        for action_type in AT:
            result = generate_fallback_narration(action_type)
            assert isinstance(result, str)
            assert len(result) > 0

    def test_target_substituted(self):
        """The {target} placeholder is filled in for ATTACK."""
        result = generate_fallback_narration(AT.ATTACK, target="Goblin")
        assert "Goblin" in result

    def test_direction_substituted(self):
        """The {direction} placeholder is filled in for MOVE."""
        result = generate_fallback_narration(AT.MOVE, direction="north")
        assert "north" in result

    def test_message_substituted(self):
        """The {message} placeholder is filled in for SPEAK."""
        result = generate_fallback_narration(
            AT.SPEAK, target="Barkeep", message="Hello there!"
        )
        assert "Hello there!" in result
        assert "Barkeep" in result

    def test_rules_result_included(self):
        """The {rules} placeholder includes the rules_result for ATTACK."""
        rules = "d20(18)+5=23 vs AC 13 — HIT!"
        result = generate_fallback_narration(
            AT.ATTACK, target="Goblin", rules_result=rules
        )
        assert rules in result

    def test_no_double_spaces_when_rules_empty(self):
        """When rules_result is None, no double spaces remain."""
        result = generate_fallback_narration(AT.LOOK)
        assert "  " not in result

    def test_default_target(self):
        """When target is None, a sensible default is used (no empty string)."""
        result = generate_fallback_narration(AT.INTERACT)
        assert "{target}" not in result
        assert len(result) > 10

    def test_default_direction(self):
        """When direction is None, defaults to 'forward'."""
        result = generate_fallback_narration(AT.MOVE)
        assert "{direction}" not in result

    def test_default_message(self):
        """When message is None, a placeholder is used."""
        result = generate_fallback_narration(AT.SPEAK, target="Barkeep")
        assert "{message}" not in result


# ---------------------------------------------------------------------------
# Tests: generate_fallback_choices
# ---------------------------------------------------------------------------


class TestGenerateFallbackChoices:
    """Tests for the template choices generator."""

    def test_returns_list_of_strings(self):
        """Output is a list of strings."""
        result = generate_fallback_choices(AT.LOOK)
        assert isinstance(result, list)
        assert all(isinstance(c, str) for c in result)

    def test_three_choices(self):
        """Each action type produces exactly 3 choices."""
        for action_type in AT:
            result = generate_fallback_choices(action_type)
            assert len(result) == 3, f"{action_type} produced {len(result)} choices"

    def test_all_action_types_covered(self):
        """Every ActionType produces choices (no KeyError)."""
        for action_type in AT:
            result = generate_fallback_choices(action_type)
            assert len(result) > 0

    def test_choices_are_nonempty(self):
        """No empty-string choices."""
        for action_type in AT:
            result = generate_fallback_choices(action_type)
            for choice in result:
                assert len(choice) > 0, f"Empty choice for {action_type}"


# ---------------------------------------------------------------------------
# Tests: action route uses fallback on Ollama failure
# ---------------------------------------------------------------------------


class TestActionRouteFallback:
    """Integration tests: POST /action falls back to templates on Ollama errors."""

    @pytest.mark.asyncio
    async def test_connection_error_uses_fallback(self, fresh_state):
        """OllamaConnectionError triggers template fallback with fallback=True."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaConnectionError("Cannot connect")
        )
        set_ollama_client(client)

        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system", "user"),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post(
                    "/action", json={"action_type": "look"}
                )

        assert response.status_code == 200
        data = response.json()
        assert data["fallback"] is True
        assert data["narration"] != ""
        assert len(data["choices"]) == 3
        assert "LLM unavailable" in data["error"]
        assert "OllamaConnectionError" in data["error"]

    @pytest.mark.asyncio
    async def test_timeout_error_uses_fallback(self, fresh_state):
        """OllamaTimeoutError triggers template fallback with fallback=True."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaTimeoutError("Timed out")
        )
        set_ollama_client(client)

        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system", "user"),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post(
                    "/action", json={"action_type": "move", "direction": "east"}
                )

        assert response.status_code == 200
        data = response.json()
        assert data["fallback"] is True
        assert data["narration"] != ""
        assert len(data["choices"]) == 3

    @pytest.mark.asyncio
    async def test_model_not_found_uses_fallback(self, fresh_state):
        """OllamaModelNotFoundError triggers template fallback with fallback=True."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaModelNotFoundError("Model not found")
        )
        set_ollama_client(client)

        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system", "user"),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post(
                    "/action", json={"action_type": "speak", "target": "Barkeep", "message": "Hello"}
                )

        assert response.status_code == 200
        data = response.json()
        assert data["fallback"] is True
        assert data["narration"] != ""
        assert "OllamaModelNotFoundError" in data["error"]

    @pytest.mark.asyncio
    async def test_successful_llm_has_no_fallback_flag(self, fresh_state):
        """When Ollama succeeds, fallback should be False."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            return_value=(
                "NARRATION: The tavern smells of roasted meat.\n"
                "CHOICES:\n"
                "1. Order a drink\n"
                "2. Talk to the barkeep\n"
                "3. Leave\n"
            )
        )
        set_ollama_client(client)

        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system", "user"),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post(
                    "/action", json={"action_type": "look"}
                )

        assert response.status_code == 200
        data = response.json()
        assert data["fallback"] is False
        assert data["error"] is None

    @pytest.mark.asyncio
    async def test_fallback_attack_includes_combat_log(self, fresh_state):
        """ATTACK with Ollama down still returns combat_log from rules engine."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaConnectionError("Cannot connect")
        )
        set_ollama_client(client)

        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system", "user"),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post(
                    "/action",
                    json={
                        "action_type": "attack",
                        "target": "Goblin",
                        "extra": {"target_ac": 13},
                    },
                )

        assert response.status_code == 200
        data = response.json()
        assert data["fallback"] is True
        # Rules engine still runs even when LLM is down
        assert data["combat_log"] is not None
        assert len(data["combat_log"]) >= 1
        assert data["state_delta"] is not None

    @pytest.mark.asyncio
    async def test_fallback_narration_is_flavorful(self, fresh_state):
        """Template narration is more descriptive than the old bare-bones fallback."""
        client = MagicMock(spec=OllamaClient)
        client.generate_chat = AsyncMock(
            side_effect=OllamaConnectionError("Cannot connect")
        )
        set_ollama_client(client)

        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system", "user"),
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as ac:
                response = await ac.post(
                    "/action", json={"action_type": "look"}
                )

        data = response.json()
        narration = data["narration"]
        # Should be longer than old "You look." (8 chars)
        assert len(narration) > 20
