class_name DMPanel
extends PanelContainer

## The DM Panel displays narrative text, player choices, and free-text input.
## Built entirely in code since .tscn cannot be created directly.
## Connect to NarrativeManager signals to receive content updates.

signal choice_pressed(index: int)
signal text_submitted(text: String)

const PANEL_WIDTH := 156
const SCROLL_SPEED := 4.0

var _narrative_label: RichTextLabel
var _choices_container: VBoxContainer
var _input_field: LineEdit
var _header_label: Label
var _vbox: VBoxContainer
var _speaking_as: OptionButton
var _speaking_to: OptionButton
var _thinking_label: Label


func _ready() -> void:
	_build_ui()
	_connect_signals()
	# Small delay to ensure NarrativeManager is ready, then load existing history
	await get_tree().process_frame
	_load_existing_history()


func _build_ui() -> void:
	# Configure the panel container itself — sized by anchors/offsets in game.gd
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	size_flags_horizontal = Control.SIZE_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	# Panel style with gold left border
	add_theme_stylebox_override("panel", UIStyles.side_panel())

	# Main vertical layout — zero min width so panel respects anchor sizing
	_vbox = VBoxContainer.new()
	_vbox.custom_minimum_size = Vector2(0, 0)
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_theme_constant_override("separation", 4)
	add_child(_vbox)

	# -- Header --
	_header_label = Label.new()
	_header_label.text = "Dungeon Master"
	_header_label.clip_text = true
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_color_override("font_color", UIColors.TEXT_HEADER)
	_header_label.add_theme_font_size_override("font_size", 16)
	_vbox.add_child(_header_label)

	# Header separator
	var sep := UIStyles.h_separator(2)
	_vbox.add_child(sep)

	# -- Narrative text (uses RichTextLabel's built-in scrollbar) --
	_narrative_label = RichTextLabel.new()
	_narrative_label.bbcode_enabled = true
	_narrative_label.scroll_active = true
	_narrative_label.scroll_following = true
	_narrative_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_narrative_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_narrative_label.add_theme_color_override("default_color", UIColors.TEXT_PRIMARY)
	_narrative_label.add_theme_font_size_override("normal_font_size", 16)
	_narrative_label.add_theme_font_size_override("bold_font_size", 16)
	_narrative_label.add_theme_font_size_override("italics_font_size", 16)
	_narrative_label.add_theme_font_size_override("bold_italics_font_size", 16)
	_narrative_label.add_theme_constant_override("line_separation", 2)
	_narrative_label.text = ""
	_vbox.add_child(_narrative_label)

	# -- Thinking indicator (hidden by default) --
	_thinking_label = Label.new()
	_thinking_label.text = "The DM ponders..."
	_thinking_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_thinking_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	_thinking_label.add_theme_font_size_override("font_size", 14)
	_thinking_label.visible = false
	_vbox.add_child(_thinking_label)

	# -- Choices container --
	_choices_container = VBoxContainer.new()
	_choices_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_container.add_theme_constant_override("separation", 3)
	_vbox.add_child(_choices_container)

	# Separator before input
	var input_sep := UIStyles.h_separator(2)
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
	_speaking_as.clip_text = true
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
	_speaking_to.clip_text = true
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
	UIStyles.apply_input_styles(_input_field)

	_input_field.text_submitted.connect(_on_text_submitted)
	_vbox.add_child(_input_field)


func _connect_signals() -> void:
	if not NarrativeManager:
		Log.w("NarrativeManager autoload not available")
		return

	NarrativeManager.narrative_added.connect(_on_narrative_added)
	NarrativeManager.choices_presented.connect(_on_choices_presented)
	NarrativeManager.narrative_cleared.connect(_on_narrative_cleared)

	# Connect to orchestrator thinking signals
	var oc: Node = Engine.get_main_loop().root.get_node_or_null("/root/OrchestratorClient")
	if oc:
		if oc.has_signal("thinking_started"):
			oc.thinking_started.connect(_on_thinking_started)
		if oc.has_signal("thinking_finished"):
			oc.thinking_finished.connect(_on_thinking_finished)

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
		button.clip_text = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 16)
		# Style the choice buttons
		UIStyles.apply_choice_button_styles(button)

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
	_narrative_label.scroll_to_line(_narrative_label.get_line_count() - 1)


func _on_turn_ended_refresh() -> void:
	_refresh_target_options()


func _on_map_changed_refresh(_map: Map) -> void:
	_refresh_speaker_options()
	_refresh_target_options()


func _on_thinking_started() -> void:
	_thinking_label.visible = true


func _on_thinking_finished() -> void:
	_thinking_label.visible = false


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
