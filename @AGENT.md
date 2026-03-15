# Build / Run / Test Instructions

## Prerequisites

- Node.js 20+
- npm 10+
- Claude Code CLI installed and authenticated

## Project Structure

```
client/       # Phaser 3 + TypeScript + Vite (browser renderer)
server/       # Node.js + Socket.IO (thin relay)
shared/       # TypeScript interfaces (state contract, shared between client/server)
specs/        # Phase specs and reference GDD docs
rules/        # D&D 5e SRD markdown files
```

## Commands

```bash
# Install all dependencies (from project root)
npm install

# Start development (client + server concurrently)
npm run dev

# Build for production
npm run build

# Run tests
npm test

# Lint
npm run lint
```

## Key Conventions

- **Strict TypeScript** — `strict: true`, no `any` unless absolutely necessary
- **ESM modules** — Use ES module syntax (`import`/`export`), not CommonJS
- **Shared types** — All state contract interfaces live in `shared/` and are imported by both client and server
- **No game logic in client or server** — Claude is the game engine. Client renders JSON. Server relays messages. Neither contains game rules, combat resolution, or narrative generation.
- **Vitest** for testing — minimal config, pairs with Vite
- **Test integration points, not rendering or AI output** — Test Socket.IO delivery, CLI invocation, JSON schema conformance
