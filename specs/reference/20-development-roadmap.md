# 20 — Development Roadmap

## Philosophy

**Prove the architecture first, then add content.** Validate that Godot + local LLM + Forge can work together on the Jetson before investing in game content depth. Each phase delivers a playable vertical slice, not a layer of infrastructure.

## Phase 0 — Research & Documentation [COMPLETE]

- Evaluated open-source Godot 4 base games; selected statico/godot-roguelike-example (MIT)
- Researched legal/ToS for Claude automated usage
- Researched Jetson Orin Nano LLM capabilities (Ollama 0.18.0, CUDA 12.6)
- Researched Godot file formats for AI editability
- Designed Forge Mode architecture (persistent CLI session with /clear + forge/CLAUDE.md)
- Wrote 20 GDD reference specs, 6 research docs, 5 phase specs
- Integrated 5e-database: 334 monsters, 12 classes, 9 races (MIT, single source of truth)
- Set up Jetson: SSH, Godot 4.6.1, Python 3.10.12, Ollama + Llama 3.2 3B, Claude Code
- Migrated all development workflow from Windows+Jetson to Jetson-only

## Phase 1 — Standalone Godot Game [COMPLETE]

All HIGH and MEDIUM tasks completed. Being extended with party/companion system before advancing.

**What was built:**
- Forked and adapted statico/godot-roguelike-example base game
- D&D 5e SRD combat: full action economy (movement + action + bonus action + reaction)
  - `character_data.gd` (Resource with all 9 races, 12 classes, enums, data tables)
  - `rules_engine.gd` (Autoload), `combat_state.gd`, `damage.gd`
  - D&D 5e attack resolution with legacy fallback
  - `dnd_monster_factory.gd` + `dnd_monsters.json` (334 SRD stat blocks)
- DM panel UI (right-side panel: narrative text, choice buttons, free-text input)
  - `narrative_manager.gd` (Autoload), `dm_panel.gd`, `narratives.json`
- Hardcoded test dungeon (`dungeon_loader.gd`, `room_triggers.gd`, `test_crypt.json` — 3-floor dungeon)
- Character creation: 4-step flow (Race -> Class -> Roll Abilities -> Name & Confirm)
  - 9 races, 12 classes, 4d6-drop-lowest, random name generator
- DM archetype selection (5 archetypes: Storyteller, Taskmaster, Trickster, Historian, Guide)
- Save/load system (JSON, continuous auto-save, delete-on-resume anti-scumming)
- Hybrid combat model (roguelike exploration + tactical D&D 5e combat mode switch)
  - `game_mode.gd` (state machine), `initiative_tracker.gd` (turn order UI)
- Inventory and equipment UI (D&D 5e weight/encumbrance)
- SRD rules reference display (toggleable overlay, ? key, markdown-to-BBCode)
- Audio (procedural AudioStreamGenerator via AudioManager autoload)
- Death/permadeath flow (death screen with eulogy, memorial stats, fade-in)
- Tavern scene with NPC placement and indoor tileset

## Phase 2 — Local LLM Integration [SUBSTANTIALLY IMPLEMENTED]

The orchestrator and most supporting systems are built. Integration with the Godot client for live gameplay is the remaining work.

**What has been built:**
- DM Orchestrator: Python/FastAPI server (`orchestrator/main.py`)
  - Routes: `/action`, `/character`, `/debug`, `/srd`, `/state`, `/health`
  - Pydantic models: `GameState`, `CharacterState`, `CombatState`, `NarrativeState`, `LocationState`, `ItemState`
  - Enums: Race, DndClass, Ability, Skill, Condition, ArmorCategory, DamageType, DmArchetype, ActionType, EquipmentSlot
- Rules engine (Python): `orchestrator/engine/rules.py` — dice, combat math, SRD lookups
- Dice engine: `orchestrator/engine/dice.py`
- Spell system: `orchestrator/engine/spells.py` + `orchestrator/data/spell_data.py` + `srd_spells.json`
- Equipment data: `orchestrator/data/equipment_data.py` + `srd_equipment.json` + `srd_magic_items.json`
- SRD data loader: `orchestrator/data/srd_data.py`
- Ollama client: `orchestrator/engine/ollama_client.py`
- Prompt builder: `orchestrator/engine/prompt_builder.py`
- DM archetype prompt templates: `orchestrator/prompts/` (storyteller, taskmaster, trickster, historian, guide)
- Context manager: `orchestrator/engine/context_manager.py`
- NPC context: `orchestrator/engine/npc_context.py`
- Template fallback: `orchestrator/engine/template_fallback.py`
- Debug logger: `orchestrator/engine/debug_logger.py`
- Action model: `orchestrator/models/actions.py`
- Tests: `orchestrator/tests/`

**What remains:**
- Wire Godot client to orchestrator HTTP API (replace hardcoded narratives)
- Live DM response cycle: player action -> orchestrator -> Ollama -> response -> client
- NPC freeform dialogue via local LLM in-game
- Contextual choice generation from LLM output

## Phase 3 — Forge Mode (Claude Content Generation) [PARTIALLY IMPLEMENTED]

The Forge agent instructions, schemas, validation, and prompt templates are in place. The trigger detection and live pipeline are not yet built.

**What has been built:**
- Forge agent instructions: `forge/CLAUDE.md` (comprehensive agent prompt with workflows, schemas, validation rules)
- Design guide: `forge/design_guide.md` (encounter budgets, room ratios, monster placement, loot distribution)
- JSON schemas and examples:
  - `forge/schemas/dungeon_example.json`
  - `forge/schemas/monster_example.json`
  - `forge/schemas/narrative_example.json`
  - `forge/schemas/npc_example.json`
  - `forge/schemas/quest_example.json`
- Prompt templates for generation and editing:
  - `forge/prompt_templates/generate_dungeon.md`, `edit_dungeon.md`
  - `forge/prompt_templates/generate_npc.md`, `edit_npc.md`
  - `forge/prompt_templates/generate_quest.md`, `edit_quest.md`
  - `forge/prompt_templates/generate_narrative.md`
- Content validator: `forge/validate.py` (checks slug references, room geometry, required fields)
- Slash command definitions in forge CLAUDE.md

**What remains:**
- Forge trigger detection in orchestrator (when to invoke Claude)
- On-demand content pipeline (player action -> detect need -> forge -> load -> resume)
- Content hot-reloading in Godot
- Integration with orchestrator API

## Phase 4 — Content Depth

- Full faction system with reputation mechanics
- NPC state machines + LLM narration overlay
- Cross-death NPC memory and world persistence
- Multiple dungeon themes and boss encounters
- Quest system with branching narratives
- Overworld / node-based travel
- Party/companion system (BG3-style, up to 4 total, any NPC recruitable)
- **Goal:** Deep, replayable game content.

## Phase 5 — Polish & Formalization

- TTS for DM narration (if feasible on Jetson)
- MCP server formalization (wrap forge tools in proper MCP)
- Performance optimization for Jetson
- Playtesting and balance tuning
- Additional tilesets and sprite sheets
- **Goal:** Polished, complete game experience.

## Automated Playtest System

A two-tier playtest system exists for regression testing and game balance validation:

### Tier 1: Fast Heuristic Playtest

Shell script + Python brain that plays the game automatically:
- `scripts/playtest.sh` — Main driver. Polls DebugMonitor JSON sidecars, calls brain for decisions, sends input via xdotool.
- `scripts/playtest_brain.py` — Heuristic decision engine. Reads JSON game state, outputs a key to press.
- `scripts/monitor.sh` — Setup, launch, and monitoring utilities.
- `scripts/jetson_e2e.sh` — E2E helper functions (send_key via xdotool).
- Detects: crashes, stuck states, death, game over, timeout (10 min hard limit).
- Logs results to `/tmp/playtest_log.json`.

### Tier 2: Claude "The-Player" Agent

An intelligent playtest agent that uses multimodal reasoning:
- `scripts/the_player_prompt.md` — Agent prompt for spawning a Claude agent that plays the game.
- Reads both PNG screenshots (visual) and JSON state (data) for each turn.
- Thinks about each move, identifies bugs, reports balance observations.
- Reports: turns survived, cause of death, bugs found, balance notes, suggestions.

## Project Management

- **Task tracking** via `@fix_plan.md` (prioritized task list with HIGH/MEDIUM/LOW)
- **Phases** are tracked in `PROMPT.md` (current phase context) and `CLAUDE.md` (project instructions)
- **Direct development** on Jetson Orin Nano
- **Claude Code** is the primary developer; commits straight to master
- **No external CI/CD** — playtest system serves as regression testing

## Data Pipeline Scripts

- `scripts/convert_5e_monsters.py` — Converts 5e-database monster data to game format
- `scripts/convert_5e_classes.py` — Converts 5e-database class data
- `scripts/convert_5e_races.py` — Converts 5e-database race data
