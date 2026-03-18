"""In-memory registry for NPC agent states."""

from __future__ import annotations

import logging
from typing import Any

from orchestrator.models.npc_agent import (
    ATTITUDE_ORDER,
    ConversationMode,
    NpcAgentState,
    NpcAttitude,
)

logger = logging.getLogger(__name__)

# Singleton state store
_registry: dict[str, NpcAgentState] = {}


def get_or_create(npc_id: str, default_attitude: NpcAttitude | None = None) -> NpcAgentState:
    """Get existing NPC state or create a new one with defaults."""
    if npc_id not in _registry:
        attitude = default_attitude or NpcAttitude.INDIFFERENT
        _registry[npc_id] = NpcAgentState(npc_id=npc_id, attitude=attitude)
        logger.info("Created NPC agent state for '%s' (attitude=%s)", npc_id, attitude.value)
    return _registry[npc_id]


def update_attitude(npc_id: str, steps: int) -> NpcAttitude:
    """Shift an NPC's attitude by the given number of steps (+1 = friendlier, -1 = hostile-er).

    Returns the new attitude. Clamps at HOSTILE/HELPFUL.
    """
    state = get_or_create(npc_id)
    current_index = ATTITUDE_ORDER.index(state.attitude)
    new_index = max(0, min(len(ATTITUDE_ORDER) - 1, current_index + steps))
    state.attitude = ATTITUDE_ORDER[new_index]
    logger.info("NPC '%s' attitude shifted %+d → %s", npc_id, steps, state.attitude.value)
    return state.attitude


def set_mode(npc_id: str, mode: ConversationMode) -> None:
    """Set the conversation mode for an NPC."""
    state = get_or_create(npc_id)
    if state.mode != mode:
        logger.info("NPC '%s' mode changed: %s → %s", npc_id, state.mode.value, mode.value)
        state.mode = mode


def increment_interaction(npc_id: str) -> int:
    """Increment and return the interaction count for an NPC."""
    state = get_or_create(npc_id)
    state.interaction_count += 1
    return state.interaction_count


def set_deception(npc_id: str, turns: int) -> None:
    """Mark an NPC as under a deception effect for N turns."""
    state = get_or_create(npc_id)
    state.deception_active = True
    state.deception_turns_remaining = turns


def tick_deception(npc_id: str) -> bool:
    """Decrement deception counter. Returns True if deception just expired."""
    state = get_or_create(npc_id)
    if not state.deception_active:
        return False
    state.deception_turns_remaining -= 1
    if state.deception_turns_remaining <= 0:
        state.deception_active = False
        state.deception_turns_remaining = 0
        # Revert the attitude shift from deception (+1 step was fake)
        update_attitude(npc_id, -1)
        logger.info("NPC '%s' deception expired, attitude reverted", npc_id)
        return True
    return False


def serialize() -> dict[str, dict]:
    """Serialize all NPC states for persistence."""
    return {npc_id: state.model_dump() for npc_id, state in _registry.items()}


def deserialize(data: dict[str, dict]) -> None:
    """Restore NPC states from serialized data."""
    global _registry
    _registry = {}
    for npc_id, state_data in data.items():
        _registry[npc_id] = NpcAgentState.model_validate(state_data)
    logger.info("Deserialized %d NPC agent states", len(_registry))


def get_all() -> dict[str, NpcAgentState]:
    """Return all registered NPC states."""
    return dict(_registry)


def reset() -> None:
    """Clear all state (for testing)."""
    global _registry
    _registry = {}
