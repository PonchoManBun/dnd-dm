# Generate Dungeon

Generate a complete dungeon JSON file matching the DungeonLoader schema.

## Arguments
- `$ARGUMENTS` — Theme description and parameters (e.g., "undead crypt, 3 floors, CR 1-4, player level 3")

## Steps

1. **Read the design guide** — `design_guide.md` is MANDATORY. It contains encounter budgets, room ratios, monster placement rules, and archetype effects.

2. **Parse parameters** from `$ARGUMENTS`:
   - Extract: theme, floor count, CR range, player level, DM archetype
   - Default: 2 floors, CR 0.25-2, player level 1, party of 4, Storyteller archetype

3. **Load registries** (CRITICAL — only use valid slugs):
   - Read `../game/assets/data/dnd_monsters.json` — note all valid monster slugs and their CR values
   - Read `../game/assets/data/items.csv` — note all valid item slugs (first column, lowercased, spaces→underscores)
   - Read `../forge_output/dungeons/` — check for existing dungeon names to avoid ID collisions

4. **Load game state** (optional):
   - Try `curl -s http://localhost:8000/state` for player info and DM archetype
   - If unavailable, use sensible defaults

5. **Plan the dungeon** before writing JSON:
   - **Theme/story**: What is this place? Why are these monsters here? What happened?
   - **Room layout**: Follow the design guide ratio (1 safe, 1 combat, 1 puzzle/trap, 1 treasure, 1 boss per floor)
   - **Difficulty curve**: Wave pattern (entrance → spike → breather → climax)
   - **Encounter budgets**: Calculate XP thresholds for the party level (see design guide tables)
   - **Topology**: Linear main path with optional side branches for treasure/lore

6. **Generate dungeon JSON** following `schemas/dungeon_example.json`:
   - Top level: `name`, `description`, `floors` array
   - Each floor: `id`, `depth`, `name`, `width` (30), `height` (20), `rooms`, `corridors`
   - Each room: int `id` (sequential from 0), `name`, `x`/`y`/`w`/`h`, `type`, `narrative` (BBCode)
   - Optional: `stairs_up`, `stairs_down`, `monsters`, `items`, `trap`, `choices`, `on_clear`
   - First room per floor: type `entrance`, `stairs_up: true`
   - Rooms with stairs need 4x4 minimum
   - All positions within room bounds, all slugs from registries
   - **Monster placement must be logical** (see design guide section 5):
     - Guards near doors, scouts in corners, ranged behind melee, bosses at back
     - No monster within 2 tiles of a corridor connection point
     - Melee 3+ tiles from doors, ranged 4+ tiles, bosses 5+ tiles
   - **Environmental storytelling**: Every room tells part of the dungeon's story
   - **Loot scales with depth**: Common on floor 1, uncommon on floor 2, rare on floor 3

7. **Post-generation review** — For each combat room, answer:
   - Does each monster's position make narrative sense?
   - Can the party enter and see threats before engaging?
   - Is there tactical variety? (not just "3 goblins in a line")
   - Does the encounter XP fall within the target difficulty for this room?
   - Fix anything that doesn't pass review.

8. **Write output** to `../forge_output/dungeons/{dungeon_name}.json`

9. **Validate**: Run `python3 validate.py dungeon ../forge_output/dungeons/{dungeon_name}.json`

10. **Fix any errors** and re-validate until clean

11. **Write manifest** to `../forge_output/manifests/gen_{timestamp}.json` with design notes including monster placement rationale (see design guide section 10)
