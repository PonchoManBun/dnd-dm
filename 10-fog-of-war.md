# 10 — Fog of War

## Vision System

TWW uses D&D 5e vision rules rendered as a real-time fog-of-war overlay.

### Vision Ranges

| Source | Range | Tiles (32px) |
|--------|-------|-------------|
| **Darkvision** (racial) | 60 ft | 10 tiles |
| **Torch** (item) | 30 ft | 5 tiles |
| **No light, no darkvision** | 0 ft | Blind |

Vision is a **soft-edged circle** emanating from the player. Everything outside the vision radius is obscured.

### Fog States

- **Unexplored** — Fully black. The player has never seen this area.
- **Explored but not visible** — Dimmed/grayed out. The player has been here but can't currently see it. Shows terrain layout but not creatures or changes.
- **Visible** — Fully lit within the player's current vision radius.

## Darkness Rules

- **Bright light** — Full visibility. No penalties.
- **Dim light** — Edge of light radius. Disadvantage on Perception checks.
- **Darkness** — No visibility. Player is effectively blind (disadvantage on attacks, enemies have advantage).

Torches are inventory items that occupy the off-hand slot. They burn out over time (DM tracks duration). Running out of light in a dungeon is a serious threat.

## Stealth & Detection

- **Enemies are invisible** until the player detects them — no silhouettes, no indicators.
- **Detection** requires either: entering the enemy's proximity, or succeeding on a Perception check (passive or active).
- **Stealth approach** — Rogue or high-DEX characters can attempt to remain undetected (Stealth vs. enemy Perception).
- **Noise matters** — Combat and loud actions (breaking doors, casting loud spells) alert nearby enemies. The DM determines alert radius.
- **Surprise** — If the player detects enemies without being detected, combat begins with a surprise round (D&D 5e surprise rules).
