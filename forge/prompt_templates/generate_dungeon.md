# Generate Dungeon

## Parameters
- **Theme:** {{theme}}
- **Floor count:** {{floor_count}}
- **Target CR range:** {{cr_min}} — {{cr_max}}
- **Player level:** {{player_level}}
- **DM Archetype:** {{dm_archetype}}

## Context
{{narrative_context}}

## Instructions
Generate a complete dungeon JSON file matching the DungeonLoader schema.

### Requirements
1. Create {{floor_count}} floors with increasing difficulty
2. Each floor needs 4-6 rooms connected by corridors
3. First room on each floor must be type `entrance` with `stairs_up: true`
4. Last significant room on non-final floors needs `stairs_down: true`
5. Final floor ends with a `boss` room with `choices` and `on_clear`
6. Use only monster slugs from the registry (see `game/assets/data/dnd_monsters.json`)
7. Use only item slugs from the registry (see `game/assets/data/items.csv`)
8. All monster/item positions must be within their room bounds
9. Include `narrative` BBCode text for each room
10. Match tone to DM archetype: {{dm_archetype}}

### Output
Write the dungeon JSON to `forge_output/dungeons/{{dungeon_name}}.json`
Run `python3 forge/validate.py dungeon forge_output/dungeons/{{dungeon_name}}.json` to verify.
