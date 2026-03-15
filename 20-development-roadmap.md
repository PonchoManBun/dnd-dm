# 20 — Development Roadmap

## Philosophy

**Renderer first, then connect Claude.** Build the visual game as a working Phaser app with mock data, then wire in the AI DM. This ensures the client works independently and the state contract is proven before adding AI complexity.

## Milestone 1 — Tavern Room (MVP Visual)

- 32×32 tile map of the tavern interior
- Character sprite with movement (WASD / arrow keys)
- Wall collision detection
- Camera follow
- Basic tileset integration (OpenGameArt)
- **Goal:** A character walks around a room. That's it.

## Milestone 2 — UI Shell

- Split-screen layout (viewport + DM panel)
- Mock DM narrative text
- Action bar with placeholder stats
- Inventory overlay (empty)
- Menu screens (title, settings)

## Milestone 3 — State Contract

- Define JSON schemas for all game state objects
- Build client state parser (JSON → Phaser rendering)
- Mock game state files for testing
- Server scaffold (Socket.IO relay + state persistence)

## Milestone 4 — Claude Integration

- Connect Claude Code CLI as the DM process
- SRD markdown files downloaded, converted, indexed
- Basic DM response cycle (action → processing → response)
- Character creation flow (DM-guided)

## Milestone 5 — Combat

- Turn-based grid combat rendering
- Initiative tracker UI
- Action economy (movement, action, bonus action)
- Reaction window
- Dice animation + combat log
- Fog of war overlay

## Milestone 6 — Dungeon Generation

- Procedural floor generation (DM-created layouts)
- Multiple dungeon themes
- Loot drops + item cards
- Trap and puzzle adjudication

## Milestone 7 — Overworld & Persistence

- Node-based travel map
- Random encounters
- Day/night cycle
- Permadeath flow (death → eulogy → world log → new character)
- Cross-death NPC memory

## Milestone 8 — Polish & Post-MVP

- Audio integration (music + SFX)
- TTS implementation
- Additional tilesets and sprite sheets
- Balance tuning with DM archetype adjustments
- Bug fixing and playtesting

## Project Management

- **GitHub Issues** for task tracking
- **Milestones** map to the phases above
- **Monorepo** — all code in `/home/jetson/TWW/`
- **User role** — Game designer. Claude Code builds all code.
