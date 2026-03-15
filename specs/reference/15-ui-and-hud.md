# 15 — UI & HUD

## Split-Screen Layout

The game uses a **split-screen** design:

```
┌──────────────────────┬──────────────────┐
│                      │                  │
│    Game Viewport     │    DM Panel      │
│    (pixel art        │    (narrative     │
│     world)           │     text,         │
│                      │     dice rolls,   │
│                      │     combat log)   │
│                      │                  │
├──────────────────────┴──────────────────┤
│              Action Bar / HUD           │
└─────────────────────────────────────────┘
```

## Game Viewport (Left)

- Top-down pixel art rendering of the current location
- Character sprite, NPCs, enemies, terrain, objects
- Fog of war overlay
- Animated effects (spell impacts, torch flicker, weather)
- Building roof fade on entry

## DM Panel (Right)

- **Narrative text** — DM descriptions, dialogue, story beats
- **Dice rolls** — Animated pixel dice with results
- **Combat log** — Scrollable record of actions and outcomes
- **Choice buttons** — Contextual action options
- **Free-text input** — "Do something else..." field
- **TTS icon** — Marks text for future text-to-speech (deferred post-MVP)

## Action Bar (Bottom)

- **HP / AC / Level** — Core stats at a glance
- **Hotbar** — Quick-access slots for frequently used actions (attack, spells, items)
- **Status effects** — Active condition icons (poisoned, blessed, etc.)
- **Minimap toggle** — If the player has a map item

## Inventory Screen (Overlay)

- **Equipment slots** — Visual paper-doll layout
- **Backpack grid** — Item cards in a scrollable grid
- **Weight tracker** — Current weight / carrying capacity
- **Gold counter**

## Key UI Principles

- Dark backgrounds, light text, parchment accents
- Pixel art consistency across all UI elements
- No tooltips that break immersion — the DM explains everything narratively
- Keyboard-navigable — all menus support arrow keys and hotkeys
