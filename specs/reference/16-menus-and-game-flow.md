# 16 — Menus & Game Flow

## Game States

```
Title Screen → New Game → DM Selection → Character Creation → Tavern → Game Loop
                                                                  ↑          ↓
                                                              Death ← ← ← Combat/Explore
```

## Title Screen

- **Pixel art splash** — The Welcome Wench tavern exterior, flickering sign
- **New Game** — Starts a fresh run
- **Continue** — Resumes an existing session (if one exists; save is deleted on resume)
- **Settings** — Audio, display, keybindings
- **Credits**

## New Game Flow

1. **DM Selection** — Choose from 5 DM archetypes. Each is introduced with a short narrated sample.
2. **Character Creation** — Guided by the chosen DM (see §04).
3. **Intro Narration** — The DM sets the scene. The camera pans to the tavern interior.
4. **Tavern Entry** — Player gains control. The game begins.

## In-Game Menus

All accessible via hotkeys:

- **Inventory** (`I`) — Equipment + backpack + weight
- **Character Sheet** (`C`) — Full stats, skills, features
- **Spellbook** (`B`) — Available spells, prepared spells, slot tracker (casters only)
- **Quest Log** (`J`) — Active and completed quests (DM-maintained)
- **World Map** (`M`) — Overworld node map (requires map item)
- **Settings** (`Esc`) — Pause + settings overlay

## Save System

- **Continuous auto-save** — Server persists game state after every action
- **No manual save** — Player cannot create save points
- **Delete on resume** — Loading a save deletes it. No save-scumming.
- **Death = deletion** — Character death wipes the save

## Pause

`Esc` pauses the game (single-player only, so pause is trivial). Opens the settings overlay. The game world freezes; the DM panel is still readable.
