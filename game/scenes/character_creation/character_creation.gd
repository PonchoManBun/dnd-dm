class_name CharacterCreation
extends Control

## 4-step character creation flow: Race -> Class -> Abilities -> Name & Confirm.
## Builds UI entirely in code (no .tscn needed).

signal character_created(data: CharacterData)
signal cancel

# --- Constants ---
const STEP_COUNT: int = 4
const STEP_TITLES: Array[String] = ["Choose Race", "Choose Class", "Roll Abilities", "Name & Confirm"]

const BG_COLOR := Color(0.078, 0.047, 0.11, 1.0)  # Match default_clear_color
const PANEL_COLOR := Color(0.12, 0.1, 0.15, 0.95)
const ACCENT_COLOR := Color(0.35, 0.55, 0.85, 1.0)
const ACCENT_HOVER := Color(0.45, 0.65, 0.95, 1.0)
const SELECTED_COLOR := Color(0.25, 0.5, 0.3, 1.0)
const SELECTED_HOVER := Color(0.3, 0.6, 0.35, 1.0)
const TEXT_COLOR := Color(0.85, 0.85, 0.86, 1.0)
const DIM_TEXT_COLOR := Color(0.5, 0.5, 0.55, 1.0)
const BONUS_COLOR := Color(0.4, 0.8, 0.4, 1.0)
const TITLE_COLOR := Color(0.95, 0.85, 0.6, 1.0)

# --- State ---
var current_step: int = 0
var selected_race: CharacterData.Race = CharacterData.Race.HUMAN
var selected_class: CharacterData.DndClass = CharacterData.DndClass.FIGHTER
var base_ability_scores: Array[int] = [10, 10, 10, 10, 10, 10]
var character_name: String = ""

# --- Ordered keys for iteration ---
var _race_keys: Array[CharacterData.Race] = [
	CharacterData.Race.HUMAN,
	CharacterData.Race.ELF,
	CharacterData.Race.DWARF,
	CharacterData.Race.HALFLING,
	CharacterData.Race.HALF_ORC,
	CharacterData.Race.GNOME,
	CharacterData.Race.DRAGONBORN,
	CharacterData.Race.HALF_ELF,
	CharacterData.Race.TIEFLING,
]

var _class_keys: Array[CharacterData.DndClass] = [
	CharacterData.DndClass.FIGHTER,
	CharacterData.DndClass.WIZARD,
	CharacterData.DndClass.ROGUE,
	CharacterData.DndClass.CLERIC,
	CharacterData.DndClass.RANGER,
	CharacterData.DndClass.PALADIN,
	CharacterData.DndClass.BARBARIAN,
	CharacterData.DndClass.BARD,
	CharacterData.DndClass.DRUID,
	CharacterData.DndClass.MONK,
	CharacterData.DndClass.SORCERER,
	CharacterData.DndClass.WARLOCK,
]

var _ability_keys: Array[CharacterData.Ability] = [
	CharacterData.Ability.STRENGTH,
	CharacterData.Ability.DEXTERITY,
	CharacterData.Ability.CONSTITUTION,
	CharacterData.Ability.INTELLIGENCE,
	CharacterData.Ability.WISDOM,
	CharacterData.Ability.CHARISMA,
]

var _ability_names: Array[String] = ["STR", "DEX", "CON", "INT", "WIS", "CHA"]

# JSON data loaded from files
var _races_json: Dictionary = {}
var _classes_json: Dictionary = {}

# --- UI References ---
var _root_panel: PanelContainer
var _step_label: Label
var _title_label: Label
var _content_container: MarginContainer
var _back_button: Button
var _next_button: Button
var _step_containers: Array[Control] = []

# Step 1 - Race
var _race_buttons: Array[Button] = []
var _race_desc_label: RichTextLabel
var _race_traits_label: RichTextLabel

# Step 2 - Class
var _class_buttons: Array[Button] = []
var _class_desc_label: RichTextLabel
var _class_info_label: RichTextLabel

# Step 3 - Abilities
var _ability_score_labels: Array[Label] = []
var _ability_bonus_labels: Array[Label] = []
var _ability_total_labels: Array[Label] = []
var _reroll_button: Button

# Step 4 - Name & Confirm
var _name_input: LineEdit
var _summary_label: RichTextLabel


func _ready() -> void:
	_load_json_data()
	_build_ui()
	_roll_abilities()
	_show_step(0)


func _load_json_data() -> void:
	var races_file := FileAccess.open("res://assets/data/races.json", FileAccess.READ)
	if races_file:
		var json := JSON.new()
		var err := json.parse(races_file.get_as_text())
		if err == OK:
			_races_json = json.data
		races_file.close()

	var classes_file := FileAccess.open("res://assets/data/classes.json", FileAccess.READ)
	if classes_file:
		var json := JSON.new()
		var err := json.parse(classes_file.get_as_text())
		if err == OK:
			_classes_json = json.data
		classes_file.close()


# =========================================================================
# UI Construction
# =========================================================================

func _build_ui() -> void:
	# Full-screen background
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)

	# Outer centering
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(center)

	# Main panel
	_root_panel = PanelContainer.new()
	_root_panel.custom_minimum_size = Vector2(580, 320)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = PANEL_COLOR
	panel_style.border_color = Color(0.3, 0.3, 0.35, 0.6)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(2)
	panel_style.set_content_margin_all(10)
	_root_panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(_root_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_root_panel.add_child(vbox)

	# Header: Step indicator + Title
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	vbox.add_child(header)

	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	_step_label.add_theme_font_size_override("font_size", 12)
	header.add_child(_step_label)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Content area (swapped per step)
	_content_container = MarginContainer.new()
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_container.add_theme_constant_override("margin_left", 4)
	_content_container.add_theme_constant_override("margin_right", 4)
	_content_container.add_theme_constant_override("margin_top", 2)
	_content_container.add_theme_constant_override("margin_bottom", 2)
	vbox.add_child(_content_container)

	# Build each step container (hidden by default)
	_step_containers.resize(STEP_COUNT)
	_step_containers[0] = _build_race_step()
	_step_containers[1] = _build_class_step()
	_step_containers[2] = _build_ability_step()
	_step_containers[3] = _build_name_step()

	for container: Control in _step_containers:
		container.visible = false
		_content_container.add_child(container)

	# Separator before buttons
	var sep2 := HSeparator.new()
	vbox.add_child(sep2)

	# Navigation buttons
	var nav_bar := HBoxContainer.new()
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_bar.add_theme_constant_override("separation", 8)
	vbox.add_child(nav_bar)

	_back_button = _make_nav_button("Back")
	_back_button.pressed.connect(_on_back_pressed)
	nav_bar.add_child(_back_button)

	_next_button = _make_nav_button("Next")
	_next_button.pressed.connect(_on_next_pressed)
	nav_bar.add_child(_next_button)


func _make_nav_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 28)
	return btn


# ---- Step 1: Race Selection ----

func _build_race_step() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Left: Grid of race buttons
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size.x = 220
	hbox.add_child(left)

	var grid_label := Label.new()
	grid_label.text = "Races"
	grid_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	grid_label.add_theme_font_size_override("font_size", 12)
	left.add_child(grid_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)

	_race_buttons.clear()
	for race_enum: CharacterData.Race in _race_keys:
		var race_data: Dictionary = CharacterData.RACE_DATA[race_enum]
		var btn := Button.new()
		btn.text = race_data["name"]
		btn.custom_minimum_size = Vector2(68, 24)
		btn.add_theme_font_size_override("font_size", 12)
		var captured_race: CharacterData.Race = race_enum
		btn.pressed.connect(func() -> void: _select_race(captured_race))
		grid.add_child(btn)
		_race_buttons.append(btn)

	# Right: Description panel
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	hbox.add_child(right)

	_race_desc_label = RichTextLabel.new()
	_race_desc_label.bbcode_enabled = true
	_race_desc_label.fit_content = true
	_race_desc_label.scroll_active = false
	_race_desc_label.add_theme_font_size_override("normal_font_size", 14)
	right.add_child(_race_desc_label)

	_race_traits_label = RichTextLabel.new()
	_race_traits_label.bbcode_enabled = true
	_race_traits_label.fit_content = true
	_race_traits_label.scroll_active = false
	_race_traits_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_race_traits_label.add_theme_font_size_override("normal_font_size", 12)
	right.add_child(_race_traits_label)

	return hbox


# ---- Step 2: Class Selection ----

func _build_class_step() -> Control:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Left: Grid of class buttons
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size.x = 220
	hbox.add_child(left)

	var grid_label := Label.new()
	grid_label.text = "Classes"
	grid_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	grid_label.add_theme_font_size_override("font_size", 12)
	left.add_child(grid_label)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	left.add_child(grid)

	_class_buttons.clear()
	for cls_enum: CharacterData.DndClass in _class_keys:
		var cls_data: Dictionary = CharacterData.CLASS_DATA[cls_enum]
		var btn := Button.new()
		btn.text = cls_data["name"]
		btn.custom_minimum_size = Vector2(68, 24)
		btn.add_theme_font_size_override("font_size", 12)
		var captured_cls: CharacterData.DndClass = cls_enum
		btn.pressed.connect(func() -> void: _select_class(captured_cls))
		grid.add_child(btn)
		_class_buttons.append(btn)

	# Right: Description panel
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 4)
	hbox.add_child(right)

	_class_desc_label = RichTextLabel.new()
	_class_desc_label.bbcode_enabled = true
	_class_desc_label.fit_content = true
	_class_desc_label.scroll_active = false
	_class_desc_label.add_theme_font_size_override("normal_font_size", 14)
	right.add_child(_class_desc_label)

	_class_info_label = RichTextLabel.new()
	_class_info_label.bbcode_enabled = true
	_class_info_label.fit_content = true
	_class_info_label.scroll_active = false
	_class_info_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_class_info_label.add_theme_font_size_override("normal_font_size", 12)
	right.add_child(_class_info_label)

	return hbox


# ---- Step 3: Ability Scores ----

func _build_ability_step() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	var intro := Label.new()
	intro.text = "Roll 4d6, drop lowest for each ability score."
	intro.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	intro.add_theme_font_size_override("font_size", 12)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(intro)

	# Ability scores grid
	var grid := GridContainer.new()
	grid.columns = 4  # Name | Base | Bonus | Total
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(grid)

	# Header row
	for header_text: String in ["Ability", "Roll", "Racial", "Total"]:
		var header := Label.new()
		header.text = header_text
		header.add_theme_color_override("font_color", DIM_TEXT_COLOR)
		header.add_theme_font_size_override("font_size", 12)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		header.custom_minimum_size.x = 60
		grid.add_child(header)

	_ability_score_labels.clear()
	_ability_bonus_labels.clear()
	_ability_total_labels.clear()

	for i: int in range(6):
		# Ability name
		var name_label := Label.new()
		name_label.text = _ability_names[i]
		name_label.add_theme_color_override("font_color", TEXT_COLOR)
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.custom_minimum_size.x = 60
		grid.add_child(name_label)

		# Base score
		var score_label := Label.new()
		score_label.text = "10"
		score_label.add_theme_color_override("font_color", TEXT_COLOR)
		score_label.add_theme_font_size_override("font_size", 14)
		score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		score_label.custom_minimum_size.x = 60
		grid.add_child(score_label)
		_ability_score_labels.append(score_label)

		# Racial bonus
		var bonus_label := Label.new()
		bonus_label.text = "+0"
		bonus_label.add_theme_color_override("font_color", BONUS_COLOR)
		bonus_label.add_theme_font_size_override("font_size", 14)
		bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bonus_label.custom_minimum_size.x = 60
		grid.add_child(bonus_label)
		_ability_bonus_labels.append(bonus_label)

		# Total
		var total_label := Label.new()
		total_label.text = "10"
		total_label.add_theme_color_override("font_color", TITLE_COLOR)
		total_label.add_theme_font_size_override("font_size", 14)
		total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		total_label.custom_minimum_size.x = 60
		grid.add_child(total_label)
		_ability_total_labels.append(total_label)

	# Re-roll button
	_reroll_button = Button.new()
	_reroll_button.text = "Re-Roll"
	_reroll_button.custom_minimum_size = Vector2(100, 28)
	_reroll_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_reroll_button.pressed.connect(_on_reroll_pressed)
	vbox.add_child(_reroll_button)

	return vbox


# ---- Step 4: Name & Confirm ----

func _build_name_step() -> Control:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Name input
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "Name:"
	name_label.add_theme_color_override("font_color", TEXT_COLOR)
	name_label.add_theme_font_size_override("font_size", 14)
	name_row.add_child(name_label)

	_name_input = LineEdit.new()
	_name_input.custom_minimum_size = Vector2(200, 24)
	_name_input.placeholder_text = "Enter name..."
	_name_input.max_length = 24
	_name_input.add_theme_font_size_override("font_size", 14)
	_name_input.text_changed.connect(func(new_text: String) -> void:
		character_name = new_text
		_update_nav_buttons()
	)
	name_row.add_child(_name_input)

	# Random name button
	var random_btn := Button.new()
	random_btn.text = "Random"
	random_btn.custom_minimum_size = Vector2(70, 24)
	random_btn.add_theme_font_size_override("font_size", 12)
	random_btn.pressed.connect(_on_random_name_pressed)
	name_row.add_child(random_btn)

	# Character summary
	_summary_label = RichTextLabel.new()
	_summary_label.bbcode_enabled = true
	_summary_label.fit_content = true
	_summary_label.scroll_active = false
	_summary_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_label.add_theme_font_size_override("normal_font_size", 12)
	vbox.add_child(_summary_label)

	return vbox


# =========================================================================
# Step Navigation
# =========================================================================

func _show_step(step: int) -> void:
	current_step = clampi(step, 0, STEP_COUNT - 1)

	# Update header
	_step_label.text = "Step %d / %d" % [current_step + 1, STEP_COUNT]
	_title_label.text = STEP_TITLES[current_step]

	# Show/hide step containers
	for i: int in range(STEP_COUNT):
		_step_containers[i].visible = (i == current_step)

	# Refresh content for current step
	match current_step:
		0: _refresh_race_step()
		1: _refresh_class_step()
		2: _refresh_ability_step()
		3: _refresh_name_step()

	_update_nav_buttons()

	# Animate the transition
	_animate_step_in()


func _animate_step_in() -> void:
	var container: Control = _step_containers[current_step]
	container.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(container, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)


func _update_nav_buttons() -> void:
	# Back button
	if current_step == 0:
		_back_button.text = "Cancel"
	else:
		_back_button.text = "Back"

	# Next button
	if current_step == STEP_COUNT - 1:
		_next_button.text = "Confirm"
		_next_button.disabled = character_name.strip_edges().is_empty()
	else:
		_next_button.text = "Next"
		_next_button.disabled = false


func _on_back_pressed() -> void:
	if current_step == 0:
		cancel.emit()
	else:
		_show_step(current_step - 1)


func _on_next_pressed() -> void:
	if current_step < STEP_COUNT - 1:
		_show_step(current_step + 1)
	else:
		_confirm_character()


# =========================================================================
# Step 1: Race
# =========================================================================

func _select_race(race: CharacterData.Race) -> void:
	selected_race = race
	_refresh_race_step()
	if current_step == 2:
		_refresh_ability_step()


func _refresh_race_step() -> void:
	# Update button highlighting
	for i: int in range(_race_keys.size()):
		var is_selected: bool = (_race_keys[i] == selected_race)
		_update_selection_button(_race_buttons[i], is_selected)

	# Update description from JSON
	var race_data: Dictionary = CharacterData.RACE_DATA[selected_race]
	var race_name: String = race_data["name"]
	var race_key: String = race_name.to_lower().replace("-", "_")

	var desc: String = ""
	var traits_text: String = ""

	if _races_json.has(race_key):
		var json_data: Dictionary = _races_json[race_key]
		desc = json_data.get("description", "")
		var traits: Array = json_data.get("traits", [])
		if not traits.is_empty():
			traits_text = "[color=#888888]Traits:[/color] " + ", ".join(traits)
	else:
		desc = race_name

	# Ability bonuses
	var bonuses: Dictionary = race_data["ability_bonuses"]
	var bonus_parts: Array[String] = []
	for ability: CharacterData.Ability in bonuses:
		var idx: int = _ability_keys.find(ability)
		if idx >= 0:
			bonus_parts.append("%s +%d" % [_ability_names[idx], bonuses[ability]])
	var bonus_str: String = ", ".join(bonus_parts) if not bonus_parts.is_empty() else "None"

	var speed: int = race_data["speed"]

	_race_desc_label.text = "[b]%s[/b]\n%s" % [race_name, desc]
	_race_traits_label.text = "[color=#888888]Ability Bonuses:[/color] %s\n[color=#888888]Speed:[/color] %d ft.\n%s" % [bonus_str, speed, traits_text]


# =========================================================================
# Step 2: Class
# =========================================================================

func _select_class(cls: CharacterData.DndClass) -> void:
	selected_class = cls
	_refresh_class_step()


func _refresh_class_step() -> void:
	# Update button highlighting
	for i: int in range(_class_keys.size()):
		var is_selected: bool = (_class_keys[i] == selected_class)
		_update_selection_button(_class_buttons[i], is_selected)

	# Update description
	var cls_data: Dictionary = CharacterData.CLASS_DATA[selected_class]
	var cls_name: String = cls_data["name"]
	var cls_key: String = cls_name.to_lower()

	var desc: String = ""
	var saves_text: String = ""
	var hit_die_text: String = ""

	if _classes_json.has(cls_key):
		var json_data: Dictionary = _classes_json[cls_key]
		desc = json_data.get("description", "")

		var save_arr: Array = json_data.get("saving_throws", [])
		var save_names: Array[String] = []
		for s: Variant in save_arr:
			save_names.append(str(s).to_upper())
		saves_text = ", ".join(save_names)
	else:
		desc = cls_name

	hit_die_text = "d%d" % cls_data["hit_die"]

	# Primary ability
	var primary_idx: int = _ability_keys.find(cls_data["primary_ability"])
	var primary_name: String = _ability_names[primary_idx] if primary_idx >= 0 else "?"

	_class_desc_label.text = "[b]%s[/b]\n%s" % [cls_name, desc]
	_class_info_label.text = "[color=#888888]Hit Die:[/color] %s\n[color=#888888]Primary Ability:[/color] %s\n[color=#888888]Saving Throws:[/color] %s" % [hit_die_text, primary_name, saves_text]


# =========================================================================
# Step 3: Abilities
# =========================================================================

func _roll_abilities() -> void:
	for i: int in range(6):
		base_ability_scores[i] = Dice.keep_highest(4, 6, 3)


func _on_reroll_pressed() -> void:
	_roll_abilities()
	_refresh_ability_step()
	# Animate the scores
	for label: Label in _ability_score_labels:
		var tween := create_tween()
		label.modulate = Color(1.0, 1.0, 0.5, 1.0)
		tween.tween_property(label, "modulate", Color.WHITE, 0.3)
	for label: Label in _ability_total_labels:
		var tween := create_tween()
		label.modulate = Color(1.0, 1.0, 0.5, 1.0)
		tween.tween_property(label, "modulate", Color.WHITE, 0.3)


func _refresh_ability_step() -> void:
	var race_data: Dictionary = CharacterData.RACE_DATA[selected_race]
	var bonuses: Dictionary = race_data["ability_bonuses"]

	for i: int in range(6):
		var base: int = base_ability_scores[i]
		var ability: CharacterData.Ability = _ability_keys[i]
		var bonus: int = bonuses.get(ability, 0)
		var total: int = base + bonus

		_ability_score_labels[i].text = str(base)
		_ability_bonus_labels[i].text = "+%d" % bonus if bonus > 0 else "--"
		_ability_bonus_labels[i].add_theme_color_override(
			"font_color", BONUS_COLOR if bonus > 0 else DIM_TEXT_COLOR
		)
		_ability_total_labels[i].text = str(total)


# =========================================================================
# Step 4: Name & Confirm
# =========================================================================

const _RANDOM_NAMES: Array[String] = [
	"Aldric", "Brynn", "Cedric", "Durgan", "Elara", "Faelan",
	"Gwendolyn", "Haldir", "Isolde", "Jareth", "Keira", "Lothar",
	"Miriel", "Nerys", "Orin", "Perrin", "Quinn", "Rowan",
	"Seraphina", "Theron", "Una", "Valen", "Wren", "Xander",
	"Ysolde", "Zephyr", "Ashara", "Borin", "Caelum", "Dagny",
]


func _on_random_name_pressed() -> void:
	var idx: int = randi() % _RANDOM_NAMES.size()
	character_name = _RANDOM_NAMES[idx]
	_name_input.text = character_name
	_update_nav_buttons()


func _refresh_name_step() -> void:
	var race_data: Dictionary = CharacterData.RACE_DATA[selected_race]
	var cls_data: Dictionary = CharacterData.CLASS_DATA[selected_class]
	var bonuses: Dictionary = race_data["ability_bonuses"]

	var text: String = "[b]Character Summary[/b]\n"
	text += "[color=#888888]Race:[/color] %s\n" % race_data["name"]
	text += "[color=#888888]Class:[/color] %s\n" % cls_data["name"]
	text += "[color=#888888]Hit Die:[/color] d%d\n" % cls_data["hit_die"]
	text += "[color=#888888]Speed:[/color] %d ft.\n\n" % race_data["speed"]

	text += "[color=#888888]Ability Scores:[/color]\n"
	for i: int in range(6):
		var base: int = base_ability_scores[i]
		var ability: CharacterData.Ability = _ability_keys[i]
		var bonus: int = bonuses.get(ability, 0)
		var total: int = base + bonus
		var mod: int = CharacterData.ability_modifier(total)
		var mod_str: String = "+%d" % mod if mod >= 0 else str(mod)
		var bonus_str: String = " [color=#66cc66](+%d)[/color]" % bonus if bonus > 0 else ""
		text += "  %s: %d%s (%s)\n" % [_ability_names[i], total, bonus_str, mod_str]

	# HP calculation
	var con_ability: CharacterData.Ability = CharacterData.Ability.CONSTITUTION
	var con_total: int = base_ability_scores[2] + bonuses.get(con_ability, 0)
	var con_mod: int = CharacterData.ability_modifier(con_total)
	var hp: int = maxi(1, cls_data["hit_die"] + con_mod)
	text += "\n[color=#888888]Starting HP:[/color] %d" % hp

	_summary_label.text = text
	_update_nav_buttons()


# =========================================================================
# Confirmation
# =========================================================================

func _confirm_character() -> void:
	var data := CharacterData.new()
	data.character_name = character_name.strip_edges()
	data.race = selected_race
	data.dnd_class = selected_class
	data.level = 1
	data.experience_points = 0

	# Apply ability scores with racial bonuses
	var race_data: Dictionary = CharacterData.RACE_DATA[selected_race]
	var bonuses: Dictionary = race_data["ability_bonuses"]

	for i: int in range(6):
		var ability: CharacterData.Ability = _ability_keys[i]
		var total: int = base_ability_scores[i] + bonuses.get(ability, 0)
		data.set_ability_score(ability, total)

	# Set speed
	data.speed_feet = race_data["speed"]

	# Set HP from class hit die + CON modifier
	var cls_data: Dictionary = CharacterData.CLASS_DATA[selected_class]
	data.max_hp = maxi(1, cls_data["hit_die"] + data.get_modifier(CharacterData.Ability.CONSTITUTION))
	data.current_hp = data.max_hp
	data.hit_dice_remaining = 1

	# Set AC (no armor at start)
	data.base_ac = 10 + data.get_modifier(CharacterData.Ability.DEXTERITY)

	# Set saving throw proficiencies
	var save_abilities: Array = cls_data["saving_throws"]
	data.saving_throw_proficiencies.clear()
	for save_ability: CharacterData.Ability in save_abilities:
		data.saving_throw_proficiencies.append(save_ability)

	# Set armor proficiencies
	var armor_profs: Array = cls_data["armor_proficiencies"]
	data.armor_proficiencies.clear()
	for armor: CharacterData.ArmorCategory in armor_profs:
		data.armor_proficiencies.append(armor)

	character_created.emit(data)


# =========================================================================
# Helpers
# =========================================================================

func _update_selection_button(btn: Button, is_selected: bool) -> void:
	if is_selected:
		var style := StyleBoxFlat.new()
		style.bg_color = SELECTED_COLOR
		style.set_border_width_all(1)
		style.border_color = Color(0.4, 0.7, 0.4, 0.8)
		style.set_corner_radius_all(2)
		style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("normal", style)
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = SELECTED_HOVER
		hover_style.set_border_width_all(1)
		hover_style.border_color = Color(0.4, 0.7, 0.4, 0.8)
		hover_style.set_corner_radius_all(2)
		hover_style.set_content_margin_all(4)
		btn.add_theme_stylebox_override("hover", hover_style)
	else:
		btn.remove_theme_stylebox_override("normal")
		btn.remove_theme_stylebox_override("hover")
