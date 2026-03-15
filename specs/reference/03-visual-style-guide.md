# 03 — Visual Style Guide

## Art Direction

TWW uses a **top-down 2D pixel art** style. The aesthetic is classic 16-bit RPG — think SNES-era dungeon crawlers — with a darker, grittier palette. Art assets come from open-source tilesets (OpenGameArt.org, Tuxemon-tileset) and are modified as needed to maintain visual consistency.

## Tile Specifications

- **Tile size:** 32×32 pixels
- **Grid:** All world geometry snaps to the 32px grid
- **Sprite size:** Characters and NPCs are 32×32 (one tile) or 32×64 (tall sprites)
- **Animation:** Simple 2–4 frame loops for idle, walk, attack, and death

## Color Palette

- **Dungeons:** Dark, desaturated. Heavy use of grays, browns, and deep blues. Light sources create warm pools (amber, orange) against cold darkness.
- **Tavern:** Warmer tones. Wood browns, candlelight amber, ale gold. The safest-feeling place in the game.
- **Overworld:** Muted greens and earth tones. Weather and time-of-day shift the palette.
- **UI:** Dark panel backgrounds with light text. Parchment tones for item cards and menus.

## Visual Rules

- **Buildings:** Roofs fade to transparent when the player enters; snap back on exit.
- **Fog of war:** Unexplored areas are fully black. Explored-but-not-visible areas are dimmed.
- **Vision radius:** Rendered as a soft-edged light circle around the player (darkvision = 10 tiles, torch = 5 tiles).
- **Stealth:** Enemies outside detection range are invisible — no silhouettes, no hints.
- **Loot:** DM narrates the find first, then an item card pops up with pixel art icon and stats.
- **Dice:** Animated pixel dice roll in the DM panel. Optional cinematic mode renders dice in the main viewport.
