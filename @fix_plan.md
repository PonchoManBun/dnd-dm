# Phase 1 — Core Proof of Concept: Task List

## HIGH — Must complete (core proof of concept)

- [ ] Scaffold monorepo (`client/`, `server/`, `shared/`)
- [ ] Minimal Phaser 3 scene — colored rectangle, no sprites, boots and displays
- [ ] Socket.IO relay server — accepts player actions, forwards to Claude, returns response
- [ ] Claude CLI integration — Node.js child process spawns Claude, sends prompt, parses JSON response
- [ ] DM response cycle — full round trip: browser input → server → Claude → server → browser display
- [ ] State contract types — TypeScript interfaces for GameState, NarrativeState, PlayerAction in `shared/`

## MEDIUM — Should complete (usable UI)

- [ ] DM panel UI — right-side panel displaying narrative text from Claude's response
- [ ] Choice buttons — render NarrativeState.choices as clickable options
- [ ] Free-text input — "Do something else..." text field for custom player actions
- [ ] Loading state — visual indicator while waiting for Claude's response

## LOW — Nice to have (robustness)

- [ ] Error handling — graceful fallback when Claude CLI fails or returns invalid JSON
- [ ] Conversation history — maintain context window of recent exchanges for Claude
- [ ] Smoke tests (3 tests):
  - Phaser scene boots without error
  - Socket.IO round-trip message delivery
  - Claude JSON response validates against state contract types
