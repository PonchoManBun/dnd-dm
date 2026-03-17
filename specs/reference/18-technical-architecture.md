# 18 — Technical Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│  JETSON ORIN NANO (8GB)                                      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │  Godot 4 Game Client                                  │   │
│  │  - Renders turn-based tactical RPG (2D pixel art)      │   │
│  │  - Sends player actions to DM Orchestrator            │   │
│  │  - Watches filesystem for hot-reloaded content        │   │
│  └──────────────┬───────────────────────────────────────┘   │
│                 │ HTTP (localhost)                            │
│  ┌──────────────▼───────────────────────────────────────┐   │
│  │  DM Orchestrator (Python/FastAPI)                     │   │
│  │  - Routes player actions to local LLM                 │   │
│  │  - Deterministic rules engine (dice, combat math)     │   │
│  │  - Maintains game state + conversation history        │   │
│  │  - Escalation logic: decides when to call Forge       │   │
│  │  - SRD rules loader                                   │   │
│  └───────┬──────────────────────────┬───────────────────┘   │
│          │                          │                        │
│  ┌───────▼──────────┐   ┌──────────▼────────────────┐      │
│  │  Ollama           │   │  Forge (Claude Code CLI)   │      │
│  │  (Llama 3.2 3B)  │   │  - Persistent CLI session  │      │
│  │                   │   │    with /clear + CLAUDE.md  │      │
│  │  Real-time DM:    │   │  - Generates .tscn/.gd/    │      │
│  │  - Narration      │   │    .tres/.json files        │      │
│  │  - Combat text    │   │  - On-demand (10-60 sec,   │      │
│  │  - NPC dialogue   │   │    player waits)            │      │
│  │  - Choices        │   │  - Connects to Anthropic   │      │
│  │  ~20-43 tok/s     │   │    cloud for inference      │      │
│  └──────────────────┘   └─────────────────────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Three-Layer Architecture

### Layer 1: Godot 4 Game Client

- **Role:** Renderer + input handler. Displays game state. Sends player actions.
- **Engine:** Godot 4.x + GDScript
- **Renderer:** OpenGL Compatibility (lighter than Vulkan for 2D on Jetson)
- **Responsibilities:** Tile rendering, sprite animation, fog of war, UI overlays, input capture, sound playback, content hot-reloading
- **Does NOT:** Roll dice, resolve combat, decide NPC behavior, generate narrative
- **Base game:** Fork of [statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example) (MIT, Godot 4.6, D20 mechanics)

### Layer 2: DM Orchestrator (Python/FastAPI)

- **Role:** Central game logic coordinator. Bridges Godot, local LLM, and Forge.
- **Stack:** Python 3.10+, FastAPI, Ollama Python SDK
- **Responsibilities:**
  - Accept player actions from Godot via HTTP (localhost)
  - Route to local LLM for real-time DM response
  - Deterministic rules engine: dice rolls, combat math, SRD rules lookup
  - Maintain game state (JSON files)
  - Maintain conversation history for local LLM context
  - Escalation logic: decide when to invoke Forge Mode
  - Deliver DM response back to Godot
- **Does NOT:** Render anything, generate narrative (that's the LLM's job)

### Layer 3a: Local LLM (Ollama)

- **Role:** Real-time DM. Handles every player turn.
- **Stack:** Ollama on ARM64 + CUDA, Llama 3.2 3B (Q4_K_M)
- **Responsibilities:** Narration, combat flavor text, NPC dialogue, contextual choices, room descriptions
- **Performance:** ~20-43 tokens/sec (Super Mode), enough for 2-3 sentences in <2 seconds
- **Context:** 2048 tokens (modest, to fit in memory budget)
- **Does NOT:** Generate complex content, manage persistent state

### Layer 3b: Forge Mode (Claude Code CLI)

- **Role:** On-demand content generator. Player-action-triggered for quality content.
- **Stack:** Persistent Claude Code CLI session, Anthropic API Key
- **Responsibilities:** Generate dungeon maps, monster stat blocks, items, NPC profiles, quest arcs, narrative set pieces
- **Output:** Writes .tscn, .tres, .gd, .json files to `forge_output/` directory
- **Latency:** 10-60 seconds (player waits with "Generating..." indicator)
- **Invocation:** Orchestrator sends prompt to persistent CLI session; `/clear` + `forge/CLAUDE.md` reload before each request
- **Does NOT:** Handle real-time player actions

## State Format

### Game State (JSON)

All game state is stored as JSON files, readable by Godot, Python, and Claude:

```
/game_state/
├── player.json          # Character sheet, inventory, position
├── world.json           # World log, time, weather, global flags
├── npcs/                # Per-NPC state files
│   ├── barkeep_marta.json
│   └── captain_holt.json
├── factions/            # Per-faction state
│   ├── thieves_guild.json
│   └── town_guard.json
├── dungeons/            # Dungeon state (explored rooms, loot taken)
│   └── crypt_level_1.json
└── conversation_history.json  # LLM context window
```

### Content Directory (Claude-generated)

```
/forge_output/
├── dungeons/            # Generated level layouts (JSON grids)
├── monsters/            # Monster .tres resources or JSON
├── items/               # Item .tres resources or JSON
├── npcs/                # NPC profiles, dialogue trees
├── narrative/           # Quest arcs, room descriptions
└── scripts/             # Generated .gd behavior scripts
```

### Communication Protocol

Godot ↔ Orchestrator via HTTP/JSON on localhost:

```
POST /action     — Player takes an action
GET  /state      — Poll current game state
POST /forge/trigger — Manually trigger forge generation (dev/debug only)
```

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
- **Ollama:** Docker via jetson-containers or native install (pin to 0.5.7 if GPU issues)
- **Development:** Direct development on Jetson Orin Nano (see `specs/research/dev-workflow.md`)
- **Performance mode:** `sudo nvpmodel -m 0 && sudo jetson_clocks`
