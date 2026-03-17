"""POST /character/create endpoint -- creates a new character and initializes game state."""

from __future__ import annotations

import logging

from fastapi import APIRouter
from pydantic import BaseModel, Field

from orchestrator.models import (
    AbilityScores,
    CharacterState,
    GameState,
    LocationState,
    NarrativeState,
)
from orchestrator.models.enums import (
    Ability,
    CLASS_DATA,
    DmArchetype,
    DndClass,
    Race,
    RACE_DATA,
    Skill,
)
from orchestrator.engine.ollama_client import OllamaConnectionError, OllamaTimeoutError
from orchestrator.engine.rules import get_max_hp_for_level
from orchestrator.routes.action import get_ollama_client, set_game_state

logger = logging.getLogger(__name__)
router = APIRouter()


class CharacterCreateRequest(BaseModel):
    """Request body for character creation."""

    name: str
    race: Race
    dnd_class: DndClass
    level: int = 1
    strength: int = 10
    dexterity: int = 10
    constitution: int = 10
    intelligence: int = 10
    wisdom: int = 10
    charisma: int = 10
    alignment: str = ""
    skill_proficiencies: list[Skill] = Field(default_factory=list)
    dm_archetype: DmArchetype = DmArchetype.STORYTELLER


class CharacterCreateResponse(BaseModel):
    """Response body for character creation."""

    success: bool
    backstory: str = ""
    narration: str = ""
    error: str | None = None


@router.post("/character/create", response_model=CharacterCreateResponse)
async def create_character(req: CharacterCreateRequest) -> CharacterCreateResponse:
    """Create a new character and initialize the game state."""
    # Build character state
    character = CharacterState(
        name=req.name,
        race=req.race,
        dnd_class=req.dnd_class,
        level=req.level,
        ability_scores=AbilityScores(
            strength=req.strength,
            dexterity=req.dexterity,
            constitution=req.constitution,
            intelligence=req.intelligence,
            wisdom=req.wisdom,
            charisma=req.charisma,
        ),
        alignment=req.alignment,
        skill_proficiencies=list(req.skill_proficiencies),
    )

    # Calculate max HP from class hit die + CON modifier
    hp = get_max_hp_for_level(character)
    character.max_hp = hp
    character.current_hp = hp
    character.hit_dice_remaining = req.level

    # Set saving throw proficiencies from class data
    class_info = CLASS_DATA.get(req.dnd_class)
    if class_info is not None:
        character.saving_throw_proficiencies = list(class_info.saving_throws)
        character.armor_proficiencies = list(class_info.armor_proficiencies)

    # Set speed from race
    race_info = RACE_DATA.get(req.race)
    if race_info is not None:
        character.speed_feet = race_info.speed

    # Set base AC (no armor at start)
    character.base_ac = 10 + character.get_modifier(Ability.DEXTERITY)

    # Initialize game state
    state = GameState(
        character=character,
        location=LocationState(
            location_id="welcome_wench",
            location_name="The Welcome Wench",
            map_type="tavern",
            position_x=22,
            position_y=17,
        ),
        narrative=NarrativeState(
            dm_archetype=req.dm_archetype,
        ),
    )

    # Try to generate backstory via LLM
    backstory = ""
    narration = ""
    try:
        client = get_ollama_client()
        backstory_prompt = (
            f"Write a brief backstory (2-3 sentences) for a D&D character:\n"
            f"Name: {req.name}\n"
            f"Race: {req.race.value}\n"
            f"Class: {req.dnd_class.value}\n"
            f"Alignment: {req.alignment or 'unspecified'}\n"
            f"Write in second person ('You are...'). Be vivid but concise."
        )
        backstory = await client.generate_response(
            backstory_prompt, max_tokens=200, temperature=0.8,
        )
        character.backstory = backstory
        narration = f"Welcome, {req.name}. Your story begins at The Welcome Wench tavern."
    except (OllamaConnectionError, OllamaTimeoutError) as e:
        logger.warning("LLM unavailable for backstory: %s", e)
        backstory = (
            f"A {req.race.value} {req.dnd_class.value} who has come to seek "
            f"adventure at The Welcome Wench."
        )
        character.backstory = backstory
        narration = f"Welcome, {req.name}. The door to The Welcome Wench creaks open."
    except Exception as e:
        logger.error("Backstory generation failed: %s", e)
        backstory = ""
        narration = f"Welcome, {req.name}."

    set_game_state(state)

    return CharacterCreateResponse(
        success=True,
        backstory=backstory,
        narration=narration,
    )
