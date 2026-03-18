"""Tests for NPC profile management and NPC conversation via POST /action."""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, patch, MagicMock

from httpx import ASGITransport, AsyncClient

from orchestrator.main import app
from orchestrator.models import GameState, ActionType
from orchestrator.engine.npc_context import (
    load_npc_profiles,
    get_npc_profile,
    get_npc_name,
    list_npcs,
    reset_profiles,
    DEFAULT_NPC_PROFILES,
)
from orchestrator.engine.ollama_client import OllamaClient
from orchestrator.routes.action import set_game_state, set_ollama_client


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_npc_state():
    """Reset NPC profiles and global state before each test."""
    reset_profiles()
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]
    yield
    reset_profiles()
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
    """Create a mock OllamaClient with a canned NPC conversation response."""
    client = MagicMock(spec=OllamaClient)
    client.generate_chat = AsyncMock(
        return_value=(
            "NARRATION: The barkeep looks up with a warm smile. "
            "\"What can I get for you, traveler? We've got ale and stew tonight.\"\n"
            "CHOICES:\n"
            "1. Ask about the cellar\n"
            "2. Order a drink\n"
            "3. Ask about rumors\n"
        )
    )
    set_ollama_client(client)
    return client


# ---------------------------------------------------------------------------
# Tests: NPC profile management
# ---------------------------------------------------------------------------


class TestNpcProfileManagement:
    """Tests for the npc_context module's profile management functions."""

    def test_load_default_profiles(self):
        """load_npc_profiles() without path loads the hardcoded defaults."""
        load_npc_profiles()
        profiles = list_npcs()
        assert "marta" in profiles
        assert "old_tom" in profiles
        assert "elara" in profiles
        assert len(profiles) == 3

    def test_get_npc_profile_marta(self):
        """get_npc_profile('marta') returns Marta's profile with expected fields."""
        load_npc_profiles()
        profile = get_npc_profile("marta")
        assert profile is not None
        assert profile["name"] == "Barkeep Marta"
        assert profile["role"] == "tavern owner and barkeep"
        assert "personality" in profile
        assert "knowledge" in profile

    def test_get_npc_profile_old_tom(self):
        """get_npc_profile('old_tom') returns Old Tom's profile."""
        load_npc_profiles()
        profile = get_npc_profile("old_tom")
        assert profile is not None
        assert profile["name"] == "Old Tom"
        assert "veteran" in profile["role"] or "adventurer" in profile["role"]

    def test_get_npc_profile_elara(self):
        """get_npc_profile('elara') returns Elara's profile."""
        load_npc_profiles()
        profile = get_npc_profile("elara")
        assert profile is not None
        assert profile["name"] == "Elara the Quiet"

    def test_get_npc_profile_case_insensitive(self):
        """'Marta' and 'marta' both return the same profile."""
        load_npc_profiles()
        lower = get_npc_profile("marta")
        upper = get_npc_profile("Marta")
        assert lower is not None
        assert upper is not None
        assert lower["name"] == upper["name"]

    def test_get_npc_profile_by_display_name(self):
        """Looking up by full display name 'Barkeep Marta' works."""
        load_npc_profiles()
        profile = get_npc_profile("Barkeep Marta")
        assert profile is not None
        assert profile["name"] == "Barkeep Marta"

    def test_get_npc_profile_unknown(self):
        """get_npc_profile for an unknown NPC returns None."""
        load_npc_profiles()
        assert get_npc_profile("gandalf") is None

    def test_get_npc_name(self):
        """get_npc_name returns the display name."""
        load_npc_profiles()
        assert get_npc_name("marta") == "Barkeep Marta"
        assert get_npc_name("old_tom") == "Old Tom"
        assert get_npc_name("elara") == "Elara the Quiet"

    def test_get_npc_name_unknown(self):
        """get_npc_name returns the raw ID for unknown NPCs."""
        load_npc_profiles()
        assert get_npc_name("gandalf") == "gandalf"

    def test_list_npcs(self):
        """list_npcs returns all NPC ID keys."""
        load_npc_profiles()
        npcs = list_npcs()
        assert isinstance(npcs, list)
        assert set(npcs) == {"marta", "old_tom", "elara"}

    def test_load_from_json_file(self, tmp_path):
        """load_npc_profiles from a JSON file loads those profiles."""
        import json

        custom_data = {
            "test_npc": {
                "name": "Test NPC",
                "role": "test role",
                "personality": "test personality",
                "knowledge": "test knowledge",
            }
        }
        json_path = tmp_path / "npcs.json"
        json_path.write_text(json.dumps(custom_data), encoding="utf-8")

        load_npc_profiles(json_path, merge_forge=False)
        assert list_npcs() == ["test_npc"]
        profile = get_npc_profile("test_npc")
        assert profile is not None
        assert profile["name"] == "Test NPC"

    def test_load_bad_path_falls_back(self):
        """load_npc_profiles with a bad path falls back to defaults."""
        load_npc_profiles("/nonexistent/path.json")
        assert len(list_npcs()) == 3
        assert "marta" in list_npcs()

    def test_auto_load_on_first_access(self):
        """Accessing profiles without explicit load triggers auto-load."""
        # reset_profiles was called in fixture, so profiles are empty
        profile = get_npc_profile("marta")
        assert profile is not None
        assert profile["name"] == "Barkeep Marta"


# ---------------------------------------------------------------------------
# Tests: NPC conversation via POST /action
# ---------------------------------------------------------------------------


class TestNpcConversationEndpoint:
    """Tests for NPC conversation through the POST /action and /npc/speak endpoints."""

    @pytest.mark.asyncio
    async def test_speak_to_marta(self, fresh_state, mock_ollama):
        """POST speak action targeting marta delegates to NPC system."""
        # Mock the NPC endpoint's Ollama client
        with patch(
            "orchestrator.routes.npc._get_ollama",
            return_value=mock_ollama,
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/action",
                    json={
                        "action_type": "speak",
                        "target": "marta",
                    },
                )
            assert response.status_code == 200
            data = response.json()
            assert data["narration"] != ""
            assert "Marta" in data["narration"]

    @pytest.mark.asyncio
    async def test_speak_to_old_tom(self, fresh_state, mock_ollama):
        """POST speak action targeting old_tom delegates to NPC system."""
        with patch(
            "orchestrator.routes.npc._get_ollama",
            return_value=mock_ollama,
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/action",
                    json={
                        "action_type": "speak",
                        "target": "old_tom",
                    },
                )
            assert response.status_code == 200
            data = response.json()
            assert "Old Tom" in data["narration"]

    @pytest.mark.asyncio
    async def test_speak_to_unknown_npc(self, fresh_state, mock_ollama):
        """POST speak to unknown NPC target falls through to standard DM."""
        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system prompt", "user prompt"),
        ) as mock_build:
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/action",
                    json={
                        "action_type": "speak",
                        "target": "mysterious_stranger",
                    },
                )
            assert response.status_code == 200
            data = response.json()
            assert data["narration"] != ""
            # For unknown NPCs, falls through to standard DM handling
            mock_build.assert_called_once()
            call_kwargs = mock_build.call_args
            assert call_kwargs.kwargs.get("npc_profile") is None
            assert call_kwargs.kwargs.get("npc_name") == "mysterious_stranger"

    @pytest.mark.asyncio
    async def test_speak_with_message(self, fresh_state, mock_ollama):
        """POST speak with player message text passes it to NPC system."""
        with patch(
            "orchestrator.routes.npc._get_ollama",
            return_value=mock_ollama,
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/action",
                    json={
                        "action_type": "speak",
                        "target": "marta",
                        "message": "Tell me about the cellar.",
                    },
                )
            assert response.status_code == 200
            data = response.json()
            assert data["narration"] != ""
            assert "Marta" in data["narration"]

    @pytest.mark.asyncio
    async def test_speak_with_extra_profile_fallback(self, fresh_state, mock_ollama):
        """When NPC is unknown but extra contains profile data, it is used."""
        with patch(
            "orchestrator.engine.prompt_builder.build_dm_prompt",
            return_value=("system prompt", "user prompt"),
        ) as mock_build:
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/action",
                    json={
                        "action_type": "speak",
                        "target": "custom_npc",
                        "extra": {
                            "name": "Custom NPC",
                            "role": "wandering merchant",
                            "personality": "Jovial and talkative.",
                            "knowledge": "Trade routes and prices.",
                        },
                    },
                )
            assert response.status_code == 200
            call_kwargs = mock_build.call_args
            npc_profile = call_kwargs.kwargs.get("npc_profile")
            assert npc_profile is not None
            assert npc_profile["name"] == "Custom NPC"
            assert call_kwargs.kwargs.get("npc_name") == "Custom NPC"

    @pytest.mark.asyncio
    async def test_speak_choices_returned(self, fresh_state, mock_ollama):
        """Speak action targeting known NPC returns NPC-system choices."""
        with patch(
            "orchestrator.routes.npc._get_ollama",
            return_value=mock_ollama,
        ):
            transport = ASGITransport(app=app)
            async with AsyncClient(
                transport=transport, base_url="http://test"
            ) as client:
                response = await client.post(
                    "/action",
                    json={
                        "action_type": "speak",
                        "target": "marta",
                    },
                )
            data = response.json()
            # NPC system generates mode-based choices
            assert len(data["choices"]) > 0
            assert "End conversation" in data["choices"]
