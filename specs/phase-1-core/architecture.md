# Phase 1 Architecture — Three-Layer Single-Machine Topology

## Overview

All components run on a single Jetson Orin Nano (8GB shared memory):

```
┌──────────────────────────────────────────────────────┐
│  JETSON ORIN NANO                                     │
│                                                       │
│  [Godot 4 Client] ──HTTP──▶ [DM Orchestrator]        │
│                              │            │           │
│                    [Ollama/LLM]    [Forge/Claude]     │
└──────────────────────────────────────────────────────┘
```

## Architecture Principles

1. **Client = dumb renderer.** Godot reads game state JSON and draws pixels. No dice, no combat, no narrative.
2. **Orchestrator = the brain.** Routes between LLM, Forge, and rules engine. Maintains all state.
3. **Local LLM = fast DM.** Handles every turn. Narration, dialogue, choices. ~20-43 tok/s.
4. **Forge (Claude) = quality content.** On-demand generation of dungeons, monsters, quests via persistent CLI session. 10-60 sec, player waits.
5. **State contract = JSON.** All layers communicate via JSON. Godot reads JSON. Orchestrator writes JSON. Claude generates JSON. Everyone speaks the same language.
6. **Deterministic rules stay deterministic.** Dice, combat math, conditions — no LLM involved. Fair, reproducible, SRD-compliant.

## Communication

| From | To | Transport | Format |
|------|----|-----------|--------|
| Godot | Orchestrator | HTTP localhost | JSON |
| Orchestrator | Ollama | Ollama Python SDK | JSON messages |
| Orchestrator | Claude | Claude Code CLI (persistent session) | Prompts + JSON output |
| Orchestrator | Game State | File I/O | JSON files |
| Forge | Content Output | File I/O | .json, .tres, .gd, .tscn |

## State Contract

The orchestrator outputs JSON game state. The Godot client renders it.

### GameState

```json
{
  "scene": "tavern|overworld|dungeon|combat",
  "turn": 42,
  "time_of_day": "evening",
  "character": { "name": "...", "race": "...", "class": "...", "level": 5, "hp": {"current": 28, "max": 35}, "ac": 16, "abilities": {"str": 14, "dex": 12, ...}, "equipment": {...}, "inventory": [...], "conditions": [], "gold": 150, "xp": 6500, "position": {"x": 12, "y": 8} },
  "location": { "map_id": "crypt_level_1", "room_id": "room_3" },
  "npcs": [{ "id": "skeleton_1", "position": {"x": 15, "y": 8}, "hp": {"current": 13, "max": 13} }],
  "narrative": { "text": "A skeleton emerges from the shadows...", "choices": ["Attack with sword", "Cast shield", "Retreat"], "allow_free_text": true, "dice_rolls": [{"type": "d20", "result": 17, "label": "Initiative"}], "combat_log": [] }
}
```

### PlayerAction

```json
{
  "type": "choice|freetext|move|hotkey",
  "value": "Attack with sword",
  "timestamp": 1710000000
}
```

## Base Game

Fork of [statico/godot-roguelike-example](https://github.com/statico/godot-roguelike-example):
- MIT license, Godot 4.6, pure GDScript
- D20 combat, BSP dungeon gen, inventory, fog of war
- Data-driven (CSV), behavior tree AI, faction system
- Designed for AI-assisted editing

## Key Technical Decisions

| Decision | Choice | Reason |
|----------|--------|--------|
| Game engine | Godot 4 + GDScript | ARM64 support, text-based files, AI-friendly |
| Local LLM | Llama 3.2 3B via Ollama | Fits in 8GB, 20-43 tok/s, tool calling support |
| Forge backend | Claude Code CLI (persistent session) | /clear + CLAUDE.md, file I/O tools, Commercial Terms |
| Orchestrator | Python/FastAPI | Async, Ollama SDK, CLI integration, simple |
| State format | JSON files | Readable by all layers, simple, diffable |
| Communication | HTTP localhost | Simple, no WebSocket complexity needed |
| Renderer | OpenGL Compatibility | Lower memory than Vulkan on Jetson |
