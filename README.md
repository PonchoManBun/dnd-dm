# The Welcome Wench

A single-player 2D pixel art dungeon crawler where **Claude Code CLI is the game engine**.

Phaser 3 renders the world. Claude reads D&D 5e SRD markdown, rolls dice, resolves combat, controls every NPC, and generates narrative — like a human Dungeon Master. You don't play a video game that imitates D&D. You play D&D with a pixel art tabletop.

## Tech Stack

- **Client:** Phaser 3 + TypeScript + Vite
- **Server:** Node.js + Socket.IO
- **Engine/DM:** Claude Code CLI
- **Rules:** D&D 5e SRD (markdown)
- **Tests:** Vitest

## Development Phases

| Phase | Name | Goal |
|-------|------|------|
| **1** | Core Proof of Concept | Prove Claude can be the DM |
| **2** | Character & Tavern | Create a character, exist in the world |
| **3** | Combat | Fight something |
| **4** | Dungeon Crawl | Enter a dungeon, fight, loot, return |
| **5** | Living World | NPCs remember, factions exist, death matters |
| **6** | Polish | Full game flow, audio, visual refinement |

**Current phase:** Phase 1

## Project Structure

```
PROMPT.md              # Current phase context (RALPH)
@fix_plan.md           # Prioritized task list (RALPH)
@AGENT.md              # Build/run/test commands (RALPH)
CLAUDE.md              # Project instructions for Claude Code
specs/
  phase-1-core/        # Phase 1 design specs (active)
  phase-2-tavern/      # Phase 2 placeholder
  phase-3-combat/      # Phase 3 placeholder
  phase-4-dungeon/     # Phase 4 placeholder
  phase-5-world/       # Phase 5 placeholder
  phase-6-polish/      # Phase 6 placeholder
  reference/           # Original 20 GDD documents
rules/                 # D&D 5e SRD markdown files
```

## Architecture

```
Browser (Phaser 3) ◄──Socket.IO──► Node.js Server ◄──CLI──► Claude Code (DM)
```

- **Client** = dumb renderer (reads JSON, draws pixels)
- **Server** = thin relay (shuttles messages, persists state)
- **Claude** = the engine (decides everything)

## Design Pillars

1. **The DM is real.** Claude interprets rules, improvises, and reacts to creativity.
2. **Permadeath matters.** One life. The world remembers your dead characters.
3. **Emergent everything.** Quests, factions, NPCs — generated, never scripted.
4. **Dark comedy.** Dangerous, absurd, and narrated with gallows humor.

## Specs

Full game design is documented across 20 GDD files in `specs/reference/`. Phase-specific build specs are in `specs/phase-N-*/`.
