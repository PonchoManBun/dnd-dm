# 18 — Technical Architecture

## System Overview

```
+-------------------------------------------------------------+
|  JETSON ORIN NANO (8GB)                                      |
|                                                              |
|  +------------------------------------------------------+   |
|  |  Godot 4 Game Client                                  |   |
|  |  - Renders turn-based tactical RPG (2D pixel art)     |   |
|  |  - Sends player actions to DM Orchestrator            |   |
|  |  - 16x16 tile grid, DawnLike tileset                  |   |
|  +----------------+-------------------------------------+   |
|                   | HTTP (localhost)                          |
|  +----------------v-------------------------------------+   |
|  |  DM Orchestrator (Python/FastAPI)                     |   |
|  |  - Routes player actions to local LLM                 |   |
|  |  - Deterministic rules engine (dice, combat math)     |   |
|  |  - Maintains game state + conversation history        |   |
|  |  - SRD rules loader                                   |   |
|  +---------+------------------------+-------------------+   |
|            |                        |                        |
|  +---------v----------+   +--------v-----------------+      |
|  |  Ollama             |   |  Forge (Claude Code CLI) |      |
|  |  (Llama 3.2 3B)    |   |  - Persistent CLI session|      |
|  |                     |   |    with /clear + CLAUDE.md|     |
|  |  Real-time DM:      |   |  - Generates .json       |      |
|  |  - Narration        |   |    content files          |      |
|  |  - Combat text      |   |  - On-demand (10-60 sec, |      |
|  |  - NPC dialogue     |   |    player waits)          |      |
|  |  - Choices          |   |  - Connects to Anthropic  |      |
|  |  ~20-43 tok/s       |   |    cloud for inference    |      |
|  +---------------------+   +--------------------------+      |
+-------------------------------------------------------------+
```

## Three-Layer Architecture

### Layer 1: Godot 4 Game Client

- **Role:** Renderer + input handler. Displays game state. Sends player actions.
- **Engine:** Godot 4.x + GDScript
- **Renderer:** OpenGL Compatibility (lighter than Vulkan for 2D on Jetson)
- **Responsibilities:** Tile rendering (16x16 grid), sprite display, fog of war, UI overlays (HUD, DM panel, initiative tracker, modals), input capture, procedural audio playback, auto-save
- **Does NOT:** Roll dice (in orchestrator mode), resolve combat, decide NPC behavior, generate narrative
- **Base game:** Fork of [statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example) (MIT, Godot 4.6, D20 mechanics)
- **Client-side rules:** In Phase 1, the GDScript `RulesEngine` handles all combat math locally. In Phase 2, this moves to the orchestrator.

### Layer 2: DM Orchestrator (Python/FastAPI)

- **Role:** Central game logic coordinator. Bridges Godot, local LLM, and Forge.
- **Stack:** Python 3.10+, FastAPI, Ollama Python SDK
- **Entry point:** `orchestrator/main.py` — FastAPI app with route modules
- **Routes:**
  - `action.py` — `POST /action` — Core DM response cycle (parse action, apply rules, call LLM, return response)
  - `character.py` — Character state management
  - `state.py` — `GET /state` — Poll current game state
  - `srd.py` — SRD rules lookup
  - `debug.py` — Debug/diagnostic endpoints
- **Responsibilities:**
  - Accept player actions from Godot via HTTP (localhost)
  - Route to local LLM for real-time DM response
  - Deterministic rules engine: dice rolls, combat math, spell resolution, rest mechanics
  - Maintain game state (in-memory `GameState` object)
  - Maintain conversation history for local LLM context
  - Template fallback narration when LLM is unavailable
  - Deliver DM response back to Godot
- **Does NOT:** Render anything, generate narrative (that's the LLM's job)

### Layer 3a: Local LLM (Ollama)

- **Role:** Real-time DM. Handles every player turn.
- **Stack:** Ollama v0.18.0 on ARM64 + CUDA, Llama 3.2 3B (Q4_K_M)
- **Compatibility:** Ollama v0.18.0 works fine on Jetson — no version pinning or downgrade needed.
- **Responsibilities:** Narration, combat flavor text, NPC dialogue, contextual choices, room descriptions
- **Performance:** ~20-43 tokens/sec (Super Mode), enough for 2-3 sentences in <2 seconds
- **Context:** 2048 tokens (modest, to fit in memory budget)
- **Does NOT:** Generate complex content, manage persistent state

### Layer 3b: Forge Mode (Claude Code CLI)

- **Role:** On-demand content generator. Player-action-triggered for quality content.
- **Stack:** Persistent Claude Code CLI session, Anthropic API Key
- **Responsibilities:** Generate dungeon maps, monster stat blocks, items, NPC profiles, quest arcs, narrative set pieces
- **Output:** Writes content to `forge_output/` directory (see below)
- **Latency:** 10-60 seconds (player waits with "Generating..." indicator)
- **Invocation:** Manual CLI session; `/clear` + `forge/CLAUDE.md` reload before each request
- **Integration status:** Forge tools exist and the output directory is populated, but the orchestrator does **not** currently call Forge during live gameplay. No `/forge/trigger` endpoint is implemented.
- **Does NOT:** Handle real-time player actions

## State Format

### Game State (Client-Side)

Game state is serialized by `GameStateSerializer` to a **single JSON save file** at `user://save.json`. The serializer writes:

```json
{
  "version": 1,
  "timestamp": 1234567890,
  "current_turn": 42,
  "max_depth": 3,
  "game_over": false,
  "current_map_id": "level_2",
  "current_map_depth": 2,
  "faction_affinities": { "0": 100, "1": -30, "2": -100, "3": -100 },
  "player": {
    "slug": "knight",
    "name": "Aldric",
    "role": 0,
    "hp": 28, "max_hp": 34,
    "character_data": { ... },
    "skill_levels": { ... },
    "status_effects": [ ... ],
    "inventory": [ ... ],
    "equipment": { ... },
    "position_x": 5, "position_y": 3
  }
}
```

Key details:
- Maps are **not** serialized — they are regenerated from the `WorldPlan` seed on load
- The player's full `CharacterData` (D&D 5e stats, proficiencies, conditions) is serialized
- Inventory and equipment are serialized as item slugs with metadata
- Faction affinities are serialized as faction_type -> value pairs
- Save version is validated on load to prevent incompatible data

### Orchestrator State (Server-Side)

The orchestrator maintains an in-memory `GameState` object containing:
- `CharacterState` — player stats, HP, AC, level, conditions, spell slots
- `NarrativeState` — DM archetype, turn number, current narration, choices, conversation history
- `LocationState` — current location name, map type, position

### Content Directory (Forge-Generated)

```
forge_output/
+-- dungeons/      # Generated dungeon layouts (JSON grids)
+-- monsters/      # Monster stat blocks (JSON)
+-- items/         # Item definitions (JSON)
+-- npcs/          # NPC profiles
+-- narrative/     # Quest arcs, room descriptions
+-- manifests/     # Generation tracking metadata
+-- _fallback/     # Fallback content when Forge unavailable
```

### Communication Protocol

Godot <-> Orchestrator via HTTP/JSON on localhost:

```
POST /action     -- Player takes an action (returns DmResponse)
GET  /state      -- Poll current game state
GET  /health     -- Health check (returns {"status": "ok", "phase": 2})
```

Additional routes for character management, SRD lookup, and debug logging exist but are not part of the core gameplay loop.

## Memory Budget (8GB Shared)

| Component | RAM |
|-----------|-----|
| L4T OS (headless) | ~800 MB |
| System reserved | ~500 MB |
| Ollama + 3B model (Q4_K_M) | ~2.2-2.3 GB |
| KV cache (2048 ctx) | ~200-500 MB |
| Godot 4 (2D pixel art) | ~200-400 MB |
| Python orchestrator | ~50-100 MB |
| **Total** | **~4.0-4.6 GB** |
| **Remaining** | **~1.9-2.5 GB** |

8 GB NVMe swap file as safety net.

## Build & Dev

- **Godot 4:** ARM64 Linux build from godotengine.org
- **Python:** 3.10+ with FastAPI, Ollama SDK
- **Ollama:** v0.18.0 — works fine on Jetson, no version pinning needed
- **Development:** Direct development on Jetson Orin Nano (see `specs/research/dev-workflow.md`)
- **Performance mode:** `sudo nvpmodel -m 0 && sudo jetson_clocks`
