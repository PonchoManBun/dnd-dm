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
	},
	DndClass.WIZARD: {
		"name": "Wizard",
		"hit_die": 6,
		"primary_ability": Ability.INTELLIGENCE,
		"saving_throws": [Ability.INTELLIGENCE, Ability.WISDOM],
		"armor_proficiencies": [],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.HISTORY, Skill.INSIGHT, Skill.INVESTIGATION, Skill.MEDICINE, Skill.RELIGION],
	},
	DndClass.ROGUE: {
		"name": "Rogue",
		"hit_die": 8,
		"primary_ability": Ability.DEXTERITY,
		"saving_throws": [Ability.DEXTERITY, Ability.INTELLIGENCE],
		"armor_proficiencies": [ArmorCategory.LIGHT],
		"num_skills": 4,
		"skill_choices": [Skill.ACROBATICS, Skill.ATHLETICS, Skill.DECEPTION, Skill.INSIGHT, Skill.INTIMIDATION, Skill.INVESTIGATION, Skill.PERCEPTION, Skill.PERFORMANCE, Skill.PERSUASION, Skill.SLEIGHT_OF_HAND, Skill.STEALTH],
	},
	DndClass.CLERIC: {
		"name": "Cleric",
		"hit_die": 8,
		"primary_ability": Ability.WISDOM,
		"saving_throws": [Ability.WISDOM, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.HISTORY, Skill.INSIGHT, Skill.MEDICINE, Skill.PERSUASION, Skill.RELIGION],
	},
	DndClass.RANGER: {
		"name": "Ranger",
		"hit_die": 10,
		"primary_ability": Ability.DEXTERITY,
		"saving_throws": [Ability.STRENGTH, Ability.DEXTERITY],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 3,
		"skill_choices": [Skill.ANIMAL_HANDLING, Skill.ATHLETICS, Skill.INSIGHT, Skill.INVESTIGATION, Skill.NATURE, Skill.PERCEPTION, Skill.STEALTH, Skill.SURVIVAL],
	},
	DndClass.PALADIN: {
		"name": "Paladin",
		"hit_die": 10,
		"primary_ability": Ability.STRENGTH,
		"saving_throws": [Ability.WISDOM, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.HEAVY, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ATHLETICS, Skill.INSIGHT, Skill.INTIMIDATION, Skill.MEDICINE, Skill.PERSUASION, Skill.RELIGION],
	},
	DndClass.BARBARIAN: {
		"name": "Barbarian",
		"hit_die": 12,
		"primary_ability": Ability.STRENGTH,
		"saving_throws": [Ability.STRENGTH, Ability.CONSTITUTION],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ANIMAL_HANDLING, Skill.ATHLETICS, Skill.INTIMIDATION, Skill.NATURE, Skill.PERCEPTION, Skill.SURVIVAL],
	},
	DndClass.BARD: {
		"name": "Bard",
		"hit_die": 8,
		"primary_ability": Ability.CHARISMA,
		"saving_throws": [Ability.DEXTERITY, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT],
		"num_skills": 3,
		"skill_choices": [Skill.ACROBATICS, Skill.ANIMAL_HANDLING, Skill.ARCANA, Skill.ATHLETICS, Skill.DECEPTION, Skill.HISTORY, Skill.INSIGHT, Skill.INTIMIDATION, Skill.INVESTIGATION, Skill.MEDICINE, Skill.NATURE, Skill.PERCEPTION, Skill.PERFORMANCE, Skill.PERSUASION, Skill.RELIGION, Skill.SLEIGHT_OF_HAND, Skill.STEALTH, Skill.SURVIVAL],
	},
	DndClass.DRUID: {
		"name": "Druid",
		"hit_die": 8,
		"primary_ability": Ability.WISDOM,
		"saving_throws": [Ability.INTELLIGENCE, Ability.WISDOM],
		"armor_proficiencies": [ArmorCategory.LIGHT, ArmorCategory.MEDIUM, ArmorCategory.SHIELDS],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.ANIMAL_HANDLING, Skill.INSIGHT, Skill.MEDICINE, Skill.NATURE, Skill.PERCEPTION, Skill.RELIGION, Skill.SURVIVAL],
	},
	DndClass.MONK: {
		"name": "Monk",
		"hit_die": 8,
		"primary_ability": Ability.DEXTERITY,
		"saving_throws": [Ability.STRENGTH, Ability.DEXTERITY],
		"armor_proficiencies": [],
		"num_skills": 2,
		"skill_choices": [Skill.ACROBATICS, Skill.ATHLETICS, Skill.HISTORY, Skill.INSIGHT, Skill.RELIGION, Skill.STEALTH],
	},
	DndClass.SORCERER: {
		"name": "Sorcerer",
		"hit_die": 6,
		"primary_ability": Ability.CHARISMA,
		"saving_throws": [Ability.CONSTITUTION, Ability.CHARISMA],
		"armor_proficiencies": [],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.DECEPTION, Skill.INSIGHT, Skill.INTIMIDATION, Skill.PERSUASION, Skill.RELIGION],
	},
	DndClass.WARLOCK: {
		"name": "Warlock",
		"hit_die": 8,
		"primary_ability": Ability.CHARISMA,
		"saving_throws": [Ability.WISDOM, Ability.CHARISMA],
		"armor_proficiencies": [ArmorCategory.LIGHT],
		"num_skills": 2,
		"skill_choices": [Skill.ARCANA, Skill.DECEPTION, Skill.HISTORY, Skill.INTIMIDATION, Skill.INVESTIGATION, Skill.NATURE, Skill.RELIGION],
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
