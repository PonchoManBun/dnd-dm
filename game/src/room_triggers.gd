class_name RoomTriggers
extends RefCounted

## Handles first-entry room events: narrative text, monster awareness, trap activation.
## Tracks which rooms have been visited to avoid repeat triggers.

# Set of visited room keys: "map_id:room_id"
static var _visited_rooms: Dictionary = {}


static func clear() -> void:
	_visited_rooms.clear()


static func has_visited(map_id: String, room_id: int) -> bool:
	var key := "%s:%d" % [map_id, room_id]
	return _visited_rooms.has(key)


static func mark_visited(map_id: String, room_id: int) -> void:
	var key := "%s:%d" % [map_id, room_id]
	_visited_rooms[key] = true


## Check if player entered a new room and fire triggers.
## Call this after player movement.
static func check_room_entry(map: Map, player_pos: Vector2i, dungeon_floor: DungeonLoader.FloorData) -> void:
	var cell := map.get_cell(player_pos)
	if cell.area_type != MapCell.Type.ROOM:
		return

	var room_id := cell.room_id
	if room_id < 0:
		return

	if has_visited(map.id, room_id):
		return

	mark_visited(map.id, room_id)

	# Find the room data
	var room_data: DungeonLoader.RoomData = null
	for room: DungeonLoader.RoomData in dungeon_floor.rooms:
		if room.id == room_id:
			room_data = room
			break

	if not room_data:
		return

	# Fire narrative trigger
	if room_data.narrative:
		_fire_narrative(room_data)

	# Fire trap trigger
	if not room_data.trap.is_empty():
		_fire_trap(room_data.trap)

	# Fire choice trigger
	if not room_data.choices.is_empty():
		_fire_choices(room_data)


static func _fire_narrative(room_data: DungeonLoader.RoomData) -> void:
	# Add room name as header
	var header := "[b]%s[/b]" % room_data.name
	NarrativeManager.add_narrative(header)
	NarrativeManager.add_narrative(room_data.narrative)

	# Also log to the regular message system
	World.message_logged.emit(
		"[color=#aaaaaa]You enter %s.[/color]" % room_data.name,
		LogMessages.Level.NORMAL
	)


static func _fire_trap(trap_data: Dictionary) -> void:
	var trap_type: String = trap_data.get("type", "unknown")
	var dc: int = trap_data.get("dc", 12)
	var damage_dice: int = trap_data.get("damage_dice", 1)
	var damage_sides: int = trap_data.get("damage_sides", 6)

	# If player has character data, use D&D 5e saving throw
	if World.player.character_data:
		var save_result := RulesEngine.saving_throw(
			World.player.character_data,
			CharacterData.Ability.DEXTERITY,
			dc
		)
		if save_result.success:
			NarrativeManager.add_combat_narrative(
				"[color=green]You dodge the %s! (DEX save: %s)[/color]" % [
					trap_type.replace("_", " "), save_result.roll.description
				]
			)
		else:
			var damage := Dice.roll(damage_dice, damage_sides)
			World.player.hp = maxi(0, World.player.hp - damage)
			if World.player.character_data:
				World.player.character_data.current_hp = World.player.hp
			NarrativeManager.add_combat_narrative(
				"[color=red]The %s hits you for %d damage! (DEX save: %s)[/color]" % [
					trap_type.replace("_", " "), damage, save_result.roll.description
				]
			)
	else:
		# Legacy: simple 50% dodge chance
		if Dice.chance(0.5):
			NarrativeManager.add_combat_narrative(
				"[color=green]You dodge the trap![/color]"
			)
		else:
			var damage := Dice.roll(damage_dice, damage_sides)
			World.player.hp = maxi(0, World.player.hp - damage)
			NarrativeManager.add_combat_narrative(
				"[color=red]The trap hits you for %d damage![/color]" % damage
			)


static func _fire_choices(room_data: DungeonLoader.RoomData) -> void:
	var choice_texts: Array[String] = []
	for choice: Dictionary in room_data.choices:
		choice_texts.append(choice.get("text", "???"))

	NarrativeManager.present_choices(choice_texts, func(index: int) -> void:
		_handle_choice(room_data, index)
	)


static func _handle_choice(room_data: DungeonLoader.RoomData, choice_index: int) -> void:
	if choice_index < 0 or choice_index >= room_data.choices.size():
		return

	var choice: Dictionary = room_data.choices[choice_index]
	var action: String = choice.get("action", "")

	match action:
		"combat":
			NarrativeManager.add_narrative("[color=yellow]You charge into battle![/color]")
		"stealth_check":
			var dc: int = choice.get("dc", 15)
			if World.player.character_data:
				var result := RulesEngine.ability_check(
					World.player.character_data,
					CharacterData.Skill.STEALTH,
					dc
				)
				if result.success:
					NarrativeManager.add_narrative(
						"[color=green]You slip past unnoticed! (Stealth: %s)[/color]" % result.roll.description
					)
				else:
					NarrativeManager.add_narrative(
						"[color=red]You're spotted! (Stealth: %s)[/color]" % result.roll.description
					)
			else:
				NarrativeManager.add_narrative("[color=yellow]You attempt to sneak past...[/color]")
		"persuasion_check":
			var dc: int = choice.get("dc", 15)
			if World.player.character_data:
				var result := RulesEngine.ability_check(
					World.player.character_data,
					CharacterData.Skill.PERSUASION,
					dc
				)
				if result.success:
					NarrativeManager.add_narrative(
						"[color=green]The creature accepts your offering! (Persuasion: %s)[/color]" % result.roll.description
					)
				else:
					NarrativeManager.add_narrative(
						"[color=red]The creature is unimpressed and attacks! (Persuasion: %s)[/color]" % result.roll.description
					)
			else:
				NarrativeManager.add_narrative("[color=yellow]You try to negotiate...[/color]")
		_:
			NarrativeManager.add_narrative("You proceed cautiously.")


## Check if a room's monsters are all dead and fire on_clear events.
static func check_room_cleared(map: Map, room_data: DungeonLoader.RoomData) -> void:
	if room_data.on_clear.is_empty():
		return

	# Check if any monsters from this room are still alive
	for monster_def: Dictionary in room_data.monsters:
		var pos := Vector2i(monster_def.get("x", 0), monster_def.get("y", 0))
		var cell := map.get_cell(pos)
		if cell.monster and not cell.monster.is_dead:
			return  # Still enemies alive

	# All clear
	var narrative: String = room_data.on_clear.get("narrative", "")
	if narrative:
		NarrativeManager.add_narrative(narrative)

	if room_data.on_clear.get("victory", false):
		NarrativeManager.add_narrative("[color=gold][b]VICTORY! You have completed the dungeon![/b][/color]")
		World.message_logged.emit(
			"[color=cyan]Congratulations! You've conquered the dungeon![/color]",
			LogMessages.Level.GREAT
		)
