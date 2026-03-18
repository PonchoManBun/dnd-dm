# Edit NPC

## Parameters
- **Target NPC ID:** {{npc_id}}
- **Operation:** {{operation}}
- **Details:** {{details}}

## Supported Operations
- `update_knowledge` — Add/remove knowledge after story events
- `change_disposition` — Shift disposition based on player actions
- `add_secrets` — New secrets discovered through gameplay
- `update_greeting` — Change after quest completion or story beat

## Instructions
1. Read the existing NPC file
2. Apply the `{{operation}}` operation: {{details}}
3. Maintain backward compatibility (keep simple format fields in sync with rich format)
4. Run `python3 forge/validate.py npc` on the output to verify
