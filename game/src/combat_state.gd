class_name CombatState
extends RefCounted

## Tracks per-turn action economy for D&D 5e combat.
## Each combatant gets: Movement + Action + Bonus Action + Reaction per turn.

var combatant: Monster
var movement_remaining: int = 0  # In tiles (speed_feet / 5)
var has_action: bool = true
var has_bonus_action: bool = true
var has_reaction: bool = true
var has_used_extra_attack: bool = false

# Initiative tracking
var initiative: int = 0

# Turn tracking within a combat round
var has_taken_turn: bool = false


func _init(p_combatant: Monster = null) -> void:
	combatant = p_combatant
	if combatant and combatant.character_data:
		reset_turn()


func reset_turn() -> void:
	has_taken_turn = false
	has_action = true
	has_bonus_action = true
	# Reaction resets at start of YOUR turn, not on use
	has_reaction = true
	has_used_extra_attack = false
	if combatant and combatant.character_data:
		var base_speed: int = combatant.character_data.speed_feet
		movement_remaining = RulesEngine.apply_condition_speed_modifiers(
			combatant.character_data, base_speed
		) / 5
	else:
		movement_remaining = 6  # Default 30ft = 6 tiles


func use_movement(tiles: int) -> bool:
	if tiles <= movement_remaining:
		movement_remaining -= tiles
		return true
	return false


func use_action() -> bool:
	if has_action:
		has_action = false
		return true
	return false


func use_bonus_action() -> bool:
	if has_bonus_action:
		has_bonus_action = false
		return true
	return false


func use_reaction() -> bool:
	if has_reaction:
		has_reaction = false
		return true
	return false


func can_move() -> bool:
	return movement_remaining > 0


func can_act() -> bool:
	return has_action


func can_bonus_act() -> bool:
	return has_bonus_action


func can_react() -> bool:
	return has_reaction


func is_turn_exhausted() -> bool:
	return not has_action and not has_bonus_action and movement_remaining <= 0


func _to_string() -> String:
	return "CombatState(move=%d, action=%s, bonus=%s, reaction=%s)" % [
		movement_remaining, has_action, has_bonus_action, has_reaction
	]
