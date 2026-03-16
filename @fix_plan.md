# Phase 1 — Standalone Godot Game: Task List

## COMPLETED — Phase 0 Readiness

- [x] Jetson Orin Nano: SSH working (192.168.2.1, user jetson, direct ethernet)
- [x] Jetson: Ollama 0.18.0 + Llama 3.2 3B running on GPU (CUDA 12.6)
- [x] Jetson: Project repo cloned to ~/dnd-dm
- [x] Windows: Godot 4.6.1 installed (winget)
- [x] Windows: Python 3.13, Git, Claude Code ready
- [x] D&D 5e SRD markdown files in rules/ (17 chapter files, OGL licensed, BTMorton/dnd-5e-srd)
- [x] All Phase 0 research and specs complete
- [x] PROMPT.md, CLAUDE.md, @AGENT.md updated for Phase 1

---

## Phase 1 Tasks (Standalone Godot Game — No AI)

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
- [ ] Adapt tileset/sprites for TWW visual style (darker palette, 32x32 or base game's 16x16)
- [ ] Implement DM archetype selection (UI only, no LLM — stores choice for Phase 2)
- [ ] Inventory and equipment UI (paper-doll slots, backpack grid, weight tracker)
- [ ] SRD rules reference display in-game (load markdown from rules/ for tooltips/info panels)

### LOW — Nice to have

- [ ] Audio integration (placeholder music + SFX)
- [ ] Death/permadeath flow (UI only — last stand prompt, eulogy screen, memorial wall)
- [ ] Install Godot 4 ARM64 on Jetson for on-device testing

---

## Environment Notes

- **Jetson memory:** 8 GB shared. Desktop GUI uses ~400 MB + Xorg ~140 MB. Close Firefox and extra Claude sessions before running Ollama with 3B model. Consider headless mode if memory is tight in Phase 2.
- **SRD upgrade path:** Current rules/ has 17 chapter-level files (BTMorton). For Phase 2+ when per-entity lookup matters, swap to OldManUmby/DND.SRD.Wiki (CC-BY-4.0, ~900 individual files per spell/monster/class).
- **Base game:** statico/godot-roguelike-example — MIT, Godot 4.6, GDScript, D20 combat, BSP dungeon gen, CSV data-driven, behavior tree AI, fog of war. Copy into game/, don't GitHub-fork.
- **Godot on Windows:** `godot` command available after shell restart, or use full path at `AppData/Local/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_*/Godot_v4.6.1-stable_win64_console.exe`
