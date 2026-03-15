# 18 — Technical Architecture

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

## Phaser 3 Client

- **Role:** Renderer + input handler. Displays JSON game state. Sends player actions.
- **Stack:** Phaser 3, TypeScript, Vite
- **Responsibilities:** Tile rendering, sprite animation, fog of war, UI overlays, input capture, sound playback
- **Does NOT:** Roll dice, resolve combat, decide NPC behavior, generate narrative

## Node.js Server

- **Role:** Thin relay + state persistence. Not a game engine.
- **Stack:** Node.js, Socket.IO, file-based or SQLite state store
- **Responsibilities:** Relay messages between client and Claude, persist game state, manage sessions, enforce save rules (delete on resume)
- **Does NOT:** Contain game logic

## Claude Code CLI (The Engine)

- **Role:** The actual game engine. The Dungeon Master.
- **Reads:** D&D 5e SRD markdown files (modular, indexed, loaded on demand)
- **Maintains:** Full game state (character, inventory, map, NPCs, factions, world log)
- **Outputs:** JSON game state objects → server relays → client renders
- **Decides:** Everything — combat resolution, loot drops, NPC behavior, narrative, difficulty

## State Contract

Claude outputs structured JSON game state. The client renders it. The state contract defines the interface between AI and renderer. See §19 for data models.

## Monorepo Structure

```
/home/jetson/TWW/
├── client/      # Phaser 3 + TypeScript + Vite
├── server/      # Node.js + Socket.IO
├── docs/        # GDD, design notes
└── rules/       # D&D 5e SRD .md files
```

## Build & Dev

- **Vite** for client dev server and bundling
- **Node.js** for server runtime
- **Claude Code CLI** runs alongside as the DM process
