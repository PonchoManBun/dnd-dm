"""NPC conversation endpoints — per-NPC LLM agent system.

POST /npc/speak      — Freeform NPC conversation
POST /npc/skill_check — Attempt Persuasion/Intimidation/Deception
GET  /npc/status/{id} — Current NPC attitude, mode, interaction count
GET  /npcs            — All NPC profiles (merged hand-authored + Forge)
"""

from __future__ import annotations

import logging
import time

from fastapi import APIRouter
from pydantic import BaseModel, Field

from orchestrator.engine import npc_agent_registry as registry
from orchestrator.engine.npc_context import get_npc_profile, list_npcs, load_npc_profiles
from orchestrator.engine.npc_knowledge import get_knowledge_for_attitude
from orchestrator.engine.npc_mode_detector import detect_mode
from orchestrator.engine.npc_prompt_builder import build_choices_for_mode, build_npc_prompt
from orchestrator.engine.npc_skill_checks import resolve_npc_skill_check
from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaModelNotFoundError,
    OllamaTimeoutError,
)
from orchestrator.models.npc_agent import ConversationMode, NpcAttitude

logger = logging.getLogger(__name__)

router = APIRouter()

# Shared Ollama client — will be created on first use
_ollama: OllamaClient | None = None


def _get_ollama() -> OllamaClient:
    global _ollama
    if _ollama is None:
        _ollama = OllamaClient(num_ctx=1024)
    return _ollama


# ---------------------------------------------------------------------------
# Request / Response models
# ---------------------------------------------------------------------------


class NpcSpeakRequest(BaseModel):
    npc_id: str
    message: str
    speaker: str = "adventurer"


class NpcSkillCheckRequest(BaseModel):
    npc_id: str
    skill: str  # "persuasion", "intimidation", "deception"


class NpcResponse(BaseModel):
    narration: str
    choices: list[str] = Field(default_factory=list)
    npc_id: str
    mode: str = "chatting"
    attitude: str = "indifferent"
    skill_check_result: dict | None = None
    error: str | None = None
    fallback: bool = False


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.post("/npc/speak", response_model=NpcResponse)
async def npc_speak(request: NpcSpeakRequest) -> NpcResponse:
    """Handle freeform NPC conversation via per-NPC LLM agent."""
    t_start = time.perf_counter()

    # Look up NPC profile
    profile = get_npc_profile(request.npc_id)
    if not profile:
        return NpcResponse(
            narration="You don't see anyone by that name.",
            npc_id=request.npc_id,
            error=f"Unknown NPC: {request.npc_id}",
            fallback=True,
        )

    npc_name = profile.get("name", request.npc_id)

    # Get or create NPC agent state
    default_attitude_str = profile.get("attitude_default", "indifferent")
    try:
        default_attitude = NpcAttitude(default_attitude_str)
    except ValueError:
        default_attitude = NpcAttitude.INDIFFERENT

    state = registry.get_or_create(request.npc_id, default_attitude)
    registry.increment_interaction(request.npc_id)

    # Tick deception if active
    registry.tick_deception(request.npc_id)

    # Detect conversation mode from player message
    detected_mode = detect_mode(request.message, profile, state.mode, state.attitude)
    registry.set_mode(request.npc_id, detected_mode)
    state = registry.get_or_create(request.npc_id)  # refresh

    # Build compact prompt
    system_prompt, user_prompt = build_npc_prompt(profile, state, request.message)

    # Call Ollama
    narration = ""
    error: str | None = None
    used_fallback = False

    try:
        client = _get_ollama()
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
        raw_response = await client.generate_chat(messages, max_tokens=80, temperature=0.8)
        # Clean up the response — strip any meta-commentary
        narration = raw_response.strip()

    except (OllamaConnectionError, OllamaTimeoutError, OllamaModelNotFoundError) as e:
        logger.warning("NPC LLM unavailable for '%s': %s", request.npc_id, e)
        error = f"LLM unavailable: {type(e).__name__}"
        # Fallback: use mode-specific greeting or profile greeting
        mode_prompts = profile.get("mode_prompts", {})
        narration = mode_prompts.get(state.mode.value, profile.get("greeting", "..."))
        used_fallback = True
    except Exception as e:
        logger.error("Unexpected error in NPC speak: %s", e, exc_info=True)
        error = f"Internal error: {str(e)}"
        narration = profile.get("greeting", "...")
        used_fallback = True

    # Clear skill context after it's been used
    state.skill_context = None

    # Wrap NPC dialogue with BBCode formatting
    formatted = f'[color=#d9d566]{npc_name}[/color] says, "[i]{narration}[/i]"'

    # Generate deterministic choices
    choices = build_choices_for_mode(state.mode, profile, state)

    t_elapsed = (time.perf_counter() - t_start) * 1000
    logger.info(
        "NPC '%s' responded in %.0fms (mode=%s, attitude=%s, fallback=%s)",
        request.npc_id, t_elapsed, state.mode.value, state.attitude.value, used_fallback,
    )

    return NpcResponse(
        narration=formatted,
        choices=choices,
        npc_id=request.npc_id,
        mode=state.mode.value,
        attitude=state.attitude.value,
        error=error,
        fallback=used_fallback,
    )


@router.post("/npc/skill_check", response_model=NpcResponse)
async def npc_skill_check(request: NpcSkillCheckRequest) -> NpcResponse:
    """Attempt a social skill check against an NPC."""
    profile = get_npc_profile(request.npc_id)
    if not profile:
        return NpcResponse(
            narration="You don't see anyone by that name.",
            npc_id=request.npc_id,
            error=f"Unknown NPC: {request.npc_id}",
            fallback=True,
        )

    # Need character state for the check
    from orchestrator.routes.action import get_game_state
    game_state = get_game_state()

    result = resolve_npc_skill_check(
        game_state.character,
        request.npc_id,
        request.skill,
    )

    npc_name = profile.get("name", request.npc_id)
    state = registry.get_or_create(request.npc_id)

    # Build narration from the skill check result
    outcome = "succeeds" if result.success else "fails"
    narration = (
        f"[color=#6cb4c4]{request.skill.title()} check ({result.roll_description})[/color]\n"
        f"The attempt {outcome}. "
        f"[color=#d9d566]{npc_name}[/color]'s attitude: "
        f"{result.old_attitude} \u2192 {result.new_attitude}"
    )

    choices = build_choices_for_mode(state.mode, profile, state)

    return NpcResponse(
        narration=narration,
        choices=choices,
        npc_id=request.npc_id,
        mode=state.mode.value,
        attitude=result.new_attitude,
        skill_check_result={
            "success": result.success,
            "skill": result.skill,
            "roll_total": result.roll_total,
            "dc": result.dc,
            "roll_description": result.roll_description,
            "old_attitude": result.old_attitude,
            "new_attitude": result.new_attitude,
        },
    )


@router.get("/npc/status/{npc_id}")
async def npc_status(npc_id: str) -> dict:
    """Get current NPC state."""
    state = registry.get_or_create(npc_id)
    return state.model_dump()


@router.get("/npcs")
async def list_all_npcs() -> dict:
    """List all NPC profiles merged from hand-authored and Forge sources."""
    # Ensure profiles are loaded
    npc_ids = list_npcs()
    result: dict[str, dict] = {}
    for npc_id in npc_ids:
        profile = get_npc_profile(npc_id)
        if profile:
            # Include current agent state if it exists
            state = registry.get_or_create(npc_id)
            result[npc_id] = {
                **profile,
                "agent_state": state.model_dump(),
            }
    return result
