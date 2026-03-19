extends Node2D

## Tavern scene controller — orchestrates TavernMap, TavernRenderer,
## NPC/obstacle handlers, and player movement.
## Supports loading from Forge-generated JSON or hardcoded fallback.
## Press F5 to hot-reload the tavern JSON during iteration.

signal npc_interacted(npc_name: String)
signal exit_triggered

const TILE_SIZE := 16

# Preload scripts to avoid ARM64 class_name cache misses
const _TavernMapScript = preload("res://src/tavern_map.gd")
const _NpcHandlerScript = preload("res://scenes/tavern/tavern_npc_handler.gd")
const _ObstacleHandlerScript = preload("res://scenes/tavern/tavern_obstacle_handler.gd")

# Default JSON search path for Forge-generated taverns
const _TAVERN_JSON_DIR := "res://../../forge_output/taverns/"
const _TAVERN_JSON_FALLBACK := "res://../../forge_output/taverns/the_welcome_wench.json"

var _tavern_map: RefCounted  # TavernMap
var _npc_handler: RefCounted  # TavernNpcHandler
var _obstacle_handler: RefCounted  # TavernObstacleHandler
var _tavern_json_path: String = ""  # Path used for F5 reload

var player_pos: Vector2i
var _npc_sprites: Dictionary = {}  # name -> Sprite2D
var _candle_lights: Array[PointLight2D] = []
var _candle_tweens: Array[Tween] = []

# Autoload references (runtime resolution per conventions)
var _nm: Node  # NarrativeManager
var _oc: Node  # OrchestratorClient

# Scene tree references
@onready var renderer: Node2D = $TavernRenderer
@onready var npc_layer: Node2D = $NPCs
@onready var player_sprite: Sprite2D = $Player


func _ready() -> void:
	_nm = get_node_or_null("/root/NarrativeManager")
	_oc = get_node_or_null("/root/OrchestratorClient")

	# Try to load tavern from JSON, fallback to hardcoded
	_tavern_map = _load_tavern_map()

	# Create handlers
	_npc_handler = _NpcHandlerScript.new(_nm, _oc)
	_obstacle_handler = _ObstacleHandlerScript.new(_nm)

	# Render the map via TileMapLayers
	renderer.render_tavern(_tavern_map)

	# Place NPCs and player
	_place_npcs()
	_place_player()

	# Setup candle lights for warm flickering atmosphere
	_setup_candle_lights()

	# UI layer with DM panel
	_setup_ui()

	# Entrance narration (from JSON or fallback)
	_nm.clear()
	if _tavern_map.entrance_narration.size() > 0:
		for line: String in _tavern_map.entrance_narration:
			_nm.add_narrative(line)
	else:
		_nm.add_narrative(
			"[color=#6cb4c4][b]The Welcome Wench[/b][/color]\n"
			+ "You push open the heavy oak door. The warmth of the tavern "
			+ "washes over you — crackling hearth, the clink of mugs, "
			+ "and the low murmur of conversation."
		)
		_nm.add_narrative(
			"[color=#d9d566]Barkeep Marta[/color] stands behind the polished bar, "
			+ "wiping down a mug. [color=#d9d566]Old Tom[/color] nurses an ale at a "
			+ "nearby table. A [color=#d9d566]hooded figure[/color] sits alone in the "
			+ "corner. A [color=#d9d566]quest board[/color] on the far wall catches your eye."
		)

	# Release GUI focus so WASD works immediately
	get_viewport().gui_release_focus.call_deferred()


func _load_tavern_map() -> RefCounted:
	# Try the absolute path for forge_output on disk
	var abs_path := ProjectSettings.globalize_path(_TAVERN_JSON_FALLBACK)
	if FileAccess.file_exists(abs_path):
		_tavern_json_path = abs_path
		print("TavernController: Loading tavern from %s" % abs_path)
		return _TavernMapScript.from_json(abs_path)

	# Try user:// path
	var user_path := "user://forge_output/taverns/the_welcome_wench.json"
	if FileAccess.file_exists(user_path):
		_tavern_json_path = user_path
		print("TavernController: Loading tavern from %s" % user_path)
		return _TavernMapScript.from_json(user_path)

	# Fallback to hardcoded
	print("TavernController: No tavern JSON found, using hardcoded fallback")
	return _TavernMapScript.new()


func _place_npcs() -> void:
	# Place NPCs from tavern_map.npc_data (works for both JSON and fallback)
	for npc: Dictionary in _tavern_map.npc_data:
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
	player_pos = _tavern_map.player_spawn
	var psn: StringName = _tavern_map.player_sprite_name
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


func _setup_candle_lights() -> void:
	# Create a radial gradient texture for all candle lights
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var light_tex := GradientTexture2D.new()
	light_tex.gradient = gradient
	light_tex.fill = GradientTexture2D.FILL_RADIAL
	light_tex.fill_from = Vector2(0.5, 0.5)
	light_tex.fill_to = Vector2(0.5, 0.0)
	light_tex.width = 128
	light_tex.height = 128

	# Candle positions from atmosphere data or fallback
	var atm: Dictionary = _tavern_map.atmosphere
	var raw_positions: Array = atm.get("candle_positions", [[12, 11], [13, 4], [20, 17]])
	var candle_color := Color(1.0, 0.85, 0.5)
	var candle_energy: float = 0.6
	var flicker_lo: float = 0.5
	var flicker_hi: float = 0.7

	if atm.has("candle_color"):
		var cc: Array = atm["candle_color"]
		if cc.size() >= 3:
			candle_color = Color(float(cc[0]), float(cc[1]), float(cc[2]))
	if atm.has("candle_energy"):
		candle_energy = float(atm["candle_energy"])
	if atm.has("candle_flicker_range"):
		var fr: Array = atm["candle_flicker_range"]
		if fr.size() >= 2:
			flicker_lo = float(fr[0])
			flicker_hi = float(fr[1])

	for i in range(raw_positions.size()):
		var cp: Array = raw_positions[i]
		if cp.size() < 2:
			continue
		var px: float = float(cp[0]) * TILE_SIZE + TILE_SIZE / 2.0
		var py: float = float(cp[1]) * TILE_SIZE + TILE_SIZE / 2.0

		var light := PointLight2D.new()
		light.name = "CandleLight%d" % (i + 1)
		light.position = Vector2(px, py)
		light.color = candle_color
		light.energy = candle_energy
		light.texture_scale = 2.5
		light.texture = light_tex
		add_child(light)
		_candle_lights.append(light)

		# Flicker animation via tween
		var tween := create_tween().set_loops()
		tween.tween_property(light, "energy", flicker_hi, 0.8 + randf() * 0.4)
		tween.tween_property(light, "energy", flicker_lo, 0.8 + randf() * 0.4)
		_candle_tweens.append(tween)


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

	# Provide tavern NPC names to the DM panel "To" dropdown
	var npc_ids: Array[String] = _tavern_map.get_all_npc_ids()
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

	# F5: Hot-reload tavern from JSON (for Forge iteration loop)
	if event.keycode == KEY_F5:
		_reload_tavern()
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
	if not _tavern_map.is_in_bounds(new_pos):
		return

	# Check for door (exit)
	if _tavern_map.get_char_at(new_pos) == "D":
		exit_triggered.emit()
		return

	# Check for NPC interaction (bump-to-interact)
	if _tavern_map.has_npc(new_pos):
		# Don't spam dialogue while choices are pending
		if _nm and _nm.is_awaiting_choice():
			return
		var npc_id: String = _tavern_map.get_npc_at(new_pos)
		var npc_profile: Dictionary = _npc_handler.get_profile(npc_id)
		var npc_display_name: String = npc_profile.get("name", npc_id)
		npc_interacted.emit(npc_display_name)
		_npc_handler.handle_npc_interaction(npc_id)
		return

	# Check walkability
	if not _tavern_map.is_walkable(new_pos):
		# Don't re-trigger obstacle while choices are displayed
		if _obstacle_handler.is_active():
			return
		var obstacle: String = _tavern_map.get_obstacle_at(new_pos)
		if obstacle != "":
			_obstacle_handler.handle_obstacle(obstacle)
		return

	# Move the player
	player_pos = new_pos
	player_sprite.position = Vector2(
		player_pos.x * TILE_SIZE + TILE_SIZE / 2,
		player_pos.y * TILE_SIZE + TILE_SIZE / 2,
	)


## Hot-reload tavern from JSON (F5 key). Clears and re-renders everything.
func _reload_tavern() -> void:
	if _tavern_json_path == "":
		if _nm:
			_nm.add_narrative("[color=gray][i]No tavern JSON loaded — nothing to reload.[/i][/color]")
		return

	print("TavernController: Reloading tavern from %s" % _tavern_json_path)

	# Reload the data model
	_tavern_map = _TavernMapScript.from_json(_tavern_json_path)

	# Clear existing NPC sprites
	for sprite_name: String in _npc_sprites:
		var sprite: Sprite2D = _npc_sprites[sprite_name]
		sprite.queue_free()
	_npc_sprites.clear()

	# Clear existing candle lights and tweens
	for tween: Tween in _candle_tweens:
		tween.kill()
	_candle_tweens.clear()
	for light: PointLight2D in _candle_lights:
		light.queue_free()
	_candle_lights.clear()

	# Re-render
	renderer.render_tavern(_tavern_map)
	_place_npcs()
	_place_player()
	_setup_candle_lights()

	# Notify
	if _nm:
		_nm.add_narrative("[color=gray][i]Tavern reloaded from JSON.[/i][/color]")
