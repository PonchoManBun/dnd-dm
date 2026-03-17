extends Node2D

## Tavern scene controller — orchestrates TavernMap, TavernRenderer,
## NPC/obstacle handlers, and player movement.

signal npc_interacted(npc_name: String)
signal exit_triggered

const TILE_SIZE := 16

# Preload scripts to avoid ARM64 class_name cache misses
const _TavernMapScript = preload("res://src/tavern_map.gd")
const _NpcHandlerScript = preload("res://scenes/tavern/tavern_npc_handler.gd")
const _ObstacleHandlerScript = preload("res://scenes/tavern/tavern_obstacle_handler.gd")

var _tavern_map: RefCounted  # TavernMap
var _npc_handler: RefCounted  # TavernNpcHandler
var _obstacle_handler: RefCounted  # TavernObstacleHandler

var player_pos: Vector2i
var _npc_sprites: Dictionary = {}  # name -> Sprite2D

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

	# Build data model
	_tavern_map = _TavernMapScript.new()

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

	# Entrance narration
	_nm.clear()
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


func _place_npcs() -> void:
	# NPC positions and sprites accessed through the data model instance
	var barkeep_pos: Vector2i = _tavern_map.BARKEEP_POS
	var old_tom_pos: Vector2i = _tavern_map.OLD_TOM_POS
	var elara_pos: Vector2i = _tavern_map.ELARA_POS

	# Barkeep Marta — warm amber tint
	var marta := _create_npc_sprite("Marta", barkeep_pos, &"player-25")
	marta.modulate = Color(0.8, 0.5, 0.3, 1.0)
	npc_layer.add_child(marta)
	_npc_sprites["Marta"] = marta

	# Old Tom — earthy brown tint
	var old_tom := _create_npc_sprite("OldTom", old_tom_pos, &"player-31")
	old_tom.modulate = Color(0.55, 0.4, 0.25, 1.0)
	npc_layer.add_child(old_tom)
	_npc_sprites["OldTom"] = old_tom

	# Elara — deep purple/blue tint
	var elara := _create_npc_sprite("Elara", elara_pos, &"player-4")
	elara.modulate = Color(0.4, 0.3, 0.7, 1.0)
	npc_layer.add_child(elara)
	_npc_sprites["Elara"] = elara


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
	player_pos = _tavern_map.PLAYER_SPAWN
	var player_sprite_name: StringName = _tavern_map.PLAYER_SPRITE_NAME
	player_sprite.texture = CharacterTiles.TEXTURE
	player_sprite.region_enabled = true
	player_sprite.region_rect = CharacterTiles.get_region(player_sprite_name)
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

	# Candle positions (pixel coords) — bar, dining area, entrance
	var candle_positions: Array[Vector2] = [
		Vector2(12 * TILE_SIZE + 8, 11 * TILE_SIZE + 8),   # Bar area
		Vector2(13 * TILE_SIZE + 8, 4 * TILE_SIZE + 8),    # Dining area
		Vector2(20 * TILE_SIZE + 8, 17 * TILE_SIZE + 8),   # Near entrance
	]

	for i in range(candle_positions.size()):
		var light := PointLight2D.new()
		light.name = "CandleLight%d" % (i + 1)
		light.position = candle_positions[i]
		light.color = Color(1.0, 0.85, 0.5)
		light.energy = 0.6
		light.texture_scale = 2.5
		light.texture = light_tex
		add_child(light)

		# Flicker animation via tween
		var tween := create_tween().set_loops()
		tween.tween_property(light, "energy", 0.7, 0.8 + randf() * 0.4)
		tween.tween_property(light, "energy", 0.5, 0.8 + randf() * 0.4)


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


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.is_echo():
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
