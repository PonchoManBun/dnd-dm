# Edit Quest

Edit an existing quest — add stages, modify outcomes, or update rewards.

## Arguments
- `$ARGUMENTS` — Quest ID and operation (e.g., "crypt_of_the_fallen add_stage 'Return to Old Tom with news'")

## Steps

1. **Parse** the target quest ID and operation from `$ARGUMENTS`
   - Supported operations: `add_stage`, `modify_outcomes`, `update_rewards`

2. **Read** the existing quest file from `../forge_output/narrative/{quest_id}.json`

3. **Apply the edit**:
   - `add_stage`: Create new stage with sequential ID, wire into existing stage outcomes
   - `modify_outcomes`: Update success/failure narratives and next_stage references
   - `update_rewards`: Adjust XP, gold, items, reputation values

4. **Write** updated quest back

5. **Validate**: Run `python3 validate.py quest ../forge_output/narrative/{quest_id}.json`
