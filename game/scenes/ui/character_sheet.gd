class_name CharacterSheet
extends PanelContainer

## Full-screen character sheet overlay showing D&D 5e stats.
## Toggle with Shift+C. Reads from World.player.character_data.

var _close_button: Button
var _content_hbox: HBoxContainer
var _left_column: VBoxContainer
var _right_column: VBoxContainer


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Panel style
	add_theme_stylebox_override("panel", UIStyles.overlay_panel())

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# -- Header row --
	var header_row := HBoxContainer.new()
	header_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(header_row)

	var header := Label.new()
	header.text = "Character Sheet"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_theme_color_override("font_color", UIColors.TEXT_HEADER)
	header.add_theme_font_size_override("font_size", 16)
	header_row.add_child(header)

	_close_button = Button.new()
	_close_button.text = "X"
	UIStyles.apply_close_button_styles(_close_button)
	_close_button.pressed.connect(func() -> void: visible = false)
	header_row.add_child(_close_button)

	# Separator
	var sep := UIStyles.h_separator(2)
	vbox.add_child(sep)

	# -- Two-column body --
	_content_hbox = HBoxContainer.new()
	_content_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_hbox.add_theme_constant_override("separation", 8)
	vbox.add_child(_content_hbox)

	# Left column: scroll container
	var left_scroll := ScrollContainer.new()
	left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_scroll.size_flags_stretch_ratio = 0.45
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_hbox.add_child(left_scroll)

	_left_column = VBoxContainer.new()
	_left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_column.add_theme_constant_override("separation", 3)
	left_scroll.add_child(_left_column)

	# Vertical separator
	var vsep := UIStyles.v_separator()
	_content_hbox.add_child(vsep)

	# Right column: scroll container
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_stretch_ratio = 0.55
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_content_hbox.add_child(right_scroll)

	_right_column = VBoxContainer.new()
	_right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_column.add_theme_constant_override("separation", 3)
	right_scroll.add_child(_right_column)


func toggle() -> void:
	visible = not visible
	if visible:
		_refresh()


func _refresh() -> void:
	# Clear existing content
	for child in _left_column.get_children():
		child.queue_free()
	for child in _right_column.get_children():
		child.queue_free()

	var player := World.player
	if not player or not player.character_data:
		_add_label(_left_column, "No character data available.", UIColors.TEXT_DIM)
		return

	var cd := player.character_data

	# === LEFT COLUMN ===

	# Name, Race, Class, Level
	_add_label(_left_column, cd.character_name, UIColors.TEXT_HEADER)
	_add_label(_left_column, "%s %s, Level %d" % [cd.get_race_name(), cd.get_class_name_str(), cd.level], UIColors.TEXT_PRIMARY)

	# XP bar
	var xp_next := _get_xp_for_next_level(cd)
	if xp_next > 0:
		_add_label(_left_column, "XP: %d / %d" % [cd.experience_points, xp_next], UIColors.TEXT_DIM)

	# HP
	_add_label(_left_column, "HP: %d / %d" % [player.hp, player.max_hp], UIColors.TEXT_PRIMARY)

	_add_section_separator(_left_column)

	# Ability Scores
	_add_label(_left_column, "Ability Scores", UIColors.TEXT_HEADER)
	var abilities := [
		["STR", CharacterData.Ability.STRENGTH],
		["DEX", CharacterData.Ability.DEXTERITY],
		["CON", CharacterData.Ability.CONSTITUTION],
		["INT", CharacterData.Ability.INTELLIGENCE],
		["WIS", CharacterData.Ability.WISDOM],
		["CHA", CharacterData.Ability.CHARISMA],
	]
	for ab: Array in abilities:
		var name_str: String = ab[0]
		var ability: CharacterData.Ability = ab[1]
		var score := cd.get_ability_score(ability)
		var mod := cd.get_modifier(ability)
		var mod_str := "+%d" % mod if mod >= 0 else str(mod)
		_add_label(_left_column, "%s: %d (%s)" % [name_str, score, mod_str], UIColors.TEXT_PRIMARY)

	_add_section_separator(_left_column)

	# Proficiency bonus, AC, Speed
	_add_label(_left_column, "Prof. Bonus: +%d" % cd.get_proficiency_bonus(), UIColors.TEXT_PRIMARY)
	_add_label(_left_column, "Armor Class: %d" % player.get_armor_class(), UIColors.TEXT_PRIMARY)
	_add_label(_left_column, "Speed: %d ft" % cd.speed_feet, UIColors.TEXT_PRIMARY)

	_add_section_separator(_left_column)

	# Saving Throws
	_add_label(_left_column, "Saving Throws", UIColors.TEXT_HEADER)
	for ab: Array in abilities:
		var name_str: String = ab[0]
		var ability: CharacterData.Ability = ab[1]
		var mod := cd.get_modifier(ability)
		var is_prof := cd.is_proficient_in_saving_throw(ability)
		if is_prof:
			mod += cd.get_proficiency_bonus()
		var mod_str := "+%d" % mod if mod >= 0 else str(mod)
		var prof_mark := "*" if is_prof else " "
		_add_label(_left_column, "%s %s: %s" % [prof_mark, name_str, mod_str], UIColors.TEXT_PRIMARY)

	# === RIGHT COLUMN ===

	# Skills
	_add_label(_right_column, "Skills", UIColors.TEXT_HEADER)
	var skills := [
		["Acrobatics", CharacterData.Skill.ACROBATICS],
		["Animal Handling", CharacterData.Skill.ANIMAL_HANDLING],
		["Arcana", CharacterData.Skill.ARCANA],
		["Athletics", CharacterData.Skill.ATHLETICS],
		["Deception", CharacterData.Skill.DECEPTION],
		["History", CharacterData.Skill.HISTORY],
		["Insight", CharacterData.Skill.INSIGHT],
		["Intimidation", CharacterData.Skill.INTIMIDATION],
		["Investigation", CharacterData.Skill.INVESTIGATION],
		["Medicine", CharacterData.Skill.MEDICINE],
		["Nature", CharacterData.Skill.NATURE],
		["Perception", CharacterData.Skill.PERCEPTION],
		["Performance", CharacterData.Skill.PERFORMANCE],
		["Persuasion", CharacterData.Skill.PERSUASION],
		["Religion", CharacterData.Skill.RELIGION],
		["Sleight of Hand", CharacterData.Skill.SLEIGHT_OF_HAND],
		["Stealth", CharacterData.Skill.STEALTH],
		["Survival", CharacterData.Skill.SURVIVAL],
	]
	for sk: Array in skills:
		var skill_name: String = sk[0]
		var skill: CharacterData.Skill = sk[1]
		var ability: CharacterData.Ability = CharacterData.SKILL_ABILITIES[skill]
		var mod := cd.get_modifier(ability)
		var is_prof := cd.is_proficient_in_skill(skill)
		var has_exp := cd.has_expertise_in_skill(skill)
		if has_exp:
			mod += cd.get_proficiency_bonus() * 2
		elif is_prof:
			mod += cd.get_proficiency_bonus()
		var mod_str := "+%d" % mod if mod >= 0 else str(mod)
		var mark := "**" if has_exp else ("*" if is_prof else " ")
		_add_label(_right_column, "%s %s: %s" % [mark, skill_name, mod_str], UIColors.TEXT_PRIMARY)

	_add_section_separator(_right_column)

	# Class Features
	var features := cd.get_feature_names()
	if features.size() > 0:
		_add_label(_right_column, "Class Features", UIColors.TEXT_HEADER)
		for feature_name: String in features:
			var info: Dictionary = cd.class_features[feature_name]
			var text := feature_name
			if info.max_uses > 0:
				text += " (%d/%d)" % [info.max_uses - info.uses, info.max_uses]
			_add_label(_right_column, text, UIColors.TEXT_PRIMARY)

	# Conditions
	if cd.conditions.size() > 0:
		_add_section_separator(_right_column)
		_add_label(_right_column, "Conditions", UIColors.TEXT_HEADER)
		for condition: CharacterData.Condition in cd.conditions:
			_add_label(_right_column, CharacterData.Condition.keys()[condition].capitalize(), GameColors.ORANGE)


func _add_label(parent: VBoxContainer, text: String, color: Color) -> void:
	parent.add_child(UIStyles.make_label(text, color))


func _add_section_separator(parent: VBoxContainer) -> void:
	parent.add_child(UIStyles.h_separator(2))


func _get_xp_for_next_level(cd: CharacterData) -> int:
	if cd.level >= CharacterData.XP_THRESHOLDS.size():
		return 0
	return CharacterData.XP_THRESHOLDS[cd.level]
