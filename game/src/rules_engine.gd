class_name RulesEngine
extends Node

## Centralized D&D 5e rules engine.
## All game mechanics go through here. In Phase 2, this becomes an HTTP client
## calling the Python orchestrator.

# Roll results
class RollResult:
	extends RefCounted
	var total: int = 0
	var natural_roll: int = 0
	var modifier: int = 0
	var advantage: bool = false
	var disadvantage: bool = false
	var is_critical_hit: bool = false
	var is_critical_miss: bool = false
	var description: String = ""

	func _to_string() -> String:
		return description

class AttackResult:
	extends RefCounted
	var hit: bool = false
	var critical: bool = false
	var damage: int = 0
	var damage_type: Damage.Type = Damage.Type.SLASHING
	var attack_roll: RollResult
	var damage_description: String = ""
	var attack_description: String = ""

class SavingThrowResult:
	extends RefCounted
	var success: bool = false
	var roll: RollResult
	var dc: int = 0

class AbilityCheckResult:
	extends RefCounted
	var success: bool = false
	var roll: RollResult
	var dc: int = 0


## Calculate ability modifier: (score - 10) / 2, rounded down
static func ability_modifier(score: int) -> int:
	return CharacterData.ability_modifier(score)


## Proficiency bonus based on level: +2 at 1st, scales every 4 levels
static func proficiency_bonus(level: int) -> int:
	return 2 + (level - 1) / 4


## Roll a d20 with optional advantage/disadvantage
static func d20_roll(advantage: bool = false, disadvantage: bool = false) -> RollResult:
	var result := RollResult.new()
	result.advantage = advantage and not disadvantage
	result.disadvantage = disadvantage and not advantage

	var roll1 := Dice.roll(1, 20)
	if result.advantage:
		var roll2 := Dice.roll(1, 20)
		result.natural_roll = maxi(roll1, roll2)
		result.description = "d20(%d,%d)=%d" % [roll1, roll2, result.natural_roll]
	elif result.disadvantage:
		var roll2 := Dice.roll(1, 20)
		result.natural_roll = mini(roll1, roll2)
		result.description = "d20(%d,%d)=%d" % [roll1, roll2, result.natural_roll]
	else:
		result.natural_roll = roll1
		result.description = "d20(%d)" % roll1

	result.is_critical_hit = result.natural_roll == 20
	result.is_critical_miss = result.natural_roll == 1
	result.total = result.natural_roll
	return result


## Make an attack roll.
## attacker_data: CharacterData of the attacker
## target_ac: target's armor class
## ability: STR or DEX (finesse weapons use higher)
## proficient: whether attacker is proficient with the weapon
## advantage/disadvantage: situational modifiers
static func attack_roll(
	attacker_data: CharacterData,
	target_ac: int,
	ability: CharacterData.Ability = CharacterData.Ability.STRENGTH,
	proficient: bool = true,
	advantage: bool = false,
	disadvantage: bool = false,
) -> RollResult:
	var result := d20_roll(advantage, disadvantage)

	# Always miss on natural 1, always hit on natural 20
	if result.is_critical_miss:
		result.total = -1  # Guarantees miss
		result.modifier = 0
		result.description += " NATURAL 1"
		return result

	var mod := attacker_data.get_modifier(ability)
	var prof := attacker_data.get_proficiency_bonus() if proficient else 0
	result.modifier = mod + prof
	result.total = result.natural_roll + result.modifier
	result.description += "+%d" % result.modifier
	if result.modifier != mod:
		result.description += "(mod%d+prof%d)" % [mod, prof]
	result.description += "=%d vs AC %d" % [result.total, target_ac]

	if result.is_critical_hit:
		result.description += " CRITICAL HIT!"
	elif result.total >= target_ac:
		result.description += " HIT!"
	else:
		result.description += " MISS"

	return result


## Roll damage dice, doubling dice on critical hit (not modifier).
## Returns total damage.
static func damage_roll(
	num_dice: int,
	die_size: int,
	modifier: int = 0,
	critical: bool = false,
) -> int:
	var dice_count := num_dice * 2 if critical else num_dice
	var roll := Dice.roll(dice_count, die_size)
	return maxi(0, roll + modifier)


## Format a damage roll for the combat log.
static func format_damage_roll(
	num_dice: int,
	die_size: int,
	roll_total: int,
	modifier: int = 0,
	critical: bool = false,
) -> String:
	var dice_str := "%dd%d" % [num_dice * 2 if critical else num_dice, die_size]
	if critical:
		dice_str += "(crit)"
	var base := roll_total - modifier
	if modifier != 0:
		return "%s(%d)+%d=%d" % [dice_str, base, modifier, roll_total]
	return "%s(%d)=%d" % [dice_str, base, roll_total]


## Full melee/ranged attack resolution.
static func resolve_attack(
	attacker_data: CharacterData,
	target_ac: int,
	weapon_dice: int,
	weapon_sides: int,
	damage_type: Damage.Type,
	ability: CharacterData.Ability = CharacterData.Ability.STRENGTH,
	proficient: bool = true,
	advantage: bool = false,
	disadvantage: bool = false,
) -> AttackResult:
	var result := AttackResult.new()
	result.damage_type = damage_type

	# Attack roll
	result.attack_roll = attack_roll(attacker_data, target_ac, ability, proficient, advantage, disadvantage)
	result.critical = result.attack_roll.is_critical_hit
	result.attack_description = result.attack_roll.description

	# Check hit
	if result.attack_roll.is_critical_miss:
		result.hit = false
		return result

	result.hit = result.attack_roll.is_critical_hit or result.attack_roll.total >= target_ac
	if not result.hit:
		return result

	# Damage roll
	var dmg_mod := attacker_data.get_modifier(ability)
	result.damage = damage_roll(weapon_dice, weapon_sides, dmg_mod, result.critical)
	result.damage_description = format_damage_roll(weapon_dice, weapon_sides, result.damage, dmg_mod, result.critical)
	result.damage_description += " %s" % Damage.type_to_string(damage_type)

	return result


## Make a saving throw.
static func saving_throw(
	character_data: CharacterData,
	ability: CharacterData.Ability,
	dc: int,
	advantage: bool = false,
	disadvantage: bool = false,
) -> SavingThrowResult:
	var result := SavingThrowResult.new()
	result.dc = dc

	# Check conditions that auto-fail
	if ability == CharacterData.Ability.STRENGTH or ability == CharacterData.Ability.DEXTERITY:
		if character_data.has_condition(CharacterData.Condition.PARALYZED) \
				or character_data.has_condition(CharacterData.Condition.STUNNED) \
				or character_data.has_condition(CharacterData.Condition.UNCONSCIOUS):
			result.success = false
			result.roll = RollResult.new()
			result.roll.description = "AUTO-FAIL (incapacitated)"
			return result

	result.roll = d20_roll(advantage, disadvantage)
	var mod := character_data.get_modifier(ability)
	var prof := character_data.get_proficiency_bonus() if character_data.is_proficient_in_saving_throw(ability) else 0
	result.roll.modifier = mod + prof
	result.roll.total = result.roll.natural_roll + result.roll.modifier
	result.success = result.roll.total >= dc
	result.roll.description += "+%d=%d vs DC %d — %s" % [
		result.roll.modifier, result.roll.total, dc,
		"SUCCESS" if result.success else "FAILURE"
	]
	return result


## Make an ability check.
static func ability_check(
	character_data: CharacterData,
	skill: CharacterData.Skill,
	dc: int,
	advantage: bool = false,
	disadvantage: bool = false,
) -> AbilityCheckResult:
	var result := AbilityCheckResult.new()
	result.dc = dc

	var ability: CharacterData.Ability = CharacterData.SKILL_ABILITIES[skill]
	result.roll = d20_roll(advantage, disadvantage)
	var mod := character_data.get_modifier(ability)
	var prof := 0
	if character_data.has_expertise_in_skill(skill):
		prof = character_data.get_proficiency_bonus() * 2
	elif character_data.is_proficient_in_skill(skill):
		prof = character_data.get_proficiency_bonus()
	result.roll.modifier = mod + prof
	result.roll.total = result.roll.natural_roll + result.roll.modifier
	result.success = result.roll.total >= dc
	result.roll.description += "+%d=%d vs DC %d — %s" % [
		result.roll.modifier, result.roll.total, dc,
		"SUCCESS" if result.success else "FAILURE"
	]
	return result


## Roll initiative: d20 + DEX modifier
static func initiative_roll(character_data: CharacterData) -> int:
	var roll := Dice.roll(1, 20)
	var dex_mod := character_data.get_modifier(CharacterData.Ability.DEXTERITY)
	return roll + dex_mod + character_data.initiative_bonus


## Calculate AC from equipment.
## base_ac depends on armor type:
##   No armor: 10 + DEX mod
##   Light: armor_base + DEX mod
##   Medium: armor_base + min(DEX mod, 2)
##   Heavy: armor_base (no DEX)
##   Shield: +2
static func calculate_ac(
	character_data: CharacterData,
	armor_base: int = 0,
	armor_type: CharacterData.ArmorCategory = CharacterData.ArmorCategory.LIGHT,
	has_shield: bool = false,
) -> int:
	var ac: int
	var dex_mod := character_data.get_modifier(CharacterData.Ability.DEXTERITY)

	if armor_base <= 0:
		# No armor
		ac = 10 + dex_mod
	else:
		match armor_type:
			CharacterData.ArmorCategory.LIGHT:
				ac = armor_base + dex_mod
			CharacterData.ArmorCategory.MEDIUM:
				ac = armor_base + mini(dex_mod, 2)
			CharacterData.ArmorCategory.HEAVY:
				ac = armor_base
			_:
				ac = 10 + dex_mod

	if has_shield:
		ac += 2

	return ac


## Check if a condition grants advantage on attacks against the target.
static func has_advantage_against(target_data: CharacterData) -> bool:
	return (
		target_data.has_condition(CharacterData.Condition.BLINDED)
		or target_data.has_condition(CharacterData.Condition.PARALYZED)
		or target_data.has_condition(CharacterData.Condition.STUNNED)
		or target_data.has_condition(CharacterData.Condition.UNCONSCIOUS)
		or target_data.has_condition(CharacterData.Condition.RESTRAINED)
		or target_data.has_condition(CharacterData.Condition.PRONE)
	)


## Check if a condition grants disadvantage on the attacker's attacks.
static func has_disadvantage_from_conditions(attacker_data: CharacterData) -> bool:
	return (
		attacker_data.has_condition(CharacterData.Condition.BLINDED)
		or attacker_data.has_condition(CharacterData.Condition.FRIGHTENED)
		or attacker_data.has_condition(CharacterData.Condition.POISONED)
		or attacker_data.has_condition(CharacterData.Condition.RESTRAINED)
		or attacker_data.has_condition(CharacterData.Condition.PRONE)
	)


## Apply condition mechanical effects to speed.
## Returns modified speed in feet.
static func apply_condition_speed_modifiers(character_data: CharacterData, base_speed: int) -> int:
	var speed := base_speed
	if character_data.has_condition(CharacterData.Condition.GRAPPLED) \
			or character_data.has_condition(CharacterData.Condition.RESTRAINED):
		speed = 0
	if character_data.has_condition(CharacterData.Condition.PRONE):
		# Prone: moving costs an extra foot for every foot (halved)
		speed = speed / 2
	return speed
