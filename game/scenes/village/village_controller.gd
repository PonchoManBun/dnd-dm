extends Node2D

## Village scene controller — orchestrates VillageMap, VillageRenderer,
## NPC/obstacle handlers, and player movement.
## The village is the main hub with buildings that have visible interiors.
## Supports loading from Forge-generated JSON or hardcoded fallback.
## Press F5 to hot-reload the village JSON during iteration.

signal npc_interacted(npc_name: String)
signal exit_triggered

const TILE_SIZE := 16

# Preload scripts to avoid ARM64 class_name cache misses
const _VillageMapScript = preload("res://src/village_map.gd")
const _NpcHandlerScript = preload("res://scenes/tavern/tavern_npc_handler.gd")
const _ObstacleHandlerScript = preload("res://scenes/tavern/tavern_obstacle_handler.gd")

# Default JSON search path for Forge-generated villages
const _VILLAGE_JSON_DIR := "res://../../forge_output/villages/"
const _VILLAGE_JSON_FALLBACK := "res://../../forge_output/villages/hommlet.json"

var _village_map: RefCounted  # VillageMap
var _npc_handler: RefCounted  # TavernNpcHandler (reused)
var _obstacle_handler: RefCounted  # TavernObstacleHandler (reused)
var _village_json_path: String = ""  # Path used for F5 reload

var player_pos: Vector2i
var _npc_sprites: Dictionary = {}  # name -> Sprite2D
var _current_building: Dictionary = {}  # Track which building player is in

# Autoload references (runtime resolution per conventions)
var _nm: Node  # NarrativeManager
var _oc: Node  # OrchestratorClient

# Scene tree references
@onready var renderer: Node2D = $VillageRenderer
@onready var npc_layer: Node2D = $NPCs
@onready var player_sprite: Sprite2D = $Player


func _ready() -> void:
	_nm = get_node_or_null("/root/NarrativeManager")
	_oc = get_node_or_null("/root/OrchestratorClient")

	# Try to load village from JSON, fallback to hardcoded
	_village_map = _load_village_map()

	# Create handlers (reuse tavern handlers)
	_npc_handler = _NpcHandlerScript.new(_nm, _oc)
	_obstacle_handler = _ObstacleHandlerScript.new(_nm)

	# Render the map via TileMapLayers
	renderer.render_village(_village_map)

	# Place NPCs and player
	_place_npcs()
	_place_player()

	# UI layer with DM panel
	_setup_ui()

	# Entrance narration (from JSON or fallback)
	_nm.clear()
	if _village_map.entrance_narration.size() > 0:
		for line: String in _village_map.entrance_narration:
			_nm.add_narrative(line)
	else:
		_nm.add_narrative(
			"[color=#6cb4c4][b]%s[/b][/color]\n" % _village_map.village_name
			+ "You arrive at the village. Buildings with thatched roofs "
			+ "line the dirt paths, and the sounds of daily life fill the air."
		)

	# Release GUI focus so WASD works immediately
	get_viewport().gui_release_focus.call_deferred()


func _load_village_map() -> RefCounted:
	# Try the absolute path for forge_output on disk
	var abs_path := ProjectSettings.globalize_path(_VILLAGE_JSON_FALLBACK)
	if FileAccess.file_exists(abs_path):
		_village_json_path = abs_path
		print("VillageController: Loading village from %s" % abs_path)
		return _VillageMapScript.from_json(abs_path)

	# Try user:// path
	var user_path := "user://forge_output/villages/hommlet.json"
	if FileAccess.file_exists(user_path):
		_village_json_path = user_path
		print("VillageController: Loading village from %s" % user_path)
		return _VillageMapScript.from_json(user_path)

	# Fallback to hardcoded
	print("VillageController: No village JSON found, using hardcoded fallback")
	return _VillageMapScript.new()


func _place_npcs() -> void:
	# Place NPCs from village_map.npc_data (works for both JSON and fallback)
	for npc: Dictionary in _village_map.npc_data:
		var display_name: String = str(npc.get("display_name", npc.get("npc_id", "NPC")))
		var pos_arr: Variant = npc.get("position", [0, 0])
		var arr: Array = pos_arr if pos_arr is Array else [0, 0]
		var grid_pos := Vector2i(int(arr[0]), int(arr[1]))
		var sprite_name := StringName(str(npc.get("sprite_name", "player-0")))

		var sprite := _create_npc_sprite(display_name, grid_pos, sprite_name)

		# Apply modulate color if specified
		var mod: Variant = npc.get("modulate", null)
		if mod is Array and (mod as Array).size() >= 4:
			var m: Array = mod
			sprite.modulate = Color(float(m[0]), float(m[1]), float(m[2]), float(m[3]))

		npc_layer.add_child(sprite)
		_npc_sprites[display_name] = sprite


func _create_npc_sprite(npc_name: String, grid_pos: Vector2i, sprite_name: StringName) -> Sprite2D:
	var center := Vector2(
		grid_pos.x * TILE_SIZE + TILE_SIZE / 2,
		grid_pos.y * TILE_SIZE + TILE_SIZE / 2,
	)
	var sprite := Sprite2D.new()
	sprite.name = npc_name
	sprite.texture = CharacterTiles.TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = CharacterTiles.get_region(sprite_name)
	sprite.hframes = 2
	sprite.frame = 0
	sprite.centered = true
	sprite.position = center
	return sprite


func _place_player() -> void:
	player_pos = _village_map.player_spawn
	var psn: StringName = _village_map.player_sprite_name
	player_sprite.texture = CharacterTiles.TEXTURE
	player_sprite.region_enabled = true
	player_sprite.region_rect = CharacterTiles.get_region(psn)
	player_sprite.hframes = 2
	player_sprite.frame = 0
	player_sprite.position = Vector2(
		player_pos.x * TILE_SIZE + TILE_SIZE / 2,
		player_pos.y * TILE_SIZE + TILE_SIZE / 2,
	)

	# Camera2D is a child of Player in the scene tree — auto-follows
	var camera: Camera2D = player_sprite.get_node("Camera2D")
	camera.make_current()


func _setup_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	var dm_panel := DMPanel.new()
	var panel_ratio := 192.0 / 576.0  # ~1/3 of viewport width
	dm_panel.anchor_left = 1.0 - panel_ratio
	dm_panel.anchor_right = 1.0
	dm_panel.anchor_top = 0.0
	dm_panel.anchor_bottom = 1.0
	ui_layer.add_child(dm_panel)

	# Provide village NPC names to the DM panel "To" dropdown
	var npc_ids: Array[String] = _village_map.get_all_npc_ids()
	var npc_names: Array[String] = []
	var npc_id_map: Dictionary = {}  # display_name -> npc_id
	for npc_id: String in npc_ids:
		var profile: Dictionary = _npc_handler.get_profile(npc_id)
		var display_name: String = profile.get("name", npc_id)
		npc_names.append(display_name)
		npc_id_map[display_name] = npc_id
	dm_panel.set_available_targets(npc_names, npc_id_map)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.is_echo():
		return

	# F5: Hot-reload village from JSON (for Forge iteration loop)
	if event.keycode == KEY_F5:
		_reload_village()
		get_viewport().set_input_as_handled()
		return

	var direction := Vector2i.ZERO
	match event.keycode:
		KEY_W, KEY_UP:
			direction = Vector2i(0, -1)
		KEY_S, KEY_DOWN:
			direction = Vector2i(0, 1)
		KEY_A, KEY_LEFT:
			direction = Vector2i(-1, 0)
		KEY_D, KEY_RIGHT:
			direction = Vector2i(1, 0)
		_:
			return

	_try_move(direction)
	get_viewport().set_input_as_handled()


func _try_move(direction: Vector2i) -> void:
	var new_pos := player_pos + direction

	# Bounds check
	if not _village_map.is_in_bounds(new_pos):
		return

	# Check for exit (dungeon gate, etc.)
	var exit_dest: String = _village_map.get_exit_at(new_pos)
	if exit_dest != "":
		exit_triggered.emit()
		return

	# Check for NPC interaction (bump-to-interact)
	if _village_map.has_npc(new_pos):
		# Don't spam dialogue while choices are pending
		if _nm and _nm.is_awaiting_choice():
			return
		var npc_id: String = _village_map.get_npc_at(new_pos)
		var npc_profile: Dictionary = _npc_handler.get_profile(npc_id)
		var npc_display_name: String = npc_profile.get("name", npc_id)
		npc_interacted.emit(npc_display_name)
		_npc_handler.handle_npc_interaction(npc_id)
		return

	# Check walkability
	if not _village_map.is_walkable(new_pos):
		# Don't re-trigger obstacle while choices are displayed
		if _obstacle_handler.is_active():
			return
		var obstacle: String = _village_map.get_obstacle_at(new_pos)
		if obstacle != "":
			_obstacle_handler.handle_obstacle(obstacle)
		return

	# Move the player
	player_pos = new_pos
	player_sprite.position = Vector2(
		player_pos.x * TILE_SIZE + TILE_SIZE / 2,
		player_pos.y * TILE_SIZE + TILE_SIZE / 2,
	)

	# Check building context change
	var building: Dictionary = _village_map.get_building_at(new_pos)
	if building != _current_building:
		_current_building = building
		if not building.is_empty() and _nm:
			_nm.add_narrative(
				"[color=#6cb4c4]You enter the %s.[/color]" % building.get("name", "building")
			)


## Hot-reload village from JSON (F5 key). Clears and re-renders everything.
func _reload_village() -> void:
	if _village_json_path == "":
		if _nm:
			_nm.add_narrative("[color=gray][i]No village JSON loaded — nothing to reload.[/i][/color]")
		return

	print("VillageController: Reloading village from %s" % _village_json_path)

	# Reload the data model
	_village_map = _VillageMapScript.from_json(_village_json_path)

	# Clear existing NPC sprites
	for sprite_name: String in _npc_sprites:
		var sprite: Sprite2D = _npc_sprites[sprite_name]
		sprite.queue_free()
	_npc_sprites.clear()

	# Reset building context
	_current_building = {}

	# Re-render
	renderer.render_village(_village_map)
	_place_npcs()
	_place_player()

	# Notify
	if _nm:
		_nm.add_narrative("[color=gray][i]Village reloaded from JSON.[/i][/color]")
