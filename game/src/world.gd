extends Node

const ESCAPE_LEVEL = "_exit"

# World is a main global singleton that holds the game state and handles
# mutations. Eventually it should be serializable and loadable from a save file.

signal world_initialized
signal map_changed(map: Map)
signal effect_occurred(effect: ActionEffect)
signal message_logged(message: String, level: int)
signal turn_started
signal turn_ended
signal game_ended
signal energy_updated(monster: Monster)

# Like NetHack, we world_plan the dungeon in advance, but levels are only created when
# they are first visited.
var world_plan: WorldPlan

# Always keep a reference to the player
var player: Monster

# Keep track of generated maps
var maps: Dictionary  # Map[id] -> Map
var current_map: Map

# Turn management
var current_turn: int
var game_mode: GameMode = GameMode.new()

# Party system
var party: Party = Party.new()

# Is the game over?
var game_over: bool = false

## Returns the currently-controlled character.
## In combat: returns the active combatant if it's a party member.
## In exploration: returns the player.
var active_character: Monster:
	get:
		if game_mode.is_combat():
			var active := game_mode.get_active_combatant()
			if active and party.is_party_member(active.combatant):
				return active.combatant
		return player

# Keep track of the max depth reached
var max_depth: int = 1

# Dungeon loader data (set when playing a JSON-defined dungeon)
var dungeon_data: DungeonLoader.DungeonData = null
var current_floor_data: DungeonLoader.FloorData = null

# Set to true when game state was loaded from a save file.
# game.gd checks this to skip World.initialize() after scene change.
var loaded_from_save: bool = false

# The player's faction affinity
var faction_affinities: Dictionary = {
	Factions.Type.HUMAN: 100,  # There could be different human factions with different affinities
	Factions.Type.CRITTERS: -30,  # Somewhat hostile. Maybe add taming?
	Factions.Type.MONSTERS: -100,  # Initially hostile but can improve
	Factions.Type.UNDEAD: -100,  # Initially hostile but can improve
}


func _init() -> void:
	Log.i("===========================")
	Log.i("= Godot Roguelike Example =")
	Log.i("===========================")
	Log.i("")


func _ready() -> void:
	initialize()


func initialize() -> void:
	Log.i("Initializing world...")

	# Initialize all vars
	current_turn = 1
	game_over = false
	game_mode = GameMode.new()
	max_depth = 1
	party = Party.new()

	# Create a new world world_plan
	world_plan = WorldPlan.new(WorldPlan.WorldType.NORMAL)
	Log.i("World world_plan created: %s" % world_plan)

	# Create the player with starting equipment
	player = MonsterFactory.create_monster(&"knight", Roles.Type.KNIGHT)
	Roles.equip_monster(player, Roles.Type.KNIGHT)

	# Apply character creation data if available (set by main menu)
	if has_meta("player_character_data"):
		var char_data: CharacterData = get_meta("player_character_data") as CharacterData
		if char_data:
			player.character_data = char_data
			player.name = char_data.character_name
			player.max_hp = char_data.max_hp
			player.hp = char_data.current_hp
			Log.i("Applied character creation data: %s the %s %s" % [
				char_data.character_name, char_data.get_race_name(), char_data.get_class_name_str()
			])
		remove_meta("player_character_data")

	Log.i("Player created: %s" % player)

	# Check if we should load a test dungeon instead of normal world gen
	if has_meta("use_test_dungeon"):
		remove_meta("use_test_dungeon")
		initialize_from_dungeon("res://assets/data/dungeons/test_crypt.json")
		return

	# Create the first level
	maps.clear()
	var plan := world_plan.get_first_level_plan()
	var map := _generate_map(plan)
	maps[map.id] = map
	current_map = map

	# Add the player to the main entrance
	if not map.add_monster_at_stairs(player, Obstacle.Type.STAIRS_UP):
		Log.e("Failed to add player to main entrance")

	# Place any existing companions near the player
	var player_start := map.find_monster_position(player)
	if player_start != Utils.INVALID_POS:
		_place_companions_near(player_start)

	# Compute FOV before the first turn
	update_vision()

	# Signal that the world is ready
	map_changed.emit(current_map)
	world_initialized.emit()


func initialize_from_dungeon(path: String) -> void:
	Log.i("Loading dungeon from: %s" % path)

	dungeon_data = DungeonLoader.load_dungeon(path)
	if not dungeon_data:
		Log.e("Failed to load dungeon: %s" % path)
		return

	Log.i("Dungeon loaded: %s (%d floors)" % [dungeon_data.name, dungeon_data.floors.size()])

	# Clear visited rooms for this new dungeon
	RoomTriggers.clear()

	# Generate maps for all floors and wire stair destinations
	maps.clear()
	for i in range(dungeon_data.floors.size()):
		var floor_data := dungeon_data.floors[i]
		var map := DungeonLoader.generate_map_from_floor(floor_data)
		maps[floor_data.id] = map

		# Wire stair destinations based on floor ordering
		_wire_stair_destinations(map, floor_data, i)

	# Start on the first floor
	current_floor_data = dungeon_data.floors[0]
	current_map = maps[current_floor_data.id]

	# Add the player at the entrance (stairs_up position)
	if not current_map.add_monster_at_stairs(player, Obstacle.Type.STAIRS_UP):
		Log.e("Failed to add player to dungeon entrance")

	# Place any existing companions near the player
	var player_start := current_map.find_monster_position(player)
	if player_start != Utils.INVALID_POS:
		_place_companions_near(player_start)

	# Compute FOV before the first turn
	update_vision()

	# Signal that the world is ready
	map_changed.emit(current_map)
	world_initialized.emit()


## Wire destination_level on stairs obstacles based on floor ordering in the dungeon.
func _wire_stair_destinations(map: Map, floor_data: DungeonLoader.FloorData, floor_index: int) -> void:
	for x in range(map.width):
		for y in range(map.height):
			var cell := map.get_cell(Vector2i(x, y))
			if not cell.obstacle:
				continue

			if cell.obstacle.type == Obstacle.Type.STAIRS_UP:
				if floor_index == 0:
					# First floor: stairs up leads to escape
					cell.obstacle.destination_level = ESCAPE_LEVEL
				else:
					cell.obstacle.destination_level = dungeon_data.floors[floor_index - 1].id

			elif cell.obstacle.type == Obstacle.Type.STAIRS_DOWN:
				if floor_index < dungeon_data.floors.size() - 1:
					cell.obstacle.destination_level = dungeon_data.floors[floor_index + 1].id


func _generate_map(plan: WorldPlan.LevelPlan) -> Map:
	match plan.type:
		WorldPlan.LevelType.ARENA:
			var generator := MapGeneratorFactory.create_generator(
				MapGeneratorFactory.GeneratorType.ARENA
			)
			return (
				generator
				. generate_map(
					20,
					15,
					{
						"depth": plan.depth,
					}
				)
			)

		WorldPlan.LevelType.DUNGEON:
			var generator := MapGeneratorFactory.create_generator(
				MapGeneratorFactory.GeneratorType.DUNGEON
			)
			return (
				generator
				. generate_map(
					30,
					20,
					{
						# Dungeon generation parameters
						"min_room_size": 5,
						"max_room_size": 9,
						"size_variation": 0.6,
						"room_placement_attempts": 500,
						"target_room_count": 30,
						"border_buffer": 3,
						"room_expansion_chance": 0.5,
						"max_expansion_attempts": 3,
						"horizontal_expansion_bias": 0.5,
						# Level parameters
						"depth": plan.depth,
						"has_up_stairs": plan.up_destination != "",
						"has_down_stairs": plan.down_destination != "",
						"has_amulet": plan.has_amulet
					}
				)
			)

		_:
			Log.e("Unsupported level type: %s" % plan.type)
			assert(false)
			return null


# Apply an action (presumably from the player) to the world and complete the turn.
func apply_player_action(action: BaseAction) -> ActionResult:
	# In combat, validate action economy before executing
	if game_mode.is_combat():
		var cs := game_mode.get_combat_state(active_character)
		if cs:
			var block_reason := _validate_combat_action(cs, action)
			if not block_reason.is_empty():
				message_logged.emit("[color=yellow]%s[/color]" % block_reason)
				return null

	Log.i("[color=lime]======== TURN %d STARTED ========[/color]" % World.current_turn)
	turn_started.emit()

	# Apply the player's action
	Log.i("Applying action: %s" % action)
	var result := action.apply(current_map)
	if not result:
		Log.i("[color=gray]==== TURN CANCELLED (Action Failed) ====[/color]")
		return null

	# If the action failed, return early without advancing the turn
	if not result.success:
		if result.message:
			message_logged.emit(result.message)
		Log.i("[color=gray]==== TURN CANCELLED (Result False) ====[/color]")
		return result

	# Check room entry triggers if playing a dungeon
	if current_floor_data:
		var player_pos := current_map.find_monster_position(player)
		if player_pos != Utils.INVALID_POS:
			RoomTriggers.check_room_entry(current_map, player_pos, current_floor_data)

	if game_mode.is_combat():
		_apply_combat_player_turn(result)
	else:
		_apply_exploration_turn(result)

	return result


## Validate whether a combat action is allowed given remaining resources.
## Returns empty string if allowed, or a reason string if blocked.
func _validate_combat_action(cs: CombatState, action: BaseAction) -> String:
	# Check if the action requires movement
	if action is PlayerAttackMoveAction:
		var dir: Vector2i = (action as PlayerAttackMoveAction).direction
		var player_pos := current_map.find_monster_position(active_character)
		var target_pos := player_pos + dir
		var target_monster := current_map.get_monster(target_pos)

		if target_monster:
			# This will be a melee attack — needs an action
			if not cs.can_act():
				return "No action remaining this turn!"
		else:
			# This is movement — needs movement points
			if not cs.can_move():
				return "No movement remaining this turn!"

	elif action is PlayerMeleeAction or action is PlayerFireAction:
		if not cs.can_act():
			return "No action remaining this turn!"

	return ""


func _apply_exploration_turn(result: ActionResult) -> void:
	# Update all monster status effects
	for monster in current_map.get_monsters():
		monster.tick_status_effects()
		monster.tick_encumbrance()

	# Process player nutrition
	var nutrition_cost := 1 + result.extra_nutrition_consumed
	var nutrition_result := player.nutrition.decrease(nutrition_cost)
	if nutrition_result.message:
		message_logged.emit(nutrition_result.message, LogMessages.Level.BAD)
	if nutrition_result.died:
		player.is_dead = true
		effect_occurred.emit(
			DeathEffect.new(player, current_map.find_monster_position(player), true)
		)
		game_over = true
		game_ended.emit()
		return

	# Process natural healing
	if player.nutrition.value >= Nutrition.THRESHOLD_STARVING and player.hp < player.max_hp:
		if current_turn % 3 == 0:
			var heal_amount := 1
			if player.nutrition.value >= Nutrition.THRESHOLD_SATIATED:
				heal_amount += 1
			player.hp = mini(player.hp + heal_amount, player.max_hp)

	# Check if player action was an attack — might trigger combat
	var attack_target: Monster = null
	for effect in result.effects:
		if effect is AttackEffect:
			attack_target = effect.target
			break

	if attack_target and _check_combat_trigger(attack_target):
		# Combat started from bump-attack — emit effects and return
		for effect in result.effects:
			effect_occurred.emit(effect)
		if result.message:
			message_logged.emit(result.message, result.message_level)
		return

	# Move companions toward the player
	var player_pos := current_map.find_monster_position(player)
	if player_pos != Utils.INVALID_POS:
		for companion in party.members:
			if companion.is_dead:
				continue
			var comp_pos := current_map.find_monster_position(companion)
			if comp_pos == Utils.INVALID_POS:
				continue
			var dist := comp_pos.distance_to(player_pos)
			# Only follow if more than 2 tiles away
			if dist > 2.0:
				var step := Pathfinding.get_next_step(current_map, comp_pos, player_pos, true)
				if step != Vector2i.ZERO:
					var target_pos := comp_pos + step
					var target_cell := current_map.get_cell(target_pos)
					if target_cell.is_walkable() and not target_cell.monster:
						current_map.get_cell(comp_pos).monster = null
						target_cell.monster = companion
						var move_effect := MoveEffect.new(companion, target_pos, comp_pos)
						result.effects.append(move_effect)

	# Accumulate energy for all monsters
	for monster in current_map.get_monsters():
		monster.energy += monster.get_speed()

	# Build a list of results from the action
	var results: Array[ActionResult] = [result]

	# Give turns to monsters that have enough energy
	var monsters := current_map.get_monsters()
	Log.d("Checking %d monsters for turns" % monsters.size())
	for monster in monsters:
		if is_party_member(monster):
			continue
		if monster.energy >= Monster.SPEED_NORMAL:
			var monster_action := monster.get_next_action(current_map)
			if monster_action:
				var monster_result := monster_action.apply(current_map)
				results.append(monster_result)
			monster.energy -= Monster.SPEED_NORMAL
			energy_updated.emit(monster)

	# Update area effects
	update_area_effects()

	# Update vision
	update_vision()

	# Check FOW reveal combat trigger
	if _check_combat_trigger():
		# Combat started from FOW reveal — emit effects and return
		for res in results:
			for effect in res.effects:
				effect_occurred.emit(effect)
			if res.message:
				message_logged.emit(res.message, res.message_level)
		return

	# Now emit all the results
	for res in results:
		for effect in res.effects:
			effect_occurred.emit(effect)
		if res.message:
			message_logged.emit(res.message, res.message_level)

	# Emit turn ended signal
	Log.i("[color=lime]-------- TURN %d ENDED --------[/color]" % World.current_turn)
	turn_ended.emit()

	# Mark the turn as over
	current_turn += 1

	# Is the entire party dead?
	if player.is_dead and party.all_dead():
		game_over = true
		game_ended.emit()


func _apply_combat_player_turn(result: ActionResult) -> void:
	# Tick active character status effects
	active_character.tick_status_effects()

	# Consume action economy resources based on what the player did
	var cs := game_mode.get_combat_state(active_character)
	if cs:
		_consume_combat_resources(cs, result)

	# Update vision
	update_vision()

	# Emit result effects
	for effect in result.effects:
		effect_occurred.emit(effect)
	if result.message:
		message_logged.emit(result.message, result.message_level)

	# Is the entire party dead?
	if player.is_dead and party.all_dead():
		game_over = true
		game_ended.emit()
		return

	# Auto-advance turn if the player has exhausted all resources or explicitly ended
	if cs and (cs.is_turn_exhausted() or result.message == "You end your turn."):
		if cs.is_turn_exhausted():
			message_logged.emit("[color=gray]Turn ended — no actions remaining.[/color]")
		game_mode.advance_turn()


## Consume CombatState resources based on what the action result contained.
func _consume_combat_resources(cs: CombatState, result: ActionResult) -> void:
	var had_attack := false
	var had_move := false

	for effect in result.effects:
		if effect is AttackEffect or effect is HitEffect:
			had_attack = true
		elif effect is MoveEffect and is_party_member(effect.target):
			had_move = true

	if had_attack:
		cs.use_action()
	elif had_move:
		cs.use_movement(1)


## Execute the current monster's combat turn.
## Loops through the monster's full action economy: move + attack.
func apply_combat_monster_turn() -> void:
	var cs := game_mode.get_active_combatant()
	if not cs or is_party_member(cs.combatant):
		return

	var monster := cs.combatant

	# Tick monster status effects
	monster.tick_status_effects()

	# Loop: give the monster actions until resources exhausted
	var actions_taken := 0
	var max_actions := 12  # Safety limit (6 move + action + buffer)
	while actions_taken < max_actions and not cs.is_turn_exhausted():
		var monster_action := monster.get_next_action(current_map)
		if not monster_action:
			break

		var result := monster_action.apply(current_map)
		if not result or not result.success:
			break

		# Consume action economy resources
		_consume_combat_resources(cs, result)

		# Emit effects
		for effect in result.effects:
			effect_occurred.emit(effect)
		if result.message:
			message_logged.emit(result.message, result.message_level)

		actions_taken += 1

		# If the monster used its action (attacked), stop looping
		if not cs.has_action:
			break

	# Update vision after full turn
	update_vision()

	# Is the entire party dead?
	if player.is_dead and party.all_dead():
		game_over = true
		game_ended.emit()
		return

	# Advance to next combatant
	game_mode.advance_turn()


func handle_special_level(id: String) -> void:
	match id:
		ESCAPE_LEVEL:
			# Request confirmation before letting the player leave
			var confirmed: Variant = await Modals.confirm(
				"Confirm Escape",
				"Are you sure you want to leave the dungeon? This will end your adventure."
			)
			if confirmed:
				current_map.find_and_remove_monster(player)
				message_logged.emit("[color=cyan]You have escaped the dungeon.[/color]")
				game_ended.emit()


func handle_level_transition(destination_level: String, coming_from_stairs: Obstacle.Type) -> void:
	if dungeon_data:
		# Dungeon-loaded transition: maps are pre-generated
		if not maps.has(destination_level):
			Log.e("No dungeon map found for %s" % destination_level)
			return

		# Update current_floor_data to match the destination
		for floor_data in dungeon_data.floors:
			if floor_data.id == destination_level:
				current_floor_data = floor_data
				break
	else:
		# Normal procedural transition
		var plan := world_plan.get_level_plan(destination_level)
		if not plan:
			Log.e("No level plan found for %s" % destination_level)
			return

		# Generate or load the next level
		if not maps.has(destination_level):
			var map := _generate_map(plan)
			map.id = destination_level
			maps[destination_level] = map

	# Remove player and companions from current map
	current_map.find_and_remove_monster(player)
	for companion in party.members:
		current_map.find_and_remove_monster(companion)

	# Switch to the new map
	current_map = maps[destination_level]
	max_depth = maxi(max_depth, current_map.depth)

	# Add player at appropriate entrance based on which stairs they used
	var target_stairs_type := (
		Obstacle.Type.STAIRS_DOWN
		if coming_from_stairs == Obstacle.Type.STAIRS_UP
		else Obstacle.Type.STAIRS_UP
	)
	if not current_map.add_monster_at_stairs(player, target_stairs_type):
		Log.e("Failed to add player at stairs")

	# Update FOV for new position
	var player_pos := current_map.find_monster_position(player)
	current_map.compute_fov(player_pos, player.sight_radius)

	# Place companions near the player
	_place_companions_near(player_pos)

	# Signal that the map has changed
	map_changed.emit(current_map)


## Updates all area effects and applies their damage
func update_area_effects() -> void:
	var messages: Array[String] = []

	for x in range(current_map.width):
		for y in range(current_map.height):
			var cell := current_map.get_cell(Vector2i(x, y))
			var pos := Vector2i(x, y)

			# Check for armed grenades and handle their countdown
			for item in cell.items:
				if item.type == Item.Type.GRENADE and item.is_armed:
					item.turns_to_activate -= 1
					if item.turns_to_activate <= 0:
						# Remove the grenade from the map
						current_map.remove_item(pos, item)
						# Apply the grenade's area effect
						if item.aoe_config:
							current_map.apply_aoe(
								pos,
								item.aoe_config.radius,
								item.aoe_config.type,
								item.damage,
								item.aoe_config.turns
							)
							messages.append("%s explodes!" % item.get_name(Item.NameFormat.THE))
							# Create visual explosion effect
							await VisualEffects.create_explosion(
								get_tree().current_scene, pos, true
							)
						else:
							Log.e("Armed grenade has no AOE config: %s" % item)

	# Apply damage from each effect *after* the grenades have exploded
	for x in range(current_map.width):
		for y in range(current_map.height):
			var cell := current_map.get_cell(Vector2i(x, y))
			var pos := Vector2i(x, y)

			# Apply damage from each effect
			for effect in cell.area_effects:
				if cell.monster:
					var monster: Monster = cell.monster
					var result := Combat.resolve_aoe_damage(monster, effect.damage, effect.type)
					if result.killed:
						monster.is_dead = true
						if monster != player:
							messages.append(
								"%s is killed!" % monster.get_name(Monster.NameFormat.THE)
							)
							effect_occurred.emit(DeathEffect.new(monster, pos, monster == player))
							monster.drop_everything()
			# Update effect durations
			cell.update_effects()

	# Log all messages at once
	for msg in messages:
		message_logged.emit(msg)


func update_vision() -> void:
	var player_pos := current_map.find_monster_position(player)
	if player.has_status_effect(StatusEffect.Type.BLIND):
		current_map.clear_fov(player_pos)
	else:
		current_map.compute_fov(player_pos, player.sight_radius)


func is_party_member(monster: Monster) -> bool:
	return party.is_party_member(monster)


## Place all living party companions on walkable cells adjacent to the given position.
func _place_companions_near(pos: Vector2i) -> void:
	var placed := 0
	for companion in party.members:
		if companion.is_dead:
			continue
		# Remove from old map position if present
		current_map.find_and_remove_monster(companion)
		var found_spot := false
		for dir in Utils.ALL_DIRECTIONS:
			var adj := pos + dir
			if not current_map.is_in_bounds(adj):
				continue
			var cell := current_map.get_cell(adj)
			if cell.is_walkable() and not cell.monster:
				cell.monster = companion
				placed += 1
				found_spot = true
				break
		if not found_spot:
			Log.e("Could not place companion %s near %s" % [companion.name, pos])
	if placed > 0:
		Log.i("Placed %d companions near %s" % [placed, pos])


## Check if combat should start from FOW reveal or bump-attack.
func _check_combat_trigger(bump_target: Monster = null) -> bool:
	if game_mode.is_combat():
		return false

	var player_pos := current_map.find_monster_position(player)
	if player_pos == Utils.INVALID_POS:
		return false

	# Get visible monsters that are AGGRESSIVE and hostile to the player
	var visible_monsters := current_map.get_visible_monsters()
	var enemies: Array[Monster] = []
	for monster in visible_monsters:
		if is_party_member(monster):
			continue
		if monster.is_hostile_to(player) and monster.behavior == Monster.Behavior.AGGRESSIVE:
			enemies.append(monster)

	var player_surprised := false
	var enemies_surprised := false

	if bump_target:
		# Player bump-attacked something — it joins combat even if not AGGRESSIVE
		if bump_target not in enemies:
			bump_target.behavior = Monster.Behavior.AGGRESSIVE
			enemies.append(bump_target)
		# If bump target wasn't visible (player snuck up), enemies are surprised
		var target_pos := current_map.find_monster_position(bump_target)
		if target_pos != Utils.INVALID_POS and not current_map.is_visible(target_pos):
			enemies_surprised = true
		game_mode.enter_combat(player, enemies, bump_target, player_surprised, enemies_surprised)
		return true
	else:
		# FOW reveal check — any AGGRESSIVE hostile visible?
		if enemies.size() > 0:
			game_mode.enter_combat(player, enemies)
			return true

	return false
