class_name DMPanel
extends PanelContainer

## The DM Panel displays narrative text, player choices, and free-text input.
## Built entirely in code since .tscn cannot be created directly.
## Connect to NarrativeManager signals to receive content updates.

signal choice_pressed(index: int)
signal text_submitted(text: String)

const PANEL_WIDTH := 156
const SCROLL_SPEED := 4.0

var _scroll_container: ScrollContainer
var _narrative_label: RichTextLabel
var _choices_container: VBoxContainer
var _input_field: LineEdit
var _header_label: Label
var _vbox: VBoxContainer
var _speaking_as: OptionButton
var _speaking_to: OptionButton


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

	# Panel style with gold left border
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = UIColors.PANEL_BG
	panel_style.border_color = UIColors.FRAME_GOLD
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
	_header_label.text = "Dungeon Master"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", UIColors.TEXT_HEADER)
	_header_label.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(_header_label)

	# Header separator
	var sep := HSeparator.new()
	var sep_style := StyleBoxLine.new()
	sep_style.color = UIColors.SEPARATOR
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
	_narrative_label.add_theme_color_override("default_color", UIColors.TEXT_PRIMARY)
	_narrative_label.add_theme_font_size_override("normal_font_size", 16)
	_narrative_label.add_theme_font_size_override("bold_font_size", 16)
	_narrative_label.add_theme_font_size_override("italics_font_size", 16)
	_narrative_label.add_theme_font_size_override("bold_italics_font_size", 16)
	_narrative_label.add_theme_constant_override("line_separation", 2)
	_narrative_label.text = ""
	_scroll_container.add_child(_narrative_label)

	# -- Choices container --
	_choices_container = VBoxContainer.new()
	_choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_container.add_theme_constant_override("separation", 3)
	_vbox.add_child(_choices_container)

	# Separator before input
	var input_sep := HSeparator.new()
	var input_sep_style := StyleBoxLine.new()
	input_sep_style.color = UIColors.SEPARATOR
	input_sep_style.thickness = 1
	input_sep.add_theme_stylebox_override("separator", input_sep_style)
	input_sep.add_theme_constant_override("separation", 2)
	_vbox.add_child(input_sep)

	# -- Speaker selectors --
	var speaker_row := HBoxContainer.new()
	speaker_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_row.add_theme_constant_override("separation", 4)
	_vbox.add_child(speaker_row)

	var as_label := Label.new()
	as_label.text = "As:"
	as_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	as_label.add_theme_font_size_override("font_size", 14)
	speaker_row.add_child(as_label)

	_speaking_as = OptionButton.new()
	_speaking_as.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaking_as.add_theme_font_size_override("font_size", 14)
	_speaking_as.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_speaking_as.flat = true
	speaker_row.add_child(_speaking_as)

	var to_label := Label.new()
	to_label.text = "To:"
	to_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	to_label.add_theme_font_size_override("font_size", 14)
	speaker_row.add_child(to_label)

	_speaking_to = OptionButton.new()
	_speaking_to.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_speaking_to.add_theme_font_size_override("font_size", 14)
	_speaking_to.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_speaking_to.flat = true
	speaker_row.add_child(_speaking_to)

	_refresh_speaker_options()
	_refresh_target_options()

	# -- Free-text input --
	_input_field = LineEdit.new()
	_input_field.focus_mode = Control.FOCUS_CLICK  # Never auto-grab keyboard focus
	_input_field.placeholder_text = "Say something..."
	_input_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_field.add_theme_font_size_override("font_size", 16)
	_input_field.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	_input_field.add_theme_color_override("font_placeholder_color", UIColors.TEXT_DIM)

	# Style the input field background
	var input_normal := StyleBoxFlat.new()
	input_normal.bg_color = UIColors.INPUT_BG
	input_normal.border_color = UIColors.INPUT_BORDER
	input_normal.border_width_bottom = 1
	input_normal.content_margin_left = 4.0
	input_normal.content_margin_right = 4.0
	input_normal.content_margin_top = 2.0
	input_normal.content_margin_bottom = 2.0
	_input_field.add_theme_stylebox_override("normal", input_normal)

	var input_focus := StyleBoxFlat.new()
	input_focus.bg_color = UIColors.INPUT_BG
	input_focus.border_color = UIColors.FRAME_GOLD
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

	# Refresh dropdowns when the world state changes
	World.turn_ended.connect(_on_turn_ended_refresh)
	World.map_changed.connect(_on_map_changed_refresh)


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
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_color", UIColors.CHOICE_TEXT)
		button.add_theme_color_override("font_hover_color", UIColors.CHOICE_HOVER_TEXT)
		button.add_theme_color_override("font_pressed_color", UIColors.CHOICE_PRESSED_TEXT)

		# Style the choice buttons
		var btn_normal := StyleBoxFlat.new()
		btn_normal.bg_color = UIColors.BUTTON_BG
		btn_normal.content_margin_left = 4.0
		btn_normal.content_margin_right = 4.0
		btn_normal.content_margin_top = 2.0
		btn_normal.content_margin_bottom = 2.0
		button.add_theme_stylebox_override("normal", btn_normal)

		var btn_hover := StyleBoxFlat.new()
		btn_hover.bg_color = UIColors.BUTTON_HOVER
		btn_hover.content_margin_left = 4.0
		btn_hover.content_margin_right = 4.0
		btn_hover.content_margin_top = 2.0
		btn_hover.content_margin_bottom = 2.0
		button.add_theme_stylebox_override("hover", btn_hover)

		var btn_pressed := StyleBoxFlat.new()
		btn_pressed.bg_color = UIColors.BUTTON_PRESSED
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

	# Prepend speaker context if a non-player companion is selected
	var submitted_text := text
	var speaker_idx := _speaking_as.selected
	if speaker_idx > 0:
		var speaker_name := _speaking_as.get_item_text(speaker_idx)
		submitted_text = "[Speaking as: %s] %s" % [speaker_name, text]

	var target_idx := _speaking_to.selected
	if target_idx > 0:
		var target_name := _speaking_to.get_item_text(target_idx)
		submitted_text = "[Speaking to: %s] %s" % [target_name, submitted_text]

	text_submitted.emit(submitted_text)

	if NarrativeManager:
		NarrativeManager.submit_input(submitted_text)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _input_field.has_focus():
			_input_field.release_focus()
			get_viewport().set_input_as_handled()


func _on_narrative_cleared() -> void:
	_narrative_label.text = ""
	_clear_choices()


func _scroll_to_bottom() -> void:
	# Wait a frame for layout to update, then scroll to the bottom
	await get_tree().process_frame
	_scroll_container.scroll_vertical = int(_scroll_container.get_v_scroll_bar().max_value)


func _on_turn_ended_refresh() -> void:
	_refresh_target_options()


func _on_map_changed_refresh(_map: Map) -> void:
	_refresh_speaker_options()
	_refresh_target_options()


## Populate "Speaking as" with the player name + all companion names.
func _refresh_speaker_options() -> void:
	_speaking_as.clear()

	# Index 0 = the player (default)
	var player_name := "Player"
	if World.player:
		player_name = World.player.name
	_speaking_as.add_item(player_name)

	# Add party companions
	for member: Monster in World.party.members:
		_speaking_as.add_item(member.name)

	_speaking_as.selected = 0


## Populate "Speaking to" with nearby visible non-party monsters.
func _refresh_target_options() -> void:
	_speaking_to.clear()

	# Index 0 = nobody in particular (DM / general)
	_speaking_to.add_item("(anyone)")

	if not World.current_map:
		return

	# List visible non-party monsters
	var visible := World.current_map.get_visible_monsters()
	for monster: Monster in visible:
		if World.party.is_party_member(monster):
			continue
		_speaking_to.add_item(monster.name)

	_speaking_to.selected = 0
