class_name PartyBar
extends VBoxContainer

## Compact party portrait bar showing all party members with HP bars.
## Placed in the HUD's left panel, replaces the single-character name + HP display.

const SLOT_HEIGHT := 20
const ICON_SIZE := Vector2(16, 16)
const HP_BAR_HEIGHT := 4

var _slots: Array[PanelContainer] = []
var _active_tween: Tween


func _ready() -> void:
	add_theme_constant_override("separation", 1)
	World.world_initialized.connect(_rebuild)
	World.turn_ended.connect(_rebuild)
	World.game_mode.active_combatant_changed.connect(_on_active_changed)


func _rebuild() -> void:
	_clear()
	var members := World.party.get_all_members()
	for member: Monster in members:
		var slot := _build_slot(member)
		add_child(slot)
		_slots.append(slot)
	_highlight_active()


func _on_active_changed(_cs: CombatState) -> void:
	_highlight_active()
	# Also refresh HP values since combat state changed
	_refresh_hp_bars()


func _highlight_active() -> void:
	# Kill any existing pulsing tween
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null

	var active_monster: Monster = World.active_character
	for i in _slots.size():
		var slot := _slots[i]
		var member: Monster = slot.get_meta("member")
		var is_active := member == active_monster
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel").duplicate()

		if is_active:
			style.border_color = UIColors.FRAME_GOLD
			style.set_border_width_all(1)
			slot.add_theme_stylebox_override("panel", style)
			# Pulse effect in combat
			if World.game_mode.is_combat():
				_active_tween = create_tween().set_loops()
				_active_tween.tween_property(slot, "modulate", Color(1.2, 1.1, 0.9), 0.5)
				_active_tween.tween_property(slot, "modulate", Color.WHITE, 0.5)
		else:
			style.border_color = UIColors.FRAME_DARK
			style.set_border_width_all(1)
			slot.add_theme_stylebox_override("panel", style)
			slot.modulate = Color.WHITE


func _refresh_hp_bars() -> void:
	for slot in _slots:
		var member: Monster = slot.get_meta("member")
		var bar: ColorRect = slot.get_meta("hp_fill")
		var bar_bg: ColorRect = slot.get_meta("hp_bg")
		_update_hp_bar(bar, bar_bg, member)


func _build_slot(member: Monster) -> PanelContainer:
	var slot := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIColors.PANEL_BG
	style.border_color = UIColors.FRAME_DARK
	style.set_border_width_all(1)
	style.content_margin_left = 2.0
	style.content_margin_right = 2.0
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	slot.add_theme_stylebox_override("panel", style)
	slot.set_meta("member", member)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 1)
	slot.add_child(vbox)

	# Top row: icon + name
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 2)
	vbox.add_child(top_row)

	# Character icon
	var icon := TextureRect.new()
	icon.custom_minimum_size = ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = _get_portrait_texture(member)
	top_row.add_child(icon)

	# Name label
	var name_label := Label.new()
	name_label.text = _get_display_name(member)
	name_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	name_label.clip_text = true
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if member.is_dead:
		name_label.add_theme_color_override("font_color", UIColors.COMBAT_DEAD)
	else:
		name_label.add_theme_color_override("font_color", UIColors.TEXT_PRIMARY)
	top_row.add_child(name_label)

	# HP bar background
	var hp_bg := ColorRect.new()
	hp_bg.custom_minimum_size = Vector2(0, HP_BAR_HEIGHT)
	hp_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.color = Color(0.15, 0.12, 0.08)
	vbox.add_child(hp_bg)
	slot.set_meta("hp_bg", hp_bg)

	# HP bar fill (drawn over bg)
	var hp_fill := ColorRect.new()
	hp_fill.custom_minimum_size = Vector2(0, HP_BAR_HEIGHT)
	hp_fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_bg.add_child(hp_fill)
	slot.set_meta("hp_fill", hp_fill)

	_update_hp_bar(hp_fill, hp_bg, member)

	# Gray out dead members
	if member.is_dead:
		slot.modulate = Color(0.5, 0.5, 0.5, 0.7)

	return slot


func _update_hp_bar(fill: ColorRect, bg: ColorRect, member: Monster) -> void:
	if member.max_hp <= 0:
		fill.visible = false
		return

	var ratio := clampf(float(member.hp) / float(member.max_hp), 0.0, 1.0)

	# Size the fill as a fraction of the background width
	# We need to defer this since the bg may not be laid out yet
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	fill.custom_minimum_size.x = bg.custom_minimum_size.x * ratio if bg.custom_minimum_size.x > 0 else 0

	# Use anchors to fill proportionally
	fill.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fill.anchor_right = ratio

	# Color based on HP percentage
	if ratio > 0.5:
		fill.color = UIColors.HP_HIGH
	elif ratio > 0.25:
		fill.color = UIColors.HP_MID
	else:
		fill.color = UIColors.HP_LOW


func _get_portrait_texture(member: Monster) -> Texture2D:
	# Use same lookup logic as actor.gd
	var appearances: Array = []
	var data := MonsterFactory.monster_data.get(member.slug, {}) as Dictionary
	if not data.is_empty():
		appearances = data.get("appearance", [])
	else:
		appearances = DndMonsterFactory.get_appearances(member.slug)

	if appearances.is_empty():
		return CharacterTiles.get_texture(&"debug")

	var tile_name: String = appearances[member.variant % appearances.size()]
	return CharacterTiles.get_texture(StringName(tile_name))


func _get_display_name(member: Monster) -> String:
	if member == World.player and member.character_data:
		var cd := member.character_data
		return cd.character_name if not cd.character_name.is_empty() else "Adventurer"
	return member.name


func _clear() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
	for slot in _slots:
		slot.queue_free()
	_slots.clear()
