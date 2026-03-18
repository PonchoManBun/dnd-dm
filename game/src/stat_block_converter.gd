class_name StatBlockConverter
extends RefCounted

## Converts a D&D monster stat block into a party companion.
## Uses DndMonsterFactory as the base, then adjusts faction, behavior,
## and applies class proficiencies.


## Create a companion-ready Monster from a D&D monster slug.
## If dnd_class is -1, infers class from highest ability score.
static func convert_to_companion(slug: StringName, companion_name: String = "", dnd_class: int = -1) -> Monster:
	var monster := DndMonsterFactory.create_monster(slug)
	if not monster:
		Log.e("StatBlockConverter: Failed to create monster from slug: %s" % slug)
		return null

	# Set companion properties
	monster.faction = Factions.Type.HUMAN
	monster.behavior = Monster.Behavior.PASSIVE

	# Override name if provided
	if not companion_name.is_empty():
		monster.name = companion_name
		if monster.character_data:
			monster.character_data.character_name = companion_name

	# Infer or apply class
	if monster.character_data:
		var cd := monster.character_data
		if dnd_class == -1:
			cd.dnd_class = _infer_class(cd) as CharacterData.DndClass
		else:
			cd.dnd_class = dnd_class as CharacterData.DndClass

		# Apply class proficiencies
		_apply_class_proficiencies(cd)

		# Initialize class features
		cd.initialize_class_features()

		# Recalculate HP based on class hit die
		cd.max_hp = cd.get_max_hp_for_level()
		cd.current_hp = cd.max_hp
		monster.hp = cd.max_hp
		monster.max_hp = cd.max_hp

	# Rebuild behavior tree (passive companion doesn't attack on its own)
	monster.behavior_tree = MonsterAI.create_behavior_tree(monster)

	return monster


## Infer the best D&D class from ability scores.
static func _infer_class(cd: CharacterData) -> CharacterData.DndClass:
	# Find the highest ability score
	var scores := {
		CharacterData.Ability.STRENGTH: cd.strength,
		CharacterData.Ability.DEXTERITY: cd.dexterity,
		CharacterData.Ability.CONSTITUTION: cd.constitution,
		CharacterData.Ability.INTELLIGENCE: cd.intelligence,
		CharacterData.Ability.WISDOM: cd.wisdom,
		CharacterData.Ability.CHARISMA: cd.charisma,
	}

	var best_ability: CharacterData.Ability = CharacterData.Ability.STRENGTH
	var best_score: int = 0
	for ability: CharacterData.Ability in scores:
		if scores[ability] > best_score:
			best_score = scores[ability]
			best_ability = ability

	# Map primary ability to class
	match best_ability:
		CharacterData.Ability.STRENGTH:
			return CharacterData.DndClass.FIGHTER
		CharacterData.Ability.DEXTERITY:
			return CharacterData.DndClass.ROGUE
		CharacterData.Ability.CONSTITUTION:
			return CharacterData.DndClass.BARBARIAN
		CharacterData.Ability.INTELLIGENCE:
			return CharacterData.DndClass.WIZARD
		CharacterData.Ability.WISDOM:
			return CharacterData.DndClass.CLERIC
		CharacterData.Ability.CHARISMA:
			return CharacterData.DndClass.BARD

	return CharacterData.DndClass.FIGHTER


## Apply saving throw and skill proficiencies from class data.
static func _apply_class_proficiencies(cd: CharacterData) -> void:
	var class_data: Dictionary = CharacterData.CLASS_DATA.get(cd.dnd_class, {})
	if class_data.is_empty():
		return

	# Saving throw proficiencies
	cd.saving_throw_proficiencies.clear()
	var save_throws: Array = class_data.get("saving_throws", [])
	for st: Variant in save_throws:
		cd.saving_throw_proficiencies.append(st as CharacterData.Ability)

	# Armor proficiencies
	cd.armor_proficiencies.clear()
	var armor_profs: Array = class_data.get("armor_proficiencies", [])
	for ap: Variant in armor_profs:
		cd.armor_proficiencies.append(ap as CharacterData.ArmorCategory)

	# Skill proficiencies — pick the first N from the class skill list
	cd.skill_proficiencies.clear()
	var num_skills: int = class_data.get("num_skills", 2)
	var skill_choices: Array = class_data.get("skill_choices", [])
	for i in range(mini(num_skills, skill_choices.size())):
		cd.skill_proficiencies.append(skill_choices[i] as CharacterData.Skill)
