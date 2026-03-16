class_name DeathScreen
extends Control

## Full-screen permadeath screen with sequential fade-in animations.
## Built entirely in code -- no .tscn needed.

# Colors matching the game's dark theme (from CharacterCreation / GameColors)
const BG_COLOR := Color(0.0, 0.0, 0.0, 0.0)  # starts transparent, fades in
const BG_TARGET := Color(0.0, 0.0, 0.0, 0.92)
const TITLE_COLOR := Color(0.827, 0.271, 0.286, 1.0)  # GameColors.RED
const EULOGY_COLOR := Color(0.85, 0.85, 0.86, 1.0)  # CharacterCreation TEXT_COLOR
const STAT_LABEL_COLOR := Color(0.5, 0.5, 0.55, 1.0)  # DIM_TEXT_COLOR
const STAT_VALUE_COLOR := Color(0.95, 0.85, 0.6, 1.0)  # CharacterCreation TITLE_COLOR
const SEPARATOR_COLOR := Color(0.827, 0.271, 0.286, 0.3)  # dim red
const BUTTON_COLOR := Color(0.12, 0.1, 0.15, 0.95)  # PANEL_COLOR
const BUTTON_BORDER := Color(0.3, 0.3, 0.35, 0.6)

const OVERLAY_FADE_DURATION := 1.5
const ELEMENT_FADE_DURATION := 0.8
const ELEMENT_STAGGER := 0.4

# UI elements for animation
var _bg_rect: ColorRect
var _title_label: Label
var _eulogy_label: Label
var _memorial_container: VBoxContainer
var _button_container: HBoxContainer


func _ready() -> void:
	# Block all input from passing through
	mouse_filter = MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	_build_ui()
	_animate_entrance()


func _build_ui() -> void:
	# --- Dark overlay background ---
	_bg_rect = ColorRect.new()
	_bg_rect.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_bg_rect.color = BG_COLOR
	_bg_rect.mouse_filter = MOUSE_FILTER_STOP
	add_child(_bg_rect)

	# --- Centering container ---
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	center.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(center)

	# --- Main vertical layout ---
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# --- Title: "YOU HAVE FALLEN" ---
	_title_label = Label.new()
	_title_label.text = "YOU HAVE FALLEN"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 32)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.modulate.a = 0.0
	_title_label.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_title_label)

	# --- Separator ---
	var sep1 := _make_separator()
	sep1.modulate.a = 0.0
	_title_label.set_meta("separator", sep1)
	vbox.add_child(sep1)

	# --- Eulogy text ---
	_eulogy_label = Label.new()
	_eulogy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_eulogy_label.add_theme_font_size_override("font_size", 16)
	_eulogy_label.add_theme_color_override("font_color", EULOGY_COLOR)
	_eulogy_label.modulate.a = 0.0
	_eulogy_label.mouse_filter = MOUSE_FILTER_IGNORE
	_eulogy_label.text = _build_eulogy_text()
	vbox.add_child(_eulogy_label)

	# --- Memorial stats ---
	_memorial_container = VBoxContainer.new()
	_memorial_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_memorial_container.add_theme_constant_override("separation", 4)
	_memorial_container.modulate.a = 0.0
	_memorial_container.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_memorial_container)

	_build_memorial_stats()

	# --- Separator ---
	var sep2 := _make_separator()
	sep2.modulate.a = 0.0
	_memorial_container.set_meta("separator", sep2)
	vbox.add_child(sep2)

	# --- Buttons ---
	_button_container = HBoxContainer.new()
	_button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_button_container.add_theme_constant_override("separation", 24)
	_button_container.modulate.a = 0.0
	_button_container.mouse_filter = MOUSE_FILTER_IGNORE
	vbox.add_child(_button_container)

	var new_adventure_btn := _make_button("New Adventure")
	new_adventure_btn.pressed.connect(_on_new_adventure)
	_button_container.add_child(new_adventure_btn)

	var quit_btn := _make_button("Quit")
	quit_btn.pressed.connect(_on_quit)
	_button_container.add_child(quit_btn)


func _build_eulogy_text() -> String:
	var player := World.player
	if not player:
		return "An unknown adventurer, lost to the depths."

	var char_name := ""
	var race_name := ""
	var class_name_str := ""

	if player.character_data:
		char_name = player.character_data.character_name
		race_name = player.character_data.get_race_name()
		class_name_str = player.character_data.get_class_name_str()
	else:
		char_name = player.name
		race_name = "Adventurer"
		class_name_str = ""

	if char_name.is_empty():
		char_name = "A nameless hero"

	var eulogy := "%s the %s" % [char_name, race_name]
	if not class_name_str.is_empty():
		eulogy += " " + class_name_str
	eulogy += ",\nslain on depth %d, turn %d." % [World.max_depth, World.current_turn]
	return eulogy


func _build_memorial_stats() -> void:
	# Header
	var header := Label.new()
	header.text = "- Memorial -"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 14)
	header.add_theme_color_override("font_color", STAT_LABEL_COLOR)
	header.mouse_filter = MOUSE_FILTER_IGNORE
	_memorial_container.add_child(header)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 4
	_memorial_container.add_child(spacer)

	# Stats grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.mouse_filter = MOUSE_FILTER_IGNORE
	_memorial_container.add_child(grid)

	var player := World.player
	if not player:
		return

	# HP
	_add_stat_row(grid, "Final HP:", "%d / %d" % [maxi(player.hp, 0), player.max_hp])

	# AC
	_add_stat_row(grid, "Armor Class:", str(player.get_armor_class()))

	# Level (from character data if available)
	if player.character_data:
		_add_stat_row(grid, "Level:", str(player.character_data.level))

	# Turns survived
	_add_stat_row(grid, "Turns Survived:", str(World.current_turn))

	# Max depth
	_add_stat_row(grid, "Deepest Depth:", str(World.max_depth))


func _add_stat_row(grid: GridContainer, label_text: String, value_text: String) -> void:
	var label := Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", STAT_LABEL_COLOR)
	label.custom_minimum_size.x = 120
	label.mouse_filter = MOUSE_FILTER_IGNORE
	grid.add_child(label)

	var value := Label.new()
	value.text = value_text
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	value.add_theme_font_size_override("font_size", 14)
	value.add_theme_color_override("font_color", STAT_VALUE_COLOR)
	value.custom_minimum_size.x = 80
	value.mouse_filter = MOUSE_FILTER_IGNORE
	grid.add_child(value)


func _make_separator() -> ColorRect:
	# Use a ColorRect instead because HSeparator is hard to style
	var sep := ColorRect.new()
	sep.color = SEPARATOR_COLOR
	sep.custom_minimum_size = Vector2(280, 1)
	sep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	sep.mouse_filter = MOUSE_FILTER_IGNORE
	return sep


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(140, 32)
	btn.add_theme_font_size_override("font_size", 14)

	# Style matching the dark theme
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = BUTTON_COLOR
	normal_style.border_color = BUTTON_BORDER
	normal_style.set_border_width_all(1)
	normal_style.set_corner_radius_all(2)
	normal_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", normal_style)

	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(0.18, 0.15, 0.22, 0.95)
	hover_style.border_color = TITLE_COLOR  # red highlight on hover
	hover_style.set_border_width_all(1)
	hover_style.set_corner_radius_all(2)
	hover_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("hover", hover_style)

	var pressed_style := StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.08, 0.06, 0.1, 0.95)
	pressed_style.border_color = TITLE_COLOR
	pressed_style.set_border_width_all(1)
	pressed_style.set_corner_radius_all(2)
	pressed_style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("pressed", pressed_style)

	return btn


func _animate_entrance() -> void:
	var tween := create_tween()

	# Phase 0: Background fade in
	tween.tween_property(_bg_rect, "color", BG_TARGET, OVERLAY_FADE_DURATION)\
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Phase 1: Title fades in
	tween.tween_property(_title_label, "modulate:a", 1.0, ELEMENT_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Also fade separator under title
	var sep1: Control = _title_label.get_meta("separator")
	tween.parallel().tween_property(sep1, "modulate:a", 1.0, ELEMENT_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)\
		.set_delay(ELEMENT_FADE_DURATION * 0.5)

	# Phase 2: Eulogy fades in
	tween.tween_property(_eulogy_label, "modulate:a", 1.0, ELEMENT_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)\
		.set_delay(ELEMENT_STAGGER)

	# Phase 3: Memorial stats fade in
	tween.tween_property(_memorial_container, "modulate:a", 1.0, ELEMENT_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)\
		.set_delay(ELEMENT_STAGGER)
	# Also fade separator under memorial
	var sep2: Control = _memorial_container.get_meta("separator")
	tween.parallel().tween_property(sep2, "modulate:a", 1.0, ELEMENT_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)\
		.set_delay(ELEMENT_FADE_DURATION * 0.5)

	# Phase 4: Buttons fade in
	tween.tween_property(_button_container, "modulate:a", 1.0, ELEMENT_FADE_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)\
		.set_delay(ELEMENT_STAGGER)


func _unhandled_input(event: InputEvent) -> void:
	# Only respond once buttons are visible (animation finished)
	if _button_container.modulate.a < 0.9:
		# Consume input to prevent game interaction during animation
		if event is InputEventKey or event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_new_adventure()
	elif event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_quit()


func _on_new_adventure() -> void:
	Modals.close_all_modals()
	get_tree().change_scene_to_file("res://scenes/menu/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
