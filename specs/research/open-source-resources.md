# Open Source Resources Reference

A curated catalog of open source libraries, addons, data sources, art assets, and audio for The Welcome Wench. Each entry includes ROI (value to TWW) and complexity (integration effort) ratings on a 1-5 scale.

**Rating Key:**
- **ROI 1-5:** 1 = nice-to-have, 5 = game-changing for TWW
- **Complexity 1-5:** 1 = drop-in, 5 = significant integration work
- **Phase:** Which development phase the resource is most relevant to
- **Verdict:** YES (integrate), NO (skip), or CONDITIONAL (evaluate when conditions are met)

---

## Scope Notes

TWW's architecture (see CLAUDE.md) imposes constraints on addon selection:

1. **Client = dumb renderer.** Godot reads JSON game state and draws pixels. No game logic in the client. Addons that add game logic (AI, quest state, dice rolls) to Godot conflict with this rule and get thrown away when the Python orchestrator takes over in Phase 2.
2. **LLM generates dialogue.** The local LLM and Forge handle all narration, NPC dialogue, and quest content. Dialogue/quest editor addons have limited value.
3. **TWW uses 16x16 tiles.** The codebase (`world_tiles.png`, `character_tiles.png`, `item_sprites.png`) is 16x16. Art assets at 32x32 require downscaling or a tilemap rework.
4. **Existing systems matter.** Several features already have working implementations in the codebase. ROI ratings below account for what's already built.

ROI ratings in this document have been audited against the actual codebase (19,810 lines GDScript, 136 files) as of 2026-03-16.

Verdicts assigned 2026-03-17. Cross-checked against architecture rules in `CLAUDE.md` and `specs/phase-1-core/architecture.md`.

---

## Godot Addons

All addons below are **MIT licensed** unless noted otherwise.

### Behavior Trees & AI

#### Beehave
- **URL:** https://github.com/bitbrain/beehave
- **License:** MIT
- **Description:** Behavior tree addon with visual editor and in-editor debug view for designing complex NPC behaviors.
- **Godot 4:** Yes (v2.9.2+)
- **ROI: 2** — ~~4~~ Monster AI moves to Python orchestrator in Phase 2, making a Godot-side BT addon throwaway work. The codebase already has `monster_ai.gd` with behavior tree patterns for Phase 1.
- **ARCHITECTURE NOTE:** Conflicts with "client = dumb renderer" rule. AI logic belongs in the orchestrator.
- **Complexity: 2** — Clean addon architecture, installs via AssetLib.
- **Jetson:** Pure GDScript, no performance concerns.
- **Phase:** Reference only
- **Verdict: NO** — AI moves to Python orchestrator Phase 2. Throwaway work.

#### LimboAI
- **URL:** https://github.com/limbonaut/limboai
- **License:** MIT
- **Description:** C++ behavior trees + hierarchical state machines with built-in editor, visual debugger, and GDScript task support. Available as C++ module or GDExtension.
- **Godot 4:** Yes (built specifically for Godot 4)
- **ROI: 2** — ~~5~~ More powerful than Beehave, but same architecture problem: AI moves to Python orchestrator in Phase 2. GDExtension ARM64 build adds complexity for throwaway work.
- **ARCHITECTURE NOTE:** Conflicts with "client = dumb renderer" rule. AI logic belongs in the orchestrator.
- **Complexity: 3** — GDExtension build required for Jetson (ARM64). Pre-built binaries exist for x86.
- **Jetson:** Needs ARM64 GDExtension build. C++ performance is actually ideal for constrained hardware.
- **Phase:** Reference only
- **Verdict: NO** — Same architecture conflict as Beehave + needs ARM64 GDExtension build.

### Camera

#### Phantom Camera
- **URL:** https://github.com/ramokz/phantom-camera
- **License:** MIT
- **Description:** Cinemachine-inspired camera addon with follow, look-at, multi-target framing, and tweened transitions for Camera2D/3D.
- **Godot 4:** Yes (requires Godot 4.3+)
- **ROI: 3** — Smooth camera following party through dungeon rooms. Multi-target framing useful for tactical combat overview.
- **Complexity: 2** — Drop-in addon, well documented.
- **Jetson:** Pure GDScript/shader, no concerns.
- **Phase:** 1-2 (dungeon exploration, combat camera)
- **Verdict: CONDITIONAL** — Phase 6. Only if tactical combat needs multi-target camera framing.

### Map Import

#### YATI (Yet Another Tiled Importer)
- **URL:** https://github.com/Kiamo2/YATI
- **License:** MIT
- **Description:** Imports Tiled Map Editor files (.tmx, .tmj) into Godot 4 as native scenes and tilesets.
- **Godot 4:** Yes (Godot 4 only)
- **ROI: 3** — ~~5~~ TWW currently uses a custom JSON dungeon format (`test_crypt.json`, `dungeon_loader.gd`). YATI only matters if Forge outputs Tiled format, which hasn't been decided. Conditional value.
- **Complexity: 2** — Straightforward importer, converts at import time.
- **Jetson:** Import-time only, zero runtime cost.
- **Phase:** 2-3 (conditional on Forge output format decision)
- **Verdict: CONDITIONAL** — Phase 4. Only if Forge outputs Tiled format (.tmx/.tmj) instead of custom JSON.

### Dialogue

#### Dialogic 2
- **URL:** https://github.com/dialogic-godot/dialogic
- **License:** MIT
- **Description:** Full-featured dialogue and visual novel editor integrated into Godot. Supports branching dialogue, characters, timelines, and themes.
- **Godot 4:** Yes (Dialogic 2.x for Godot 4)
- **ROI: 1** — ~~3~~ LLM generates all dialogue dynamically in Phase 2+. `narrative_manager.gd` already handles queued narrative, choice buttons, callbacks, and history for Phase 1. Heavy addon with no clear use case.
- **EXISTING IMPLEMENTATION:** `narrative_manager.gd` covers narrative display, choices, and history.
- **Complexity: 3** — Large addon with many features. Overhead for a project that generates most dialogue dynamically.
- **Jetson:** Pure GDScript, no concerns. But adds significant editor weight.
- **Phase:** Not recommended
- **Verdict: NO** — `narrative_manager.gd` exists; LLM replaces scripted dialogue in Phase 2+.

#### Dialogue Manager
- **URL:** https://github.com/nathanhoad/godot_dialogue_manager
- **License:** MIT
- **Description:** Lightweight stateless branching dialogue editor using script-like syntax with localization support.
- **Godot 4:** Yes (requires Godot 4.4+)
- **ROI: 2** — ~~4~~ `narrative_manager.gd` already handles narrative display with queued messages, choice buttons, callbacks, and history. LLM replaces scripted dialogue in Phase 2. Script-based format is interesting for reference only.
- **EXISTING IMPLEMENTATION:** `narrative_manager.gd` covers the dialogue rendering use case.
- **Complexity: 2** — Minimal footprint, clean API.
- **Jetson:** Lightweight, no concerns.
- **Phase:** Reference only
- **Verdict: NO** — Same as Dialogic 2. `narrative_manager.gd` covers the use case.

### Visual Effects

#### Godot VFX Library
- **URL:** https://github.com/haowg/GODOT-VFX-LIBRARY
- **License:** MIT
- **Description:** 35+ particle effects and 17+ shaders for combat, movement, spells, environmental, and status effects.
- **Godot 4:** Yes
- **ROI: 3** — Spell effects, combat feedback, environmental atmosphere. Adds juice to tactical combat.
- **Complexity: 1** — Copy-paste individual effects as needed. No framework dependency.
- **Jetson:** Particle effects can be GPU-heavy. Test on Jetson; may need to reduce particle counts.
- **Phase:** 3-4 (combat polish, visual feedback)
- **Verdict: YES** — Phase 3. Copy individual effects as needed. Test particle counts on Jetson.

#### Fancy Scene Changes
- **URL:** https://github.com/nightblade9/godot-fancy-scene-changes
- **License:** MIT
- **Description:** Shader-based scene transitions: tile reveal, circle/ellipse fades, linear gradients, custom noise textures.
- **Godot 4:** Yes (main branch targets Godot 4.x)
- **ROI: 2** — Nice room transition effects. Low priority but adds polish.
- **Complexity: 1** — Drop-in shader library.
- **Jetson:** Shader-based, minimal GPU cost.
- **Phase:** 4-5 (polish)
- **Verdict: YES** — Phase 6. Drop-in shader transitions, zero game logic.

### Quest & Game Systems

#### Questify
- **URL:** https://github.com/TheWalruzz/godot-questify
- **License:** MIT
- **Description:** Graph-based quest editor and manager with visual node editing, branching objectives, and translation support.
- **Godot 4:** Yes
- **ROI: 1** — ~~3~~ Quest state belongs in the Python orchestrator per architecture rules. Graph-based system in Godot directly conflicts with the JSON state contract. Quests are AI-generated by Forge.
- **ARCHITECTURE NOTE:** Conflicts with "client = dumb renderer" rule. Quest state belongs in orchestrator.
- **Complexity: 3** — Graph-based system may conflict with orchestrator's JSON state management.
- **Jetson:** Pure GDScript, no concerns.
- **Phase:** Not recommended
- **Verdict: NO** — Quest state belongs in orchestrator. Conflicts with architecture.

#### DiceEngine
- **URL:** https://github.com/ThePat02/DiceEngine
- **License:** MIT
- **Description:** Dice roller addon providing a Dice singleton for rolling arbitrary dice and evaluating DiceCheck resources for skill checks.
- **Godot 4:** Yes (GDScript)
- **ROI: 1** — ~~2~~ TWW already has `dice.gd`. Rules engine is Python-side per architecture. Redundant for game logic, and visual dice rolling doesn't need a dedicated addon.
- **EXISTING IMPLEMENTATION:** `dice.gd` handles dice rolling for Phase 1.
- **Complexity: 1** — Tiny addon, trivial integration.
- **Jetson:** Negligible footprint.
- **Phase:** Not recommended
- **Verdict: NO** — `dice.gd` already complete. Rules engine moves to Python.

### Input & Audio

#### Input Helper
- **URL:** https://github.com/nathanhoad/godot_input_helper
- **License:** MIT
- **Description:** Device detection, input remapping/serialization, action labels, and controller rumble.
- **Godot 4:** Yes (v4.7.0 for Godot 4.4)
- **ROI: 2** — ~~3~~ 30+ input actions already defined in `project.godot` with full keyboard mapping. Game input handling is complete. Device detection and remapping could still be useful for Jetson gamepad support.
- **EXISTING IMPLEMENTATION:** Full keyboard input mapping in `project.godot` (30+ actions).
- **Complexity: 1** — Drop-in singleton.
- **Jetson:** Specifically helpful for Jetson input management.
- **Phase:** 3+ (gamepad/remapping polish)
- **Verdict: CONDITIONAL** — Phase 5. Only if gamepad support on Jetson is desired.

#### Event Audio
- **URL:** https://github.com/bbbscarter/event-audio-godot
- **License:** MIT
- **Description:** Fire-and-forget event-based audio system mapping trigger strings to audio banks with random variant selection and positional tracking.
- **Godot 4:** Not explicitly confirmed (needs testing)
- **ROI: 3** — Event-based audio fits TWW's signal-driven architecture. Random variant selection adds variety.
- **Complexity: 2** — May need Godot 4 compatibility verification/porting.
- **Jetson:** Lightweight audio system, no concerns.
- **Phase:** 3-4 (audio integration)
- **Verdict: YES** — Phase 3. Maps onto existing `audio_manager.gd` signal architecture.

### Combat Components

#### Fog of War
- **URL:** https://github.com/TABmk/godot-4-fog-of-war
- **License:** MIT
- **Description:** Fog of war / auto-mapping system with debounced rendering, caching optimizations, and character-following.
- **Godot 4:** Yes (built for Godot 4+)
- **ROI: 2** — ~~5~~ The codebase already has a working vision system: `visible_cells`/`seen_cells` tracking, `sight_radius` per monster, MapRenderer dims non-visible tiles to 40%. Only useful as reference for upgrading to proper shadowcasting algorithm.
- **EXISTING IMPLEMENTATION:** Vision system with `visible_cells`/`seen_cells`, per-entity `sight_radius`, MapRenderer fog dimming.
- **Complexity: 2** — Purpose-built for the exact use case. May need tuning for tile-based grid.
- **Jetson:** Debounced rendering and caching are Jetson-friendly optimizations.
- **Phase:** Reference only (shadowcasting upgrade)
- **Verdict: NO** — `visible_cells`/`seen_cells` system already works. Reference only.

#### Health / HitBox / HurtBox Components
- **URL:** https://github.com/cluttered-code/godot-health-hitbox-hurtbox
- **License:** MIT
- **Description:** Reusable 2D/3D health tracking, collision-based HitBox/HurtBox damage, and raycast HitScan with signal-driven data flow.
- **Godot 4:** Yes (requires Godot 4.4+)
- **ROI: 2** — TWW combat is turn-based and orchestrator-driven, not real-time collision. Limited direct use, but signal patterns are a useful reference.
- **Complexity: 1** — Modular components, take what you need.
- **Jetson:** Minimal footprint.
- **Phase:** 3 (combat visual feedback)
- **Verdict: NO** — Real-time collision system; TWW is turn-based.

---

## 5e SRD Data

### 5e-bits/5e-database
- **URL:** https://github.com/5e-bits/5e-database
- **License:** MIT
- **Description:** The most comprehensive structured JSON database of D&D 5e SRD content. Covers monsters, spells, classes, races, equipment, and all SRD categories. Companion REST + GraphQL API at https://github.com/5e-bits/5e-srd-api.
- **ROI: 5** — Direct import into Python rules engine. Structured JSON matches TWW's state contract. Eliminates manual data entry for all SRD content.
- **Complexity: 2** — JSON files ready for import. Schema is well-documented.
- **Jetson:** Data files only, zero runtime cost.
- **Phase:** 1 (integrated)
- **Verdict: YES** — **Integrated in Phase 1.** Single source of truth for monsters (334), classes (12), races (9). Conversion scripts in `scripts/convert_5e_*.py`.

### Open5e API
- **URL:** https://github.com/open5e/open5e-api
- **Website:** https://open5e.com | **API:** https://api.open5e.com
- **License:** OGL + CC-BY-4.0
- **Description:** Community-driven REST API for 5e SRD content built with Django. Includes SRD plus third-party OGL content (Tome of Beasts, etc.). Supports filtering and search.
- **ROI: 3** — Useful for development-time lookups and validation. For production, prefer the static 5e-database JSON (offline capability on Jetson).
- **Complexity: 1** — Standard REST API, no integration needed beyond HTTP calls.
- **Jetson:** Network-dependent. Not suitable for offline play. Use 5e-database for embedded data.
- **Phase:** 2 (development reference, rules validation)
- **Verdict: CONDITIONAL** — Dev-time validation only. Not for production (Jetson may be offline). Use 5e-database for embedded data.

### BTMorton/dnd-5e-srd
- **URL:** https://github.com/BTMorton/dnd-5e-srd
- **License:** OGL v1.0a
- **Description:** Full 5e SRD in Markdown, JSON, and YAML formats. Chapter-based organization.
- **ROI: 2** — TWW already has SRD markdown in `rules/`. Redundant for data, but the JSON/YAML formats could supplement existing markdown for LLM context injection.
- **Complexity: 1** — Static files, no integration.
- **Jetson:** No runtime cost.
- **Phase:** 2 (supplementary reference)
- **Verdict: NO** — Already in `rules/`. 5e-database provides the structured JSON instead.

---

## Art Assets

### Dungeon Crawl 32x32 Tiles
- **URL:** https://opengameart.org/content/dungeon-crawl-32x32-tiles
- **License:** CC0 (Public Domain)
- **Description:** 6,000+ tiles at 32x32 pixels. Terrain, walls, dungeon features, monsters, spell effects, items, GUI elements, player characters, weapons, armor. Originally from Dungeon Crawl Stone Soup.
- **ROI: 3** — ~~5~~ The largest CC0 dungeon art collection (6,000+ tiles), but at 32x32 it's a **resolution mismatch** — TWW uses 16x16 tiles (`world_tiles.png`, `character_tiles.png`, `item_sprites.png`). Would require downscaling or tilemap rework. 16x16 tilesets (0x72 DungeonTileset II, DawnLike) are better fits.
- **RESOLUTION NOTE:** TWW codebase is 16x16. This tileset is 32x32.
- **Complexity: 2** — ~~1~~ CC0, but needs downscaling pipeline or tilemap rework to match 16x16 grid.
- **Jetson:** No performance concerns.
- **Phase:** 2-3 (supplementary art, requires scaling)
- **Verdict: NO** — 32x32 vs 16x16 resolution mismatch. No downscaling pipeline.

### Kenney 1-Bit Pack
- **URL:** https://kenney.nl/assets/1-bit-pack
- **License:** CC0 (Public Domain)
- **Description:** 1,078 monochrome 16x16 assets. Fantasy, indoor, outdoor, urban themes.
- **ROI: 2** — Distinctive 1-bit aesthetic but doesn't match TWW's pixel art direction. Best as placeholder or for minimalist UI elements.
- **Complexity: 1** — Download and use.
- **Jetson:** Tiny assets, zero concerns.
- **Phase:** 1 (placeholder art, UI icons)
- **Verdict: NO** — Monochrome clashes with DawnLike pixel art style.

### 0x72 DungeonTileset II
- **URL:** https://0x72.itch.io/dungeontileset-ii
- **License:** CC0 (Public Domain)
- **Description:** 16x16 dungeon tileset with walls, floors, torches, animated character sprites (zombies, lizards, dwarfs, orcs, demons, undead), weapons, items, traps. Autotile support.
- **ROI: 4** — Complete animated sprite set purpose-built for dungeon crawlers. CC0 license. The animated enemies and heroes are immediately usable.
- **Complexity: 1** — Well-organized spritesheets with documentation.
- **Jetson:** 16x16 is even lighter than 32x32.
- **Phase:** 1-2 (character/monster sprites)
- **Verdict: YES** — Phase 3. Animated 16x16 monster sprites (zombies, orcs, demons) to supplement current limited static set.

### DawnLike Universal Roguelike Tileset
- **URL:** https://opengameart.org/content/dawnlike-16x16-universal-rogue-like-tileset-v181
- **License:** CC-BY 4.0
- **Description:** 1,057+ tiles at 16x16 using DawnBringer 16-color palette. Characters, monsters (2-frame animations), weapons, equipment, items, dungeon tiles, GUI elements.
- **ROI: 4** — Cohesive universal roguelike tileset. The consistent palette creates a unified visual style across all game elements.
- **Complexity: 1** — Organized tilesheets, well documented.
- **Jetson:** 16x16, minimal footprint.
- **Phase:** 1-2 (alternative complete art direction)
- **Verdict: YES** — Phase 2. Already in use. Expand for tavern NPC sprites and additional world tiles.

### Pixel_Poem 2D Pixel Dungeon Asset Pack
- **URL:** https://pixel-poem.itch.io/dungeon-assetpuck
- **License:** Free for commercial/personal use (no redistribution)
- **Description:** 16x16 dungeon tileset with 20+ props, monster set, 3 character classes (knight, wizard, priest) with full animation sets (idle, walk, attack, damage, death), traps, and UI.
- **ROI: 3** — Complete character animation sets are valuable. Free version is sufficient for core needs.
- **Complexity: 1** — Standard spritesheet format.
- **Jetson:** No concerns.
- **Phase:** 2-3 (character animation upgrade)
- **Verdict: CONDITIONAL** — Phase 4. Only if combat design calls for full character animation (idle/walk/attack/damage/death) beyond current 2-frame swap.

### Liberated Pixel Cup (LPC)
- **URL:** https://lpc.opengameart.org/
- **License:** CC-BY-SA 3.0 / GPLv3 (dual-licensed)
- **Description:** Community-created overhead RPG art at 32x32. Modular character sprite system allowing mix-and-match of bodies, armor, weapons, hair. Large ecosystem of expansions.
- **ROI: 2** — ~~4~~ Modular character system is interesting, but at 32x32 it's a **resolution mismatch** with TWW's 16x16 codebase. Complex sprite assembly pipeline adds build complexity. CC-BY-SA license is restrictive.
- **RESOLUTION NOTE:** TWW codebase is 16x16. LPC is 32x32.
- **Complexity: 3** — Modular system requires sprite assembly pipeline. CC-BY-SA requires attribution and share-alike.
- **Jetson:** 32x32 base, no concerns. Sprite assembly is build-time, not runtime.
- **Phase:** Reference only (resolution mismatch + complex pipeline)
- **Verdict: NO** — 32x32 resolution mismatch + CC-BY-SA + complex sprite assembly pipeline.

**Notable LPC Expansion — Medieval Fantasy Character Sprites:**
- **URL:** https://opengameart.org/content/lpc-medieval-fantasy-character-sprites
- **License:** CC-BY-SA 3.0 / GPL 3.0 / OGA-BY 3.0

### 16x16 Indoor RPG Tileset (The Baseline)
- **URL:** https://opengameart.org/content/16x16-indoor-rpg-tileset-the-baseline
- **License:** CC-BY 3.0
- **Description:** 16x16 indoor tiles — floors, walls, furniture, decorative pieces. Good for tavern/building interiors.
- **ROI: 2** — Supplementary indoor tiles for The Welcome Wench tavern and building scenes.
- **Complexity: 1** — Standard tileset.
- **Jetson:** No concerns.
- **Phase:** 2-3 (tavern/town scenes)
- **Verdict: YES** — Phase 2. Tavern interior tiles (floors, walls, furniture) for the Welcome Wench hub.

---

## Audio

### RPG Sound Pack (artisticdude)
- **URL:** https://opengameart.org/content/rpg-sound-pack
- **License:** CC0 (Public Domain)
- **Description:** 95 WAV sound effects for RPGs — battle sounds (spells, weapon swings/clashes), inventory (armor, bottles, coins), UI, NPC vocalizations (beasts, ogres, slimes), environmental (creaky doors).
- **ROI: 5** — Purpose-built RPG SFX covering nearly every TWW need. CC0 license, 95 effects in one pack.
- **Complexity: 1** — Download, organize, assign to events.
- **Jetson:** WAV files, standard playback.
- **Phase:** 2-3 (audio integration)
- **Verdict: YES** — Phase 2-3. Begin replacing procedural sine-wave placeholders in Phase 2, complete in Phase 3.

### Kenney RPG Audio
- **URL:** https://kenney.nl/assets/rpg-audio
- **License:** CC0 (Public Domain)
- **Description:** 50 sound effects — foley, footsteps, and weapon effects.
- **ROI: 3** — Good supplementary combat/movement SFX.
- **Complexity: 1** — Download and use.
- **Jetson:** No concerns.
- **Phase:** 3 (combat audio)
- **Verdict: YES** — Phase 3. Supplementary combat/movement SFX.

### Kenney Impact Sounds
- **URL:** https://kenney.nl/assets/impact-sounds
- **License:** CC0 (Public Domain)
- **Description:** 130 foley impact sound effects.
- **ROI: 3** — Hit/damage feedback for tactical combat.
- **Complexity: 1** — Download and use.
- **Jetson:** No concerns.
- **Phase:** 3 (combat audio)
- **Verdict: YES** — Phase 3. Varied hit/damage feedback replacing generic noise burst.

### Kenney Interface Sounds
- **URL:** https://kenney.nl/assets/interface-sounds
- **License:** CC0 (Public Domain)
- **Description:** 100 click, button, and UI interaction sounds.
- **ROI: 3** — Menu, inventory, and UI feedback sounds.
- **Complexity: 1** — Download and use.
- **Jetson:** No concerns.
- **Phase:** 2-3 (UI audio)
- **Verdict: YES** — Phase 2. UI feedback for menus, inventory, DM panel choices. Currently zero UI audio.

### Kenney Music Jingles
- **URL:** https://kenney.nl/assets/music-jingles
- **License:** CC0 (Public Domain)
- **Description:** 85 short musical jingles for transitions, notifications, and UI cues.
- **ROI: 2** — Level-up stingers, event cues, achievement sounds. Not background music.
- **Complexity: 1** — Download and use.
- **Jetson:** No concerns.
- **Phase:** 4 (polish)
- **Verdict: CONDITIONAL** — Phase 4. Only after XP/level-up is implemented.

### Fantasy Sound Effects Library (Little Robot Sound Factory)
- **URL:** https://opengameart.org/content/fantasy-sound-effects-library
- **License:** CC-BY 3.0 (attribution to littlerobotsoundfactory.com)
- **Description:** 45 fantasy SFX — ambience, dragon growls, dirt/water footsteps, goblin voices, inventory sounds, jingles, gold pickup, spell effects, trap sounds.
- **ROI: 3** — Fantasy-specific SFX that complement the RPG Sound Pack. Goblin voices and spell effects are directly useful.
- **Complexity: 1** — Download and use. Attribution required.
- **Jetson:** No concerns.
- **Phase:** 3 (combat/exploration audio)
- **Verdict: YES** — Phase 3. Goblin voices, spell effects, trap sounds. Attribution required (CC-BY 3.0).

### 50 RPG Sound Effects (Kenney via OGA)
- **URL:** https://opengameart.org/content/50-rpg-sound-effects
- **License:** CC0 (Public Domain)
- **Description:** 50 OGG effects — metal, cloth, book, footstep, creak, coin, knife sounds.
- **ROI: 2** — Supplementary RPG foley effects.
- **Complexity: 1** — Download and use.
- **Jetson:** No concerns.
- **Phase:** 3 (supplementary audio)
- **Verdict: NO** — Redundant with RPG Sound Pack + Kenney packs already selected.

### Tabletop Audio
- **URL:** https://tabletopaudio.com/
- **License:** CC-BY-NC-ND 4.0 (Non-Commercial, No Derivatives)
- **Description:** 300+ original 10-minute ambient/music tracks designed for tabletop RPGs. Fantasy, Sci-Fi, Historical, Horror genres.
- **ROI: 4** — Thematically perfect for a D&D game. 10-minute ambient loops are ideal for dungeon exploration and combat music.
- **Complexity: 1** — Streaming or download.
- **Jetson:** Audio streaming/playback is trivial. 10-minute tracks need ~20MB each if stored locally.
- **Phase:** 3-4 (ambient music)
- **LICENSE WARNING:** CC-BY-NC-ND is the most restrictive Creative Commons license. Prohibits commercial use AND modifications (no remixing, cutting, or tempo changes). Fine for personal/hobby project. If TWW ever goes commercial, **must** obtain Patreon license ($10/mo at time of writing) or replace entirely.
- **Verdict: CONDITIONAL** — Phase 5. **Only if TWW stays non-commercial** (CC-BY-NC-ND). Otherwise use Incompetech.

### Incompetech (Kevin MacLeod)
- **URL:** https://incompetech.com/music/royalty-free/
- **License:** CC-BY 4.0 (attribution required)
- **Description:** Large library of royalty-free music. RPG-relevant genres: Dark World, Horror, Medieval, Soundtrack, Mystery. Professional orchestral/electronic compositions.
- **ROI: 3** — Professional background music with RPG-suitable tracks. Full compositions, not chiptune.
- **Complexity: 1** — Download, attribute in credits.
- **Jetson:** Standard audio playback.
- **Phase:** 3-4 (background music)
- **Verdict: CONDITIONAL** — Phase 4. Background music for dungeon exploration. CC-BY 4.0, commercial-safe.

### Freesound.org
- **URL:** https://freesound.org/
- **License:** Mixed per-sound (CC0, CC-BY, CC-BY-NC — filter by license)
- **Description:** 720,000+ sounds in collaborative database. Extensive RPG-relevant content: combat, environmental ambience, UI effects.
- **ROI: 3** — Massive supplementary source for any sound you can't find elsewhere. Filter for CC0/CC-BY.
- **Complexity: 2** — Per-sound license checking required. No bulk download of curated packs.
- **Jetson:** No concerns.
- **Phase:** 3-5 (fill audio gaps)
- **Verdict: CONDITIONAL** — Phase 5. Gap-filling for specific missing sounds. Per-sound license checking required.

---

## Reference Projects

### godot-tactical-rpg
- **URL:** https://github.com/ramaureirac/godot-tactical-rpg
- **License:** MIT
- **Description:** Tactical RPG template for Godot 4. Scalable architecture with Models/Modules/Services patterns, class system, map management, TacticsCamera. v2.0 with Godot 4.3 support. Detailed wiki.
- **ROI: 5** — Most directly relevant reference. Architecture patterns (grid combat, turn management, Models/Modules/Services) map closely to TWW's needs. Wiki is excellent.
- **Complexity: N/A** — Reference only, not a dependency.
- **Phase:** 1-3 (architecture reference throughout)
- **Verdict: YES** — Reference. Wiki for grid combat, turn management patterns. Consult in Phase 2-3.

### GDQuest Open RPG
- **URL:** https://github.com/gdquest-demos/godot-open-rpg
- **License:** MIT
- **Description:** Turn-based RPG demo for Godot 4. Covers combat system, inventory, character progression, map transitions, dialogues, grid-based movement, and UI. Teaching-focused with clean code.
- **ROI: 4** — Excellent reference for turn-based combat loops, inventory, dialogue rendering, and UI structure. Clean teaching codebase.
- **Complexity: N/A** — Reference only.
- **Phase:** 1-3 (combat, inventory, UI reference)
- **Verdict: YES** — Reference. Client-server split patterns, tavern UI layout. Consult in Phase 2-3.

### GDQuest 2D Tactical RPG Movement
- **URL:** https://github.com/gdquest-demos/godot-2d-tactical-rpg-movement
- **License:** MIT
- **Description:** Focused demo for grid-based movement in a 2D tactical RPG. Cursor-based unit selection, walkable area display, path preview.
- **ROI: 4** — The most targeted reference for tile-based tactical movement, pathfinding visualization, and cursor interaction.
- **Complexity: N/A** — Reference only.
- **Phase:** 1-2 (grid movement implementation)
- **Verdict: YES** — Reference. Walkable area display, path preview for tactical combat. Consult in Phase 3.

---

## Verdict Summary

*Verdicts assigned 2026-03-17. Cross-checked against architecture rules in `CLAUDE.md` and `specs/phase-1-core/architecture.md`.*

### YES — Integrate (15)

| Resource | Category | License | Phase | Why |
|----------|----------|---------|-------|-----|
| **5e-bits/5e-database** | SRD Data | MIT | 1 (integrated) | Single source of truth. 334 monsters, 12 classes, 9 races. |
| **RPG Sound Pack** | Audio | CC0 | 2-3 | Begin replacing procedural placeholders in Phase 2, complete in Phase 3. |
| **Kenney Interface Sounds** | Audio | CC0 | 2 | UI feedback for menus, inventory, DM panel. Zero UI audio currently. |
| **DawnLike tileset** (expand) | Art | CC-BY 4.0 | 2 | Already in use. Expand for tavern NPC sprites and world tiles. |
| **16x16 Indoor RPG Tileset** | Art | CC-BY 3.0 | 2 | Tavern interior tiles for the Welcome Wench hub. |
| **0x72 DungeonTileset II** | Art | CC0 | 3 | Animated 16x16 monster sprites. |
| **Godot VFX Library** | VFX | MIT | 3 | Spell particles, combat feedback, hit impacts. |
| **Event Audio** | Audio | MIT | 3 | Fire-and-forget with random variant selection. |
| **Kenney RPG Audio** | Audio | CC0 | 3 | Supplementary combat/movement SFX. |
| **Kenney Impact Sounds** | Audio | CC0 | 3 | Varied hit/damage feedback. |
| **Fantasy Sound Effects Library** | Audio | CC-BY 3.0 | 3 | Goblin voices, spell effects, trap sounds. |
| **Fancy Scene Changes** | VFX | MIT | 6 | Shader-based scene transitions. |
| **godot-tactical-rpg** | Reference | MIT | 2-3 | Grid combat, turn management patterns. |
| **GDQuest Open RPG** | Reference | MIT | 2-3 | Client-server split, tavern UI layout. |
| **GDQuest Tactical Movement** | Reference | MIT | 3 | Walkable area display, path preview. |

### CONDITIONAL — Evaluate When Ready (8)

| Resource | Phase | Condition |
|----------|-------|-----------|
| **YATI** | 4 | Only if Forge outputs Tiled format (.tmx/.tmj) |
| **Pixel_Poem Dungeon Pack** | 4 | Only if combat needs full character animation beyond 2-frame swap |
| **Incompetech** | 4 | Background music for dungeon exploration |
| **Kenney Music Jingles** | 4 | Only after XP/level-up is implemented |
| **Open5e API** | 2 | Dev-time validation only, not production |
| **Input Helper** | 5 | Only if gamepad support on Jetson is desired |
| **Tabletop Audio** | 5 | Only if TWW stays non-commercial (CC-BY-NC-ND) |
| **Freesound.org** | 5 | Gap-filling, per-sound license checking required |
| **Phantom Camera** | 6 | Only if tactical combat needs multi-target camera framing |

### NO — Skip (13)

| Resource | Why |
|----------|-----|
| **Beehave** | AI moves to Python orchestrator Phase 2 |
| **LimboAI** | Same + needs ARM64 GDExtension build |
| **Dialogic 2** | `narrative_manager.gd` exists; LLM replaces scripted dialogue |
| **Dialogue Manager** | Same as above |
| **Questify** | Quest state belongs in orchestrator |
| **DiceEngine** | `dice.gd` already complete |
| **Fog of War addon** | `visible_cells`/`seen_cells` system already works |
| **Health/HitBox/HurtBox** | Real-time collision; TWW is turn-based |
| **BTMorton/dnd-5e-srd** | Already in `rules/` |
| **Dungeon Crawl 32x32** | 32x32 vs 16x16 mismatch |
| **Kenney 1-Bit Pack** | Monochrome clashes with pixel art style |
| **LPC 32x32** | Resolution mismatch + CC-BY-SA + complex pipeline |
| **50 RPG Sound Effects** | Redundant with RPG Sound Pack + Kenney packs |

### What NOT to Do

1. **Don't front-load polish** — VFX, transitions, and music jingles belong in Phase 3-6, not Phase 2
2. **Don't add Godot-side game logic** — Beehave, LimboAI, Questify, DiceEngine all get thrown away when orchestrator takes over
3. **Don't mix tile resolutions** — Stick with 16x16. No 32x32 tilesets without a downscaling pipeline.
4. **Don't add heavy addons** — Dialogic, LPC sprite assembly, etc. add complexity for marginal value
5. **Don't use Open5e API in production** — Jetson may be offline. Use static 5e-database JSON instead. Open5e is dev-time validation only.
