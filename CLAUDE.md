# The Welcome Wench — Project Instructions

## What This Is

A single-player 2D pixel art turn-based tactical RPG with a dual-model AI Dungeon Master. A local LLM handles real-time DM duties (narration, freeform NPC conversation, choices); Claude generates content on demand via Forge Mode (persistent CLI session with /clear + forge/CLAUDE.md). Godot 4 renders the world. Developed on Windows 11 laptop, deployed/played on Jetson Orin Nano. See `PROMPT.md` for full context.

## Project Structure

```
PROMPT.md          # Current phase context and development principles
@fix_plan.md       # Prioritized task list for current phase
@AGENT.md          # Build/run/test commands
specs/phase-1-core/  # Phase specs (architecture, DM integration, forge mode, orchestrator)
specs/research/      # Research documents (legal, base game, file formats, Jetson, MCP, dev workflow)
specs/reference/     # 20 GDD documents (game design reference)
rules/               # D&D 5e SRD markdown files
forge/               # Forge Mode working directory (has its own CLAUDE.md)
```

## Architecture Rules

1. **Client is a dumb renderer** — Godot reads JSON game state, draws pixels. No game logic.
2. **Orchestrator is the brain** — Python/FastAPI routes between LLM, Forge, and rules engine. Maintains all state.
3. **Local LLM is the fast DM** — Ollama + Llama 3.2 3B handles per-turn narration, freeform NPC dialogue, choices.
4. **Forge (Claude) is on-demand quality** — Persistent CLI session generates dungeons, monsters, items, quests. Player waits.
5. **Rules engine is deterministic** — Dice, combat math, SRD lookups in Python. Not LLM.
6. **State contract is JSON** — All layers communicate via JSON files and HTTP.

## Tech Stack

- **Client:** Godot 4.x + GDScript (base: statico/godot-roguelike-example)
- **Orchestrator:** Python 3.10+ + FastAPI
- **Real-time DM:** Ollama + Llama 3.2 3B (Q4_K_M quantization)
- **Forge:** Claude Code CLI (persistent session with /clear + forge/CLAUDE.md)
- **Rules:** D&D 5e SRD (markdown in `rules/`)
- **Development:** Windows 11 laptop
- **Deployment:** Jetson Orin Nano (8GB shared memory)

## Code Conventions

- GDScript: strictly typed, `class_name` declarations, one file per concern
- Python: type hints, async/await, FastAPI conventions
- JSON for all state and communication
- Test integration points (orchestrator API, LLM routing, forge pipeline)

## Current Phase

Phase 0: Research & Documentation — complete. See `PROMPT.md` for objectives and `@fix_plan.md` for Phase 1 tasks.
