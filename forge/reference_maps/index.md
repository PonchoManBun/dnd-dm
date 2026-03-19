# Forge Reference Map Gallery

## Purpose

This gallery provides the Forge agent with visual references for DawnLike tile art and layout patterns. When generating new maps (taverns, dungeons, mines, etc.), the Forge agent should study these examples to understand how the DawnLike tileset author composes spaces: room shapes, furniture placement, wall construction, and tile vocabulary. The goal is to produce maps that feel native to the art style.

All files here are symlinks back into `game/art/DawnLike/` to save disk space.

---

## Approved References

Example maps authored by DragonDePlatino (DawnLike tileset creator). These are the gold standard for how maps should look.

### town.gif

- **Shows:** A bustling town with multiple buildings, a central stone plaza, surrounding forest, and NPCs. Buildings include a shop (left, with weapon rack and counter), a tavern/inn (upper-right, with long bar counter, seating, and carpet), and various houses.
- **Study:** How buildings use 2-tile-thick walls with interior wood floors and exterior stone/dirt transitions. Furniture is grouped logically (bar counter with shelves behind, tables with chairs around them). Roads are stone tile with clear pathways. Grass and trees form natural borders. Door openings are 1 tile wide, centered on walls.
- **Source:** `game/art/DawnLike/Examples/Town.gif`

### dungeon.gif

- **Shows:** A multi-room stone dungeon with corridors, a large dirt-floored cavern room, a furnished side room (alchemy lab with potions, table, bookshelf), and vertical corridors with pillars. Rooms connected by narrow passages with doors.
- **Study:** Wall thickness is 2 tiles (double-layer brick). Corridors are 2-3 tiles wide. Rooms vary in size and shape. Torches/candles line walls at regular intervals for lighting. Doors placed at corridor-to-room transitions. Treasure and objects placed against walls, not blocking paths. The void/black background surrounds the dungeon.
- **Source:** `game/art/DawnLike/Examples/Dungeon.gif`

### mine.gif

- **Shows:** A natural cave system with a waterfall, mine cart tracks on wooden beams, mixed dirt/rock terrain, scattered rocks and gems, wooden support beams, and a small grassy alcove with flowers. Enemies (bats, spiders) positioned in open areas.
- **Study:** Organic room shapes with irregular edges (not rectangular). Rock walls blend into dirt floors naturally. Wooden beam supports run horizontally through tunnels. Water features flow vertically. Height transitions use ledge tiles. Mix of natural (grass, water, rock) and constructed (beams, tracks) elements.
- **Source:** `game/art/DawnLike/Examples/Mine.gif`

### underworld.gif

- **Shows:** A hellish fortress with lava rivers flanking a stone bridge, a grand hall with pillars and treasure hoard, dead trees and gravestones, fire sprites, and a throne/altar area at the top. Stone brick construction with dark palette.
- **Study:** Lava uses bright orange/red tiles creating rivers that divide the map into zones. The stone bridge is the only crossing point, creating a natural chokepoint. The upper fortress area has thick walls, symmetrical layout, and a raised dais. Environmental hazards (lava, fire) define impassable terrain. Dramatic lighting from lava and wall-mounted flames.
- **Source:** `game/art/DawnLike/Examples/Underworld.gif`

---

## Tile Vocabulary

Sprite sheets from the DawnLike tileset. Each tile is 16x16 pixels. Grid positions are given as (col, row) starting from (0, 0) at top-left.

### decor0.png

- **Contains:** Indoor furniture and decorative objects -- tables, chairs, bookshelves, cabinets, candelabras, barrels, crates, anvils, beds, fireplaces, carpets/rugs, fountains, statues, wall-mounted torches, signs, gravestones, and water features.
- **Grid:** 8 cols x 22 rows (128x352 px)
- **Key sprites:**
  - (0-3, 0-1): Tables and chairs (wood, dark wood variants)
  - (4-7, 0-1): Shelves, vines/foliage, pots, lanterns
  - (0-7, 2-3): Counters, barrels, crates, candelabras, chandeliers
  - (0-3, 4-5): Beds (single and double)
  - (4-7, 4-5): Weapon racks, armor stands, thrones
  - (0-7, 6-7): More furniture variants -- benches, stools, cabinets
  - (0-3, 8-9): Bookshelves, scroll racks
  - (0-7, 10-11): Anvils, forges, workbenches
  - (0-7, 12-13): Rugs and carpets (red, blue/gray)
  - (0-7, 14-17): Chests, crates, pots, urns, sacks
  - (0-7, 18-19): Water features, fountains, wells
  - (0-7, 20-21): Gravestones, signs, misc outdoor decor

### floor.png

- **Contains:** Floor and ground tiles with autotile borders -- stone, wood, grass, dirt, brick, sand, ice, water, lava, and specialty floors. Top rows contain palette swatches and autotile templates.
- **Grid:** 21 cols x 39 rows (336x624 px)
- **Key sprites:**
  - (0-6, 0): Palette reference swatches (8 colors) and autotile layout guides
  - (0-6, 1-4): Stone/brick floor variants (gray, blue-gray) with full autotile edges
  - (7-13, 1-4): Grass tiles with autotile edges
  - (14-20, 1-4): Orange cobblestone/path tiles with autotile edges
  - (0-6, 5-8): Dark blue/purple stone (dungeon floors)
  - (7-13, 5-8): Dirt/earth tiles with autotile edges
  - (0-6, 9-12): Sand/desert tiles
  - (7-13, 9-12): Orange brick/terracotta
  - (14-20, 9-12): Light tiles (ice, marble) and puddle/pond water
  - (0-6, 13-16): Red/dark red stone tiles
  - (7-13, 13-16): Wooden plank floors with autotile edges
  - (14-20, 13-16): Blue water / ice tiles
  - (0-6, 17-20): Dark slate/cave floor
  - (7-13, 17-20): Crop/farm field tiles (wheat, tilled earth)
  - (0-20, 21+): Additional floor variants (barrel tops, mine cart rails, specialty)

### wall.png

- **Contains:** Wall tiles using autotile format -- each wall type has a full set of corner, edge, and interior pieces for seamless tiling. Includes stone brick, cave rock, wooden, teal/ice, orange/sandstone, dark brick, red lava-rock, and crystal variants.
- **Grid:** 20 cols x 51 rows (320x816 px)
- **Key sprites:**
  - (0, 0): Autotile template showing corner/edge arrangement
  - (0-4, 1-5): Light gray stone brick walls (the standard dungeon wall)
  - (5-9, 1-5): Orange/brown cave walls
  - (10-14, 1-5): Dark checkerboard walls
  - (0-4, 6-10): Same wall types, additional connection variants
  - (5-9, 6-10): Teal/ice-tinted walls
  - (10-14, 6-10): Orange/warm stone walls
  - (15-19, 6-10): Green/mossy walls
  - (0-4, 21-25): Window and gate variants
  - (5-9, 21-25): Orange/brown window variants
  - (10-14, 21-25): Green/crystal window variants
  - Lower rows: Additional wall types (dark, red, blue, crystal) in same autotile format

### door0.png

- **Contains:** Door sprites in open and closed states for multiple styles -- wooden, iron, ornate, barred, and portcullis variants. Each door has front-facing and side-facing orientations.
- **Grid:** 8 cols x 6 rows (128x96 px)
- **Key sprites:**
  - (0-1, 0-5): Wooden doors (standard) -- closed and open states, vertical and horizontal
  - (2-3, 0-5): Ornate/reinforced doors with metal banding
  - (4-5, 0-5): Light/white doors (temple or palace style)
  - (6-7, 0-5): Iron gates and portcullis variants

---

## TMX Layouts

The DawnLike `Examples/` directory includes `.tmx` (Tiled Map Editor) files for each example map:

- `Examples/Town.tmx`
- `Examples/Dungeon.tmx`
- `Examples/Mine.tmx`
- `Examples/Underworld.tmx`
- `Examples/Blank.tmx` (empty template)

A `parse_tmx.py` utility (planned) can extract ASCII tile layouts from these files, showing the spatial arrangement of tile IDs in a human-readable grid. This is useful for the Forge agent to understand exact room dimensions, tile placement patterns, and layer structure without needing to open the files in Tiled.

---

## Design Patterns to Study

When generating new maps, the Forge agent should internalize these patterns from the DawnLike examples:

- **Tavern/inn interiors:** The bar counter runs along one wall (usually back wall), with shelves and barrels behind it. Seating is arranged in clusters of 1 table + 2-4 chairs with aisle space between groups. A fireplace or carpet anchors the common room. The entrance opens onto the main floor, not directly into furniture.

- **Room proportions and wall thickness:** Walls are consistently 2 tiles thick (outer face + inner face using autotile). Interior rooms range from 5x5 (small closet) to 15x12 (large hall). Corridors are 2-3 tiles wide for comfortable movement. Very large spaces use pillars or furniture to break up empty floor.

- **Furniture grouping:** Objects cluster by function -- a forge has an anvil, workbench, and tool rack nearby; a bedroom has a bed, nightstand, and chest; a library has bookshelves lining walls with a reading table in the center. Isolated single objects look wrong.

- **Door placement:** Doors are centered on the wall segment they occupy, or placed at corridor junctions. Corner entries (door at the very edge of a wall) are rare. Doors always have 1 tile of clear floor on both sides for passage. Double-wide doorways use two door tiles side by side for grand entrances.

- **Transition between indoor/outdoor areas:** Building exteriors use wall tiles facing outward with a clear ground-floor footprint. The transition from outdoor (grass, dirt, stone path) to indoor (wood plank, stone floor) happens at the door threshold. Outdoor areas use scattered objects (trees, rocks, flowers) to fill space naturally rather than tiling in rigid grids.

- **Lighting and atmosphere:** Torches and candles are placed at regular intervals along dungeon walls (every 4-6 tiles). Indoor rooms have at least one light source. Darker areas (caves, underworld) use fewer lights for mood. Lava and water provide ambient environmental lighting.

- **Negative space:** The void (black background) is used deliberately in underground maps to define the boundary of explored space. Not every corner needs to be filled -- empty floor tiles with occasional debris feel more natural than packing every cell with objects.
