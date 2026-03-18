class_name Recruitment
extends RefCounted

## NPC recruitment system. Handles Charisma (Persuasion) checks and
## companion creation via StatBlockConverter.


## Check if the party can accept more companions.
static func can_recruit() -> bool:
	return not World.party.is_full()


## Attempt to recruit an NPC. Returns the companion Monster on success, null on failure.
## dc is the Persuasion DC for the check.
static func recruit_npc(slug: StringName, npc_name: String, dnd_class: int = -1, dc: int = 10) -> Monster:
	if not can_recruit():
		World.message_logged.emit("[color=yellow]Your party is already full (max %d companions).[/color]" % Party.MAX_COMPANIONS)
		return null

	# Persuasion check
	var roll_result := _persuasion_check(dc)
	if not roll_result.success:
		World.message_logged.emit("[color=yellow]%s declines your offer. (Persuasion %d vs DC %d)[/color]" % [npc_name, roll_result.total, dc])
		return null

	# Create companion
	var companion := StatBlockConverter.convert_to_companion(slug, npc_name, dnd_class)
	if not companion:
		Log.e("Recruitment: Failed to create companion from slug: %s" % slug)
		return null

	# Add to party
	World.party.add_member(companion)

	# Place on map adjacent to player
	_place_near_player(companion)

	World.message_logged.emit("[color=lime]%s joins your party! (Persuasion %d vs DC %d)[/color]" % [npc_name, roll_result.total, dc])
	return companion


## Roll Persuasion check using player's CharacterData if available.
static func _persuasion_check(dc: int) -> Dictionary:
	var player := World.player
	var roll := Dice.roll(1, 20)
	var bonus := 0

	if player.character_data:
		# CHA modifier + proficiency if proficient
		bonus = player.character_data.get_modifier(CharacterData.Ability.CHARISMA)
		if player.character_data.is_proficient_in_skill(CharacterData.Skill.PERSUASION):
			bonus += player.character_data.get_proficiency_bonus()

	var total := roll + bonus
	return {"success": total >= dc, "total": total, "roll": roll, "bonus": bonus}


## Place a companion on an adjacent walkable cell near the player.
static func _place_near_player(companion: Monster) -> void:
	var player_pos := World.current_map.find_monster_position(World.player)
	if player_pos == Utils.INVALID_POS:
		Log.e("Recruitment: Player position not found")
		return

	# Try all 8 adjacent directions
	for dir: Vector2i in Utils.ALL_DIRECTIONS:
		var pos := player_pos + dir
		if not World.current_map.is_in_bounds(pos):
			continue
		var cell := World.current_map.get_cell(pos)
		if cell.is_walkable() and not cell.monster:
			cell.monster = companion
			Log.i("Placed companion %s at %s" % [companion.name, pos])
			return

	# Fallback: place at player position (shouldn't happen but safe)
	Log.e("Recruitment: No adjacent walkable cell found, placing at player pos")
	var cell := World.current_map.get_cell(player_pos)
	cell.monster = companion
