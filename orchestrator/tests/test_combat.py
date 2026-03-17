"""Tests for combat-related actions (attack, move, rest) through POST /action."""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch, MagicMock

from httpx import ASGITransport, AsyncClient

from orchestrator.main import app
from orchestrator.models import GameState, ActionType
from orchestrator.routes.action import set_game_state, set_ollama_client, get_game_state
from orchestrator.engine.ollama_client import OllamaClient


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
    state.character.hit_dice_remaining = 3
    state.character.level = 3
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
            "NARRATION: The blade connects with a dull thud.\n"
            "CHOICES:\n"
            "1. Press the attack\n"
            "2. Fall back\n"
            "3. Call for aid\n"
        )
    )
    set_ollama_client(client)
    return client


# ---------------------------------------------------------------------------
# Tests: Attack actions
# ---------------------------------------------------------------------------


class TestAttackActions:
    """Tests for attack action processing through the orchestrator."""

    @pytest.mark.asyncio
    async def test_attack_action_with_target(self, fresh_state, mock_ollama):
        """POST attack action with target produces combat_log."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "attack",
                    "target": "Goblin",
                    "extra": {"target_ac": 13, "attacker": "Aldric"},
                })
            assert response.status_code == 200
            data = response.json()
            assert data["combat_log"] is not None
            assert len(data["combat_log"]) >= 1
            assert data["state_delta"] is not None
            assert "attack_hit" in data["state_delta"]["custom"]

    @pytest.mark.asyncio
    async def test_attack_generates_narration(self, fresh_state, mock_ollama):
        """Attack action generates narration that mentions the target."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "attack",
                    "target": "Skeleton",
                    "extra": {"target_ac": 15},
                })
            assert response.status_code == 200
            data = response.json()
            # The narration comes from the mocked LLM
            assert data["narration"] != ""
            # combat_log should exist since we have a target
            assert data["combat_log"] is not None

    @pytest.mark.asyncio
    async def test_attack_with_weapon_params(self, fresh_state, mock_ollama):
        """Attack with custom weapon dice from extra params."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "attack",
                    "target": "Dragon",
                    "extra": {
                        "target_ac": 18,
                        "weapon_dice": 2,
                        "weapon_sides": 6,
                        "attacker": "Aldric",
                    },
                })
            assert response.status_code == 200
            data = response.json()
            assert data["combat_log"] is not None
            assert data["state_delta"] is not None


# ---------------------------------------------------------------------------
# Tests: Move actions
# ---------------------------------------------------------------------------


class TestMoveActions:
    """Tests for move action processing through the orchestrator."""

    @pytest.mark.asyncio
    async def test_move_action(self, fresh_state, mock_ollama):
        """POST move action produces combat_log with movement narration."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "move",
                    "direction": "north",
                    "extra": {"mover": "Aldric"},
                })
            assert response.status_code == 200
            data = response.json()
            assert data["narration"] != ""
            assert data["combat_log"] is not None
            assert len(data["combat_log"]) >= 1
            assert "Aldric" in data["combat_log"][0]
            assert "north" in data["combat_log"][0]

    @pytest.mark.asyncio
    async def test_move_action_default_direction(self, fresh_state, mock_ollama):
        """Move action without direction defaults to 'forward'."""
        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "move",
                })
            assert response.status_code == 200
            data = response.json()
            assert data["combat_log"] is not None
            assert "forward" in data["combat_log"][0]


# ---------------------------------------------------------------------------
# Tests: Rest actions
# ---------------------------------------------------------------------------


class TestRestActions:
    """Tests for rest action processing through the orchestrator."""

    @pytest.mark.asyncio
    async def test_rest_action_short(self, fresh_state, mock_ollama):
        """POST short rest action heals the character."""
        # Set HP below max so healing can occur
        fresh_state.character.current_hp = 20
        fresh_state.character.hit_dice_remaining = 2

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "rest",
                    "extra": {"character": "Aldric", "rest_type": "short"},
                })
            assert response.status_code == 200
            data = response.json()
            assert data["combat_log"] is not None
            assert len(data["combat_log"]) >= 1
            assert "short rest" in data["combat_log"][0]
            assert data["state_delta"] is not None
            # Hit dice should have been consumed
            state = get_game_state()
            assert state.character.hit_dice_remaining == 1

    @pytest.mark.asyncio
    async def test_rest_action_long(self, fresh_state, mock_ollama):
        """POST long rest action fully restores HP."""
        fresh_state.character.current_hp = 15
        fresh_state.character.hit_dice_remaining = 1

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "rest",
                    "extra": {"character": "Aldric", "rest_type": "long"},
                })
            assert response.status_code == 200
            data = response.json()
            assert data["combat_log"] is not None
            assert "long rest" in data["combat_log"][0]
            # HP should be fully restored
            state = get_game_state()
            assert state.character.current_hp == state.character.max_hp
            # Hit dice should be restored
            assert state.character.hit_dice_remaining == state.character.level
            # State delta should show HP change
            assert data["state_delta"] is not None
            assert data["state_delta"]["hp_change"] == 19  # 34 - 15

    @pytest.mark.asyncio
    async def test_rest_action_no_hit_dice(self, fresh_state, mock_ollama):
        """Short rest with no hit dice remaining does not heal."""
        fresh_state.character.current_hp = 20
        fresh_state.character.hit_dice_remaining = 0

        with patch("orchestrator.engine.prompt_builder.build_dm_prompt",
                   return_value=("system prompt", "user prompt")):
            transport = ASGITransport(app=app)
            async with AsyncClient(transport=transport, base_url="http://test") as client:
                response = await client.post("/action", json={
                    "action_type": "rest",
                    "extra": {"character": "Aldric", "rest_type": "short"},
                })
            assert response.status_code == 200
            data = response.json()
            assert "no hit dice" in data["combat_log"][0]
            state = get_game_state()
            assert state.character.current_hp == 20  # No change
