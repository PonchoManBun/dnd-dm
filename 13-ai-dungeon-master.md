# 13 — AI Dungeon Master

## Role

The AI DM is not a feature — it **is** the game engine. Claude Code CLI reads D&D 5e SRD markdown files, maintains game state, rolls dice, resolves mechanics, controls every NPC, generates narrative, and adjudicates every player action. Phaser renders what the DM decides.

## DM Archetypes

At game start, the player chooses a DM personality:

| Archetype | Style |
|-----------|-------|
| **Classic Storyteller** | Balanced narrative and challenge. The default experience. |
| **Cruel Taskmaster** | Harder encounters, fewer drops, more ambushes, less mercy. |
| **Whimsical Trickster** | Chaotic encounters, absurd NPCs, dark humor cranked up. |
| **Grim Historian** | Lore-heavy. Deep world-building. Every ruin has a history. |
| **Merciful Guide** | Easier. More hints, generous loot, forgiving DM calls. |

## The DM Response Cycle

This is the core game loop:

1. **Player takes action** (move, attack, speak, interact, type custom action).
2. **Input locks.** Loading indicator appears.
3. **Claude processes.** Reads relevant SRD rules, current game state, NPC context, and faction state.
4. **DM responds.** Narrative text appears in the DM panel. Game state updates. Animations play.
5. **Reaction window.** If applicable, the player can use reactions (Shield, Counterspell, etc.) or skip.
6. **Turn resolves.** Input unlocks. Player's turn again.

## DM Input Options

The player always sees:

- **Contextual choices** — DM-suggested actions appropriate to the situation
- **"Do something else..."** — Free-text input. Type anything. The DM will adjudicate it.

This is what makes TWW a D&D game, not a menu-driven RPG. The player can always try something creative.

## Level-Up Narration

The DM narrates level-ups in character, explains options as if a mentor is speaking, and lets the player choose. No raw stat screens.
