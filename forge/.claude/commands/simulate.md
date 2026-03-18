---
description: "Run headless dungeon simulation — validate playability, balance, connectivity, and render map preview"
allowed-tools: Bash, Read, Write, Glob, Grep
---

# Dungeon Simulation

Run the headless dungeon simulator to validate that a dungeon is playable as a proper D&D session. Checks connectivity, encounter balance, monster placement, loot economy, and runs Monte Carlo combat simulations. Optionally renders a pixel-accurate map preview.

## Command: $ARGUMENTS

Parse the arguments. Examples:

- `/simulate` — simulate the most recently modified dungeon in `../forge_output/dungeons/`
- `/simulate crypt_of_the_fallen` — simulate a specific dungeon by name
- `/simulate ../forge_output/dungeons/shadow_keep.json` — simulate by path
- `/simulate crypt_of_the_fallen --level 3` — simulate at party level 3
- `/simulate render` — simulate + render pixel map preview
- `/simulate render shadow_keep --level 5` — render specific dungeon at level 5

Default parameters if not specified:
- `--level 1`
- `--party-size 4`
- `--runs 100`
- `--seed` (none, random)

---

## Steps

1. **Resolve the dungeon file**:
   - If a path is given, use it directly
   - If a name is given (no path separators), look for it in `../forge_output/dungeons/{name}.json` and `../game/assets/data/dungeons/{name}.json`
   - If no file specified, find the most recently modified `.json` in `../forge_output/dungeons/`
   - If no dungeons found anywhere, tell the user and stop

2. **Run schema validation first** (fast sanity check):
   ```bash
   python3 validate.py dungeon $DUNGEON_PATH
   ```
   If validation fails, report errors and stop — simulation results would be meaningless on invalid JSON.

3. **Run the simulation**:
   ```bash
   python3 simulate.py $DUNGEON_PATH --level $LEVEL --party-size $PARTY_SIZE --runs $RUNS
   ```
   Add `--seed $SEED` if a seed was specified.

4. **If `render` subcommand was used**, also generate the pixel map preview:
   ```bash
   python3 simulate.py $DUNGEON_PATH --level $LEVEL --party-size $PARTY_SIZE --runs $RUNS --render /tmp/dungeon_preview.png
   ```
   Then read the image at `/tmp/dungeon_preview.png` to show the user.

5. **Analyze the results** and provide a summary:

   **If PLAYABLE:**
   - Confirm the dungeon passes all checks
   - Highlight any warnings that might be worth addressing
   - Report survival rate and deadliest room
   - If survival rate > 90%, note the dungeon may be too easy

   **If ISSUES FOUND:**
   - List all errors (connectivity, cross-floor stairs)
   - List critical warnings (CR violations, boss too easy, empty loot)
   - Report survival rate — if < 50%, the dungeon needs rebalancing
   - Suggest specific fixes:
     - Low survival → reduce monster count or CR in deadliest room
     - Connectivity errors → check corridor definitions connect all rooms
     - Loot warnings → add items to empty combat/treasure rooms
     - Placement warnings → move monsters further from corridor entries

6. **If the user wants fixes**, edit the dungeon JSON directly:
   - Read the dungeon file
   - Apply the suggested changes (rebalance encounters, add loot, fix placement)
   - Re-run validation and simulation to confirm the fix
   - Report the before/after comparison (survival rate, warnings)
