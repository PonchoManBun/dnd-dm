"""D&D 5e rules engine, Ollama client, context management.

Re-exports the most commonly used symbols so callers can write::

    from orchestrator.engine import ability_modifier, resolve_attack, RollResult
"""

from __future__ import annotations

from orchestrator.engine.context_manager import (
    CONTEXT_WINDOW,
    MAX_RECENT_EXCHANGES,
    MIN_RESPONSE_BUDGET,
    RESPONSE_BUDGET,
    SYSTEM_BUDGET,
    add_exchange,
    calculate_response_budget,
    compress_exchange,
    compress_history,
    format_exchange,
    format_history,
    trim_history,
)
from orchestrator.engine.dice import d20, roll, roll_4d6_drop_lowest
from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaModelNotFoundError,
    OllamaTimeoutError,
)
from orchestrator.engine.npc_context import (
    get_npc_name,
    get_npc_profile,
    list_npcs,
    load_npc_profiles,
)
from orchestrator.engine.template_fallback import (
    generate_fallback_choices,
    generate_fallback_narration,
)
from orchestrator.engine.prompt_builder import (
    build_dm_prompt,
    load_archetype_prompt,
    format_state_summary,
    format_action_context,
    format_npc_context,
)
from orchestrator.engine.rules import (
    AbilityCheckResult,
    AttackResult,
    RollResult,
    SavingThrowResult,
    ability_check,
    ability_modifier,
    apply_condition_speed_modifiers,
    attack_roll,
    calculate_ac,
    d20_roll,
    damage_roll,
    format_damage_roll,
    get_max_hp_for_level,
    has_advantage_against,
    has_disadvantage_from_conditions,
    initiative_roll,
    proficiency_bonus,
    resolve_attack,
    saving_throw,
)

__all__ = [
    # NPC context
    "get_npc_name",
    "get_npc_profile",
    "list_npcs",
    "load_npc_profiles",
    # Template fallback
    "generate_fallback_narration",
    "generate_fallback_choices",
    # Context management
    "add_exchange",
    "compress_exchange",
    "compress_history",
    "trim_history",
    "format_exchange",
    "format_history",
    "calculate_response_budget",
    "CONTEXT_WINDOW",
    "SYSTEM_BUDGET",
    "RESPONSE_BUDGET",
    "MIN_RESPONSE_BUDGET",
    "MAX_RECENT_EXCHANGES",
    # Prompt builder
    "build_dm_prompt",
    "load_archetype_prompt",
    "format_state_summary",
    "format_action_context",
    "format_npc_context",
    # Ollama
    "OllamaClient",
    "OllamaConnectionError",
    "OllamaModelNotFoundError",
    "OllamaTimeoutError",
    # Dice
    "d20",
    "roll",
    "roll_4d6_drop_lowest",
    # Result types
    "AbilityCheckResult",
    "AttackResult",
    "RollResult",
    "SavingThrowResult",
    # Core maths
    "ability_modifier",
    "proficiency_bonus",
    # Rolls
    "d20_roll",
    "attack_roll",
    "damage_roll",
    "format_damage_roll",
    "resolve_attack",
    "saving_throw",
    "ability_check",
    "initiative_roll",
    # AC & HP
    "calculate_ac",
    "get_max_hp_for_level",
    # Conditions
    "has_advantage_against",
    "has_disadvantage_from_conditions",
    "apply_condition_speed_modifiers",
]
