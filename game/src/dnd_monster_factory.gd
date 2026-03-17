class_name DndMonsterFactory
extends RefCounted

## Creates monsters with full D&D 5e stat blocks from dnd_monsters.json.
## Works alongside MonsterFactory — D&D monsters get CharacterData, legacy monsters don't.

const JSON_PATH := "res://assets/data/dnd_monsters.json"

static var _monster_data: Dictionary = {}


static func _static_init() -> void:
	_load_data()


static func _load_data() -> void:
	var file := FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file:
		Log.e("Failed to open D&D monster data: %s" % JSON_PATH)
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		Log.e("Failed to parse D&D monster JSON: %s" % json.get_error_message())
		return
	_monster_data = json.data


static func has_monster(slug: StringName) -> bool:
	if _monster_data.is_empty():
		_load_data()
	return _monster_data.has(String(slug))


static func get_monster_slugs() -> Array[StringName]:
	if _monster_data.is_empty():
		_load_data()
	var slugs: Array[StringName] = []
	for key: String in _monster_data:
		slugs.append(StringName(key))
	return slugs


## Create a Monster with full D&D 5e CharacterData.
static func create_monster(slug: StringName) -> Monster:
	if _monster_data.is_empty():
		_load_data()

	var data: Dictionary = _monster_data.get(String(slug), {})
	assert(not data.is_empty(), "D&D monster not found: %s" % slug)

	var monster := Monster.new(true)
	monster.slug = slug
	monster.name = data.get("name", "Unknown")

	# Map species string to Species.Type
	var species_str: String = data.get("species", "human")
	monster.species = _map_species(species_str)

	# Faction
	var faction_str: String = data.get("faction", "monsters")
	monster.faction = Factions.Type.get(faction_str.to_upper(), Factions.Type.MONSTERS)

	# Behavior
	var behavior_str: String = data.get("behavior", "aggressive")
	monster.behavior = Monster.Behavior.get(behavior_str.to_upper(), Monster.Behavior.AGGRESSIVE)

	# Appearance — pick a random variant from available sprites
	var appearances := get_appearances(slug)
	monster.variant = randi() % maxi(1, appearances.size())
	monster.hit_particles_color = Color.from_string(
		data.get("hit_particles_color", "#ff0000"), Color.RED
	)
	monster.sight_radius = data.get("sight_radius", 12)

	# Body parts (humanoids have all, beasts don't)
	var has_humanoid_body := species_str in ["humanoid", "giant"]
	monster.has_head = true
	monster.has_torso = true
	monster.has_legs = has_humanoid_body
	monster.has_hands = has_humanoid_body

	# D&D 5e stats → CharacterData
	var char_data := CharacterData.new()
	char_data.character_name = monster.name
	char_data.strength = data.get("str", 10)
	char_data.dexterity = data.get("dex", 10)
	char_data.constitution = data.get("con", 10)
	char_data.intelligence = data.get("int", 10)
	char_data.wisdom = data.get("wis", 10)
	char_data.charisma = data.get("cha", 10)
	char_data.max_hp = data.get("max_hp", 10)
	char_data.current_hp = char_data.max_hp
	char_data.base_ac = data.get("ac", 10)
	char_data.speed_feet = data.get("speed", 30)
	char_data.level = _cr_to_level(data.get("cr", 0.25))
	monster.character_data = char_data

	# Map to legacy stats for backward compatibility
	monster.hp = char_data.max_hp
	monster.max_hp = char_data.max_hp
	monster._base_strength = char_data.strength
	monster.intelligence = char_data.intelligence
	monster._base_speed = _speed_feet_to_energy(char_data.speed_feet)

	# Initialize behavior tree
	monster.behavior_tree = MonsterAI.create_behavior_tree(monster)

	return monster


## Get CR (challenge rating) for a D&D monster.
static func get_cr(slug: StringName) -> float:
	if _monster_data.is_empty():
		_load_data()
	var data: Dictionary = _monster_data.get(String(slug), {})
	return data.get("cr", 0.25)


## Get appearance sprite names for a D&D monster.
static func get_appearances(slug: StringName) -> Array:
	if _monster_data.is_empty():
		_load_data()
	var data: Dictionary = _monster_data.get(String(slug), {})
	var appearance_str: String = data.get("appearance", "")
	if appearance_str.is_empty():
		return []
	return appearance_str.split(",")


## Get D&D attack data for a monster.
static func get_attacks(slug: StringName) -> Array[Dictionary]:
	var data: Dictionary = _monster_data.get(String(slug), {})
	var attacks: Array[Dictionary] = []
	for attack: Dictionary in data.get("attacks", []):
		attacks.append(attack)
	return attacks


## Get XP value for a monster.
static func get_xp(slug: StringName) -> int:
	var data: Dictionary = _monster_data.get(String(slug), {})
	return data.get("xp", 0)


static func _map_species(species_str: String) -> Species.Type:
	match species_str.to_lower():
		"humanoid": return Species.Type.HUMAN
		"undead": return Species.Type.UNDEAD
		"beast": return Species.Type.RODENT  # Best fit for small beasts
		"giant": return Species.Type.HUMAN
		"monstrosity": return Species.Type.REPTILE  # Best fit
	return Species.Type.HUMAN


static func _cr_to_level(cr: float) -> int:
	# Rough mapping: CR < 1 → level 1, CR 1-4 → level ~CR, etc.
	if cr < 1.0:
		return 1
	return maxi(1, int(cr))


static func _speed_feet_to_energy(speed_feet: int) -> int:
	# Map D&D speed to the base game's energy system
	if speed_feet <= 20:
		return Monster.SPEED_SLOW
	elif speed_feet <= 30:
		return Monster.SPEED_NORMAL
	elif speed_feet <= 40:
		return Monster.SPEED_FAST
	return Monster.SPEED_VERY_FAST
