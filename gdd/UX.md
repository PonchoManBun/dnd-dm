# The Welcome Wench — UX Design

## Screen Map

```
Title Screen
    │
    ├── New Game → Character Creation → Village (Free-Roam)
    │                                        │
    │                                        ├── Build Mode (B key toggle)
    │                                        │       └── Back to Village
    │                                        │
    │                                        ├── Expedition Prep → World Map → Dungeon/Wilderness
    │                                        │                                      │
    │                                        │                                      ├── Combat (auto-enter on hostiles)
    │                                        │                                      │       └── Back to Exploration
    │                                        │                                      │
    │                                        │                                      └── Return to Village
    │                                        │
    │                                        └── Game Over (party wipe)
    │                                                └── Wake in Village (soft death)
    │
    └── Load Game → Village (Free-Roam)
```

All modes share the same underlying world view — mode changes are HUD/input overlays, not scene transitions. The player never leaves the 2D grid world.

## Village Mode HUD

The default play mode when in Oakhaven.

```
┌─────────────────────────────────────────────────────────────┐
│ [Party Panel]          [World View]          [DM Panel]     │
│                                                             │
│  Player HP/MP         ┌───────────────────┐  DM narration   │
│  Companion 1          │                   │  NPC dialogue    │
│  Companion 2          │   Top-down 2D     │  Season/time     │
│  Companion 3          │   tile grid       │  Current quest   │
│                       │                   │                  │
│  Time: Morning        │   Player moves    │  [Choice 1]      │
│  Season: Spring       │   freely          │  [Choice 2]      │
│  Day 14, Year 1       │                   │  [Choice 3]      │
│                       └───────────────────┘                  │
│                                                              │
│  [Inventory] [Build] [Map] [Journal] [Settings]              │
└──────────────────────────────────────────────────────────────┘
```

**Left panel:** Party status — HP, MP, conditions, active buffs. Time and season display.

**Center:** World view — the 2D tile grid. Player character and NPCs move on the grid. Click to move, bump to interact.

**Right panel:** DM Panel — narration text, NPC conversation, contextual choices, free-text input. This is the primary narrative interface (carried from existing implementation).

**Bottom bar:** Quick action buttons — Inventory (I), Build Mode (B), World Map (M), Journal (J), Settings (Esc).

## Build Mode HUD

Entered by pressing **B** from Village Mode.

```
┌──────────────────────────────────────────────────────────────┐
│ [Block Palette]        [World View + Grid]     [Info Panel]  │
│                                                              │
│  Category Tabs:        ┌───────────────────┐  Selected:      │
│  [Ground] [Floor]      │                   │  Wooden Wall    │
│  [Walls] [Furniture]   │   Grid overlay    │  Cost: 4 wood   │
│  [Decor] [Objects]     │   Ghost cursor    │  HP: 20         │
│                        │   Green = valid   │                  │
│  ┌────┬────┬────┐      │   Red = invalid   │  Materials:     │
│  │wall│wall│wall│      │                   │  Wood: 45       │
│  │wood│stn │brk │      └───────────────────┘  Stone: 20      │
│  ├────┼────┼────┤                             Iron: 8        │
│  │door│wind│fenc│                                            │
│  └────┴────┴────┘                             [Undo] [Redo]  │
│                                                              │
│  [Exit Build Mode (B/Esc)]                                   │
└──────────────────────────────────────────────────────────────┘
```

**Left panel:** Block palette organized by category tabs. Each block shows a 16×16 tile preview. Scroll within category.

**Center:** World view with grid overlay. Ghost cursor (translucent selected block) follows mouse. Valid cells highlighted green, invalid red. Placed blocks appear immediately.

**Right panel:** Selected block info (name, cost, stats). Current material inventory. Undo/Redo buttons.

**Controls:**
- Left-click: Place block
- Right-click: Remove block (returns partial materials)
- Scroll wheel: Cycle through blocks in category
- Tab: Next category
- B or Esc: Exit build mode
- Z (Ctrl+Z): Undo last placement
- Y (Ctrl+Y): Redo

## Combat Mode HUD

Triggers automatically when hostiles are encountered during exploration/expedition.

```
┌──────────────────────────────────────────────────────────────┐
│ [Initiative]          [Tactical View]          [DM Panel]    │
│                                                              │
│  ▶ Player (20)        ┌───────────────────┐  "The goblin     │
│    Goblin A (15)      │                   │   snarls and     │
│    Companion 1 (12)   │   Tactical grid   │   lunges with    │
│    Goblin B (8)       │   Movement range  │   its rusty      │
│                       │   Attack targets  │   blade..."      │
│  Actions:             │                   │                  │
│  [Move] [Attack]      │   Terrain markers │  [Choice 1]      │
│  [Spell] [Item]       │   Status icons    │  [Choice 2]      │
│  [Dodge] [Dash]       └───────────────────┘                  │
│                                                              │
│  HP: 24/30  AC: 16  [End Turn]                               │
└──────────────────────────────────────────────────────────────┘
```

This HUD carries forward from the existing combat implementation with minor layout adjustments. See `specs/reference/15-ui-and-hud.md` for full combat HUD spec.

**Left panel:** Initiative order (current turn highlighted). Action buttons for the active character.

**Center:** Tactical grid with movement range highlights, attack range indicators, terrain effects.

**Right panel:** DM narration of combat events — hits, misses, kills, spell effects, environmental changes.

## DM Panel

The DM Panel is the primary narrative interface across all modes. It adapts its behavior based on the current game mode:

| Mode | DM Panel Behavior |
|------|-------------------|
| **Village** | Narrates weather, NPC greetings, seasonal events. Shows NPC conversation when talking. Offers contextual choices (visit shop, check crops, talk to NPC). |
| **Build** | Comments on construction ("A fine wall takes shape"). Warns about structural issues. Suggests improvements. |
| **Expedition** | Describes rooms, corridors, environmental details. Offers exploration choices. Warns of danger. |
| **Combat** | Narrates attacks, spells, hits, misses, kills. Describes enemy behavior. Announces initiative changes. |
| **Night/Social** | NPC conversation mode. Deeper dialogue, story revelations, quest hooks. Tavern atmosphere. |

### Panel Layout
```
┌──────────────────────┐
│  DM Narration Text   │
│  (scrollable)        │
│                      │
│  ──────────────────  │
│  [Choice 1]          │
│  [Choice 2]          │
│  [Choice 3]          │
│  ──────────────────  │
│  [Free-text input]   │
│  [Speaker: Player ▼] │
└──────────────────────┘
```

**Narration area:** Scrollable text showing DM output. Styled differently for narration vs. NPC speech vs. system messages.

**Choice buttons:** 1–4 contextual choices generated by the DM. Click or press number key.

**Free-text input:** Type anything. The DM responds. Speaker dropdown selects which party member is speaking (for NPC conversations).

## Mode Transitions

| From | To | Trigger | Transition |
|------|----|---------|------------|
| Village | Build | Press B | HUD overlay swap, grid appears |
| Build | Village | Press B/Esc | HUD overlay swap, grid hides |
| Village | Expedition Prep | Interact with world map / DM choice | Open expedition prep screen |
| Expedition Prep | Expedition | Confirm departure | Load expedition map, DM narrates journey |
| Expedition | Combat | Hostile encounter | Initiative roll, combat HUD appears |
| Combat | Expedition | All hostiles defeated/fled | Combat HUD hides, DM narrates outcome |
| Expedition | Village | Return action / death | Load village map, DM narrates return |
| Any | Game Over | TPK (total party kill) | Death screen, then wake in village |

All transitions are smooth — no loading screens within the village. Expedition maps may require a brief load.

## Camera

| Mode | Camera Behavior |
|------|-----------------|
| **Village** | Free-roam. Follows player with slight lag. Scroll wheel zooms (1x–3x). Arrow keys or WASD pan. |
| **Build** | Same as village but with zoom options for precision. Mouse at screen edge scrolls. |
| **Expedition** | Follows player character. Locked during combat to active character. |
| **Combat** | Centers on active character during their turn. Can pan with arrow keys. |

Default zoom: 2x (each 16×16 tile = 32×32 pixels on screen).

## Input Mapping

### Village Mode
| Input | Action |
|-------|--------|
| Click / WASD | Move player |
| Bump into NPC | Start conversation |
| Bump into object | Interact (harvest, open, use) |
| B | Toggle Build Mode |
| I | Open Inventory |
| M | Open World Map |
| J | Open Journal |
| Esc | Settings / Menu |
| 1-4 | Select DM choice |
| Enter | Focus free-text input |

### Build Mode
| Input | Action |
|-------|--------|
| Left-click | Place selected block |
| Right-click | Remove block |
| Scroll wheel | Cycle blocks in category |
| Tab | Next category |
| Shift+Tab | Previous category |
| Ctrl+Z | Undo |
| Ctrl+Y | Redo |
| B / Esc | Exit Build Mode |

### Combat Mode
| Input | Action |
|-------|--------|
| Click cell | Move to / Attack target |
| A | Attack action |
| S | Spell/ability menu |
| D | Dodge action |
| Space | End turn |
| Tab | Cycle through targets |
| 1-4 | Select DM choice |

### Universal
| Input | Action |
|-------|--------|
| F5 | Quick save |
| F9 | Quick load |
| F11 | Fullscreen toggle |
| ` (backtick) | Debug console (dev only) |
