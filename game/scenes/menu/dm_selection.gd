class_name DMSelection
extends Control

## DM Archetype selection screen. Builds UI entirely in code (same pattern as CharacterCreation).

signal archetype_selected(archetype_id: int)
signal cancel

# --- Archetype enum ---
enum Archetype { STORYTELLER, TASKMASTER, TRICKSTER, HISTORIAN, GUIDE }

# --- Archetype data ---
const ARCHETYPE_DATA: Array[Dictionary] = [
	{
		"id": Archetype.STORYTELLER,
		"name": "The Storyteller",
		"icon": "~",
		"flavor": "Every dungeon has a tale to tell, every monster a motive, every treasure a history. The Storyteller weaves your adventure into an epic saga where your choices echo through the narrative.",
		"effect": "Rich narrative descriptions, dramatic moments, character-focused encounters. NPCs have deeper personalities and conversations carry more weight.",
	},
	{
		"id": Archetype.TASKMASTER,
		"name": "The Taskmaster",
		"icon": "!",
		"flavor": "Fair but unforgiving. The Taskmaster respects cunning and punishes carelessness. Every room is a puzzle, every encounter a test of your tactical mind.",
		"effect": "Tactical challenges with higher stakes. Enemies use smarter strategies. Rewards clever positioning, resource management, and creative problem-solving.",
	},
	{
		"id": Archetype.TRICKSTER,
		"name": "The Trickster",
		"icon": "?",
		"flavor": "Nothing is as it seems. The Trickster delights in surprises — a treasure chest that bites back, a friendly NPC with a hidden agenda, a shortcut that leads somewhere unexpected.",
		"effect": "More traps, hidden secrets, and unexpected twists. Mimics, illusions, and misdirection are common. Exploration is richly rewarded for the observant.",
	},
	{
		"id": Archetype.HISTORIAN,
		"name": "The Historian",
		"icon": "#",
		"flavor": "These ruins were not always ruins. The Historian remembers what came before — the kingdoms that fell, the wars that scarred the land, the ancient pacts that still bind.",
		"effect": "Deep lore and world-building. Inscriptions, journals, and environmental storytelling connect events to a larger history. Knowledge checks reveal hidden context.",
	},
	{
		"id": Archetype.GUIDE,
		"name": "The Guide",
		"icon": "*",
		"flavor": "A patient hand in the darkness. The Guide ensures no adventurer is lost, offering gentle nudges toward the right path without stealing the thrill of discovery.",
		"effect": "Helpful hints when you're stuck, explains mechanics clearly, and provides context for decisions. Ideal for newcomers to dungeon crawling or D&D.",
	},
]

# --- Colors (matching CharacterCreation) ---
const BG_COLOR := Color(0.078, 0.047, 0.11, 1.0)
const PANEL_COLOR := Color(0.12, 0.1, 0.15, 0.95)
const ACCENT_COLOR := Color(0.35, 0.55, 0.85, 1.0)
const ACCENT_HOVER := Color(0.45, 0.65, 0.95, 1.0)
const SELECTED_COLOR := Color(0.25, 0.5, 0.3, 1.0)
const SELECTED_HOVER := Color(0.3, 0.6, 0.35, 1.0)
const TEXT_COLOR := Color(0.85, 0.85, 0.86, 1.0)
const DIM_TEXT_COLOR := Color(0.5, 0.5, 0.55, 1.0)
const TITLE_COLOR := Color(0.95, 0.85, 0.6, 1.0)

# --- State ---
var selected_archetype: int = Archetype.STORYTELLER

# --- UI References ---
var _root_panel: PanelContainer
var _title_label: Label
var _archetype_buttons: Array[Button] = []
var _desc_name_label: Label
var _desc_icon_label: Label
var _desc_flavor_label: RichTextLabel
var _desc_effect_label: RichTextLabel
var _confirm_button: Button
var _back_button: Button
var _content_container: Control


func _ready() -> void:
	_build_ui()
	_select_archetype(Archetype.STORYTELLER)


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
	_root_panel.custom_minimum_size = Vector2(560, 320)
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

	# Header
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 2)
	vbox.add_child(header)

	var subtitle := Label.new()
	subtitle.text = "Shape Your Adventure"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	subtitle.add_theme_font_size_override("font_size", 12)
	header.add_child(subtitle)

	_title_label = Label.new()
	_title_label.text = "Choose Your Dungeon Master"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_title_label.add_theme_font_size_override("font_size", 20)
	header.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Content area: left (buttons) + right (description)
	_content_container = HBoxContainer.new()
	(_content_container as HBoxContainer).add_theme_constant_override("separation", 10)
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_content_container)

	# --- Left: archetype button list ---
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	left.custom_minimum_size.x = 160
	_content_container.add_child(left)

	var list_label := Label.new()
	list_label.text = "Archetypes"
	list_label.add_theme_color_override("font_color", DIM_TEXT_COLOR)
	list_label.add_theme_font_size_override("font_size", 12)
	left.add_child(list_label)

	_archetype_buttons.clear()
	for i: int in range(ARCHETYPE_DATA.size()):
		var data: Dictionary = ARCHETYPE_DATA[i]
		var btn := Button.new()
		btn.text = "%s  %s" % [data["icon"], data["name"]]
		btn.custom_minimum_size = Vector2(150, 30)
		btn.add_theme_font_size_override("font_size", 13)
		var captured_id: int = data["id"]
		btn.pressed.connect(func() -> void: _select_archetype(captured_id))
		left.add_child(btn)
		_archetype_buttons.append(btn)

	# --- Right: description panel ---
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 6)
	_content_container.add_child(right)

	# Archetype name + icon row
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	right.add_child(name_row)

	_desc_icon_label = Label.new()
	_desc_icon_label.add_theme_color_override("font_color", TITLE_COLOR)
	_desc_icon_label.add_theme_font_size_override("font_size", 22)
	name_row.add_child(_desc_icon_label)

	_desc_name_label = Label.new()
	_desc_name_label.add_theme_color_override("font_color", TEXT_COLOR)
	_desc_name_label.add_theme_font_size_override("font_size", 16)
	name_row.add_child(_desc_name_label)

	# Flavor text
	_desc_flavor_label = RichTextLabel.new()
	_desc_flavor_label.bbcode_enabled = true
	_desc_flavor_label.fit_content = true
	_desc_flavor_label.scroll_active = false
	_desc_flavor_label.add_theme_font_size_override("normal_font_size", 13)
	_desc_flavor_label.add_theme_font_size_override("italics_font_size", 13)
	right.add_child(_desc_flavor_label)

	# Gameplay effect
	_desc_effect_label = RichTextLabel.new()
	_desc_effect_label.bbcode_enabled = true
	_desc_effect_label.fit_content = true
	_desc_effect_label.scroll_active = false
	_desc_effect_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_desc_effect_label.add_theme_font_size_override("normal_font_size", 12)
	right.add_child(_desc_effect_label)

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

	_confirm_button = _make_nav_button("Confirm")
	_confirm_button.pressed.connect(_on_confirm_pressed)
	nav_bar.add_child(_confirm_button)


func _make_nav_button(label_text: String) -> Button:
	var btn := Button.new()
	btn.text = label_text
	btn.custom_minimum_size = Vector2(100, 28)
	return btn


# =========================================================================
# Selection
# =========================================================================

func _select_archetype(id: int) -> void:
	selected_archetype = id
	_refresh_display()


func _refresh_display() -> void:
	# Update button highlighting
	for i: int in range(_archetype_buttons.size()):
		var is_selected: bool = (ARCHETYPE_DATA[i]["id"] == selected_archetype)
		_update_selection_button(_archetype_buttons[i], is_selected)

	# Update description panel
	var data: Dictionary = ARCHETYPE_DATA[selected_archetype]
	_desc_icon_label.text = data["icon"]
	_desc_name_label.text = data["name"]
	_desc_flavor_label.text = "[i]%s[/i]" % data["flavor"]
	_desc_effect_label.text = "[color=#888888]Gameplay Effect:[/color]\n%s" % data["effect"]

	# Animate the description in
	_animate_description()


func _animate_description() -> void:
	_desc_flavor_label.modulate.a = 0.0
	_desc_effect_label.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_desc_flavor_label, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_desc_effect_label, "modulate:a", 1.0, 0.25).set_ease(Tween.EASE_OUT).set_delay(0.05)


# =========================================================================
# Navigation
# =========================================================================

func _on_back_pressed() -> void:
	cancel.emit()


func _on_confirm_pressed() -> void:
	archetype_selected.emit(selected_archetype)


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
