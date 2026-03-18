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

7. **Write output** to `../forge_output/dungeons/{dungeon_name}.json`

8. **Validate**: Run `python3 validate.py dungeon ../forge_output/dungeons/{dungeon_name}.json`
   - If validation fails, fix schema errors and re-write. Do not proceed to simulation until validation passes.

9. **Simulate & Fix Loop** — This is the core quality gate. Run the simulator, read its report, and fix issues iteratively:

   ```bash
   python3 simulate.py ../forge_output/dungeons/{dungeon_name}.json --level {player_level} --party-size {party_size} --runs 100 --json
   ```

   Parse the JSON output and check each category. Fix issues in the dungeon JSON directly, re-write, and re-simulate until clean. **Maximum 3 iterations** — if it still fails after 3 attempts, report the remaining issues to the user.

   ### 9a. Connectivity
   - If any room is unreachable: add or fix corridor definitions so all rooms connect
   - If stairs_down is unreachable: ensure the room with stairs_down has a corridor path from entrance
   - If cross-floor stairs are missing: add `stairs_down: true` to the last significant room on each non-final floor

   ### 9b. Encounter Balance
   - If survival rate < 50%: the dungeon is too hard. Reduce monster count or swap to lower CR creatures in the deadliest room(s)
   - If survival rate > 95%: the dungeon may be too easy. Consider adding one more monster or upgrading CR in combat rooms
   - If a boss room is rated "Easy" or "Safe": increase the boss CR or add minions until it reaches at least "Medium"
   - If any encounter exceeds 1.5x Deadly threshold: remove a monster or swap to lower CR
   - If CR 2+ monsters appear vs level 1 party: swap to CR 0.25-0.5 creatures unless it's a deliberate "run away" encounter

   ### 9c. Monster Placement
   - If a monster is < 2 tiles from a corridor entry: move it deeper into the room
   - If a melee monster is < 3 tiles from entry: reposition to center or back of room
   - If a ranged monster is < 4 tiles from entry: move to far wall
   - If a boss monster is < 5 tiles from entry: move to center-back of the room

   ### 9d. Loot Economy
   - If a combat room has 0 items: add 1-2 items thematically appropriate to the monsters (weapons they carry, ammo)
   - If a treasure room has < 2 items: add items scaled to floor depth
   - If a boss room has < 2 items: add the floor's best item + consumables
   - If a boss room is missing `on_clear`: add victory narrative and `"victory": true` for final boss

   ### 9e. Render Check (optional but recommended)
   After fixing, render the pixel map to visually verify room layout:
   ```bash
   python3 simulate.py ../forge_output/dungeons/{dungeon_name}.json --render /tmp/{dungeon_name}_preview.png --runs 1
   ```
   Read the image. Check that:
   - Rooms are visually distinct (not merged or overlapping)
   - Corridors connect the right rooms with clean L-shaped paths
   - Entities (red=monsters, blue=items, green/yellow=stairs) are in sensible positions

10. **Post-generation review** — For each combat room, answer:
   - Does each monster's position make narrative sense?
   - Can the party enter and see threats before engaging?
   - Is there tactical variety? (not just "3 goblins in a line")
   - Does the encounter XP fall within the target difficulty for this room?
   - Fix anything that doesn't pass review.

11. **Write manifest** to `../forge_output/manifests/gen_{timestamp}.json` with design notes including:
    - Monster placement rationale (see design guide section 10)
    - Simulation results summary: survival rate, deadliest room, warning count
    - Any fixes applied during the simulate-fix loop
