class_name DMPanel
extends PanelContainer

## The DM Panel displays narrative text, player choices, and free-text input.
## Built entirely in code since .tscn cannot be created directly.
## Connect to NarrativeManager signals to receive content updates.

signal choice_pressed(index: int)
signal text_submitted(text: String)

const PANEL_WIDTH := 192
const SCROLL_SPEED := 4.0

## Colors matching the game's dark pixel art theme
const BG_COLOR := Color(0.06, 0.05, 0.08, 0.92)
const BORDER_COLOR := Color(0.2, 0.19, 0.2, 1.0)
const HEADER_COLOR := Color(0.42, 0.76, 0.80)  # Cyan-ish, matches GameColors.CYAN
const TEXT_COLOR := Color(0.85, 0.85, 0.86)
const CHOICE_BG_NORMAL := Color(0.15, 0.14, 0.18, 0.8)
const CHOICE_BG_HOVER := Color(0.25, 0.24, 0.30, 0.9)
const CHOICE_BG_PRESSED := Color(0.10, 0.10, 0.14, 0.9)
const CHOICE_TEXT_COLOR := Color(0.86, 0.84, 0.37)  # Yellow-ish, matches GameColors.YELLOW
const INPUT_BG_COLOR := Color(0.08, 0.07, 0.10, 0.9)
const INPUT_BORDER_COLOR := Color(0.30, 0.29, 0.32, 0.6)
const SEPARATOR_COLOR := Color(0.2, 0.19, 0.2, 0.5)

var _scroll_container: ScrollContainer
var _narrative_label: RichTextLabel
var _choices_container: VBoxContainer
var _input_field: LineEdit
var _header_label: Label
var _vbox: VBoxContainer


func _ready() -> void:
	_build_ui()
	_connect_signals()
	# Small delay to ensure NarrativeManager is ready, then load existing history
	await get_tree().process_frame
	_load_existing_history()


func _build_ui() -> void:
	# Configure the panel container itself
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Create a dark StyleBoxFlat for the panel background
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = BG_COLOR
	panel_style.border_color = BORDER_COLOR
	panel_style.border_width_left = 2
	panel_style.border_width_top = 0
	panel_style.border_width_right = 0
	panel_style.border_width_bottom = 0
	panel_style.content_margin_left = 6.0
	panel_style.content_margin_top = 4.0
	panel_style.content_margin_right = 6.0
	panel_style.content_margin_bottom = 4.0
	add_theme_stylebox_override("panel", panel_style)

	# Main vertical layout
	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	# -- Header --
	_header_label = Label.new()
	_header_label.text = "DM"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", HEADER_COLOR)
	_header_label.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(_header_label)

	# Header separator
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = SEPARATOR_COLOR
	sep_style.thickness = 1
	sep.add_theme_stylebox_override("separator", sep_style)
	sep.add_theme_constant_override("separation", 2)
	_vbox.add_child(sep)

	# -- Scroll container for narrative text --
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER

	# Style the scrollbar to match the game theme
	var scroll_style := StyleBoxFlat.new()
	scroll_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_scroll_container.add_theme_stylebox_override("panel", scroll_style)
	_vbox.add_child(_scroll_container)

	# Narrative rich text label inside scroll container
	_narrative_label = RichTextLabel.new()
	_narrative_label.bbcode_enabled = true
	_narrative_label.fit_content = true
	_narrative_label.scroll_active = false
	_narrative_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_narrative_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_narrative_label.add_theme_color_override("default_color", TEXT_COLOR)
	_narrative_label.add_theme_font_size_override("normal_font_size", 14)
	_narrative_label.add_theme_font_size_override("bold_font_size", 14)
	_narrative_label.add_theme_font_size_override("italics_font_size", 14)
	_narrative_label.add_theme_font_size_override("bold_italics_font_size", 14)
	_narrative_label.add_theme_constant_override("line_separation", 1)
	_narrative_label.text = ""
	_scroll_container.add_child(_narrative_label)

	# -- Choices container --
	_choices_container = VBoxContainer.new()
	_choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_container.add_theme_constant_override("separation", 2)
	_vbox.add_child(_choices_container)

	# Separator before input
	var input_sep := HSeparator.new()
	var input_sep_style := StyleBoxLine.new()
	input_sep_style.color = SEPARATOR_COLOR
	input_sep_style.thickness = 1
	input_sep.add_theme_stylebox_override("separator", input_sep_style)
	input_sep.add_theme_constant_override("separation", 2)
	_vbox.add_child(input_sep)

	# -- Free-text input --
	_input_field = LineEdit.new()
	_input_field.placeholder_text = "Say something..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.add_theme_font_size_override("font_size", 14)
	_input_field.add_theme_color_override("font_color", TEXT_COLOR)
	_input_field.add_theme_color_override("font_placeholder_color", Color(0.45, 0.44, 0.42, 0.6))

	# Style the input field background
	var input_normal := StyleBoxFlat.new()
	input_normal.bg_color = INPUT_BG_COLOR
	input_normal.border_color = INPUT_BORDER_COLOR
	input_normal.border_width_bottom = 1
	input_normal.content_margin_left = 4.0
	input_normal.content_margin_right = 4.0
	input_normal.content_margin_top = 2.0
	input_normal.content_margin_bottom = 2.0
	_input_field.add_theme_stylebox_override("normal", input_normal)

	var input_focus := StyleBoxFlat.new()
	input_focus.bg_color = INPUT_BG_COLOR
	input_focus.border_color = HEADER_COLOR
	input_focus.border_width_bottom = 1
	input_focus.content_margin_left = 4.0
	input_focus.content_margin_right = 4.0
	input_focus.content_margin_top = 2.0
	input_focus.content_margin_bottom = 2.0
	_input_field.add_theme_stylebox_override("focus", input_focus)

	_input_field.text_submitted.connect(_on_text_submitted)
	_vbox.add_child(_input_field)


func _connect_signals() -> void:
	if not NarrativeManager:
		Log.w("NarrativeManager autoload not available")
		return

	NarrativeManager.narrative_added.connect(_on_narrative_added)
	NarrativeManager.choices_presented.connect(_on_choices_presented)
	NarrativeManager.narrative_cleared.connect(_on_narrative_cleared)


## Load any narrative history that was added before the panel was ready.
func _load_existing_history() -> void:
	if not NarrativeManager:
		return

	var history := NarrativeManager.get_history()
	for entry: String in history:
		_append_narrative_text(entry)

	# If there are pending choices, show them
	if NarrativeManager.is_awaiting_choice():
		# The last queue entry should have the choices
		var queue := NarrativeManager._queue
		for i in range(queue.size() - 1, -1, -1):
			if queue[i].choices.size() > 0:
				var typed_choices: Array[String] = []
				typed_choices.assign(queue[i].choices)
				_on_choices_presented(typed_choices)
				break

	_scroll_to_bottom()


func _on_narrative_added(text: String) -> void:
	_append_narrative_text(text)
	_scroll_to_bottom()


func _append_narrative_text(text: String) -> void:
	if _narrative_label.text.length() > 0:
		_narrative_label.text += "\n\n"
	_narrative_label.text += text


func _on_choices_presented(choices: Array[String]) -> void:
	_clear_choices()

	for i: int in range(choices.size()):
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, choices[i]]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", CHOICE_TEXT_COLOR)
		button.add_theme_color_override("font_hover_color", Color(1.0, 1.0, 0.8))
		button.add_theme_color_override("font_pressed_color", Color(0.7, 0.68, 0.3))

		# Style the choice buttons
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = CHOICE_BG_NORMAL
		btn_normal.content_margin_left = 4.0
		btn_normal.content_margin_right = 4.0
		btn_normal.content_margin_top = 2.0
		btn_normal.content_margin_bottom = 2.0
		button.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = CHOICE_BG_HOVER
		btn_hover.content_margin_left = 4.0
		btn_hover.content_margin_right = 4.0
		btn_hover.content_margin_top = 2.0
		btn_hover.content_margin_bottom = 2.0
		button.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = CHOICE_BG_PRESSED
		btn_pressed.content_margin_left = 4.0
		btn_pressed.content_margin_right = 4.0
		btn_pressed.content_margin_top = 2.0
		btn_pressed.content_margin_bottom = 2.0
		button.add_theme_stylebox_override("pressed", btn_pressed)

		var btn_focus := StyleBoxEmpty.new()
		button.add_theme_stylebox_override("focus", btn_focus)

		var choice_index := i
		button.pressed.connect(func() -> void: _on_choice_pressed(choice_index))
		_choices_container.add_child(button)


func _on_choice_pressed(index: int) -> void:
	choice_pressed.emit(index)
	_clear_choices()

	if NarrativeManager:
		NarrativeManager.select_choice(index)


func _clear_choices() -> void:
	for child in _choices_container.get_children():
		child.queue_free()


func _on_text_submitted(text: String) -> void:
	if text.strip_edges().is_empty():
		return

	_input_field.text = ""
	text_submitted.emit(text)

	if NarrativeManager:
		NarrativeManager.submit_input(text)


func _on_narrative_cleared() -> void:
	_narrative_label.text = ""
	_clear_choices()


func _scroll_to_bottom() -> void:
	# Wait a frame for layout to update, then scroll to the bottom
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)
