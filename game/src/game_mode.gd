class_name GameMode
extends RefCounted

## State machine for switching between Exploration and Combat modes.
##
## EXPLORATION: Roguelike turns — grid movement, bump-to-interact, 1 action/turn.
## COMBAT: D&D 5e tactical mode — initiative order, action economy, positioning.

enum Mode {
	EXPLORATION,
	COMBAT,
}

signal mode_changed(new_mode: Mode)
signal combat_started(combatants: Array[Monster])
signal combat_ended(victory: bool)
signal turn_order_changed(order: Array[CombatState])
signal active_combatant_changed(combatant: CombatState)

var current_mode: Mode = Mode.EXPLORATION

# Combat tracking
var combatants: Array[CombatState] = []
var current_combatant_index: int = 0
var combat_round: int = 0

# Which monsters triggered combat
var _hostile_trigger: Monster = null


func get_active_combatant() -> CombatState:
	if combatants.is_empty():
		return null
	return combatants[current_combatant_index]


func is_exploration() -> bool:
	return current_mode == Mode.EXPLORATION


func is_combat() -> bool:
	return current_mode == Mode.COMBAT


## Start combat when a hostile is detected or player attacks.
func enter_combat(player: Monster, enemies: Array[Monster], trigger: Monster = null, player_surprised: bool = false, enemies_surprised: bool = false) -> void:
	if current_mode == Mode.COMBAT:
		return

	current_mode = Mode.COMBAT
	_hostile_trigger = trigger
	combat_round = 1
	combatants.clear()

	# Roll initiative for all combatants
	var player_state := CombatState.new(player)
	if player.character_data:
		player_state.initiative = RulesEngine.initiative_roll(player.character_data)
	else:
		player_state.initiative = Dice.roll(1, 20)
	combatants.append(player_state)

	for enemy in enemies:
		var enemy_state := CombatState.new(enemy)
		if enemy.character_data:
			enemy_state.initiative = RulesEngine.initiative_roll(enemy.character_data)
		else:
			enemy_state.initiative = Dice.roll(1, 20)
		combatants.append(enemy_state)

	# Sort by initiative (highest first), break ties with DEX
	combatants.sort_custom(func(a: CombatState, b: CombatState) -> bool:
		if a.initiative != b.initiative:
			return a.initiative > b.initiative
		# Tie-break: higher DEX goes first
		var a_dex := a.combatant.character_data.dexterity if a.combatant.character_data else 10
		var b_dex := b.combatant.character_data.dexterity if b.combatant.character_data else 10
		return a_dex > b_dex
	)

	# Mark surprised combatants
	for cs: CombatState in combatants:
		if cs.combatant == player and player_surprised:
			cs.is_surprised = true
		elif cs.combatant != player and enemies_surprised:
			cs.is_surprised = true

	current_combatant_index = 0
	_reset_all_turns()

	Log.i("Combat started! Round %d, %d combatants" % [combat_round, combatants.size()])
	for cs: CombatState in combatants:
		Log.i("  Initiative %d: %s" % [cs.initiative, cs.combatant.get_name()])

	mode_changed.emit(Mode.COMBAT)
	combat_started.emit(_get_all_monsters())
	turn_order_changed.emit(combatants)
	active_combatant_changed.emit(get_active_combatant())


## End the current combatant's turn and advance to the next.
func advance_turn() -> void:
	if current_mode != Mode.COMBAT:
		return

	var current := get_active_combatant()
	if current:
		current.has_taken_turn = true

	# Remove dead combatants
	_remove_dead()

	# Advance to next combatant
	current_combatant_index += 1

	# Check if round is over
	if current_combatant_index >= combatants.size():
		combat_round += 1
		current_combatant_index = 0
		_reset_all_turns()
		Log.i("Combat round %d" % combat_round)

	# Skip surprised combatants in round 1
	var next := get_active_combatant()
	if next and next.is_surprised and combat_round == 1:
		next.has_taken_turn = true
		next.is_surprised = false
		Log.i("%s is surprised and loses their turn!" % next.combatant.get_name())
		advance_turn()
		return

	# Check if combat should end
	if _should_end_combat():
		exit_combat(true)
		return

	active_combatant_changed.emit(get_active_combatant())


## End combat and return to exploration.
func exit_combat(victory: bool) -> void:
	if current_mode != Mode.COMBAT:
		return

	current_mode = Mode.EXPLORATION
	var monsters := _get_all_monsters()
	combatants.clear()
	current_combatant_index = 0
	combat_round = 0

	Log.i("Combat ended. Victory: %s" % victory)
	mode_changed.emit(Mode.EXPLORATION)
	combat_ended.emit(victory)


## Check if the player's turn is active.
func is_player_turn() -> bool:
	if current_mode != Mode.COMBAT:
		return true  # In exploration, it's always "player's turn"
	var active := get_active_combatant()
	return active != null and active.combatant == World.player


## Get combat state for a specific monster.
func get_combat_state(monster: Monster) -> CombatState:
	for cs: CombatState in combatants:
		if cs.combatant == monster:
			return cs
	return null


func _should_end_combat() -> bool:
	# Combat ends when all enemies are dead
	var enemies_alive := 0
	var player_alive := false
	for cs: CombatState in combatants:
		if cs.combatant == World.player:
			if not cs.combatant.is_dead:
				player_alive = true
		elif not cs.combatant.is_dead:
			enemies_alive += 1

	return enemies_alive == 0 or not player_alive


func _reset_all_turns() -> void:
	for cs: CombatState in combatants:
		cs.reset_turn()


func _remove_dead() -> void:
	var i := combatants.size() - 1
	while i >= 0:
		if combatants[i].combatant.is_dead:
			combatants.remove_at(i)
			if current_combatant_index > i:
				current_combatant_index -= 1
		i -= 1


func _get_all_monsters() -> Array[Monster]:
	var monsters: Array[Monster] = []
	for cs: CombatState in combatants:
		monsters.append(cs.combatant)
	return monsters
