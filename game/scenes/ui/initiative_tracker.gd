class_name InitiativeTracker
extends PanelContainer

## Displays the turn order during D&D 5e combat mode.
## Shows initiative values, names, and highlights the active combatant.

var _entries_container: VBoxContainer
var _header_label: Label
var _entry_labels: Array[RichTextLabel] = []


func _ready() -> void:
	# Build UI
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(0.3, 0.3, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	_header_label = Label.new()
	_header_label.text = "Initiative"
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.add_theme_font_size_override("font_size", 8)
	_header_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.6))
	vbox.add_child(_header_label)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 2)
	vbox.add_child(sep)

	_entries_container = VBoxContainer.new()
	_entries_container.add_theme_constant_override("separation", 1)
	vbox.add_child(_entries_container)

	# Start hidden
	visible = false


func update_turn_order(combatants: Array[CombatState], active_index: int) -> void:
	# Clear existing entries
	for label in _entry_labels:
		label.queue_free()
	_entry_labels.clear()

	for i in combatants.size():
		var cs := combatants[i]
		var label := RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		label.scroll_active = false
		label.add_theme_font_size_override("normal_font_size", 7)

		var name_text := cs.combatant.get_name(Monster.NameFormat.PLAIN)
		var init_text := str(cs.initiative)
		var hp_text := "%d/%d" % [cs.combatant.hp, cs.combatant.max_hp]

		var is_active := i == active_index
		var is_player := cs.combatant == World.player
		var is_dead := cs.combatant.is_dead

		if is_dead:
			label.text = "[color=gray][s]%s %s[/s][/color]" % [init_text, name_text]
		elif is_active:
			var color := "lime" if is_player else "red"
			label.text = "[color=%s]> %s %s (%s)[/color]" % [color, init_text, name_text, hp_text]
		elif is_player:
			label.text = "[color=cyan]  %s %s (%s)[/color]" % [init_text, name_text, hp_text]
		else:
			label.text = "[color=white]  %s %s (%s)[/color]" % [init_text, name_text, hp_text]

		if cs.is_surprised:
			label.text += " [color=yellow][Surprised][/color]"

		# Show action economy for the active combatant
		if is_active and not is_dead:
			var action_info := _get_action_economy_text(cs)
			if not action_info.is_empty():
				label.text += "\n    " + action_info

		_entries_container.add_child(label)
		_entry_labels.append(label)

	_header_label.text = "Initiative (Round %d)" % maxi(1, _get_round_from_combatants(combatants))


func show_tracker() -> void:
	visible = true


func hide_tracker() -> void:
	visible = false


func _get_round_from_combatants(_combatants: Array[CombatState]) -> int:
	return World.game_mode.combat_round


func _get_action_economy_text(cs: CombatState) -> String:
	var parts: Array[String] = []
	if cs.movement_remaining > 0:
		parts.append("[color=cyan]Mv:%d[/color]" % cs.movement_remaining)
	if cs.has_action:
		parts.append("[color=lime]Act[/color]")
	if cs.has_bonus_action:
		parts.append("[color=yellow]Bon[/color]")
	if cs.has_reaction:
		parts.append("[color=orange]Rea[/color]")
	if parts.is_empty():
		return "[color=gray]No actions (Space=end)[/color]"
	return " ".join(parts) + " [color=gray](Space=end)[/color]"
