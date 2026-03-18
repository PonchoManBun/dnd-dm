# Generate Narrative Pool

## Parameters
- **Theme:** {{theme}}
- **Categories:** {{categories}}
- **Count per category:** {{count_per_category}}
- **DM Archetype:** {{dm_archetype}}

## Instructions
Generate narrative pool entries matching the `narratives.json` structure.

### Format Reference
The narratives.json structure uses these categories:
- `room_entry` — Keyed by theme (dungeon, cave, crypt, etc.), each containing an array of description strings
- `combat_start` — Array of combat initiation descriptions
- `combat_end` — Array of combat conclusion descriptions
- `item_discovery` — Array of item finding descriptions
- `choice_scenarios` — Array of {text, choices[]} objects
- `rest` — Array of rest descriptions
- `level_transition` — Array of floor transition descriptions

### Requirements
1. Generate {{count_per_category}} entries per requested category
2. Match tone to DM archetype: {{dm_archetype}}
3. Keep descriptions concise (1-2 sentences)
4. For choice_scenarios, include 2-3 choices per scenario
5. Do not duplicate existing entries (read existing pools first)

### Output
Write to `forge_output/narrative/pools/{{theme}}_narratives.json`
