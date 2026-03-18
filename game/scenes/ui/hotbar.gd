class_name Hotbar
extends HBoxContainer

## Hotbar with 6 action slots displayed at bottom-center of game viewport.
## Auto-populated from equipped weapons and class features.
## Keys 1-6 activate slots.

const MAX_SLOTS := 6

signal slot_activated(index: int)

var _slots: Array[PanelContainer] = []
var _slot_labels: Array[Label] = []
var _slot_key_labels: Array[Label] = []
var _slot_data: Array[Dictionary] = []  # [{name, available, type}]


func _ready() -> void:
	add_theme_constant_override("separation", 2)
	_build_slots()
	# Start hidden, shown when useful
	visible = false

	World.world_initialized.connect(_refresh)
	World.turn_ended.connect(_refresh)


func _build_slots() -> void:
	for i in MAX_SLOTS:
		var slot := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = UIColors.PANEL_BG_LIGHT
		style.border_color = UIColors.FRAME_GOLD
		style.set_border_width_all(1)
		style.content_margin_left = 2.0
		style.content_margin_right = 2.0
		style.content_margin_top = 1.0
		style.content_margin_bottom = 1.0
		slot.add_theme_stylebox_override("panel", style)
		slot.custom_minimum_size = Vector2(24, 20)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 0)
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_child(vbox)

		# Key label (1-6)
		var key_label := Label.new()
		key_label.text = str(i + 1)
		key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_label.add_theme_font_size_override("font_size", 16)
		key_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)
		vbox.add_child(key_label)

		# Action name label
		var name_label := Label.new()
		name_label.text = ""
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
		vbox.add_child(name_label)

		add_child(slot)
		_slots.append(slot)
		_slot_labels.append(name_label)
		_slot_key_labels.append(key_label)
		_slot_data.append({})


func _refresh() -> void:
	_slot_data.clear()
	_slot_data.resize(MAX_SLOTS)
	for i in MAX_SLOTS:
		_slot_data[i] = {}

	var player := World.player
	if not player:
		visible = false
		return

	var slot_idx := 0

	# Melee attack
	var melee := player.equipment.get_equipped_item(Equipment.Slot.MELEE)
	if melee and slot_idx < MAX_SLOTS:
		_slot_data[slot_idx] = {"name": "Melee", "available": true, "type": "attack"}
		slot_idx += 1

	# Ranged attack
	var ranged := player.equipment.get_equipped_item(Equipment.Slot.RANGED)
	if ranged and slot_idx < MAX_SLOTS:
		_slot_data[slot_idx] = {"name": "Ranged", "available": true, "type": "attack"}
		slot_idx += 1

	# Class features with uses
	if player.character_data:
		var cd := player.character_data
		for feature_name: String in cd.class_features:
			if slot_idx >= MAX_SLOTS:
				break
			var info: Dictionary = cd.class_features[feature_name]
			# Only show features that have limited uses (action economy)
			if info.max_uses > 0:
				var avail: bool = info.uses < info.max_uses
				_slot_data[slot_idx] = {"name": feature_name, "available": avail, "type": "feature"}
				slot_idx += 1

	# Update visual
	for i in MAX_SLOTS:
		var data: Dictionary = _slot_data[i]
		if data.is_empty():
			_slot_labels[i].text = ""
			_slots[i].modulate.a = 0.3
		else:
			_slot_labels[i].text = data.name.substr(0, 6)  # Truncate long names
			var available: bool = data.get("available", true)
			_slots[i].modulate.a = 1.0 if available else 0.4

	# Show hotbar in combat
	visible = World.game_mode.is_combat()


func activate_slot(index: int) -> void:
	if index < 0 or index >= MAX_SLOTS:
		return
	var data: Dictionary = _slot_data[index]
	if data.is_empty():
		return
	if not data.get("available", true):
		return
	slot_activated.emit(index)
