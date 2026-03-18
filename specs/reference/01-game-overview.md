# 01 — Game Overview

## Elevator Pitch

**The Welcome Wench** (TWW) is a single-player 2D pixel art turn-based tactical RPG with a dual-model AI Dungeon Master. A local LLM (Llama 3.2 3B via Ollama) handles real-time DM duties — narration, freeform NPC conversation, contextual choices. Claude generates heavyweight content on demand via Forge Mode — dungeons, monsters, items, quest arcs. Godot 4 renders the world as a dumb client, reading JSON game state and drawing pixels. A Python/FastAPI orchestrator coordinates everything with a deterministic D&D 5e rules engine. Developed and played on a Jetson Orin Nano (8GB).

## Design Pillars

1. **The DM is real.** Two AI models collaborate as Dungeon Master. The local LLM improvises per-turn narration and freeform NPC dialogue. Claude generates structured content (dungeons, quests, NPCs) on demand. Neither follows scripts.
2. **Permadeath matters.** One life. Anti-save-scumming (auto-save deletes on death/resume). Every decision carries weight. The world remembers your dead characters.
3. **Emergent everything.** Quests, factions, NPC relationships, and dungeon layouts are generated — never hand-authored beyond the initial test content. No two runs are alike.
4. **Dark comedy.** The world is dangerous and absurd. Death is frequent and narrated with gallows humor. Think Diablo meets Discworld.

## Core Game Loop

1. **Tavern** — Rest, shop, talk to NPCs (freeform LLM conversation), pick up quests, create characters.
2. **Dungeon** — Explore procedural floors. Tactical D&D 5e combat, traps, puzzles, loot. Roguelike exploration with combat mode switching.
3. **Return or Die** — Survive and return to the tavern with loot, or die and start fresh.

## Architecture

Three layers communicate via JSON:

1. **Client (Godot 4.x + GDScript)** — Dumb renderer. Reads JSON game state, draws pixels, handles input. No game logic, no dice, no combat math. Based on statico/godot-roguelike-example (MIT).
2. **Orchestrator (Python 3.10+ / FastAPI)** — The brain. Routes between LLM, Forge, and rules engine. Maintains all authoritative game state. Deterministic D&D 5e rules engine handles dice, combat math, SRD lookups.
3. **LLM Layer** — Dual-model:
   - **Local LLM (Ollama + Llama 3.2 3B, Q4_K_M)** — Fast DM. Handles per-turn narration, freeform NPC dialogue, contextual choices. ~20-43 tok/s on Jetson.
   - **Forge (Claude Code CLI)** — On-demand quality. Persistent CLI session generates dungeons, monsters, items, quest arcs. Player waits (10-60 sec).

## Party System (Planned)

BG3-style companion system:
- Up to 3 companions + the player character (4 total party members)
- Any NPC can be recruited through conversation
- NPCs use monster stat blocks that convert to full character sheets when recruited
- First XP earned grants the companion their first class level

## Platform & Controls

- **Godot 4.x** native desktop application (GL Compatibility renderer)
- **Keyboard + mouse** — WASD/QEZC for 8-directional grid movement, hotkeys for actions, mouse click for attack/move-to
- **Top-down view** with 16x16 pixel tiles
- **Viewport:** 576x324 base resolution, scaled 2x with integer scaling
- **Target platform:** Jetson Orin Nano (8GB shared memory) — development and play

## Combat Model

- **Exploration mode:** Roguelike turns — grid movement, bump-to-interact, energy-based action costs
- **Combat mode:** Tactical D&D 5e — movement points + action + bonus action + reaction, initiative order, positioning, terrain, flanking

## NPC Model

Every NPC is a freeform conversational agent powered by the local LLM. No menu trees, no canned dialogue. Players can negotiate, bluff, ask directions, or say anything. The DM archetype (Storyteller, Taskmaster, Trickster, Historian, Guide) shapes the NPC's tone and behavior.

## Target Experience

A solo D&D session that feels handcrafted — but is entirely AI-driven.
