"""Top-level game state models and persistence helpers."""

from __future__ import annotations

import json
import time
from enum import Enum
from pathlib import Path
from typing import Any

from pydantic import BaseModel, Field

from orchestrator.models.character import CharacterState
from orchestrator.models.enums import Condition, DmArchetype


# ---------------------------------------------------------------------------
# Equipment slot enum
# ---------------------------------------------------------------------------


class EquipmentSlot(str, Enum):
    HEAD = "head"
    BODY = "body"
    CLOAK = "cloak"
    GLOVES = "gloves"
    BOOTS = "boots"
    RING_1 = "ring_1"
    RING_2 = "ring_2"
    AMULET = "amulet"
    MAIN_HAND = "main_hand"
    OFF_HAND = "off_hand"
    BELT = "belt"


# ---------------------------------------------------------------------------
# Sub-state models
# ---------------------------------------------------------------------------


class ItemState(BaseModel):
    """An inventory or equipment item."""

    slug: str
    name: str
    quantity: int = 1
    weight: float = 0.0
    properties: dict[str, Any] = Field(default_factory=dict)


class LocationState(BaseModel):
    """Where the player currently is."""

    location_id: str = ""
    location_name: str = ""
    position_x: int = 0
    position_y: int = 0
    map_type: str = "tavern"  # e.g. "tavern", "dungeon", "overworld"


class NarrativeState(BaseModel):
    """DM narrative context."""

    dm_archetype: DmArchetype = DmArchetype.STORYTELLER
    history: list[dict[str, Any]] = Field(default_factory=list)
    current_narration: str = ""
    current_choices: list[str] = Field(default_factory=list)
    turn_number: int = 0


class CombatantState(BaseModel):
    """A single combatant in an encounter."""

    combatant_id: str
    name: str
    is_player: bool = False
    current_hp: int = 0
    max_hp: int = 0
    armor_class: int = 10
    position_x: int = 0
    position_y: int = 0
    initiative: int = 0
    conditions: list[Condition] = Field(default_factory=list)


class CombatState(BaseModel):
    """Full combat encounter state."""

    active: bool = False
    combatants: list[CombatantState] = Field(default_factory=list)
    current_turn_index: int = 0
    round_number: int = 1


# ---------------------------------------------------------------------------
# Top-level game state
# ---------------------------------------------------------------------------


class GameState(BaseModel):
    """Complete serializable game state."""

    version: int = 1
    timestamp: float = Field(default_factory=time.time)
    character: CharacterState = Field(default_factory=CharacterState)
    location: LocationState = Field(default_factory=LocationState)
    narrative: NarrativeState = Field(default_factory=NarrativeState)
    combat: CombatState | None = None
    inventory: list[ItemState] = Field(default_factory=list)
    equipment: dict[EquipmentSlot, ItemState | None] = Field(default_factory=dict)


# ---------------------------------------------------------------------------
# Persistence helpers
# ---------------------------------------------------------------------------


def save_game_state(state: GameState, path: str | Path) -> None:
    """Serialize *state* to a JSON file at *path*."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(state.model_dump_json(indent=2), encoding="utf-8")


def load_game_state(path: str | Path) -> GameState:
    """Deserialize a GameState from a JSON file at *path*."""
    path = Path(path)
    raw = path.read_text(encoding="utf-8")
    data = json.loads(raw)
    return GameState.model_validate(data)
