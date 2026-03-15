# The Welcome Wench — RALPH Development Context

## Project

**The Welcome Wench** (TWW) is a single-player 2D pixel art dungeon crawler where **Claude Code CLI is the game engine/DM**. Phaser 3 renders the world. Claude reads D&D 5e SRD markdown, rolls dice, resolves combat, controls every NPC, and generates narrative — like a human Dungeon Master. The player doesn't play a video game that imitates D&D. They play D&D with a pixel art tabletop.

## Current Phase: Phase 1 — Core Proof of Concept

**Goal:** Prove Claude can be the DM.

### Objectives
1. Minimal Phaser 3 scene (colored rectangle — no art assets)
2. Claude CLI integration via Node.js + Socket.IO
3. Basic DM response cycle: player types → Claude responds → text displays
4. Minimal JSON state contract (GameState, NarrativeState, PlayerAction)

### Phase 1 is done when:
- A player can type a message in the browser
- It reaches Claude via Socket.IO → Node.js → Claude CLI
- Claude responds with valid JSON matching the state contract
- The response text appears in the DM panel

## Tech Stack

- **Client:** Phaser 3 + TypeScript + Vite
- **Server:** Node.js + Socket.IO
- **Engine/DM:** Claude Code CLI
- **Rules:** D&D 5e SRD (markdown files in `rules/`)
- **Tests:** Vitest

## Architecture Principles

1. **Client = dumb renderer.** It reads JSON game state and draws pixels. It does NOT roll dice, resolve combat, decide NPC behavior, or generate narrative.
2. **Server = thin relay.** It shuttles messages between client and Claude, persists state. It does NOT contain game logic.
3. **Claude = authoritative engine.** Claude IS the game engine. It decides everything — combat, loot, NPC behavior, narrative, difficulty.
4. **State contract is the interface.** Claude outputs structured JSON. The client renders it. The contract defines what connects AI to renderer.

## Development Principles

1. **Prove risky things first.** Claude-as-DM is the core innovation and the biggest risk. Validate it before investing in visual polish.
2. **Vertical slices.** Each phase delivers a playable slice — not a layer of infrastructure.
3. **Keep it simple.** No over-engineering. The game logic lives in Claude's brain, not in the codebase.
4. **Tests ≈ 20% effort.** Test integration points (Socket.IO, CLI invocation, JSON parsing). Don't test Claude's narrative quality or Phaser rendering.
5. **Iterate on specs.** Phase specs are written when that phase begins. Earlier phases inform later specs.

## Current Tasks

See `@fix_plan.md` for the prioritized task list.

## Specs

See `specs/phase-1-core/` for current phase specifications:
- `overview.md` — Design pillars, core loop, platform
- `architecture.md` — Client/server/Claude pipeline, state contract
- `dm-integration.md` — DM response cycle, input options

See `specs/reference/` for the full 20-document GDD archive.
