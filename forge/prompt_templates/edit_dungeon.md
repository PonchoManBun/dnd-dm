# Edit Dungeon

## Parameters
- **Target file:** {{dungeon_file}}
- **Operation:** {{operation}}
- **Details:** {{details}}

## Supported Operations
- `add_room` — Add a new room with valid ID, connect via corridor
- `modify_room` — Change monsters, items, narrative, type of an existing room
- `rebalance_encounters` — Adjust monster count/CR across all rooms for target player level {{player_level}}
- `add_floor` — Append new floor, wire stairs from previous floor's last room
- `modify_narrative` — Update room descriptions, choices, on_clear text

## Instructions
1. Read the existing dungeon file at `{{dungeon_file}}`
2. Apply the `{{operation}}` operation with the following details: {{details}}
3. Ensure all validation rules still hold after the edit
4. Write the updated file back to `{{dungeon_file}}`
5. Run `python3 forge/validate.py dungeon {{dungeon_file}}` to verify
