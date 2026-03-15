# 19 — Data Models

## State Contract

Claude outputs JSON game state objects. The Phaser client reads them and renders. This contract is the critical interface between the AI engine and the renderer.

## Core Models

### GameState

```json
{
  "scene": "tavern | overworld | dungeon | combat",
  "turn": 42,
  "timeOfDay": "night",
  "character": { /* CharacterState */ },
  "location": { /* LocationState */ },
  "npcs": [ /* NpcState[] */ ],
  "narrative": { /* NarrativeState */ },
  "ui": { /* UiState */ }
}
```

### CharacterState

```json
{
  "name": "Thrain",
  "race": "dwarf",
  "class": "fighter",
  "level": 3,
  "hp": { "current": 28, "max": 34 },
  "ac": 16,
  "abilities": { "str": 16, "dex": 12, "con": 14, "int": 8, "wis": 13, "cha": 10 },
  "equipment": { "mainHand": "...", "body": "...", /* slots */ },
  "inventory": [ /* ItemCard[] */ ],
  "conditions": [],
  "gold": 45,
  "xp": 900,
  "position": { "x": 5, "y": 8 }
}
```

### LocationState

```json
{
  "id": "ashmaw-caves-f2",
  "name": "Ashmaw Caves, Floor 2",
  "tiles": [ /* 2D grid of tile IDs */ ],
  "fogOfWar": [ /* 2D grid: 0=unexplored, 1=explored, 2=visible */ ],
  "entities": [ /* positioned NPCs, enemies, objects */ ]
}
```

### NarrativeState

```json
{
  "text": "The door creaks open...",
  "choices": ["Enter cautiously", "Kick it open", "Listen first"],
  "allowFreeText": true,
  "diceRolls": [{ "type": "d20", "result": 14, "label": "Perception" }],
  "combatLog": ["Thrain attacks Goblin: 18 vs AC 13 — hit! 8 damage."],
  "ttsMarked": true
}
```

### ItemCard

```json
{
  "name": "Longsword +1",
  "rarity": "uncommon",
  "type": "weapon",
  "damage": "1d8+1 slashing",
  "weight": 3,
  "description": "The blade hums faintly.",
  "properties": ["versatile"]
}
```

## Design Principles

- **Claude is authoritative** — the server never modifies game state, only stores it
- **Client is a dumb renderer** — it reads JSON and draws pixels
- **Schemas evolve** — these are starting shapes, refined during development
