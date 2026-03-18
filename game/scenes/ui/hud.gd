class_name HUD
extends Control

signal drop_requested(selections: Array[ItemSelection])

@onready var party_bar: PartyBar = %PartyBar
@onready var status_text: RichTextLabel = %StatusText
@onready var inventory_button: Button = %InventoryButton
@onready var hover_info: RichTextLabel = %HoverInfo
@onready var throw_info: RichTextLabel = %ThrowInfo
@onready var drag_effect: ReferenceRect = %DragEffect
@onready var melee_container: HBoxContainer = %MeleeContainer
@onready var ranged_container: HBoxContainer = %RangedContainer
@onready var armor_container: HBoxContainer = %ArmorContainer
@onready var char_sheet_button: Button = %CharSheetButton

const MAX_LOG_LENGTH = 10000
const EQUIPMENT_ICON_SIZE := Vector2(16, 16)
const MAX_MODULES := 3

# Disable this during movement path execution
var updates_enabled: bool = true

var _debug_mode: bool = false
var debug_mode: bool:
	get:
		return _debug_mode
	set(value):
		_debug_mode = value
		_update_display()


func _ready() -> void:
	assert(party_bar, "PartyBar is not found")
	assert(status_text, "StatusText is not found")

	World.world_initialized.connect(_on_world_initialized)
	World.turn_ended.connect(_on_turn_ended)

	inventory_button.focus_mode = Control.FOCUS_NONE
	inventory_button.pressed.connect(_on_inventory_button_pressed)

	char_sheet_button.focus_mode = Control.FOCUS_NONE
	char_sheet_button.pressed.connect(func() -> void:
		Input.action_press("toggle_character_sheet")
		Input.action_release("toggle_character_sheet")
	)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	throw_info.visible = false


func _on_world_initialized() -> void:
	_update_display()


func _on_turn_ended() -> void:
	_update_display()


func set_hover_info(text: Variant) -> void:
	if not updates_enabled:
		return

	if text is String:
		hover_info.visible = true
		hover_info.text = "[right]" + text
	else:
		hover_info.visible = false


func _update_display() -> void:
	if not updates_enabled:
		return

	# Update equipment displays (icon-only, no text labels)
	_build_weapon_container(
		melee_container, World.player.equipment.get_equipped_item(Equipment.Slot.MELEE)
	)

	_build_weapon_container(
		ranged_container, World.player.equipment.get_equipped_item(Equipment.Slot.RANGED)
	)

	_build_armor_container(armor_container)

	# Update basic status text — compact with AC, level, and XP
	var ac_text := "AC:%d" % World.player.get_armor_class()
	var lvl_text := ""
	var xp_text := ""
	if World.player.character_data:
		var cd := World.player.character_data
		lvl_text = " Lv%d" % cd.level
		var xp_next := 0
		if cd.level < CharacterData.XP_THRESHOLDS.size():
			xp_next = CharacterData.XP_THRESHOLDS[cd.level]
		if xp_next > 0:
			xp_text = " XP:%d/%d" % [cd.experience_points, xp_next]
		else:
			xp_text = " XP:MAX"
	status_text.text = "T:%d %s%s%s" % [World.current_turn, ac_text, lvl_text, xp_text]
	var nutrition_status := World.player.nutrition.get_status()
	if nutrition_status != Nutrition.Status.NORMAL:
		var text := Nutrition.get_status_rich_text_label(nutrition_status)
		status_text.text += " - " + text

	# Update status effects
	for effect: StatusEffect in World.player.status_effects:
		var color := GameColors.ORANGE.to_html()
		status_text.text += (
			" - [color=%s][pulse]%s[/pulse][/color]" % [color, effect.get_adjective()]
		)

	# Debug info
	if debug_mode:
		status_text.text += "\n[color=cyan]Debug info\n"
		status_text.text += "Nutr: %d" % World.player.nutrition.value
		status_text.text += (
			" - Load: %.1f/%.1f"
			% [World.player.get_current_load(), World.player.get_max_carrying_capacity()]
		)
		status_text.text += "[/color]"


func _on_inventory_button_pressed() -> void:
	Modals.toggle_inventory()


func _on_mouse_entered() -> void:
	if get_viewport().gui_is_dragging():
		drag_effect.visible = true


func _on_mouse_exited() -> void:
	drag_effect.visible = false


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if data is Item:
		return true
	return false


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Item:
		var item: Item = data
		var selection := ItemSelection.new(item, item.quantity)
		drop_requested.emit([selection])


func _create_equipment_icon(
	texture: Texture2D, tooltip: String, item: Item = null
) -> HBoxContainer:
	var container := HBoxContainer.new()
	container.add_theme_constant_override("separation", 2)

	var icon := TextureRect.new()
	icon.custom_minimum_size = EQUIPMENT_ICON_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture = texture
	icon.tooltip_text = tooltip
	container.add_child(icon)

	return container


func _build_weapon_container(container: HBoxContainer, item: Item) -> void:
	# Clear all children
	for child in container.get_children():
		child.queue_free()

	# Set container properties
	container.add_theme_constant_override("separation", 0)

	if item:
		var main_icon := _create_equipment_icon(
			ItemTiles.get_texture(item.sprite_name), item.get_info(), item
		)
		container.add_child(main_icon)

		# Check for missing ammo in ranged weapons
		if item.ammo_type != Damage.AmmoType.NONE:
			var has_ammo := false
			for child: Item in item.children.to_array():
				if child.type == Item.Type.AMMO and child.quantity > 0:
					has_ammo = true
					break

			if not has_ammo:
				var meta := Label.new()
				meta.text = "(!)"
				meta.theme_type_variation = &"SubtleLabel"
				container.add_child(meta)
				return

		# Add module slots
		var children := item.children.to_array()
		for i in range(MAX_MODULES):
			if children.size() > i:
				var child: Item = children[i]
				var module_icon := _create_equipment_icon(
					ItemTiles.get_texture(child.sprite_name), child.get_info(), child
				)
				container.add_child(module_icon)

				# Add ammo count
				if child.type == Item.Type.AMMO:
					var meta := Label.new()
					meta.text = "(%d)" % child.quantity
					meta.theme_type_variation = &"SubtleLabel"
					container.add_child(meta)
	else:
		var meta := Label.new()
		meta.text = "-"
		meta.theme_type_variation = &"SubtleLabel"
		container.add_child(meta)


func _build_armor_container(container: HBoxContainer) -> void:
	# Clear all children
	for child in container.get_children():
		child.queue_free()

	# Set container properties
	container.add_theme_constant_override("separation", 0)

	var has_armor := false
	for slot: Equipment.Slot in [
		Equipment.Slot.UPPER_ARMOR,
		Equipment.Slot.LOWER_ARMOR,
		Equipment.Slot.BASE,
		Equipment.Slot.CLOAK,
		Equipment.Slot.FOOTWEAR,
		Equipment.Slot.MASK,
		Equipment.Slot.GLOVES,
		Equipment.Slot.HEADWEAR,
		Equipment.Slot.BELT
	]:
		var item := World.player.equipment.get_equipped_item(slot)
		if item:
			has_armor = true
			var icon := _create_equipment_icon(
				ItemTiles.get_texture(item.sprite_name), item.get_info(), item
			)
			container.add_child(icon)

			# Check children of armor items for power sources
			for child: Item in item.children.to_array():
				var child_icon := _create_equipment_icon(
					ItemTiles.get_texture(child.sprite_name), child.get_info(), child
				)
				container.add_child(child_icon)

	if not has_armor:
		var meta := Label.new()
		meta.text = "-"
		meta.theme_type_variation = &"SubtleLabel"
		container.add_child(meta)
