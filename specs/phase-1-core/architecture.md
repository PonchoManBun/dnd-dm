# Phase 1: Core Proof of Concept — Architecture

> Extracted from [GDD 18 — Technical Architecture](../reference/18-technical-architecture.md) and [GDD 19 — Data Models](../reference/19-data-models.md)

## System Overview

```
┌─────────────┐     WebSocket      ┌─────────────┐     CLI / API     ┌─────────────┐
│   Phaser 3   │ ◄──(Socket.IO)──► │  Node.js     │ ◄──────────────► │ Claude Code  │
│   Client     │                   │  Server      │                  │ CLI (DM)     │
│  (browser)   │                   │              │                  │              │
│  TypeScript  │                   │  State store  │                  │  SRD .md     │
│  Vite        │                   │  Relay        │                  │  files       │
└─────────────┘                    └─────────────┘                   └─────────────┘
```

## Component Roles

### Phaser 3 Client (Browser)
- **Role:** Renderer + input handler
- **Does:** Display JSON game state, capture player input, send actions via Socket.IO
- **Does NOT:** Roll dice, resolve combat, decide NPC behavior, generate narrative

### Node.js Server
- **Role:** Thin relay + state persistence
- **Does:** Relay messages between client and Claude, persist game state, manage sessions
- **Does NOT:** Contain game logic

### Claude Code CLI (The Engine)
- **Role:** The actual game engine / Dungeon Master
- **Reads:** D&D 5e SRD markdown files
- **Maintains:** Full game state
- **Outputs:** JSON game state objects → server relays → client renders
- **Decides:** Everything — combat, loot, NPC behavior, narrative, difficulty

## State Contract

Claude outputs structured JSON game state. The client renders it. These TypeScript interfaces define the boundary.

### GameState

```typescript
interface GameState {
  scene: 'tavern' | 'overworld' | 'dungeon' | 'combat';
  turn: number;
  timeOfDay: string;
  character: CharacterState;
  location: LocationState;
  npcs: NpcState[];
  narrative: NarrativeState;
  ui: UiState;
}
```

### NarrativeState

```typescript
interface NarrativeState {
  text: string;
  choices: string[];
  allowFreeText: boolean;
  diceRolls: DiceRoll[];
  combatLog: string[];
  ttsMarked: boolean;
}

interface DiceRoll {
  type: string;     // e.g., "d20"
  result: number;
  label: string;    // e.g., "Perception"
}
```

### PlayerAction

```typescript
interface PlayerAction {
  type: 'choice' | 'freetext' | 'move' | 'hotkey';
  value: string;    // The choice text, free-text input, direction, or hotkey ID
  timestamp: number;
}
```

### CharacterState

```typescript
interface CharacterState {
  name: string;
  race: string;
  class: string;
  level: number;
  hp: { current: number; max: number };
  ac: number;
  abilities: { str: number; dex: number; con: number; int: number; wis: number; cha: number };
  equipment: Record<string, string>;
  inventory: ItemCard[];
  conditions: string[];
  gold: number;
  xp: number;
  position: { x: number; y: number };
}
```

## Phase 1 Scope

For the proof of concept, implement:
1. The three-component pipeline (client → server → Claude → server → client)
2. `NarrativeState` and `PlayerAction` types in `shared/`
3. A minimal `GameState` (can be a subset — just `narrative` and `scene` are enough)
4. Socket.IO message passing with `player:action` and `dm:response` events

Full `CharacterState`, `LocationState`, and `ItemCard` are defined in `shared/` as types but not populated until Phase 2.

## Monorepo Structure

```
client/      # Phaser 3 + TypeScript + Vite
server/      # Node.js + Socket.IO
shared/      # TypeScript interfaces (state contract)
rules/       # D&D 5e SRD .md files
```

## Design Principles

- **Claude is authoritative** — the server never modifies game state, only stores it
- **Client is a dumb renderer** — it reads JSON and draws pixels
- **Schemas evolve** — these are starting shapes, refined during development
