class_name GameStateSerializer
extends RefCounted

## Serializes and deserializes the full game state to/from a Dictionary (JSON-compatible).
## Phase 1: saves player data, current map id/depth, turn number, and world plan seed.
## Maps are regenerated on load (not serialized).

const SAVE_VERSION := 2


static func serialize_game_state() -> Dictionary:
	var player := World.player
	var pos := World.current_map.find_monster_position(player)

	var data := {
		"version": SAVE_VERSION,
		"timestamp": Time.get_unix_time_from_system(),
		"current_turn": World.current_turn,
		"max_depth": World.max_depth,
		"game_over": World.game_over,
		"current_map_id": World.current_map.id,
		"current_map_depth": World.current_map.depth,
		"faction_affinities": _serialize_faction_affinities(),
		"player": _serialize_player(player, pos),
		"party": _serialize_party(),
	}
	return data


static func deserialize_game_state(data: Dictionary) -> bool:
	if not _validate_save_data(data):
		Log.e("Save data validation failed")
		return false

	var version: int = data.get("version", 0)
	if version < 1 or version > SAVE_VERSION:
		Log.e("Incompatible save version: %d (expected 1-%d)" % [version, SAVE_VERSION])
		return false

	# Restore world state (JSON parses numbers as float, so cast to int)
	World.current_turn = int(data["current_turn"])
	World.max_depth = int(data["max_depth"])
	World.game_over = data["game_over"] as bool

	# Restore faction affinities
	_deserialize_faction_affinities(data["faction_affinities"])

	# Recreate the world plan and generate maps up to the saved depth
	World.world_plan = WorldPlan.new(WorldPlan.WorldType.NORMAL)
	World.maps.clear()

	# Generate maps for all levels up to the current one
	var target_map_id: String = data["current_map_id"]
	for level_plan: WorldPlan.LevelPlan in World.world_plan.levels:
		var map := World._generate_map(level_plan)
		map.id = level_plan.id
		World.maps[map.id] = map
		if map.id == target_map_id:
			World.current_map = map

	if not World.current_map or World.current_map.id != target_map_id:
		Log.e("Failed to find or generate target map: %s" % target_map_id)
		return false

	# Recreate the player
	var player_data: Dictionary = data["player"]
	var slug := StringName(player_data["slug"] as String)
	var role: Roles.Type = int(player_data["role"]) as Roles.Type

	World.player = MonsterFactory.create_monster(slug, role)
	var player := World.player

	# Restore player stats (JSON numbers are floats, cast to int)
	player.hp = int(player_data["hp"])
	player.max_hp = int(player_data["max_hp"])
	player.energy = int(player_data["energy"])
	player.is_dead = player_data["is_dead"] as bool

	# Restore nutrition
	player.nutrition.value = int(player_data["nutrition"])

	# Restore character data if present
	if player_data.has("character_data") and player_data["character_data"] != null:
		_deserialize_character_data(player, player_data["character_data"])

	# Restore skill levels
	if player_data.has("skill_levels"):
		_deserialize_skill_levels(player, player_data["skill_levels"])

	# Restore status effects
	if player_data.has("status_effects"):
		_deserialize_status_effects(player, player_data["status_effects"])

	# Clear default inventory and equipment (MonsterFactory gives starting gear)
	player.inventory.clear()
	for slot: Equipment.Slot in Equipment.Slot.values():
		player.equipment.equipped_items[slot] = null

	# Restore inventory
	if player_data.has("inventory"):
		for item_dict: Dictionary in player_data["inventory"]:
			var item := _deserialize_item(item_dict)
			if item:
				player.add_item(item)

	# Restore equipment
	if player_data.has("equipment"):
		_deserialize_equipment(player, player_data["equipment"])

	# Place player on the map
	var player_pos := Vector2i(int(player_data["position_x"]), int(player_data["position_y"]))
	var cell := World.current_map.get_cell(player_pos)
	cell.monster = player

	# Compute FOV
	World.update_vision()

	# Restore party companions (v2+)
	World.party = Party.new()
	if version >= 2 and data.has("party"):
		for companion_data: Dictionary in data["party"]:
			var comp_slug := StringName(companion_data["slug"] as String)
			var comp_monster: Monster
			if DndMonsterFactory.has_monster(comp_slug):
				comp_monster = DndMonsterFactory.create_monster(comp_slug)
			else:
				var comp_role: Roles.Type = int(companion_data["role"]) as Roles.Type
				comp_monster = MonsterFactory.create_monster(comp_slug, comp_role)

			# Restore companion stats
			comp_monster.hp = int(companion_data["hp"])
			comp_monster.max_hp = int(companion_data["max_hp"])
			comp_monster.energy = int(companion_data["energy"])
			comp_monster.is_dead = companion_data["is_dead"] as bool
			comp_monster.nutrition.value = int(companion_data["nutrition"])
			comp_monster.name = companion_data.get("name", comp_monster.name) as String
			comp_monster.faction = Factions.Type.HUMAN
			comp_monster.behavior = Monster.Behavior.PASSIVE

			# Restore character data
			if companion_data.has("character_data") and companion_data["character_data"] != null:
				_deserialize_character_data(comp_monster, companion_data["character_data"])

			# Restore skill levels
			if companion_data.has("skill_levels"):
				_deserialize_skill_levels(comp_monster, companion_data["skill_levels"])

			# Restore status effects
			if companion_data.has("status_effects"):
				_deserialize_status_effects(comp_monster, companion_data["status_effects"])

			# Clear default inventory and restore saved inventory
			comp_monster.inventory.clear()
			for slot: Equipment.Slot in Equipment.Slot.values():
				comp_monster.equipment.equipped_items[slot] = null

			if companion_data.has("inventory"):
				for item_dict: Dictionary in companion_data["inventory"]:
					var item := _deserialize_item(item_dict)
					if item:
						comp_monster.add_item(item)

			if companion_data.has("equipment"):
				_deserialize_equipment(comp_monster, companion_data["equipment"])

			# Place companion on map
			var comp_pos := Vector2i(int(companion_data["position_x"]), int(companion_data["position_y"]))
			if World.current_map.is_in_bounds(comp_pos):
				var comp_cell := World.current_map.get_cell(comp_pos)
				if comp_cell.is_walkable() and not comp_cell.monster:
					comp_cell.monster = comp_monster

			# Add to party
			World.party.add_member(comp_monster)

		Log.i("Restored %d party companions" % World.party.members.size())

	# Mark that the world was loaded from a save so game.gd skips re-initialization
	World.loaded_from_save = true

	Log.i("Game state restored successfully (turn %d, map %s)" % [World.current_turn, target_map_id])
	return true


# --- Player Serialization ---

static func _serialize_player(player: Monster, pos: Vector2i) -> Dictionary:
	var data := {
		"slug": String(player.slug),
		"name": player.name,
		"role": player.role as int,
		"species": player.species as int,
		"variant": player.variant,
		"hp": player.hp,
		"max_hp": player.max_hp,
		"energy": player.energy,
		"is_dead": player.is_dead,
		"nutrition": player.nutrition.value,
		"position_x": pos.x,
		"position_y": pos.y,
		"sight_radius": player.sight_radius,
		"character_data": _serialize_character_data(player.character_data),
		"skill_levels": _serialize_skill_levels(player),
		"status_effects": _serialize_status_effects(player),
		"inventory": _serialize_inventory(player),
		"equipment": _serialize_equipment(player),
	}
	return data


static func _serialize_party() -> Array:
	var companions: Array = []
	for companion in World.party.members:
		var pos := World.current_map.find_monster_position(companion)
		if pos == Utils.INVALID_POS:
			pos = Vector2i.ZERO
		companions.append(_serialize_player(companion, pos))
	return companions


# --- CharacterData Serialization ---

static func _serialize_character_data(cd: CharacterData) -> Variant:
	if cd == null:
		return null
	return {
		"character_name": cd.character_name,
		"race": cd.race as int,
		"dnd_class": cd.dnd_class as int,
		"level": cd.level,
		"experience_points": cd.experience_points,
		"strength": cd.strength,
		"dexterity": cd.dexterity,
		"constitution": cd.constitution,
		"intelligence": cd.intelligence,
		"wisdom": cd.wisdom,
		"charisma": cd.charisma,
		"max_hp": cd.max_hp,
		"current_hp": cd.current_hp,
		"temp_hp": cd.temp_hp,
		"hit_dice_remaining": cd.hit_dice_remaining,
		"base_ac": cd.base_ac,
		"speed_feet": cd.speed_feet,
		"initiative_bonus": cd.initiative_bonus,
		"death_save_successes": cd.death_save_successes,
		"death_save_failures": cd.death_save_failures,
		"saving_throw_proficiencies": _enum_array_to_int_array(cd.saving_throw_proficiencies),
		"skill_proficiencies": _enum_array_to_int_array(cd.skill_proficiencies),
		"skill_expertise": _enum_array_to_int_array(cd.skill_expertise),
		"armor_proficiencies": _enum_array_to_int_array(cd.armor_proficiencies),
		"weapon_proficiencies": _stringname_array_to_string_array(cd.weapon_proficiencies),
		"conditions": _enum_array_to_int_array(cd.conditions),
	}


static func _deserialize_character_data(player: Monster, cd_data: Dictionary) -> void:
	if player.character_data == null:
		player.character_data = CharacterData.new()
	var cd := player.character_data
	cd.character_name = cd_data.get("character_name", "") as String
	cd.race = int(cd_data.get("race", 0)) as CharacterData.Race
	cd.dnd_class = int(cd_data.get("dnd_class", 0)) as CharacterData.DndClass
	cd.level = int(cd_data.get("level", 1))
	cd.experience_points = int(cd_data.get("experience_points", 0))
	cd.strength = int(cd_data.get("strength", 10))
	cd.dexterity = int(cd_data.get("dexterity", 10))
	cd.constitution = int(cd_data.get("constitution", 10))
	cd.intelligence = int(cd_data.get("intelligence", 10))
	cd.wisdom = int(cd_data.get("wisdom", 10))
	cd.charisma = int(cd_data.get("charisma", 10))
	cd.max_hp = int(cd_data.get("max_hp", 10))
	cd.current_hp = int(cd_data.get("current_hp", 10))
	cd.temp_hp = int(cd_data.get("temp_hp", 0))
	cd.hit_dice_remaining = int(cd_data.get("hit_dice_remaining", 1))
	cd.base_ac = int(cd_data.get("base_ac", 10))
	cd.speed_feet = int(cd_data.get("speed_feet", 30))
	cd.initiative_bonus = int(cd_data.get("initiative_bonus", 0))
	cd.death_save_successes = int(cd_data.get("death_save_successes", 0))
	cd.death_save_failures = int(cd_data.get("death_save_failures", 0))

	cd.saving_throw_proficiencies = []
	for val: float in cd_data.get("saving_throw_proficiencies", []):
		cd.saving_throw_proficiencies.append(int(val) as CharacterData.Ability)

	cd.skill_proficiencies = []
	for val: float in cd_data.get("skill_proficiencies", []):
		cd.skill_proficiencies.append(int(val) as CharacterData.Skill)

	cd.skill_expertise = []
	for val: float in cd_data.get("skill_expertise", []):
		cd.skill_expertise.append(int(val) as CharacterData.Skill)

	cd.armor_proficiencies = []
	for val: float in cd_data.get("armor_proficiencies", []):
		cd.armor_proficiencies.append(int(val) as CharacterData.ArmorCategory)

	cd.weapon_proficiencies = []
	for val: Variant in cd_data.get("weapon_proficiencies", []):
		cd.weapon_proficiencies.append(StringName(val as String))

	cd.conditions = []
	for val: float in cd_data.get("conditions", []):
		cd.conditions.append(int(val) as CharacterData.Condition)


# --- Skill Levels ---

static func _serialize_skill_levels(player: Monster) -> Dictionary:
	var data := {}
	for skill_type: Skills.Type in player.skill_levels:
		data[str(skill_type as int)] = player.skill_levels[skill_type] as int
	return data


static func _deserialize_skill_levels(player: Monster, data: Dictionary) -> void:
	for key: String in data:
		var skill_type: Skills.Type = int(key) as Skills.Type
		var level: Skills.Level = int(data[key]) as Skills.Level
		player.skill_levels[skill_type] = level


# --- Status Effects ---

static func _serialize_status_effects(player: Monster) -> Array:
	var effects: Array = []
	for effect: StatusEffect in player.status_effects:
		effects.append({
			"type": effect.type as int,
			"turns_remaining": effect.turns_remaining,
			"magnitude": effect.magnitude,
			"original_turns": effect.original_turns,
		})
	return effects


static func _deserialize_status_effects(player: Monster, effects_data: Array) -> void:
	player.status_effects.clear()
	for effect_dict: Dictionary in effects_data:
		var effect := StatusEffect.new(
			int(effect_dict["type"]) as StatusEffect.Type,
			int(effect_dict["turns_remaining"]),
			int(effect_dict.get("magnitude", 1)),
		)
		effect.original_turns = int(effect_dict.get("original_turns", effect.turns_remaining))
		player.status_effects.append(effect)


# --- Inventory Serialization ---

static func _serialize_inventory(player: Monster) -> Array:
	var items: Array = []
	for item: Item in player.inventory.to_array():
		# Skip items that are equipped (they are serialized separately)
		if player.equipment.is_item_equipped(item):
			continue
		items.append(_serialize_item(item))
	return items


static func _serialize_item(item: Item) -> Dictionary:
	var slug := _find_item_slug(item)
	var data := {
		"slug": String(slug),
		"name": item.name,
		"type": item.type as int,
		"quantity": item.quantity,
		"enhancement": item.enhancement,
		"is_armed": item.is_armed,
		"turns_to_activate": item.turns_to_activate,
		"is_open": item.is_open,
	}

	# Serialize children (modules, ammo)
	if item.children.size() > 0:
		var children_data: Array = []
		for child: Item in item.children.to_array():
			children_data.append(_serialize_item(child))
		data["children"] = children_data

	return data


static func _deserialize_item(data: Dictionary) -> Item:
	var slug := StringName(data.get("slug", ""))
	if slug.is_empty():
		Log.e("Item has no slug, cannot deserialize")
		return null

	if not ItemFactory.item_data.has(slug):
		Log.e("Unknown item slug during load: %s" % slug)
		return null

	var item := ItemFactory.create_item(slug)
	item.quantity = int(data.get("quantity", 1))
	item.enhancement = int(data.get("enhancement", 0))
	item.is_armed = data.get("is_armed", false) as bool
	item.turns_to_activate = int(data.get("turns_to_activate", 0))
	item.is_open = data.get("is_open", false) as bool

	# Deserialize children
	if data.has("children"):
		for child_data: Dictionary in data["children"]:
			var child := _deserialize_item(child_data)
			if child:
				item.add_child(child)

	return item


# --- Equipment Serialization ---

static func _serialize_equipment(player: Monster) -> Dictionary:
	var data := {}
	for slot: Equipment.Slot in Equipment.Slot.values():
		var item: Item = player.equipment.get_equipped_item(slot)
		if item:
			data[str(slot as int)] = _serialize_item(item)
	return data


static func _deserialize_equipment(player: Monster, equip_data: Dictionary) -> void:
	for slot_key: String in equip_data:
		var slot: Equipment.Slot = int(slot_key) as Equipment.Slot
		var item_data: Dictionary = equip_data[slot_key]
		var item := _deserialize_item(item_data)
		if item:
			player.add_item(item)
			player.equipment.equip(item, slot)


# --- Faction Affinities ---

static func _serialize_faction_affinities() -> Dictionary:
	var data := {}
	for faction: Factions.Type in World.faction_affinities:
		data[str(faction as int)] = World.faction_affinities[faction]
	return data


static func _deserialize_faction_affinities(data: Dictionary) -> void:
	World.faction_affinities.clear()
	for key: String in data:
		var faction: Factions.Type = int(key) as Factions.Type
		World.faction_affinities[faction] = int(data[key])


# --- Utility Functions ---

static func _find_item_slug(item: Item) -> StringName:
	# Search item_data by matching name
	for slug: StringName in ItemFactory.item_data:
		var data: Dictionary = ItemFactory.item_data[slug]
		if data[&"name"] == item.name:
			return slug
	Log.e("Could not find slug for item: %s" % item.name)
	return &""


static func _validate_save_data(data: Dictionary) -> bool:
	var required_keys := ["version", "current_turn", "current_map_id", "player"]
	for key: String in required_keys:
		if not data.has(key):
			Log.e("Save data missing required key: %s" % key)
			return false
	return true


static func _enum_array_to_int_array(arr: Array) -> Array:
	var result: Array = []
	for val: Variant in arr:
		result.append(val as int)
	return result


static func _stringname_array_to_string_array(arr: Array[StringName]) -> Array:
	var result: Array = []
	for val: StringName in arr:
		result.append(String(val))
	return result
