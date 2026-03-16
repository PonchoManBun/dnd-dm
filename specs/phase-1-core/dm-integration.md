# DM Integration — Dual-Model Architecture

> See [GDD 13 — AI Dungeon Master](../reference/13-ai-dungeon-master.md) for full DM design

## The DM System

The AI DM is a **dual-model system** coordinated by the DM Orchestrator:

| Model | Role | Speed | When Used |
|-------|------|-------|-----------|
| **Local LLM** (Llama 3.2 3B) | Real-time DM | ~20-43 tok/s | Every player turn |
| **Claude** (CLI session) | Forge content gen | 10-60 sec | On demand, player waits |

The **DM Orchestrator** (Python/FastAPI) handles deterministic rules (dice, combat math, SRD lookups) and routes between models.

## The DM Response Cycle

```
Player → Godot (HTTP) → Orchestrator → Rules Engine → Local LLM → Orchestrator → Godot
                                                   ↘ (on trigger) Forge → content files → resume
```

1. **Player takes action** — types or clicks in Godot
2. **Orchestrator receives** — parses action, loads game state
3. **Rules engine resolves** — dice rolls, combat math, SRD checks
4. **Local LLM narrates** — receives rules outcome + context, generates text
5. **Orchestrator merges** — combines rules results + narration
6. **Godot renders** — narrative text, choices, state updates

## DM Input Options

- **Contextual choices** — LLM-suggested actions appropriate to the situation
- **"Do something else..."** — Free-text input. Type anything. The DM will adjudicate it.

## DM Archetypes

Implemented as prompt templates for the local LLM:

| Archetype | Style |
|-----------|-------|
| **Classic Storyteller** | Balanced narrative and challenge. The default. |
| **Cruel Taskmaster** | Harder encounters, fewer drops, more ambushes. |
| **Whimsical Trickster** | Chaotic encounters, absurd NPCs, dark humor. |
| **Grim Historian** | Lore-heavy. Deep world-building. |
| **Merciful Guide** | Easier. More hints, generous loot. |

## What's Deterministic vs What's AI

| System | Handler |
|--------|---------|
| Dice rolls, attack resolution, damage | **Orchestrator** (Python) |
| Spell mechanics, conditions | **Orchestrator** (SRD lookup) |
| Narration, flavor text | **Local LLM** |
| NPC dialogue, choices | **Local LLM** |
| Dungeon layouts, monster design, quests | **Forge (Claude)** |

## Forge Triggers

The orchestrator triggers Forge for heavyweight content when the player's action requires it:
- New dungeon floor, boss encounters, major story beats
- New NPC profiles, quest arcs, unique items
- Level-up class feature descriptions

Forge is player-action-triggered — the game shows a "Generating..." indicator while content is produced by a persistent Claude Code CLI session. Gameplay resumes when content is ready.

## Implementation Phases

- **Phase 1:** No AI. Hardcoded content. Proves Godot client works.
- **Phase 2:** Local LLM integration. DM response cycle works.
- **Phase 3:** Forge Mode. Claude generates content on demand.
