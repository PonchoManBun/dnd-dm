"""POST /action endpoint — the core DM response cycle."""

from __future__ import annotations

import logging
import time
from pathlib import Path

from fastapi import APIRouter, HTTPException

from orchestrator.models import (
    PlayerAction, DmResponse, StateDelta, ActionType, DmArchetype,
    GameState, NarrativeState, LocationState,
)
from orchestrator.engine.ollama_client import (
    OllamaClient, OllamaConnectionError, OllamaTimeoutError, OllamaModelNotFoundError,
)
from orchestrator.engine.template_fallback import (
    generate_fallback_narration,
    generate_fallback_choices,
)
from orchestrator.engine.debug_logger import get_debug_logger, estimate_tokens

logger = logging.getLogger(__name__)

router = APIRouter()

# Game state — in-memory for Phase 2, loaded from disk on startup
_game_state: GameState | None = None
_ollama: OllamaClient | None = None


def get_game_state() -> GameState:
    """Get current game state, creating a default if none exists."""
    global _game_state
    if _game_state is None:
        _game_state = GameState()
    return _game_state


def set_game_state(state: GameState) -> None:
    """Replace the current game state (used for testing and initialization)."""
    global _game_state
    _game_state = state


def get_ollama_client() -> OllamaClient:
    """Get or create the Ollama client."""
    global _ollama
    if _ollama is None:
        _ollama = OllamaClient()
    return _ollama


def set_ollama_client(client: OllamaClient) -> None:
    """Replace the Ollama client (used for testing)."""
    global _ollama
    _ollama = client


def parse_llm_response(raw: str) -> tuple[str, list[str]]:
    """Parse the LLM's raw text into narration and choices.

    Expected format:
    NARRATION: <text>
    CHOICES:
    1. <choice>
    2. <choice>
    3. <choice>

    Falls back gracefully if format isn't followed:
    - If no NARRATION: prefix, treat the whole text as narration
    - If no CHOICES: section, return empty choices list
    """
    narration = ""
    choices: list[str] = []

    # Try to split on NARRATION: and CHOICES:
    raw = raw.strip()

    if "NARRATION:" in raw:
        parts = raw.split("NARRATION:", 1)
        after_narration = parts[1]

        if "CHOICES:" in after_narration:
            narration_part, choices_part = after_narration.split("CHOICES:", 1)
            narration = narration_part.strip()

            # Parse numbered choices
            for line in choices_part.strip().split("\n"):
                line = line.strip()
                # Strip leading number + dot: "1. Do something" -> "Do something"
                if line and len(line) > 2 and line[0].isdigit() and line[1] in ".)":
                    choices.append(line[2:].strip())
                elif line and len(line) > 3 and line[:2].replace(".", "").isdigit():
                    # Handle "10. ..."
                    idx = line.find(".")
                    if idx > 0:
                        choices.append(line[idx + 1:].strip())
        else:
            narration = after_narration.strip()
    else:
        # No structured format — treat everything as narration
        narration = raw

    return narration, choices


@router.post("/action", response_model=DmResponse)
async def handle_action(action: PlayerAction) -> DmResponse:
    """Process a player action through the full DM response cycle.

    Flow:
    1. Load current game state
    2. Apply rules engine for mechanical resolution (attacks, checks, etc.)
    3. Build LLM prompt from archetype + state + action + history
    4. Call Ollama for narration
    5. Parse LLM response into narration + choices
    6. Update game state (narrative history, turn number)
    7. Return DmResponse
    """
    state = get_game_state()
    rules_result: str | None = None
    state_delta: StateDelta | None = None
    combat_log: list[str] | None = None

    # --- Step 2: Apply rules for mechanical actions ---
    if action.action_type == ActionType.ATTACK and action.target:
        # For Phase 2, use simple defaults. Full combat integration comes later.
        from orchestrator.engine.rules import resolve_attack
        from orchestrator.models.enums import Ability, DamageType

        extra = action.extra or {}
        target_ac = extra.get("target_ac", 13)
        weapon_dice = extra.get("weapon_dice", 1)
        weapon_sides = extra.get("weapon_sides", 8)
        attacker_name = extra.get("attacker", state.character.name or "Player")

        result = resolve_attack(
            state.character,
            target_ac=target_ac,
            weapon_dice=weapon_dice,
            weapon_sides=weapon_sides,
            damage_type=DamageType.SLASHING,
            ability=Ability.STRENGTH,
            proficient=True,
        )
        rules_result = (
            f"{attacker_name} attacks {action.target}: "
            f"{result.attack_description}"
        )
        if result.hit:
            rules_result += f" | {result.damage_description}"
            state_delta = StateDelta(custom={"attack_hit": True, "damage": result.damage})
            combat_log = [result.attack_description, result.damage_description]
        else:
            state_delta = StateDelta(custom={"attack_hit": False})
            combat_log = [result.attack_description]

    elif action.action_type == ActionType.MOVE:
        extra = action.extra or {}
        mover = extra.get("mover", state.character.name or "Player")
        direction = action.direction or "forward"
        rules_result = f"{mover} moves {direction}."
        combat_log = [rules_result]

    elif action.action_type == ActionType.REST:
        extra = action.extra or {}
        character_name = extra.get("character", state.character.name or "Player")
        rest_type = extra.get("rest_type", "short")

        if rest_type == "long":
            # Long rest: restore all HP, hit dice, and spell slots
            healed = state.character.max_hp - state.character.current_hp
            state.character.current_hp = state.character.max_hp
            state.character.hit_dice_remaining = state.character.level
            for lvl in state.character.spell_slots_max:
                state.character.spell_slots[lvl] = state.character.spell_slots_max[lvl]
            rules_result = (
                f"{character_name} takes a long rest. "
                f"HP restored to {state.character.max_hp}/{state.character.max_hp}"
                + (f" (+{healed} HP)." if healed > 0 else ".")
            )
            state_delta = StateDelta(hp_change=healed)
        else:
            # Short rest: spend hit dice to heal (simplified: heal 1d hit_die + CON mod)
            from orchestrator.engine import dice as dice_mod
            from orchestrator.models.enums import Ability, CLASS_DATA

            if state.character.hit_dice_remaining > 0:
                class_info = CLASS_DATA[state.character.dnd_class]
                hit_die = class_info.hit_die
                con_mod = state.character.get_modifier(Ability.CONSTITUTION)
                healed = max(1, dice_mod.roll(1, hit_die) + con_mod)
                old_hp = state.character.current_hp
                state.character.current_hp = min(
                    state.character.max_hp, state.character.current_hp + healed
                )
                actual_heal = state.character.current_hp - old_hp
                state.character.hit_dice_remaining -= 1
                rules_result = (
                    f"{character_name} takes a short rest, spending a hit die. "
                    f"Healed {actual_heal} HP "
                    f"({old_hp} -> {state.character.current_hp}/{state.character.max_hp})."
                )
                state_delta = StateDelta(hp_change=actual_heal)
            else:
                rules_result = (
                    f"{character_name} takes a short rest but has no hit dice remaining."
                )
                state_delta = StateDelta(hp_change=0)

        combat_log = [rules_result]

    elif action.action_type == ActionType.CAST_SPELL:
        from orchestrator.engine.spells import resolve_spell

        extra = action.extra or {}
        spell_name = extra.get("spell_name", action.target or "")
        slot_level = extra.get("slot_level")  # None = use spell's base level
        target_ac = extra.get("target_ac", 13)
        target_save_mod = extra.get("target_save_modifier", 0)
        caster_name = extra.get("caster", state.character.name or "Player")

        if not spell_name:
            rules_result = f"{caster_name} tries to cast a spell, but no spell was specified."
            combat_log = [rules_result]
        else:
            spell_result = resolve_spell(
                state.character,
                spell_name,
                slot_level=slot_level,
                target_ac=target_ac,
                target_save_modifier=target_save_mod,
            )

            # Consume spell slot (cantrips cost nothing)
            slot_error: str | None = None
            if spell_result.slot_used > 0:
                current_slots = state.character.spell_slots.get(spell_result.slot_used, 0)
                if current_slots <= 0:
                    slot_error = (
                        f"{caster_name} has no level {spell_result.slot_used} "
                        f"spell slots remaining."
                    )
                else:
                    state.character.spell_slots[spell_result.slot_used] = current_slots - 1

            if slot_error:
                rules_result = slot_error
                combat_log = [slot_error]
            else:
                target_name = action.target or "the target"
                rules_result = f"{caster_name} casts {spell_result.spell_name} at {target_name}: {spell_result.description}"

                custom: dict = {"spell_name": spell_result.spell_name, "spell_hit": spell_result.hit}
                if spell_result.hit:
                    custom["damage"] = spell_result.damage
                    custom["damage_type"] = spell_result.damage_type
                if spell_result.slot_used > 0:
                    custom["slot_used"] = spell_result.slot_used
                    custom["slots_remaining"] = state.character.spell_slots[spell_result.slot_used]

                state_delta = StateDelta(custom=custom)
                combat_log = [spell_result.description]

    # --- Delegate NPC speech to dedicated NPC system ---
    if action.action_type == ActionType.SPEAK and action.target:
        try:
            from orchestrator.engine.npc_context import get_npc_profile
            from orchestrator.routes.npc import npc_speak, NpcSpeakRequest

            # Only delegate if the target is a known NPC
            if get_npc_profile(action.target) is not None:
                npc_request = NpcSpeakRequest(
                    npc_id=action.target,
                    message=action.message or "Hello",
                    speaker=state.character.name or "adventurer",
                )
                npc_response = await npc_speak(npc_request)
                # Update game state
                state.narrative.turn_number += 1
                state.narrative.current_narration = npc_response.narration
                state.narrative.current_choices = npc_response.choices
                state.narrative.history.append({
                    "turn": state.narrative.turn_number,
                    "action": f"speak {action.target}: \"{action.message or ''}\"",
                    "response": npc_response.narration[:200],
                    "compressed": False,
                })
                return DmResponse(
                    narration=npc_response.narration,
                    choices=npc_response.choices,
                    error=npc_response.error,
                    fallback=npc_response.fallback,
                )
        except Exception as e:
            logger.warning("NPC system delegation failed: %s, falling back to DM", e)
            # Fall through to standard DM handling

    # --- Step 3 & 4: Build prompt and call LLM ---
    narration = ""
    choices: list[str] = []
    error: str | None = None
    used_fallback = False
    prompt_text = ""
    response_text = ""
    t_start = time.perf_counter()

    try:
        from orchestrator.engine.prompt_builder import build_dm_prompt
        from orchestrator.engine.npc_context import get_npc_profile, get_npc_name

        npc_profile = None
        npc_name = None
        if action.action_type == ActionType.SPEAK and action.target:
            npc_name = action.target
            # Look up NPC profile from the profile store first
            npc_profile = get_npc_profile(npc_name)
            # Fall back to extra data sent by the client if not in store
            if npc_profile is None and action.extra:
                npc_profile = action.extra
            # Use the canonical display name if we found a profile
            if npc_profile:
                npc_name = npc_profile.get("name", npc_name)

        system_prompt, user_prompt = build_dm_prompt(
            archetype=state.narrative.dm_archetype,
            action=action,
            character=state.character,
            location=state.location,
            history=state.narrative.history,
            rules_result=rules_result,
            npc_profile=npc_profile,
            npc_name=npc_name,
        )
        prompt_text = system_prompt + user_prompt

        client = get_ollama_client()
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
        raw_response = await client.generate_chat(messages, max_tokens=600, temperature=0.7)
        response_text = raw_response
        narration, choices = parse_llm_response(raw_response)

    except (OllamaConnectionError, OllamaTimeoutError, OllamaModelNotFoundError) as e:
        logger.warning("LLM unavailable: %s — using template fallback", e)
        error = f"LLM unavailable: {type(e).__name__}"
        narration = generate_fallback_narration(
            action.action_type,
            target=action.target,
            direction=action.direction,
            message=action.message,
            rules_result=rules_result,
        )
        choices = generate_fallback_choices(action.action_type)
        used_fallback = True
    except ImportError:
        # prompt_builder not available yet — use fallback
        logger.warning("prompt_builder not available — using template fallback")
        narration = generate_fallback_narration(
            action.action_type,
            target=action.target,
            direction=action.direction,
            message=action.message,
            rules_result=rules_result,
        )
        choices = generate_fallback_choices(action.action_type)
        used_fallback = True
    except Exception as e:
        logger.error("Unexpected error in DM response cycle: %s", e, exc_info=True)
        error = f"Internal error: {str(e)}"
        narration = generate_fallback_narration(
            action.action_type,
            target=action.target,
            direction=action.direction,
            message=action.message,
            rules_result=rules_result,
        )
        choices = generate_fallback_choices(action.action_type)
        used_fallback = True

    # --- Debug logging ---
    t_elapsed_ms = (time.perf_counter() - t_start) * 1000
    debug_log = get_debug_logger()
    debug_log.log(
        action_type=action.action_type.value,
        target=action.target,
        prompt_tokens_est=estimate_tokens(prompt_text) if prompt_text else 0,
        response_tokens_est=estimate_tokens(response_text) if response_text else 0,
        latency_ms=t_elapsed_ms,
        narration_snippet=narration,
        error=error,
    )

    # --- Step 6: Update game state ---
    state.narrative.turn_number += 1
    state.narrative.current_narration = narration
    state.narrative.current_choices = choices

    # Add exchange to history
    action_summary = f"{action.action_type.value}"
    if action.target:
        action_summary += f" {action.target}"
    if action.message:
        action_summary += f': "{action.message}"'

    state.narrative.history.append({
        "turn": state.narrative.turn_number,
        "action": action_summary,
        "response": narration[:200],  # Truncate for history storage
        "compressed": False,
    })

    # --- Step 7: Return response ---
    return DmResponse(
        narration=narration,
        choices=choices,
        state_delta=state_delta,
        combat_log=combat_log,
        error=error,
        fallback=used_fallback,
    )


def _fallback_narration(action: PlayerAction, rules_result: str | None) -> str:
    """Generate basic narration when LLM is unavailable.

    .. deprecated:: Use :func:`generate_fallback_narration` from
       ``template_fallback`` instead.  Kept for backward compatibility
       in tests.
    """
    return generate_fallback_narration(
        action.action_type,
        target=action.target,
        direction=action.direction,
        message=action.message,
        rules_result=rules_result,
    )


def _fallback_choices(action: PlayerAction) -> list[str]:
    """Generate basic choices when LLM is unavailable.

    .. deprecated:: Use :func:`generate_fallback_choices` from
       ``template_fallback`` instead.  Kept for backward compatibility
       in tests.
    """
    return generate_fallback_choices(action.action_type)
