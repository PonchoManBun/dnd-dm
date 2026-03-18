# 03 — Visual Style Guide

## Art Direction

TWW uses a **top-down 2D pixel art** style. The aesthetic is classic 16-bit RPG — think SNES-era dungeon crawlers — with a darker, grittier palette. Art assets come from the DawnLike 16x16 tileset (DawnBringer, OpenGameArt.org) and are modified as needed to maintain visual consistency.

## Tile Specifications

- **Tile size:** 16x16 pixels (defined in `Constants.TILE_SIZE`)
- **Grid:** All world geometry snaps to the 16px grid
- **Sprite size:** Characters use the DawnLike character atlas — 32x16 with 2 animation frames per character (frame 0 = idle). Sprites are region-clipped from the character_tiles atlas.
- **Animation:** Character sprites use 2-frame atlas regions. Visual effects (explosions, dust motes) use particle systems and procedural generation.

## Tile Atlases

The game uses multiple tile atlases generated at build time:

- **world_tiles** — Walls (16 directional variants like `wall-5-nsew`), floors, doors, decor (tables, chairs, bar counters, shelves, memorial plaques)
- **indoor_tiles** — Indoor floor tiles (e.g., `indoor-77` for tavern wood planks), indoor decorations
- **character_tiles** — Character/NPC sprites (e.g., `player-25` for Marta, `player-31` for Old Tom, `player-4` for Elara)

## Color Palette

- **Dungeons:** Dark, desaturated. Heavy use of grays, browns, and deep blues. Fog of war uses full black for unexplored and dimmed tiles for explored-but-not-visible. An ambient vignette shader (`ambient_vignette.gdshader`) subtly darkens screen edges for atmosphere.
- **Tavern:** Warmer tones via CanvasModulate tint (`Color(1.0, 0.92, 0.82)` — warm candlelight). Wood browns, candlelight amber. Warm-tinted DustMotes particles add atmosphere. The safest-feeling place in the game.
- **UI:** Dark panel backgrounds (`Color(0.06, 0.05, 0.08, 0.92)`) with light text. Cyan headers, yellow choice buttons. Parchment tones for menus.

## Visual Effects

- **CanvasModulate tint:** Applied in the tavern scene to create warm indoor lighting. Each environment type can apply its own CanvasModulate color.
- **Ambient vignette shader:** `ambient_vignette.gdshader` — smooth edge-darkening effect with configurable intensity (default 0.4) and softness (0.45). Applied as a canvas_item shader.
- **Hit vignette shader:** `hit_vignette.gdshader` — red screen flash on damage. Applied via a full-screen ColorRect with adjustable `vignette_intensity`.
- **Dust motes:** Particle system (`dust_motes.tscn`) spawned in indoor scenes. Tavern uses warm-tinted dust motes (`Color(1.0, 0.9, 0.7, 0.8)`).
- **Explosions:** Particle effect resource (`explosion.tres`) for area-of-effect visuals.
- **Status popups:** Floating text popups (`status_popup.tscn`) for damage numbers, condition changes.
- **Splatter effects:** Green splatter particles (`splatter_green.tscn`) for death/gore.

## Visual Rules

- **Fog of war:** Unexplored areas are fully black. Explored-but-not-visible areas are dimmed. Vision is computed via FOV algorithm from the player's position.
- **Vision radius:** Defined per-monster by `sight_radius`. Blindness status effect clears FOV entirely.
- **Stealth:** Enemies outside detection range are invisible — no silhouettes, no hints.
- **Loot:** Items on the ground are shown as tile sprites. Pickup triggers an inventory modal.
- **Dice:** All dice rolls are displayed as **text** in the combat log and DM panel (e.g., "d20(15)+5=20 vs AC 13 HIT!"). There are no animated dice sprites.

## Planned (Not Yet Implemented)

- **Roof transparency:** Buildings fading to transparent when the player enters.
- **Overworld palette:** Muted greens and earth tones with weather and time-of-day shifting.
- **BG3-style party:** Companion portrait sprites in the HUD showing health status.
