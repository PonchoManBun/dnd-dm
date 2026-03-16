# Phase 1 Overview — Core Architecture

> See [GDD 01 — Game Overview](../reference/01-game-overview.md) for full game design

## Elevator Pitch

**The Welcome Wench** (TWW) is a single-player 2D pixel art turn-based tactical RPG with an AI Dungeon Master that runs a full D&D 5e campaign. A **local LLM** on a Jetson Orin Nano handles real-time DM duties (narration, combat text, NPC conversation, choices), while **Claude** (via a persistent CLI session) generates high-quality content on demand — dungeon maps, monsters, items, quest arcs. **Godot 4** renders the world. You don't play a video game that imitates D&D. You play D&D with a pixel art tabletop.

### Hybrid Combat Model
- **Exploration:** Roguelike turns — grid movement, bump-to-interact, simple actions
- **Combat:** Tactical D&D 5e mode — movement + action + bonus action + reaction, positioning matters, terrain effects, flanking

## Design Pillars

1. **The DM is real.** A local LLM improvises narration and reacts to player creativity like a human DM. Every NPC is a live conversational agent — no menu trees, no canned dialogue. Claude generates the content that makes the world rich.
2. **Permadeath matters.** One life. No save-scumming. Every decision carries weight. The world remembers your dead characters.
3. **Emergent everything.** Quests, factions, NPC relationships, and dungeon layouts are generated — never hand-authored. No two runs are alike.
4. **Dark comedy.** The world is dangerous and absurd. Death is frequent and narrated with gallows humor. Think Diablo meets Discworld.

## Core Game Loop

1. **Tavern** — Rest, shop, talk to NPCs, pick up quests, create characters.
2. **Travel** — Navigate the overworld. Random encounters. DM narration.
3. **Dungeon** — Explore procedural floors. Combat, traps, puzzles, loot.
4. **Return or Die** — Survive and return with loot, or die and start fresh.

## Platform & Hardware

- **Game client:** Godot 4.x + GDScript (2D pixel art, 16x16 tiles)
- **Hardware:** Jetson Orin Nano (8GB) — runs all components
- **Base game:** Fork of statico/godot-roguelike-example (MIT, Godot 4.6, D20 combat)
- **Controls:** Keyboard (WASD/arrows) + mouse

## Architecture

Three layers on one machine:
1. **Godot 4 Client** — Renderer + input. Communicates with orchestrator via HTTP.
2. **DM Orchestrator** — Python/FastAPI. Rules engine + LLM routing + state management.
3. **AI Layer** — Ollama (real-time DM) + Claude Code CLI (on-demand Forge Mode).

See [architecture.md](architecture.md) for full details.

## Phase 1 Scope (Standalone Godot Game)

For the first buildable milestone:
- Fork and adapt the base game
- Adapt D20 combat to D&D 5e SRD rules
- Add DM panel UI (narrative text, choices, free-text input)
- Hardcoded test dungeon with hand-authored content
- Basic character creation flow
- Save/load system
- **No AI yet** — Phase 1 proves the game client works independently

The local LLM and Forge integration come in Phase 2 and Phase 3.
