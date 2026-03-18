# Edit Quest

## Parameters
- **Target quest ID:** {{quest_id}}
- **Operation:** {{operation}}
- **Details:** {{details}}

## Supported Operations
- `add_stage` — Insert new quest stage with branching
- `modify_outcomes` — Change success/failure paths
- `update_rewards` — Adjust XP, items, reputation

## Instructions
1. Read the existing quest file at `forge_output/narrative/{{quest_id}}.json`
2. Apply the `{{operation}}` operation: {{details}}
3. Ensure stage IDs remain sequential and triggers are valid
4. Run `python3 forge/validate.py quest` on the output to verify
