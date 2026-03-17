"""NPC profile management and context building for conversation prompts."""

from __future__ import annotations

import json
import logging
from pathlib import Path

logger = logging.getLogger(__name__)

# NPC profiles loaded from data file or hardcoded defaults
_npc_profiles: dict[str, dict] = {}

# Default NPC profiles (fallback if no data file)
DEFAULT_NPC_PROFILES: dict[str, dict] = {
    "marta": {
        "name": "Barkeep Marta",
        "role": "tavern owner and barkeep",
        "personality": "Warm but shrewd. Knows everyone's business. Protective of regulars. Speaks plainly with dry humor.",
        "knowledge": "Local rumors, adventurer gossip, cellar problems, room rates. Knows about disappearances on the east road.",
    },
    "old_tom": {
        "name": "Old Tom",
        "role": "retired adventurer and tavern regular",
        "personality": "Grizzled veteran who tells tall tales. Drinks too much. Surprisingly sharp when sober.",
        "knowledge": "Old dungeon layouts, monster weaknesses, outdated tips. Claims to have fought a dragon.",
    },
    "elara": {
        "name": "Elara the Quiet",
        "role": "mysterious hooded traveler",
        "personality": "Speaks rarely but precisely. Observant. Knows more than she lets on. Slight elvish accent.",
        "knowledge": "Arcane lore, regional geography, hidden passages. Hints at quest hooks but never gives straight answers.",
    },
}


def load_npc_profiles(path: str | Path | None = None) -> None:
    """Load NPC profiles from a JSON file, falling back to defaults."""
    global _npc_profiles
    if path:
        try:
            data = json.loads(Path(path).read_text(encoding="utf-8"))
            _npc_profiles = data
            logger.info("Loaded NPC profiles from %s (%d NPCs)", path, len(data))
            return
        except Exception as e:
            logger.warning("Failed to load NPC profiles from %s: %s", path, e)
    _npc_profiles = dict(DEFAULT_NPC_PROFILES)


def get_npc_profile(npc_id: str) -> dict | None:
    """Get an NPC profile by ID (lowercase key).

    Accepts exact keys like "marta", or display-style names like "Marta"
    or "Barkeep Marta" which are normalized to underscore-lowercase form.
    """
    if not _npc_profiles:
        load_npc_profiles()
    # Try exact match first
    if npc_id in _npc_profiles:
        return _npc_profiles[npc_id]
    # Normalize: lowercase, replace spaces with underscores
    npc_id_lower = npc_id.lower().replace(" ", "_")
    if npc_id_lower in _npc_profiles:
        return _npc_profiles[npc_id_lower]
    # Try matching against the "name" field in each profile
    for key, profile in _npc_profiles.items():
        if profile.get("name", "").lower() == npc_id.lower():
            return profile
    return None


def get_npc_name(npc_id: str) -> str:
    """Get the display name for an NPC.

    Returns the profile's "name" field if found, otherwise returns
    the raw npc_id as-is.
    """
    profile = get_npc_profile(npc_id)
    return profile["name"] if profile else npc_id


def list_npcs() -> list[str]:
    """List all NPC IDs (the dictionary keys)."""
    if not _npc_profiles:
        load_npc_profiles()
    return list(_npc_profiles.keys())


def reset_profiles() -> None:
    """Clear loaded profiles (useful for testing)."""
    global _npc_profiles
    _npc_profiles = {}
