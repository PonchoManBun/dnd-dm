"""Action and response models for the HTTP API between Godot client and orchestrator."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from orchestrator.models.enums import ActionType, Condition


class PlayerAction(BaseModel):
    """An action submitted by the player (from the Godot client)."""

    action_type: ActionType
    target: str | None = None
    message: str | None = None
    direction: str | None = None
    item_slug: str | None = None
    extra: dict[str, Any] | None = None


class StateDelta(BaseModel):
    """A set of changes to apply to the game state after processing an action."""

    hp_change: int | None = None
    conditions_added: list[Condition] = Field(default_factory=list)
    conditions_removed: list[Condition] = Field(default_factory=list)
    items_gained: list[str] = Field(default_factory=list)
    items_lost: list[str] = Field(default_factory=list)
    position_change: tuple[int, int] | None = None
    xp_gained: int | None = None
    custom: dict[str, Any] | None = None


class DmResponse(BaseModel):
    """Response from the DM orchestrator back to the Godot client."""

    narration: str
    choices: list[str] = Field(default_factory=list)
    state_delta: StateDelta | None = None
    combat_log: list[str] | None = None
    error: str | None = None
    fallback: bool = False
