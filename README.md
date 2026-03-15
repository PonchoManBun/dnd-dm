# The Welcome Wench — Game Design Document

A 2D pixel art dungeon crawler RPG where **Claude Code CLI is the game engine**.

Phaser 3 renders the world. Claude reads D&D 5e SRD markdown files, rolls dice, resolves combat, controls NPCs, and generates narrative — just like a human Dungeon Master.

---

## Sections

| # | Section | Description |
|---|---------|-------------|
| 01 | [Game Overview](01-game-overview.md) | Elevator pitch, pillars, and core loop |
| 02 | [Narrative & Setting](02-narrative-and-setting.md) | World, tone, and lore framework |
| 03 | [Visual Style Guide](03-visual-style-guide.md) | Art direction, tile specs, palette |
| 04 | [Character Creation](04-character-creation.md) | Race, class, stats, alignment flow |
| 05 | [Character Sheet](05-character-sheet.md) | Stats, skills, equipment slots |
| 06 | [Progression & Leveling](06-progression-and-leveling.md) | XP, level-up, spell slots |
| 07 | [Item Cards](07-item-cards.md) | Loot, rarity, encumbrance, currency |
| 08 | [Permadeath & Tavern Hub](08-permadeath-and-tavern-hub.md) | Death flow, legacy, tavern as home base |
| 09 | [Overworld & Exploration](09-overworld-and-exploration.md) | Node-based travel, random encounters |
| 10 | [Fog of War](10-fog-of-war.md) | Vision, darkvision, torches, stealth |
| 11 | [Combat System](11-combat-system.md) | Turn-based grid combat, action economy |
| 12 | [Monster & NPC Sheets](12-monster-and-npc-sheets.md) | Stat blocks, behavior, social rules |
| 13 | [AI Dungeon Master](13-ai-dungeon-master.md) | DM archetypes, response cycle, narrative |
| 14 | [Multi-Agent NPC System](14-multi-agent-npc-system.md) | Faction agents, memory, event bus |
| 15 | [UI & HUD](15-ui-and-hud.md) | Split-screen layout, DM panel, hotbar |
| 16 | [Menus & Game Flow](16-menus-and-game-flow.md) | Title screen, saves, game states |
| 17 | [Audio & TTS](17-audio-and-tts.md) | Sound design, music, future TTS |
| 18 | [Technical Architecture](18-technical-architecture.md) | Client/server/Claude pipeline |
| 19 | [Data Models](19-data-models.md) | JSON schemas, state contract |
| 20 | [Development Roadmap](20-development-roadmap.md) | Milestones, MVP scope, phasing |

---

**Repo:** `/home/jetson/TWW` (private)
**Stack:** Phaser 3 · TypeScript · Vite · Node.js · Socket.IO · Claude Code CLI
**Rules:** D&D 5e SRD (markdown)
