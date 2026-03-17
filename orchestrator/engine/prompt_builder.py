"""Assembles LLM prompts from archetype template, game state, action, and history."""

from __future__ import annotations

from pathlib import Path

from orchestrator.models.enums import DmArchetype
from orchestrator.models.character import CharacterState
from orchestrator.models.game_state import LocationState
from orchestrator.models.actions import PlayerAction

# Token budget constants
CONTEXT_WINDOW = 2048
SYSTEM_PROMPT_BUDGET = 300
RESPONSE_BUDGET = 600
MIN_RESPONSE_BUDGET = 400

# Directory where .txt templates live
PROMPTS_DIR = Path(__file__).parent.parent / "prompts"


def load_archetype_prompt(archetype: DmArchetype, max_response_tokens: int) -> str:
    """Load archetype template and fill in the response token placeholder."""
    path = PROMPTS_DIR / f"{archetype.value}.txt"
    template = path.read_text(encoding="utf-8")
    return template.replace("{max_response_tokens}", str(max_response_tokens))


def format_state_summary(character: CharacterState, location: LocationState) -> str:
    """Build a compact state summary for the LLM context.

    Example output:
    PLAYER STATE: Aldric, Level 3 Human Fighter | HP: 28/34 | AC: 18 | Conditions: none
    LOCATION: The Welcome Wench tavern (tavern) at position (5, 3)
    """
    conditions_str = (
        ", ".join(c.value for c in character.conditions)
        if character.conditions
        else "none"
    )
    lines = [
        f"PLAYER STATE: {character.name}, Level {character.level} "
        f"{character.race.value.replace('_', ' ').title()} {character.dnd_class.value.title()} | "
        f"HP: {character.current_hp}/{character.max_hp} | AC: {character.base_ac} | "
        f"Conditions: {conditions_str}",
        f"LOCATION: {location.location_name or location.location_id} ({location.map_type}) "
        f"at position ({location.position_x}, {location.position_y})",
    ]
    return "\n".join(lines)


def format_action_context(
    action: PlayerAction, rules_result: str | None = None
) -> str:
    """Format the player's action and any rules engine results for the prompt.

    Example output:
    PLAYER ACTION: attack targeting Goblin
    DICE RESULTS: d20(15)+5=20 vs AC 13 HIT! 1d8(6)+3=9 slashing
    """
    parts = [f"PLAYER ACTION: {action.action_type.value}"]
    if action.target:
        parts[0] += f" targeting {action.target}"
    if action.message:
        parts[0] += f' — "{action.message}"'
    if action.direction:
        parts[0] += f" direction: {action.direction}"
    if rules_result:
        parts.append(f"DICE RESULTS: {rules_result}")
    return "\n".join(parts)


def format_npc_context(npc_name: str, npc_profile: dict) -> str:
    """Format NPC context for conversation prompts.

    npc_profile should have keys: role, personality, knowledge (all strings).
    """
    lines = [
        f"NPC: {npc_name}",
        f"Role: {npc_profile.get('role', 'unknown')}",
        f"Personality: {npc_profile.get('personality', 'neutral')}",
    ]
    knowledge = npc_profile.get("knowledge", "")
    if knowledge:
        lines.append(f"Knows: {knowledge}")
    return "\n".join(lines)


def estimate_tokens(text: str) -> int:
    """Approximate token count (~4 chars per token)."""
    return max(1, len(text) // 4)


def build_dm_prompt(
    archetype: DmArchetype,
    action: PlayerAction,
    character: CharacterState,
    location: LocationState,
    history: list[dict],
    rules_result: str | None = None,
    npc_profile: dict | None = None,
    npc_name: str | None = None,
) -> tuple[str, str]:
    """Build the complete prompt for the LLM.

    Returns:
        A (system_prompt, user_prompt) tuple ready for LLM consumption.
        system_prompt goes in the system role, user_prompt in the user role.
    """
    # 1. Calculate available space
    remaining = CONTEXT_WINDOW - SYSTEM_PROMPT_BUDGET - RESPONSE_BUDGET

    # 2. Build action context (always included)
    action_text = format_action_context(action, rules_result)
    remaining -= estimate_tokens(action_text)

    # 3. Build state summary (always included)
    state_text = format_state_summary(character, location)
    remaining -= estimate_tokens(state_text)

    # 4. Optional NPC context
    npc_text = ""
    if npc_profile and npc_name:
        npc_text = format_npc_context(npc_name, npc_profile)
        remaining -= estimate_tokens(npc_text)

    # 5. Fill remaining budget with history (most recent first)
    from orchestrator.engine.context_manager import compress_history

    history_text = compress_history(history, max_tokens=max(0, remaining))

    # 6. Compute actual response budget
    total_context = (
        estimate_tokens(state_text)
        + estimate_tokens(action_text)
        + estimate_tokens(npc_text)
        + estimate_tokens(history_text)
    )
    actual_response = max(
        MIN_RESPONSE_BUDGET, CONTEXT_WINDOW - SYSTEM_PROMPT_BUDGET - total_context
    )

    # 7. Load system prompt with response budget
    system_prompt = load_archetype_prompt(archetype, actual_response)

    # 8. Assemble user prompt
    user_parts = [state_text]
    if history_text:
        user_parts.append(history_text)
    if npc_text:
        user_parts.append(npc_text)
    user_parts.append(action_text)
    user_prompt = "\n\n".join(user_parts)

    return system_prompt, user_prompt
