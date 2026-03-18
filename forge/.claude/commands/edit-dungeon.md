# Edit Dungeon

Edit an existing dungeon file — add rooms, modify encounters, rebalance, add floors, or update narrative.

## Arguments
- `$ARGUMENTS` — Target file and operation (e.g., "test_crypt.json add_room floor crypt_f1 'Hidden Alcove' type treasure")

## Steps

1. **Parse** the target dungeon file and operation from `$ARGUMENTS`
   - Supported operations: `add_room`, `modify_room`, `rebalance_encounters`, `add_floor`, `modify_narrative`

2. **Read** the existing dungeon JSON

3. **Load registries** for slug validation:
   - `../game/assets/data/dnd_monsters.json`
   - `../game/assets/data/items.csv`

4. **Apply the edit**:
   - `add_room`: Assign next sequential room ID, position within floor bounds, add corridor connecting to existing room
   - `modify_room`: Find room by floor ID + room ID, update specified fields
   - `rebalance_encounters`: Adjust monster types/counts across all rooms for target player level
   - `add_floor`: Append new floor, set `stairs_down` on previous floor's last room, new floor starts with `entrance` + `stairs_up`
   - `modify_narrative`: Update room descriptions, choices, on_clear text

5. **Write** updated JSON back to the same file

6. **Validate**: Run `python3 validate.py dungeon {file}`

7. **Fix any errors** and re-validate
