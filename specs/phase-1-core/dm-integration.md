# Phase 1: Core Proof of Concept — DM Integration

> Extracted from [GDD 13 — AI Dungeon Master](../reference/13-ai-dungeon-master.md)

## The DM's Role

The AI DM is not a feature — it **is** the game engine. Claude Code CLI reads D&D 5e SRD markdown files, maintains game state, rolls dice, resolves mechanics, controls every NPC, generates narrative, and adjudicates every player action. Phaser renders what the DM decides.

## The DM Response Cycle

This is the core game loop that Phase 1 must prove:

1. **Player takes action** — types a message or clicks a choice button.
2. **Input locks.** Loading indicator appears.
3. **Claude processes.** Reads the player action, current game state, and any relevant context.
4. **DM responds.** Returns a JSON `NarrativeState` with text, choices, and optional dice rolls.
5. **Client renders.** Narrative text appears in the DM panel. Choice buttons appear.
6. **Input unlocks.** Player's turn again.

## DM Input Options

The player always sees:

- **Contextual choices** — DM-suggested actions appropriate to the situation (from `NarrativeState.choices`)
- **"Do something else..."** — Free-text input. Type anything. The DM will adjudicate it.

This is what makes TWW a D&D game, not a menu-driven RPG. The player can always try something creative.

## Phase 1 Implementation

### Claude CLI Invocation

The server spawns Claude Code CLI as a child process (or uses the API). The prompt includes:
1. System context: "You are a D&D 5e Dungeon Master for The Welcome Wench..."
2. Current game state (JSON)
3. The player's action
4. Instruction to respond with valid JSON matching the `NarrativeState` schema

### Response Parsing

The server:
1. Receives Claude's text output
2. Extracts the JSON block
3. Validates it against the `NarrativeState` interface
4. Forwards valid JSON to the client via Socket.IO
5. On parse failure: returns a fallback error response

### Minimal DM Prompt (Phase 1)

For the proof of concept, the DM prompt is simple:

```
You are the Dungeon Master for The Welcome Wench, a D&D 5e dungeon crawler.
The player is in the tavern. Respond to their action.

Respond with JSON matching this schema:
{
  "text": "Your narrative response",
  "choices": ["Option 1", "Option 2", "Option 3"],
  "allowFreeText": true,
  "diceRolls": [],
  "combatLog": [],
  "ttsMarked": false
}

Current state: [game state JSON]
Player action: [player input]
```

The prompt grows in sophistication in later phases as we add SRD rules, character context, combat state, etc.

## DM Archetypes (Deferred to Phase 2)

At game start, the player will choose a DM personality. For Phase 1, use the default "Classic Storyteller" personality. The full archetype table:

| Archetype | Style |
|-----------|-------|
| **Classic Storyteller** | Balanced narrative and challenge. The default. |
| **Cruel Taskmaster** | Harder encounters, fewer drops, more ambushes. |
| **Whimsical Trickster** | Chaotic encounters, absurd NPCs, dark humor. |
| **Grim Historian** | Lore-heavy. Deep world-building. |
| **Merciful Guide** | Easier. More hints, generous loot. |

## Level-Up Narration (Deferred to Phase 4)

The DM narrates level-ups in character, explains options as if a mentor is speaking, and lets the player choose. No raw stat screens.
