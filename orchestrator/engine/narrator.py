"""Lightweight DM narrator agent for embellishing base descriptions.

Takes Forge-authored room/combat descriptions and adds sensory details
via a compact LLM prompt (~160 tokens total). Falls back to base text
if Ollama is unavailable or takes >3s.
"""

from __future__ import annotations

import logging
import time

from orchestrator.engine.ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaModelNotFoundError,
    OllamaTimeoutError,
)

logger = logging.getLogger(__name__)

# Shared Ollama client
_ollama: OllamaClient | None = None

# Narrator timeout — stricter than NPC speech since we have fallback text
NARRATOR_TIMEOUT = 3.0


def _get_ollama() -> OllamaClient:
    global _ollama
    if _ollama is None:
        _ollama = OllamaClient(timeout=NARRATOR_TIMEOUT)
    return _ollama


async def embellish(
    base_description: str,
    event_type: str = "room_entry",
    archetype: str = "storyteller",
    player_summary: str = "",
) -> str:
    """Embellish a base description with sensory details via LLM.

    Args:
        base_description: The Forge-authored factual description.
        event_type: One of "room_entry", "combat_result", "trap_trigger", "room_cleared".
        archetype: DM archetype for tone matching.
        player_summary: Brief player context (e.g., "Level 3 Human Fighter, HP 28/34").

    Returns:
        Embellished text, or the base_description unchanged on fallback.
    """
    if not base_description or not base_description.strip():
        return base_description

    system_prompt = (
        f"You are a D&D narrator. Embellish the base description with sensory details. "
        f"2-3 sentences. Match {archetype} tone. No mechanics. No meta-commentary."
    )

    user_prompt = f"BASE: {base_description}"
    if player_summary:
        user_prompt += f"\nPLAYER: {player_summary}"
    user_prompt += f"\nEVENT: {event_type}"
    user_prompt += "\nEmbellish:"

    t_start = time.perf_counter()

    try:
        client = _get_ollama()
        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ]
        result = await client.generate_chat(messages, max_tokens=60, temperature=0.8)
        t_elapsed = (time.perf_counter() - t_start) * 1000

        if result and result.strip():
            logger.info("Narrator embellished in %.0fms", t_elapsed)
            return result.strip()

        logger.warning("Narrator returned empty response, using base text")
        return base_description

    except (OllamaConnectionError, OllamaTimeoutError, OllamaModelNotFoundError) as e:
        t_elapsed = (time.perf_counter() - t_start) * 1000
        logger.warning("Narrator LLM unavailable (%.0fms): %s — using base text", t_elapsed, e)
        return base_description
    except Exception as e:
        logger.error("Narrator unexpected error: %s", e, exc_info=True)
        return base_description
