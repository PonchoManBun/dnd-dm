"""GET /state endpoint — returns current game state to Godot client."""

from __future__ import annotations

from fastapi import APIRouter

from orchestrator.models import GameState
from orchestrator.routes.action import get_game_state

router = APIRouter()


@router.get("/state", response_model=GameState)
async def get_state() -> GameState:
    """Return the current game state for Godot to render."""
    return get_game_state()
