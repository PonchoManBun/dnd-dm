class_name CharacterData
extends Resource

## D&D 5e character data resource.
## Used for both player characters and NPCs with full stat blocks.

# Identity
@export var character_name: String = ""
@export var race: Race = Race.HUMAN
@export var dnd_class: DndClass = DndClass.FIGHTER
@export var level: int = 1
@export var experience_points: int = 0

# Ability Scores (3-20 for PCs, 1-30 for monsters)
@export var strength: int = 10
@export var dexterity: int = 10
@export var constitution: int = 10
@export var intelligence: int = 10
@export var wisdom: int = 10
@export var charisma: int = 10

# Hit Points
@export var max_hp: int = 10
@export var current_hp: int = 10
@export var temp_hp: int = 0
@export var hit_dice_remaining: int = 1

# Combat
@export var base_ac: int = 10
@export var speed_feet: int = 30  # Movement speed in feet (tiles = speed / 5)
@export var initiative_bonus: int = 0

# Death Saves (player only)
var death_save_successes: int = 0
var death_save_failures: int = 0

# Proficiencies
var saving_throw_proficiencies: Array[Ability] = []
var skill_proficiencies: Array[Skill] = []
var skill_expertise: Array[Skill] = []  # Double proficiency (Rogues, Bards)

# Equipment proficiencies
var armor_proficiencies: Array[ArmorCategory] = []
var weapon_proficiencies: Array[StringName] = []  # Weapon slugs or categories

# Conditions
var conditions: Array[Condition] = []

# Class Features — tracks active features and per-rest usage counts
# Keys are feature name strings, values are { "active": bool, "uses": int, "max_uses": int }
var class_features: Dictionary = {}

# Barbarian
var rage_charges: int = 0
var rage_active: bool = false

# Rogue
var sneak_attack_dice: int = 0  # Number of d6s for Sneak Attack

# Fighter
var action_surge_charges: int = 0

# Casters — indexed by spell level (index 0 = 1st-level slots, index 1 = 2nd-level, etc.)
var spell_slots: Array[int] = []
var spell_slots_used: Array[int] = []

# Monk
var ki_points: int = 0
var ki_points_max: int = 0

# Cleric
var channel_divinity_charges: int = 0

# Bard
var bardic_inspiration_charges: int = 0
var bardic_inspiration_die: int = 6  # d6 at level 1, scales later

# Druid
var wild_shape_charges: int = 0

# Paladin
var lay_on_hands_pool: int = 0

# Sorcerer
var sorcery_points: int = 0
var sorcery_points_max: int = 0

enum Race {
	HUMAN,
	ELF,
	DWARF,
	HALFLING,
	HALF_ORC,
	GNOME,
	DRAGONBORN,
	HALF_ELF,
	TIEFLING,
}

enum DndClass {
	FIGHTER,
	WIZARD,
	ROGUE,
	CLERIC,
	RANGER,
	PALADIN,
	BARBARIAN,
	BARD,
	DRUID,
	MONK,
	SORCERER,
	WARLOCK,
}

enum Ability {
	STRENGTH,
	DEXTERITY,
	CONSTITUTION,
	INTELLIGENCE,
	WISDOM,
	CHARISMA,
}

enum Skill {
	ACROBATICS,
	ANIMAL_HANDLING,
	ARCANA,
	ATHLETICS,
	DECEPTION,
	HISTORY,
	INSIGHT,
	INTIMIDATION,
	INVESTIGATION,
	MEDICINE,
	NATURE,
	PERCEPTION,
	PERFORMANCE,
	PERSUASION,
	RELIGION,
	SLEIGHT_OF_HAND,
	STEALTH,
	SURVIVAL,
}

enum Condition {
	BLINDED,
	CHARMED,
	DEAFENED,
	FRIGHTENED,
	GRAPPLED,
	INCAPACITATED,
	INVISIBLE,
	PARALYZED,
	PETRIFIED,
	POISONED,
	PRONE,
	RESTRAINED,
	STUNNED,
	UNCONSCIOUS,
}

enum ArmorCategory {
	LIGHT,
	MEDIUM,
	HEAVY,
	SHIELDS,
}

# Maps skills to their governing ability
const SKILL_ABILITIES: Dictionary = {
	Skill.ACROBATICS: Ability.DEXTERITY,
	Skill.ANIMAL_HANDLING: Ability.WISDOM,
	Skill.ARCANA: Ability.INTELLIGENCE,
	Skill.ATHLETICS: Ability.STRENGTH,
	Skill.DECEPTION: Ability.CHARISMA,
	Skill.HISTORY: Ability.INTELLIGENCE,
	Skill.INSIGHT: Ability.WISDOM,
	Skill.INTIMIDATION: Ability.CHARISMA,
	Skill.INVESTIGATION: Ability.INTELLIGENCE,
	Skill.MEDICINE: Ability.WISDOM,
	Skill.NATURE: Ability.INTELLIGENCE,
	Skill.PERCEPTION: Ability.WISDOM,
	Skill.PERFORMANCE: Ability.CHARISMA,
	Skill.PERSUASION: Ability.CHARISMA,
	Skill.RELIGION: Ability.INTELLIGENCE,
	Skill.SLEIGHT_OF_HAND: Ability.DEXTERITY,
	Skill.STEALTH: Ability.DEXTERITY,
	Skill.SURVIVAL: Ability.WISDOM,
}

# XP thresholds per level (index = level - 1)
const XP_THRESHOLDS: Array[int] = [
	0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000,
	85000, 100000, 120000, 140000, 165000, 195000, 225000, 265000, 305000, 355000,
]

# Race data
const RACE_DATA: Dictionary = {
	Race.HUMAN: {
		"name": "Human",
		"ability_bonuses": {Ability.STRENGTH: 1, Ability.DEXTERITY: 1, Ability.CONSTITUTION: 1, Ability.INTELLIGENCE: 1, Ability.WISDOM: 1, Ability.CHARISMA: 1},
		"speed": 30,
		"size": "Medium",
	},
	Race.ELF: {
		"name": "Elf",
		"ability_bonuses": {Ability.DEXTERITY: 2},
		"speed": 30,
		"size": "Medium",
	},
	Race.DWARF: {
		"name": "Dwarf",
		"ability_bonuses": {Ability.CONSTITUTION: 2},
		"speed": 25,
		"size": "Medium",
	},
	Race.HALFLING: {
		"name": "Halfling",
		"ability_bonuses": {Ability.DEXTERITY: 2},
		"speed": 25,
		"size": "Small",
	},
	Race.HALF_ORC: {
		"name": "Half-Orc",
		"ability_bonuses": {Ability.STRENGTH: 2, Ability.CONSTITUTION: 1},
		"speed": 30,
		"size": "Medium",
	},
	Race.GNOME: {
		"name": "Gnome",
		"ability_bonuses": {Ability.INTELLIGENCE: 2},
		"speed": 25,
		"size": "Small",
	},
	Race.DRAGONBORN: {
		"name": "Dragonborn",
		"ability_bonuses": {Ability.STRENGTH: 2, Ability.CHARISMA: 1},
		"speed": 30,
		"size": "Medium",
	},
	Race.HALF_ELF: {
		"name": "Half-Elf",
		"ability_bonuses": {Ability.CHARISMA: 2},
		"speed": 30,
		"size": "Medium",
	},
	Race.TIEFLING: {
		"name": "Tiefling",
		"ability_bonuses": {Ability.INTELLIGENCE: 1, Ability.CHARISMA: 2},
		"speed": 30,
		"size": "Medium",
	},
}

# Class data
const CLASS_DATA: Dictionary = {
	DndClass.FIGHTER: {
		"name": "Fighter",
		"hit_die": 10,
		"primary_ability": Ability.STRENGTH,
		"saving_throws": [Ability.STRENGTH, Ability.CONSTITUTION],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.HEAVY, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ACROBATICS, Skill.ANIMAL_HANDLING, Skill.ATHLETICS, Skill.HISTORY, Skill.INSIGHT, Skill.INTIMIDATION, Skill.PERCEPTION, Skill.SURVIVAL],
		"features": {
			1: ["Fighting Style", "Second Wind"],
			2: ["Action Surge"],
			3: ["Martial Archetype"],
		},
		"action_surge_charges": {2: 1, 3: 1},  # Gains at level 2
	},
	DndClass.WIZARD: {
		"name": "Wizard",
		"hit_die": 6,
		"primary_ability": Ability.INTELLIGENCE,
		"saving_throws": [Ability.INTELLIGENCE, Ability.WISDOM],
		"armor_proficiencies": [],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.HISTORY, Skill.INSIGHT, Skill.INVESTIGATION, Skill.MEDICINE, Skill.RELIGION],
		"features": {
			1: ["Arcane Recovery", "Spellcasting"],
			2: ["Arcane Tradition"],
			3: [],
		},
		"spell_slots": {1: [2], 2: [3], 3: [4, 2], 4: [4, 3], 5: [4, 3, 2]},
		"is_caster": true,
	},
	DndClass.ROGUE: {
		"name": "Rogue",
		"hit_die": 8,
		"primary_ability": Ability.DEXTERITY,
		"saving_throws": [Ability.DEXTERITY, Ability.INTELLIGENCE],
		"armor_proficiencies": [ArmorCategory.LIGHT],
		"num_skills": 4,
		"skill_choices": [Skill.ACROBATICS, Skill.ATHLETICS, Skill.DECEPTION, Skill.INSIGHT, Skill.INTIMIDATION, Skill.INVESTIGATION, Skill.PERCEPTION, Skill.PERFORMANCE, Skill.PERSUASION, Skill.SLEIGHT_OF_HAND, Skill.STEALTH],
		"features": {
			1: ["Expertise", "Sneak Attack", "Thieves Cant"],
			2: ["Cunning Action"],
			3: ["Roguish Archetype"],
		},
		"sneak_attack_dice": {1: 1, 3: 2, 5: 3},  # Scales every odd level
	},
	DndClass.CLERIC: {
		"name": "Cleric",
		"hit_die": 8,
		"primary_ability": Ability.WISDOM,
		"saving_throws": [Ability.WISDOM, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.HISTORY, Skill.INSIGHT, Skill.MEDICINE, Skill.PERSUASION, Skill.RELIGION],
		"features": {
			1: ["Spellcasting", "Divine Domain"],
			2: ["Channel Divinity", "Divine Domain Feature"],
			3: [],
		},
		"spell_slots": {1: [2], 2: [3], 3: [4, 2], 4: [4, 3], 5: [4, 3, 2]},
		"is_caster": true,
		"channel_divinity_charges": {2: 1},  # Gains at level 2
	},
	DndClass.RANGER: {
		"name": "Ranger",
		"hit_die": 10,
		"primary_ability": Ability.DEXTERITY,
		"saving_throws": [Ability.STRENGTH, Ability.DEXTERITY],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 3,
		"skill_choices": [Skill.ANIMAL_HANDLING, Skill.ATHLETICS, Skill.INSIGHT, Skill.INVESTIGATION, Skill.NATURE, Skill.PERCEPTION, Skill.STEALTH, Skill.SURVIVAL],
		"features": {
			1: ["Favored Enemy", "Natural Explorer"],
			2: ["Fighting Style", "Spellcasting"],
			3: ["Ranger Archetype", "Primeval Awareness"],
		},
		"spell_slots": {2: [2], 3: [3], 4: [3], 5: [4, 2]},
		"is_caster": true,
	},
	DndClass.PALADIN: {
		"name": "Paladin",
		"hit_die": 10,
		"primary_ability": Ability.STRENGTH,
		"saving_throws": [Ability.WISDOM, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.HEAVY, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ATHLETICS, Skill.INSIGHT, Skill.INTIMIDATION, Skill.MEDICINE, Skill.PERSUASION, Skill.RELIGION],
		"features": {
			1: ["Divine Sense", "Lay on Hands"],
			2: ["Fighting Style", "Spellcasting", "Divine Smite"],
			3: ["Divine Health", "Sacred Oath"],
		},
		"spell_slots": {2: [2], 3: [3], 4: [3], 5: [4, 2]},
		"is_caster": true,
		"lay_on_hands_pool_per_level": 5,  # 5 * paladin level
	},
	DndClass.BARBARIAN: {
		"name": "Barbarian",
		"hit_die": 12,
		"primary_ability": Ability.STRENGTH,
		"saving_throws": [Ability.STRENGTH, Ability.CONSTITUTION],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ANIMAL_HANDLING, Skill.ATHLETICS, Skill.INTIMIDATION, Skill.NATURE, Skill.PERCEPTION, Skill.SURVIVAL],
		"features": {
			1: ["Rage", "Unarmored Defense"],
			2: ["Reckless Attack", "Danger Sense"],
			3: ["Primal Path"],
		},
		"rage_charges": {1: 2, 3: 3},
		"rage_damage_bonus": {1: 2, 9: 3, 16: 4},  # Scales at 9 and 16
	},
	DndClass.BARD: {
		"name": "Bard",
		"hit_die": 8,
		"primary_ability": Ability.CHARISMA,
		"saving_throws": [Ability.DEXTERITY, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT],
		"num_skills": 3,
		"skill_choices": [Skill.ACROBATICS, Skill.ANIMAL_HANDLING, Skill.ARCANA, Skill.ATHLETICS, Skill.DECEPTION, Skill.HISTORY, Skill.INSIGHT, Skill.INTIMIDATION, Skill.INVESTIGATION, Skill.MEDICINE, Skill.NATURE, Skill.PERCEPTION, Skill.PERFORMANCE, Skill.PERSUASION, Skill.RELIGION, Skill.SLEIGHT_OF_HAND, Skill.STEALTH, Skill.SURVIVAL],
		"features": {
			1: ["Spellcasting", "Bardic Inspiration"],
			2: ["Jack of All Trades", "Song of Rest"],
			3: ["Bard College", "Expertise"],
		},
		"spell_slots": {1: [2], 2: [3], 3: [4, 2], 4: [4, 3], 5: [4, 3, 2]},
		"is_caster": true,
		"bardic_inspiration_charges_per_cha_mod": true,  # Uses = CHA modifier (min 1)
	},
	DndClass.DRUID: {
		"name": "Druid",
		"hit_die": 8,
		"primary_ability": Ability.WISDOM,
		"saving_throws": [Ability.INTELLIGENCE, Ability.WISDOM],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.ANIMAL_HANDLING, Skill.INSIGHT, Skill.MEDICINE, Skill.NATURE, Skill.PERCEPTION, Skill.RELIGION, Skill.SURVIVAL],
		"features": {
			1: ["Druidic", "Spellcasting"],
			2: ["Wild Shape", "Druid Circle"],
			3: [],
		},
		"spell_slots": {1: [2], 2: [3], 3: [4, 2], 4: [4, 3], 5: [4, 3, 2]},
		"is_caster": true,
		"wild_shape_charges": {2: 2},  # 2 uses, recharge on short/long rest
	},
	DndClass.MONK: {
		"name": "Monk",
		"hit_die": 8,
		"primary_ability": Ability.DEXTERITY,
		"saving_throws": [Ability.STRENGTH, Ability.DEXTERITY],
		"armor_proficiencies": [],
		"num_skills": 2,
		"skill_choices": [Skill.ACROBATICS, Skill.ATHLETICS, Skill.HISTORY, Skill.INSIGHT, Skill.RELIGION, Skill.STEALTH],
		"features": {
			1: ["Unarmored Defense", "Martial Arts"],
			2: ["Ki", "Unarmored Movement"],
			3: ["Monastic Tradition", "Deflect Missiles"],
		},
		"ki_points": {2: 2, 3: 3, 4: 4, 5: 5},  # Equal to Monk level, starts at 2
	},
	DndClass.SORCERER: {
		"name": "Sorcerer",
		"hit_die": 6,
		"primary_ability": Ability.CHARISMA,
		"saving_throws": [Ability.CONSTITUTION, Ability.CHARISMA],
		"armor_proficiencies": [],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.DECEPTION, Skill.INSIGHT, Skill.INTIMIDATION, Skill.PERSUASION, Skill.RELIGION],
		"features": {
			1: ["Spellcasting", "Sorcerous Origin"],
			2: ["Font of Magic"],
			3: ["Metamagic"],
		},
		"spell_slots": {1: [2], 2: [3], 3: [4, 2], 4: [4, 3], 5: [4, 3, 2]},
		"is_caster": true,
		"sorcery_points": {2: 2, 3: 3, 4: 4, 5: 5},  # Equal to Sorcerer level, starts at 2
	},
	DndClass.WARLOCK: {
		"name": "Warlock",
		"hit_die": 8,
		"primary_ability": Ability.CHARISMA,
		"saving_throws": [Ability.WISDOM, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.DECEPTION, Skill.HISTORY, Skill.INTIMIDATION, Skill.INVESTIGATION, Skill.NATURE, Skill.RELIGION],
		"features": {
			1: ["Otherworldly Patron", "Pact Magic"],
			2: ["Eldritch Invocations"],
			3: ["Pact Boon"],
		},
		# Warlock uses Pact Magic (all slots same level, recharge on short rest)
		"pact_slots": {1: 1, 2: 2, 3: 2, 4: 2, 5: 2},
		"pact_slot_level": {1: 1, 2: 1, 3: 2, 4: 2, 5: 3},
		"is_caster": true,
	},
}


func get_ability_score(ability: Ability) -> int:
	match ability:
		Ability.STRENGTH: return strength
		Ability.DEXTERITY: return dexterity
		Ability.CONSTITUTION: return constitution
		Ability.INTELLIGENCE: return intelligence
		Ability.WISDOM: return wisdom
		Ability.CHARISMA: return charisma
	return 10


func set_ability_score(ability: Ability, value: int) -> void:
	match ability:
		Ability.STRENGTH: strength = value
		Ability.DEXTERITY: dexterity = value
		Ability.CONSTITUTION: constitution = value
		Ability.INTELLIGENCE: intelligence = value
		Ability.WISDOM: wisdom = value
		Ability.CHARISMA: charisma = value


static func ability_modifier(score: int) -> int:
	return int(floor((score - 10) / 2.0))


func get_modifier(ability: Ability) -> int:
	return CharacterData.ability_modifier(get_ability_score(ability))


func get_proficiency_bonus() -> int:
	return 2 + (level - 1) / 4


func get_hit_die() -> int:
	return CLASS_DATA[dnd_class]["hit_die"]


func get_max_hp_for_level() -> int:
	var hit_die: int = get_hit_die()
	var con_mod: int = get_modifier(Ability.CONSTITUTION)
	# Level 1: max hit die + CON mod. Each level after: avg hit die + CON mod.
	var hp_val: int = hit_die + con_mod
	for i in range(1, level):
		hp_val += maxi(1, (hit_die / 2) + 1 + con_mod)
	return maxi(1, hp_val)


func get_movement_tiles() -> int:
	return speed_feet / 5


func has_condition(condition: Condition) -> bool:
	return condition in conditions


func add_condition(condition: Condition) -> void:
	if condition not in conditions:
		conditions.append(condition)


func remove_condition(condition: Condition) -> void:
	conditions.erase(condition)


func is_proficient_in_skill(skill: Skill) -> bool:
	return skill in skill_proficiencies


func has_expertise_in_skill(skill: Skill) -> bool:
	return skill in skill_expertise


func is_proficient_in_saving_throw(ability: Ability) -> bool:
	return ability in saving_throw_proficiencies


func get_race_name() -> String:
	return RACE_DATA[race]["name"]


func get_class_name_str() -> String:
	return CLASS_DATA[dnd_class]["name"]


## Add XP to this character. Returns true if they leveled up.
func add_xp(amount: int) -> bool:
	experience_points += amount
	if level < XP_THRESHOLDS.size() and experience_points >= XP_THRESHOLDS[level]:
		level += 1
		# Recalculate HP
		var old_max := max_hp
		max_hp = get_max_hp_for_level()
		current_hp += max_hp - old_max  # Heal the HP gained
		hit_dice_remaining = level
		initialize_class_features()
		return true
	return false


## Initialize class features based on current class and level.
## Call after setting dnd_class and level.
func initialize_class_features() -> void:
	var data: Dictionary = CLASS_DATA[dnd_class]

	# Populate class_features from feature lists
	class_features.clear()
	if data.has("features"):
		var features_by_level: Dictionary = data["features"]
		for feat_level: int in features_by_level:
			if feat_level <= level:
				for feature_name: String in features_by_level[feat_level]:
					if feature_name not in class_features:
						class_features[feature_name] = {"active": true, "uses": 0, "max_uses": 0}

	# Barbarian: rage charges
	if dnd_class == DndClass.BARBARIAN and data.has("rage_charges"):
		rage_charges = _lookup_scaling_value(data["rage_charges"], level)
		rage_active = false

	# Rogue: sneak attack dice
	if dnd_class == DndClass.ROGUE and data.has("sneak_attack_dice"):
		sneak_attack_dice = _lookup_scaling_value(data["sneak_attack_dice"], level)

	# Fighter: action surge charges
	if dnd_class == DndClass.FIGHTER and data.has("action_surge_charges"):
		action_surge_charges = _lookup_scaling_value(data["action_surge_charges"], level)

	# Monk: ki points
	if dnd_class == DndClass.MONK and data.has("ki_points"):
		ki_points_max = _lookup_scaling_value(data["ki_points"], level)
		ki_points = ki_points_max

	# Cleric: channel divinity
	if dnd_class == DndClass.CLERIC and data.has("channel_divinity_charges"):
		channel_divinity_charges = _lookup_scaling_value(data["channel_divinity_charges"], level)

	# Bard: bardic inspiration (uses = CHA modifier, minimum 1)
	if dnd_class == DndClass.BARD and data.get("bardic_inspiration_charges_per_cha_mod", false):
		bardic_inspiration_charges = maxi(1, get_modifier(Ability.CHARISMA))
		bardic_inspiration_die = 6  # d6 at levels 1-4

	# Druid: wild shape
	if dnd_class == DndClass.DRUID and data.has("wild_shape_charges"):
		wild_shape_charges = _lookup_scaling_value(data["wild_shape_charges"], level)

	# Paladin: lay on hands (5 HP per paladin level)
	if dnd_class == DndClass.PALADIN and data.has("lay_on_hands_pool_per_level"):
		lay_on_hands_pool = level * data["lay_on_hands_pool_per_level"]

	# Sorcerer: sorcery points
	if dnd_class == DndClass.SORCERER and data.has("sorcery_points"):
		sorcery_points_max = _lookup_scaling_value(data["sorcery_points"], level)
		sorcery_points = sorcery_points_max

	# Caster: spell slots
	if data.has("spell_slots"):
		var slot_table: Dictionary = data["spell_slots"]
		spell_slots = _lookup_spell_slots(slot_table, level)
		spell_slots_used.resize(spell_slots.size())
		spell_slots_used.fill(0)
	elif data.has("pact_slots"):
		# Warlock pact magic — store as a single-element spell_slots array
		var num_slots: int = _lookup_scaling_value(data["pact_slots"], level)
		var slot_lvl: int = _lookup_scaling_value(data["pact_slot_level"], level)
		spell_slots.resize(slot_lvl)
		spell_slots.fill(0)
		if slot_lvl > 0:
			spell_slots[slot_lvl - 1] = num_slots
		spell_slots_used.resize(spell_slots.size())
		spell_slots_used.fill(0)


## Look up the highest applicable value from a level-keyed scaling table.
## E.g., {1: 2, 3: 3} at level 4 returns 3.
static func _lookup_scaling_value(table: Dictionary, char_level: int) -> int:
	var result: int = 0
	for threshold_level: int in table:
		if threshold_level <= char_level:
			result = table[threshold_level]
	return result


## Look up spell slots from a level-keyed table. Returns the array for the
## highest level entry that does not exceed char_level.
static func _lookup_spell_slots(table: Dictionary, char_level: int) -> Array[int]:
	var result: Array[int] = []
	var best_level: int = 0
	for threshold_level: int in table:
		if threshold_level <= char_level and threshold_level > best_level:
			best_level = threshold_level
	if best_level > 0:
		var raw: Array = table[best_level]
		for val: int in raw:
			result.append(val)
	return result


## Returns the number of Sneak Attack d6s for this character's level.
## Returns 0 if not a Rogue or level is too low.
func get_sneak_attack_dice() -> int:
	if dnd_class != DndClass.ROGUE:
		return 0
	var data: Dictionary = CLASS_DATA[DndClass.ROGUE]
	if data.has("sneak_attack_dice"):
		return _lookup_scaling_value(data["sneak_attack_dice"], level)
	return 0


## Returns the rage damage bonus for a Barbarian at this level.
## Returns 0 if not a Barbarian or rage is not active.
func get_rage_damage_bonus() -> int:
	if dnd_class != DndClass.BARBARIAN or not rage_active:
		return 0
	var data: Dictionary = CLASS_DATA[DndClass.BARBARIAN]
	if data.has("rage_damage_bonus"):
		return _lookup_scaling_value(data["rage_damage_bonus"], level)
	return 0


## Returns the number of available (not-yet-used) spell slots at a given spell level.
## spell_level is 1-indexed (1 = 1st-level spells).
func get_available_spell_slots(spell_level: int) -> int:
	var idx: int = spell_level - 1
	if idx < 0 or idx >= spell_slots.size():
		return 0
	return maxi(0, spell_slots[idx] - spell_slots_used[idx])


## Use one spell slot at the given spell level. Returns true on success.
func use_spell_slot(spell_level: int) -> bool:
	if get_available_spell_slots(spell_level) <= 0:
		return false
	spell_slots_used[spell_level - 1] += 1
	return true


## Returns the total spell slot array for this character's class and level.
## Each index represents a spell level (index 0 = 1st-level, index 1 = 2nd-level, etc.).
## Returns an empty array for non-casters or classes without spell slots at this level.
func get_spell_slots_for_level() -> Array[int]:
	var data: Dictionary = CLASS_DATA[dnd_class]
	if data.has("spell_slots"):
		return _lookup_spell_slots(data["spell_slots"], level)
	elif data.has("pact_slots"):
		var num_slots: int = _lookup_scaling_value(data["pact_slots"], level)
		var slot_lvl: int = _lookup_scaling_value(data["pact_slot_level"], level)
		var result: Array[int] = []
		result.resize(slot_lvl)
		result.fill(0)
		if slot_lvl > 0:
			result[slot_lvl - 1] = num_slots
		return result
	return []


## Restore all spell slots (long rest).
func restore_spell_slots() -> void:
	spell_slots_used.fill(0)


## Restore all per-rest class resources (long rest).
func restore_all_resources() -> void:
	restore_spell_slots()
	# Barbarian
	if dnd_class == DndClass.BARBARIAN:
		var data: Dictionary = CLASS_DATA[DndClass.BARBARIAN]
		if data.has("rage_charges"):
			rage_charges = _lookup_scaling_value(data["rage_charges"], level)
		rage_active = false
	# Fighter
	if dnd_class == DndClass.FIGHTER:
		var data: Dictionary = CLASS_DATA[DndClass.FIGHTER]
		if data.has("action_surge_charges"):
			action_surge_charges = _lookup_scaling_value(data["action_surge_charges"], level)
	# Monk
	if dnd_class == DndClass.MONK:
		ki_points = ki_points_max
	# Cleric
	if dnd_class == DndClass.CLERIC:
		var data: Dictionary = CLASS_DATA[DndClass.CLERIC]
		if data.has("channel_divinity_charges"):
			channel_divinity_charges = _lookup_scaling_value(data["channel_divinity_charges"], level)
	# Bard
	if dnd_class == DndClass.BARD:
		bardic_inspiration_charges = maxi(1, get_modifier(Ability.CHARISMA))
	# Druid
	if dnd_class == DndClass.DRUID:
		var data: Dictionary = CLASS_DATA[DndClass.DRUID]
		if data.has("wild_shape_charges"):
			wild_shape_charges = _lookup_scaling_value(data["wild_shape_charges"], level)
	# Paladin
	if dnd_class == DndClass.PALADIN:
		var data: Dictionary = CLASS_DATA[DndClass.PALADIN]
		if data.has("lay_on_hands_pool_per_level"):
			lay_on_hands_pool = level * data["lay_on_hands_pool_per_level"]
	# Sorcerer
	if dnd_class == DndClass.SORCERER:
		sorcery_points = sorcery_points_max


## Returns true if this class is a spellcaster.
func is_caster() -> bool:
	var data: Dictionary = CLASS_DATA[dnd_class]
	return data.get("is_caster", false)


## Returns the list of feature names this character has at their current level.
func get_feature_names() -> Array[String]:
	var names: Array[String] = []
	for feature_name: String in class_features:
		names.append(feature_name)
	return names


## Returns true if the character has a specific named feature.
func has_feature(feature_name: String) -> bool:
	return feature_name in class_features
