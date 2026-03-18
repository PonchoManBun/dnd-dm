# Phase 1 — Standalone Godot Game: Task List

## COMPLETED — Phase 0 Readiness

- [x] Jetson Orin Nano: SSH working (192.168.2.1, user jetson, direct ethernet)
- [x] Jetson: Ollama 0.18.0 + Llama 3.2 3B running on GPU (CUDA 12.6)
- [x] Jetson: Project repo cloned to ~/dnd-dm
- [x] Jetson: Godot 4.6.1 installed at /usr/local/bin/godot
- [x] Jetson: Python 3.10.12, Git, Claude Code ready
- [x] D&D 5e SRD markdown files in rules/ (17 chapter files, OGL licensed, BTMorton/dnd-5e-srd)
- [x] All Phase 0 research and specs complete
- [x] PROMPT.md, CLAUDE.md, @AGENT.md updated for Phase 1
- [x] 5e-database integration: 334 monsters, 12 classes, 9 races (MIT, single source of truth)
- [x] All docs migrated from Windows->Jetson workflow to Jetson-only development

---

## COMPLETED — Phase 1 Tasks (Standalone Godot Game — No AI)

### HIGH — Must complete

- [x] Copy statico/godot-roguelike-example into `game/` directory
- [x] Evaluate base game: understand its scene tree, combat system, dungeon gen, data structures
- [x] Adapt D20 combat to D&D 5e SRD rules (action economy: movement + action + bonus + reaction)
  - character_data.gd (Resource), rules_engine.gd (Autoload), combat_state.gd, damage.gd rewrite
  - combat.gd D&D 5e attack resolution with legacy fallback
  - dnd_monster_factory.gd + dnd_monsters.json (8 SRD stat blocks)
- [x] Add DM panel UI (right-side panel: narrative text display, choice buttons, free-text input)
  - narrative_manager.gd (Autoload), dm_panel.gd, narratives.json
- [x] Create hardcoded test dungeon with hand-authored content (rooms, enemies, loot)
  - dungeon_loader.gd, room_triggers.gd, test_crypt.json (3-floor dungeon)
- [x] Basic character creation flow (race, class, ability scores per SRD)
  - character_creation.gd + .tscn, races.json (6 races), classes.json (6 classes)
  - 4-step flow: Race -> Class -> Roll Abilities (4d6 drop lowest) -> Name & Confirm
- [x] Save/load system (JSON game state, continuous auto-save, delete-on-resume)
  - game_state_serializer.gd, auto_save.gd (Autoload)
  - Atomic writes, roguelike anti-scumming (delete on death/resume)
  - Continue button on main menu

### MEDIUM — Should complete

- [x] Implement hybrid combat model (roguelike exploration + tactical D&D 5e combat mode switch)
  - game_mode.gd (state machine), initiative_tracker.gd (turn order UI)
- [x] Integrate DM panel into game scene (right 1/3 overlay in UI CanvasLayer)
- [x] Wire dungeon loader into game flow (initialize_from_dungeon, stair wiring, room triggers)
- [x] Adapt tileset/sprites for TWW visual style (CanvasModulate tint + ambient vignette shader)
- [x] Implement DM archetype selection (5 archetypes, UI only, stores choice for Phase 2)
  - dm_selection.gd + .tscn, wired between character creation and game start
- [x] Inventory and equipment UI (D&D 5e weight/encumbrance display in inventory modal)
- [x] SRD rules reference display in-game (toggleable overlay, ? key, markdown-to-BBCode)

### LOW — Nice to have

- [x] Audio integration (procedural AudioStreamGenerator sounds via AudioManager autoload)
- [x] Death/permadeath flow (immersive death screen with eulogy, memorial stats, fade-in)
- [x] Install Godot 4 ARM64 on Jetson for on-device testing (Godot 4.6.1 at /usr/local/bin/godot)
- [x] Fix class_name/autoload conflicts blocking Jetson (AutoSave, NarrativeManager)

---

## COMPLETED — Forge Mode Setup

- [x] Forge CLAUDE.md rewrite with validated schemas
- [x] Validation script (forge/validate.py)
- [x] Schema reference files
- [x] Prompt templates
- [x] Forge slash commands (8 skills)
- [x] Design guide (forge/design_guide.md)

---

## COMPLETED — Phase 2 Preparation (Partial)

- [x] Orchestrator implemented (FastAPI, routes, rules engine)
- [x] Ollama integration (client, prompt builder, context manager)
- [x] NPC dialogue via LLM (npc_context.py, speak action route)
- [x] Automated playtest system (monitor.sh, playtest.sh, playtest_brain.py, the-player agent)
- [ ] Wire Forge into orchestrator (trigger forge generation during gameplay)

---

## COMPLETED — Phase 1 Extension — Party System

All HIGH and MEDIUM tasks complete. 3 LOW items deferred to Phase 2.

### HIGH — Complete
- [x] Party data model, NPC recruitment, stat block conversion
- [x] Companion combat integration, party-aware death, dialogue UI

### MEDIUM — Complete
- [x] Companion XP tracking, equipment management, party formation, encounter balance

### LOW — Deferred to Phase 2
- [ ] Companion AI during non-combat (follow behavior, idle animations)
- [ ] Companion dismissal and re-recruitment
- [ ] Companion quest hooks (personal quests per companion)

---

## Phase 2 — Local LLM Integration

### HIGH — Must complete

- [ ] Godot HTTP client for orchestrator API (HTTPRequest nodes, response parsing)
- [ ] Wire DM panel to orchestrator (replace hardcoded narratives with LLM responses)
- [ ] Room entry narration via Ollama (trigger on room_entered signal)
- [ ] Freeform NPC conversation via LLM (free-text input → orchestrator → Ollama → DM panel)
- [ ] Combat narration via LLM (hits, misses, kills, spell effects)
- [ ] Context management in orchestrator (conversation history, world state summary)

### MEDIUM — Should complete

- [ ] Contextual choice generation (LLM suggests situational choices)
- [ ] Tavern hub scene (rest, recruit, shop, quest board — LLM-powered NPCs)
- [ ] NPC personality persistence (orchestrator tracks NPC conversation state)
- [ ] Companion AI during non-combat (deferred from Phase 1)

### LOW — Nice to have

- [ ] Companion dismissal and re-recruitment (deferred from Phase 1)
- [ ] Companion quest hooks (deferred from Phase 1)
- [ ] DM archetype affects LLM prompt style (use stored archetype choice)
- [ ] Streaming LLM responses (token-by-token display in DM panel)

---

## Environment Notes

- **Jetson memory:** 8 GB shared. Desktop GUI uses ~400 MB + Xorg ~140 MB. Close Firefox and extra Claude sessions before running Ollama with 3B model. Consider headless mode if memory is tight in Phase 2.
- **SRD upgrade path:** Current rules/ has 17 chapter-level files (BTMorton). For Phase 2+ when per-entity lookup matters, swap to OldManUmby/DND.SRD.Wiki (CC-BY-4.0, ~900 individual files per spell/monster/class).
- **Base game:** statico/godot-roguelike-example — MIT, Godot 4.6, GDScript, D20 combat, BSP dungeon gen, CSV data-driven, behavior tree AI, fog of war. Copy into game/, don't GitHub-fork.
- **Godot on Jetson:** `/usr/local/bin/godot` (ARM64 Linux build, 4.6.1)
