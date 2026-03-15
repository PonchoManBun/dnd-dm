# The Welcome Wench — Project Instructions

## What This Is

A single-player 2D pixel art dungeon crawler where Claude Code CLI is the game engine/DM. See `PROMPT.md` for full context.

## Project Structure

```
PROMPT.md          # Current phase context and development principles
@fix_plan.md       # Prioritized task list for current phase
@AGENT.md          # Build/run/test commands
specs/phase-N-*/   # Phase-specific design specs
specs/reference/   # Original 20 GDD documents (read-only reference)
rules/             # D&D 5e SRD markdown files
```

## Architecture Rules

1. **Client is a dumb renderer** — reads JSON, draws pixels. No game logic.
2. **Server is a thin relay** — shuttles messages, persists state. No game logic.
3. **Claude is the engine** — all game rules, combat, narrative, NPC behavior live in Claude.
4. **State contract is the interface** — `shared/` TypeScript types define client ↔ server ↔ Claude boundary.

## Code Conventions

- Strict TypeScript (`strict: true`, no `any`)
- ESM modules only
- Shared types in `shared/`, imported by both client and server
- Vitest for testing
- Test integration points, not rendering or AI output

## Current Phase

Phase 1: Core Proof of Concept — prove Claude can be the DM. See `PROMPT.md` for objectives and `@fix_plan.md` for tasks.
