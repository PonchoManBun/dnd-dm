# 01 — Game Overview

## Elevator Pitch

**The Welcome Wench** (TWW) is a single-player 2D pixel art dungeon crawler where an AI Dungeon Master runs a full D&D 5e campaign in real time. Claude Code CLI *is* the game engine — it reads SRD rules, rolls dice, controls every NPC, and narrates the world. Phaser 3 is just the renderer. You don't play a video game that imitates D&D. You play D&D with a pixel art tabletop.

## Design Pillars

1. **The DM is real.** Claude doesn't follow scripts. It interprets rules, improvises, and reacts to player creativity exactly like a human Dungeon Master.
2. **Permadeath matters.** One life. No save-scumming. Every decision carries weight. The world remembers your dead characters.
3. **Emergent everything.** Quests, factions, NPC relationships, and dungeon layouts are generated — never hand-authored. No two runs are alike.
4. **Dark comedy.** The world is dangerous and absurd. Death is frequent and narrated with gallows humor. Think Diablo meets Discworld.

## Core Game Loop

1. **Tavern** — Rest, shop, talk to NPCs, pick up quests, create characters.
2. **Travel** — Navigate the overworld node map. Random encounters. DM narration.
3. **Dungeon** — Explore procedural floors. Combat, traps, puzzles, loot.
4. **Return or Die** — Survive and return to the tavern with loot, or die and start fresh.

## Platform & Controls

- **Browser-based** (Phaser 3 + TypeScript + Vite)
- **Keyboard only** — arrow keys / WASD for movement, hotkeys for actions
- **Top-down view** with 32×32 pixel tiles

## Target Experience

A solo D&D session that feels handcrafted — but is entirely AI-driven.
