"""Tests for POST /character/create endpoint."""

from __future__ import annotations

import pytest
from unittest.mock import AsyncMock, MagicMock

from httpx import ASGITransport, AsyncClient

from orchestrator.main import app
from orchestrator.models.enums import (
    Ability,
    DmArchetype,
    DndClass,
    Race,
    Skill,
    CLASS_DATA,
    RACE_DATA,
)
from orchestrator.routes.action import (
    get_game_state,
    set_game_state,
    set_ollama_client,
)
from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(autouse=True)
def reset_global_state():
    """Reset module-level game state and ollama client before each test."""
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]
    yield
    set_game_state(None)  # type: ignore[arg-type]
    set_ollama_client(None)  # type: ignore[arg-type]


@pytest.fixture
def mock_ollama_backstory() -> OllamaClient:
    """Create a mock OllamaClient that returns a canned backstory."""
    client = MagicMock(spec=OllamaClient)
    client.generate_response = AsyncMock(
        return_value="You are a battle-hardened warrior from the northern wastes."
    )
    set_ollama_client(client)
    return client


@pytest.fixture
def mock_ollama_down() -> OllamaClient:
    """Create a mock OllamaClient that raises OllamaConnectionError."""
    client = MagicMock(spec=OllamaClient)
    client.generate_response = AsyncMock(
        side_effect=OllamaConnectionError("Cannot connect to Ollama")
    )
    set_ollama_client(client)
    return client


def _base_request(**overrides) -> dict:
    """Build a minimal valid character creation request, with optional overrides."""
    data = {
        "name": "Aldric",
        "race": "human",
        "dnd_class": "fighter",
        "strength": 16,
        "dexterity": 14,
        "constitution": 15,
        "intelligence": 10,
        "wisdom": 12,
        "charisma": 8,
    }
    data.update(overrides)
    return data


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


class TestCreateCharacterBasic:
    """POST /character/create returns a valid response."""

    @pytest.mark.asyncio
    async def test_create_character_basic(self, mock_ollama_backstory):
        """Basic creation returns success and backstory from LLM."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/character/create", json=_base_request()
            )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        assert data["backstory"] != ""
        assert data["narration"] != ""
        assert data["error"] is None

    @pytest.mark.asyncio
    async def test_create_character_sets_game_state(self, mock_ollama_backstory):
        """After creation, game state is initialized with the character."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post("/character/create", json=_base_request())

        state = get_game_state()
        assert state.character.name == "Aldric"
        assert state.character.race == Race.HUMAN
        assert state.character.dnd_class == DndClass.FIGHTER
        assert state.location.location_name == "The Welcome Wench"
        assert state.location.location_id == "welcome_wench"

    @pytest.mark.asyncio
    async def test_create_character_calculates_hp(self, mock_ollama_backstory):
        """HP is calculated from class hit die + CON modifier."""
        # Fighter has d10 hit die; CON 15 -> modifier +2 -> HP = 10 + 2 = 12
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post(
                "/character/create",
                json=_base_request(constitution=15),
            )

        state = get_game_state()
        # CON 15 -> modifier = floor((15-10)/2) = 2
        # Fighter hit die = 10, level 1 -> HP = 10 + 2 = 12
        assert state.character.max_hp == 12
        assert state.character.current_hp == 12

    @pytest.mark.asyncio
    async def test_create_character_sets_saving_throws(self, mock_ollama_backstory):
        """Class saving throw proficiencies are set correctly."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post("/character/create", json=_base_request())

        state = get_game_state()
        # Fighter saves: STR, CON
        fighter_info = CLASS_DATA[DndClass.FIGHTER]
        expected_saves = list(fighter_info.saving_throws)
        assert state.character.saving_throw_proficiencies == expected_saves

    @pytest.mark.asyncio
    async def test_create_character_ollama_down(self, mock_ollama_down):
        """When Ollama is unavailable, fallback backstory is generated."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/character/create", json=_base_request()
            )
        assert response.status_code == 200
        data = response.json()
        assert data["success"] is True
        # Fallback backstory should mention race and class
        assert "human" in data["backstory"]
        assert "fighter" in data["backstory"]
        assert "Welcome Wench" in data["backstory"]
        # Narration should still be present
        assert "Aldric" in data["narration"]
        assert data["error"] is None

    @pytest.mark.asyncio
    async def test_create_character_with_skills(self, mock_ollama_backstory):
        """Skill proficiencies are stored on the character."""
        skills = ["athletics", "perception"]
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/character/create",
                json=_base_request(skill_proficiencies=skills),
            )
        assert response.status_code == 200

        state = get_game_state()
        assert Skill.ATHLETICS in state.character.skill_proficiencies
        assert Skill.PERCEPTION in state.character.skill_proficiencies
        assert len(state.character.skill_proficiencies) == 2

    @pytest.mark.asyncio
    async def test_create_character_with_alignment(self, mock_ollama_backstory):
        """Alignment string is stored on the character."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            response = await client.post(
                "/character/create",
                json=_base_request(alignment="Chaotic Good"),
            )
        assert response.status_code == 200

        state = get_game_state()
        assert state.character.alignment == "Chaotic Good"

    @pytest.mark.asyncio
    async def test_create_character_sets_speed(self, mock_ollama_backstory):
        """Character speed is set from race data."""
        # Dwarf has speed 25
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post(
                "/character/create",
                json=_base_request(race="dwarf"),
            )

        state = get_game_state()
        assert state.character.speed_feet == 25

    @pytest.mark.asyncio
    async def test_create_character_sets_ac(self, mock_ollama_backstory):
        """Base AC is 10 + DEX modifier."""
        # DEX 14 -> modifier = 2 -> AC = 12
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post(
                "/character/create",
                json=_base_request(dexterity=14),
            )

        state = get_game_state()
        assert state.character.base_ac == 12

    @pytest.mark.asyncio
    async def test_create_character_sets_dm_archetype(self, mock_ollama_backstory):
        """DM archetype is passed through to narrative state."""
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post(
                "/character/create",
                json=_base_request(dm_archetype="trickster"),
            )

        state = get_game_state()
        assert state.narrative.dm_archetype == DmArchetype.TRICKSTER

    @pytest.mark.asyncio
    async def test_create_wizard_hp(self, mock_ollama_backstory):
        """Wizard HP uses d6 hit die."""
        # Wizard d6, CON 10 -> modifier 0 -> HP = 6
        transport = ASGITransport(app=app)
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            await client.post(
                "/character/create",
                json=_base_request(
                    dnd_class="wizard",
                    constitution=10,
                ),
            )

        state = get_game_state()
        assert state.character.max_hp == 6
