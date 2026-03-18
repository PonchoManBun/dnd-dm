# 14 — Multi-Agent NPC System

## Design Principle

**Every NPC is a live conversational agent. No menu trees. No canned dialogue.**

When you talk to the barkeep, the mysterious traveler, or a retired adventurer, the local LLM generates their dialogue in real-time based on their personality, knowledge, and relationship with you. You can say anything via the free-text input in the DM panel. This is a core differentiator — not a side feature.

## Current Architecture

NPC behavior is split across two very different contexts: **tavern NPCs** (fixed positions, hardcoded dialogue with LLM overlay) and **dungeon monsters** (behavior tree AI). The originally planned GDScript state machines (IDLE, PATROL, ALERT, INTERACT, FLEE, COMBAT) are **not implemented** as described.

### Tavern NPCs (Fixed Position, Dialogue-Focused)

Tavern NPCs are placed at fixed grid positions and do not move. They are defined in the tavern scene (`tavern.gd`):

| NPC | Position | Sprite | Character |
|-----|----------|--------|-----------|
| Barkeep Marta | (12, 13) | `player-25` | Tavern owner, warm, gossip |
| Old Tom | (10, 3) | `player-31` | Retired adventurer, grizzled veteran |
| Elara the Quiet | (17, 5) | `player-4` | Mysterious hooded traveler |

Tavern NPCs use a **bump-to-interact** system:
- Walking into an NPC's tile triggers a conversation
- First interaction: full greeting from NPC profile + hardcoded choice buttons
- Repeat interactions: cycling varied acknowledgments + same choices
- If the orchestrator is available, interactions are sent as `speak` actions for freeform LLM dialogue

### Dungeon Monsters (Behavior Tree AI)

Dungeon creatures use `MonsterAI` behavior trees (`game/src/monster_ai.gd`) with four behavior profiles:

- **AGGRESSIVE:** Full behavior tree — check hostility, check visibility, then try ranged combat (equip/load/fire), melee combat with weapon-seeking (find/pathfind/pickup/equip), or basic melee attack + chase. Falls back to random movement or idle.
- **FEARFUL:** Flees from the player when visible.
- **CURIOUS:** Moves toward the player when visible.
- **PASSIVE:** 50% chance to move randomly, otherwise idle.

The behavior tree system includes:
- `BTSequence` / `BTSelector` composite nodes (AND/OR logic)
- Condition checks: `CheckPlayerVisible`, `CheckHostileToPlayer`, `CheckRandomChance`, `CheckIntelligentEnough`
- Actions: `AttackPlayer`, `MoveTowardPlayer`, `FleeFromPlayer`, `MoveRandomly`, `FireAtPlayer`
- Equipment management: `CheckHasRangedWeapon`, `CheckAndEquipRangedWeapon`, `FindNearbyMeleeWeapon`, `MoveToAndPickupWeapon`, `EquipMeleeWeapon`

Monsters do **not** have freeform LLM conversation — they are purely mechanical combatants driven by behavior trees.

## Freeform LLM Conversation

When the player interacts with an NPC and the orchestrator is available, the conversation is handled by the LLM:

1. Godot sends a `speak` action with the NPC's ID and profile data
2. The orchestrator's `handle_action()` looks up the NPC profile via `npc_context.get_npc_profile()`
3. `prompt_builder.build_dm_prompt()` includes NPC context in the prompt:
   ```
   NPC: Barkeep Marta
   Role: tavern owner and barkeep
   Personality: Warm but shrewd. Knows everyone's business...
   Knows: Local rumors, adventurer gossip, cellar problems...
   ```
4. The local LLM generates dialogue in character
5. The response is displayed in the DM panel

**Conversation types supported:**
- **Information gathering:** "What do you know about the crypt?"
- **Social:** "How's business?"
- **Negotiation:** "Can you give me a discount?"
- **Free-text:** The player can type anything via the DM panel input field

### NPC Profiles (npc_context.py)

NPC profiles are managed by `orchestrator/engine/npc_context.py`:

```python
DEFAULT_NPC_PROFILES = {
    "marta": {
        "name": "Barkeep Marta",
        "role": "tavern owner and barkeep",
        "personality": "Warm but shrewd. Knows everyone's business...",
        "knowledge": "Local rumors, adventurer gossip, cellar problems...",
    },
    "old_tom": {
        "name": "Old Tom",
        "role": "retired adventurer and tavern regular",
        "personality": "Grizzled veteran who tells tall tales...",
        "knowledge": "Old dungeon layouts, monster weaknesses...",
    },
    "elara": {
        "name": "Elara the Quiet",
        "role": "mysterious hooded traveler",
        "personality": "Speaks rarely but precisely. Observant...",
        "knowledge": "Arcane lore, regional geography, hidden passages...",
    },
}
```

Profiles can also be loaded from a JSON file. The lookup supports exact IDs, normalized names, and display name matching.

## Faction System

### Current Implementation

The faction system is basic. `World.faction_affinities` tracks numeric reputation per faction type:

```gdscript
var faction_affinities: Dictionary = {
    Factions.Type.HUMAN: 100,
    Factions.Type.CRITTERS: -30,
    Factions.Type.MONSTERS: -100,
    Factions.Type.UNDEAD: -100,
}
```

Faction affinities are:
- Stored on `World` and serialized in save files via `GameStateSerializer`
- Used by monsters to determine hostility (`is_hostile_to()`)
- Modified during gameplay (e.g., attacking a faction member changes affinity)

### What's Not Implemented

- Per-NPC state files with interaction history and flags
- Faction-to-faction relationship matrix
- Reputation threshold triggers (e.g., guards attack on sight below -50)
- Faction resource tracking (members, territory, gold)
- Cross-death faction reputation persistence
- Forge-designed faction narrative arcs

## Companion NPCs

**Planned:** A BG3-style companion system where NPCs can join the player's party as controllable characters:

- Companions would have their own `CharacterData` with class, level, and equipment
- In combat, companions take individual turns in initiative order
- Companions track XP separately
- When a companion first earns XP, they receive their first player class
- The game continues as long as any companion is alive
- A speaker selection dropdown in the HUD would allow choosing which character speaks during NPC dialogue

This system is **not yet implemented**.

## NPC Memory

**Not yet implemented.** The planned per-NPC JSON state files with interaction history, disposition tracking, and knowledge flags are not built. Currently, tavern NPC interactions track only a per-session count to vary repeat greetings.

## Event System

**Not yet implemented as described.** The game has signals for effects, messages, and game state changes, but no formal event broadcast system that NPCs subscribe to for reactions. The behavior tree AI responds to the game state directly (player visibility, hostility) rather than to events.

## Cross-Death Persistence

**Partially implemented.** The memorial wall in the tavern reads from `user://memorial.json` to display fallen heroes, but no system currently writes to this file. NPC state files and cross-death knowledge persistence are planned but not built.
