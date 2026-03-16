# 20 — Development Roadmap

## Philosophy

**Prove the architecture first, then add content.** Validate that Godot + local LLM + Forge can work together on the Jetson before investing in game content depth.

## Phase 0 — Research & Documentation (Current)

- Evaluate open-source Godot 4 base games
- Research legal/ToS for Claude automated usage
- Research Jetson Orin Nano LLM capabilities
- Research Godot file formats for AI editability
- Design Forge Mode architecture (persistent CLI session)
- Rewrite GDDs and specs for new architecture
- **Goal:** All research complete, architecture documented, ready to build.

## Phase 1 — Standalone Godot Game (Hardcoded Content)

- Fork and adapt base game (statico/godot-roguelike-example)
- Adapt D20 combat to D&D 5e SRD rules
- Add DM panel UI (narrative text, choices, free-text input)
- Hardcoded test dungeon with hand-authored content
- Basic character creation flow
- Save/load system
- **Goal:** A playable turn-based tactical RPG with no AI. Proves the game client works.

## Phase 2 — Local LLM Integration

- Set up Ollama on Jetson with Llama 3.2 3B
- Build DM Orchestrator (Python/FastAPI)
- Implement DM response cycle: player → orchestrator → LLM → response
- Deterministic rules engine (dice, combat math, SRD lookups)
- DM archetype prompt templates
- NPC dialogue via local LLM (basic)
- Contextual choice generation
- **Goal:** The local LLM acts as DM for every turn. Proves the DM loop works.

## Phase 3 — Forge Mode (Claude Content Generation)

- Set up persistent Claude Code CLI session for Forge Mode
- Implement forge tools: dungeon, monster, item, NPC, narrative
- Forge trigger detection: when to call Forge
- On-demand content pipeline (player action → generate → load → resume)
- Content hot-reloading in Godot
- JSON tilemap grid → GDScript set_cell() loader
- **Goal:** Claude generates quality content on demand via persistent CLI session. Proves the forge pipeline works.

## Phase 4 — Content Depth

- Full faction system with reputation mechanics
- NPC state machines + LLM narration overlay
- Cross-death NPC memory and world persistence
- Permadeath flow (death → eulogy → new character)
- Multiple dungeon themes and boss encounters
- Quest system with branching narratives
- Overworld / node-based travel
- **Goal:** Deep, replayable game content.

## Phase 5 — Polish & Formalization

- Audio integration (music + SFX)
- TTS for DM narration (if feasible on Jetson)
- MCP server formalization (wrap forge tools in proper MCP)
- Performance optimization for Jetson
- Playtesting and balance tuning
- Additional tilesets and sprite sheets
- **Goal:** Polished, complete game experience.

## Project Management

- **GitHub Issues** for task tracking
- **Phases** map to GitHub milestones
- **Two-machine workflow** — develop on Windows 11 laptop, deploy/play on Jetson Orin Nano (see `specs/research/dev-workflow.md`)
- **User role** — Game designer. Claude Code builds code. Local LLM handles runtime.
