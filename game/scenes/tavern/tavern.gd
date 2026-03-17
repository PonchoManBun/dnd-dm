extends Node2D

## The Welcome Wench tavern — hand-crafted hub scene.
## Built programmatically from a string map layout.
## Renders tiles using sprite atlases from WorldTiles and CharacterTiles autoloads.

signal npc_interacted(npc_name: String)
signal exit_triggered

const MAP_WIDTH := 24
const MAP_HEIGHT := 20
const TILE_SIZE := 16

# The map layout as a string grid (each row must be exactly 24 characters)
const TAVERN_LAYOUT: Array[String] = [
	"########################",       # 0  - outer walls
	"#......................#",       # 1
	"#..MMMM...............S#",       # 2  - memorial wall, stairs
	"#..MMMM...TT....TT....S#",       # 3  - tables, stairs
	"#..MMMM...cc....cc....##",       # 4  - chairs, alcove wall
	"#.........TT....TT.....#",       # 5  - tables
	"#.........cc....cc.....#",       # 6  - chairs
	"#......................#",       # 7
	"##..........BB.........#",       # 8  - bar counter starts
	"#R..........BB.........#",       # 9  - rooms alcove
	"#R..........BB.........#",       # 10 - rooms alcove
	"##..........BB..QQQQ...#",       # 11 - quest board
	"#...........BB..QQQQ...#",       # 12 - quest board
	"#...........*B..QQQQ...#",       # 13 - barkeep position
	"#......................#",       # 14
	"#......................#",       # 15
	"#..ssssss..............#",       # 16 - shop counter
	"#..ssssss..............#",       # 17 - shop counter
	"#.....................DD",       # 18 - entrance doors
	"########################",       # 19 - outer walls
]

# Player spawn position (just inside the entrance door)
const PLAYER_SPAWN := Vector2i(21, 17)

# NPC positions
const BARKEEP_POS := Vector2i(12, 13)
const OLD_TOM_POS := Vector2i(10, 3)   # At a dining table
const ELARA_POS := Vector2i(17, 5)     # At another dining table

# NPC character sprite mappings (character_tiles atlas names)
const NPC_SPRITES: Dictionary = {
	"Marta": &"player-25",
	"OldTom": &"player-31",
	"Elara": &"player-4",
}
const PLAYER_SPRITE_NAME := &"player-4"

# Track which cells are walkable
var _walkable: Array = []  # 2D array of bools
var _obstacles: Dictionary = {}  # Vector2i -> String (obstacle type)

# Prevent re-triggering obstacle interaction while choices are displayed
var _obstacle_interaction_active: bool = false

# Track NPC interaction counts to avoid repeating the same greeting
var _npc_interacted: Dictionary = {}  # npc_id -> int (interaction count)

# Player node
var player_sprite: Sprite2D
var player_pos: Vector2i

# NPC sprites
var _npc_sprites: Dictionary = {}  # name -> Sprite2D

# NPC profile data loaded from JSON
var _npc_profiles: Dictionary = {}

# Map from grid position to NPC id for bump-to-interact
var _npc_positions: Dictionary = {}  # Vector2i -> String (npc_id)

# Visual layers
var _floor_layer: Node2D
var _wall_layer: Node2D
var _furniture_layer: Node2D
var _npc_layer: Node2D
var _player_layer: Node2D

# Atlas availability flags — fall back to ColorRect if atlases fail to load
var _world_atlas_available: bool = false
var _char_atlas_available: bool = false

# UI elements
var _dm_panel: DMPanel
var _ui_layer: CanvasLayer

# Autoload references (avoid parse-time resolution issues on ARM64)
var _nm: Node  # NarrativeManager
var _oc: Node  # OrchestratorClient


func _ready() -> void:
	_nm = get_node_or_null("/root/NarrativeManager")
	_oc = get_node_or_null("/root/OrchestratorClient")
	_check_atlas_availability()
	_load_npc_profiles()
	_init_walkable_grid()
	_build_visual_layers()
	_draw_map()
	_place_npcs()
	_place_player()

	# Warm palette: apply a tavern-specific CanvasModulate
	var modulate := CanvasModulate.new()
	modulate.color = Color(1.0, 0.92, 0.82, 1.0)  # Warm candlelight
	add_child(modulate)

	# -- UI Layer --
	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UILayer"
	add_child(_ui_layer)

	# -- DM Panel (right side of screen) --
	_dm_panel = DMPanel.new()
	var panel_ratio := 192.0 / 576.0  # ~1/3 of viewport width
	_dm_panel.anchor_left = 1.0 - panel_ratio
	_dm_panel.anchor_right = 1.0
	_dm_panel.anchor_top = 0.0
	_dm_panel.anchor_bottom = 1.0
	_ui_layer.add_child(_dm_panel)

	# Clear old dungeon narratives and add tavern-specific opening
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

	# Release all GUI focus so WASD/arrow keys work immediately
	get_viewport().gui_release_focus.call_deferred()


func _load_npc_profiles() -> void:
	var file := FileAccess.open("res://assets/data/npc_profiles.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_npc_profiles = json.data
		file.close()
	else:
		push_warning("Tavern: could not load npc_profiles.json, using empty profiles")


func _init_walkable_grid() -> void:
	_walkable = []
	for y in range(MAP_HEIGHT):
		var row: Array = []
		for x in range(MAP_WIDTH):
			var ch: String = TAVERN_LAYOUT[y][x]
			match ch:
				"#", "B", "T", "Q", "s", "S", "M":
					row.append(false)
					_obstacles[Vector2i(x, y)] = ch
				"R":
					row.append(false)
					_obstacles[Vector2i(x, y)] = "R"
				"*":
					row.append(false)  # Barkeep position is not walkable
					_obstacles[Vector2i(x, y)] = "*"
				"c":
					row.append(true)  # Chairs are walkable (decorative)
				"D":
					row.append(true)  # Door is walkable
				_:  # "." and anything else
					row.append(true)
		_walkable.append(row)


func _check_atlas_availability() -> void:
	# Verify WorldTiles autoload has loaded its atlas data
	if WorldTiles and WorldTiles.get_all_names().size() > 0:
		_world_atlas_available = true
	else:
		push_warning("Tavern: WorldTiles atlas not available, falling back to ColorRect rendering")

	# Verify CharacterTiles autoload has loaded its atlas data
	if CharacterTiles and CharacterTiles.get_all_names().size() > 0:
		_char_atlas_available = true
	else:
		push_warning("Tavern: CharacterTiles atlas not available, falling back to ColorRect rendering")


func _build_visual_layers() -> void:
	_floor_layer = Node2D.new()
	_floor_layer.name = "FloorLayer"
	add_child(_floor_layer)

	_wall_layer = Node2D.new()
	_wall_layer.name = "WallLayer"
	add_child(_wall_layer)

	_furniture_layer = Node2D.new()
	_furniture_layer.name = "FurnitureLayer"
	add_child(_furniture_layer)

	_npc_layer = Node2D.new()
	_npc_layer.name = "NPCLayer"
	add_child(_npc_layer)

	_player_layer = Node2D.new()
	_player_layer.name = "PlayerLayer"
	add_child(_player_layer)


func _draw_map() -> void:
	for y in range(MAP_HEIGHT):
		for x in range(MAP_WIDTH):
			var pos := Vector2(x * TILE_SIZE, y * TILE_SIZE)
			var grid_pos := Vector2i(x, y)
			var ch: String = TAVERN_LAYOUT[y][x]

			# Draw floor under everything except walls
			if ch != "#":
				_draw_floor_tile(pos)

			match ch:
				"#":
					_draw_wall_tile(pos, grid_pos)
				"B":
					_draw_bar_tile(pos)
				"T":
					_draw_table_tile(pos)
				"c":
					_draw_chair_tile(pos)
				"Q":
					_draw_quest_board_tile(pos)
				"s":
					_draw_shop_tile(pos)
				"S":
					_draw_stairs_tile(pos)
				"M":
					_draw_memorial_tile(pos, grid_pos)
				"R":
					_draw_room_tile(pos, grid_pos)
				"D":
					_draw_door_tile(pos)
				"*":
					pass  # Floor already drawn; barkeep NPC placed separately


# --- Atlas sprite helpers ---


## Create a Sprite2D from the world tile atlas positioned at the given pixel location.
## The sprite is centered = false so its top-left aligns with pos.
func _create_world_tile_sprite(pos: Vector2, sprite_name: StringName) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = WorldTiles.get_texture(sprite_name)
	sprite.centered = false
	sprite.position = pos
	return sprite


## Create a Sprite2D from the character tile atlas positioned at the given pixel center.
## Character tiles are 32x16 with 2 animation frames; we show frame 0 (left half).
func _create_character_tile_sprite(center_pos: Vector2, sprite_name: StringName) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = CharacterTiles.TEXTURE
	sprite.region_enabled = true
	sprite.region_rect = CharacterTiles.get_region(sprite_name)
	sprite.hframes = 2
	sprite.frame = 0
	sprite.centered = true
	sprite.position = center_pos
	return sprite


## Create a ColorRect fallback tile.
func _create_color_tile(pos: Vector2, color: Color, parent: Node2D, sz: Vector2 = Vector2(TILE_SIZE, TILE_SIZE), offset: Vector2 = Vector2.ZERO) -> ColorRect:
	var rect := ColorRect.new()
	rect.position = pos + offset
	rect.size = sz
	rect.color = color
	parent.add_child(rect)
	return rect


## Determine the correct directional wall tile name based on neighboring wall cells
## in the tavern layout. Mirrors the logic from MapRenderer.get_wall_tile().
func _get_tavern_wall_tile(grid_pos: Vector2i) -> StringName:
	var x := grid_pos.x
	var y := grid_pos.y
	var n := y > 0 and _is_wall_like_char(TAVERN_LAYOUT[y - 1][x])
	var s := y < MAP_HEIGHT - 1 and _is_wall_like_char(TAVERN_LAYOUT[y + 1][x])
	var e := x < MAP_WIDTH - 1 and _is_wall_like_char(TAVERN_LAYOUT[y][x + 1])
	var w := x > 0 and _is_wall_like_char(TAVERN_LAYOUT[y][x - 1])

	# All four directions
	if n and s and e and w:
		return &"wall-5-nsew"
	# Three directions
	if n and s and e and not w:
		return &"wall-5-nse"
	if n and s and not e and w:
		return &"wall-5-nsw"
	if n and not s and e and w:
		return &"wall-5-new"
	if not n and s and e and w:
		return &"wall-5-sew"
	# Two directions
	if n and s and not e and not w:
		return &"wall-5-ns"
	if not n and not s and e and w:
		return &"wall-5-ew"
	if n and e and not s and not w:
		return &"wall-5-ne"
	if n and w and not s and not e:
		return &"wall-5-nw"
	if s and e and not n and not w:
		return &"wall-5-se"
	if s and w and not n and not e:
		return &"wall-5-sw"
	# One direction
	if not n and not s and not w and e:
		return &"wall-5-ew"
	if not n and not s and w and not e:
		return &"wall-5-ew"
	if n and not s and not e and not w:
		return &"wall-5-n"
	if not n and s and not e and not w:
		return &"wall-5-ns"

	return &"wall-5-lone"


## Returns true if a tavern layout character should be treated as wall-like
## for directional wall tile selection (walls, memorial, rooms).
func _is_wall_like_char(ch: String) -> bool:
	return ch == "#" or ch == "M" or ch == "R"


# --- Tile drawing helpers (sprite-based with ColorRect fallback) ---


func _draw_floor_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		var sprite := _create_world_tile_sprite(pos, &"floor-7-nsew")
		_floor_layer.add_child(sprite)
	else:
		var variation := randf_range(-0.03, 0.03)
		_create_color_tile(pos, Color(0.35 + variation, 0.25 + variation, 0.15, 1.0), _floor_layer)


func _draw_wall_tile(pos: Vector2, grid_pos: Vector2i) -> void:
	if _world_atlas_available:
		var tile_name := _get_tavern_wall_tile(grid_pos)
		var sprite := _create_world_tile_sprite(pos, tile_name)
		_wall_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.22, 0.18, 0.14, 1.0), _wall_layer)
		_create_color_tile(pos, Color(0.28, 0.22, 0.17, 1.0), _wall_layer,
			Vector2(TILE_SIZE - 2, TILE_SIZE - 2), Vector2(1, 1))


func _draw_bar_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		# Use the table/shelf sprite for bar counter — closest visual match
		var sprite := _create_world_tile_sprite(pos, &"decor-5")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.45, 0.28, 0.12, 1.0), _furniture_layer)


func _draw_table_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		var sprite := _create_world_tile_sprite(pos, &"decor-25")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.4, 0.3, 0.18, 1.0), _furniture_layer,
			Vector2(TILE_SIZE - 4, TILE_SIZE - 4), Vector2(2, 2))


func _draw_chair_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		var sprite := _create_world_tile_sprite(pos, &"decor-24")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.38, 0.26, 0.15, 1.0), _furniture_layer,
			Vector2(TILE_SIZE - 8, TILE_SIZE - 8), Vector2(4, 4))


func _draw_quest_board_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		# Empty shelves sprite — resembles a notice board with empty slots
		var sprite := _create_world_tile_sprite(pos, &"decor-0")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.3, 0.28, 0.22, 1.0), _furniture_layer)
		_create_color_tile(pos, Color(0.8, 0.7, 0.3, 1.0), _furniture_layer,
			Vector2(4, 4), Vector2(6, 4))


func _draw_shop_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		# Empty shelves sprite for shop counter
		var sprite := _create_world_tile_sprite(pos, &"decor-0")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.38, 0.28, 0.18, 1.0), _furniture_layer)


func _draw_stairs_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		var sprite := _create_world_tile_sprite(pos, &"tile-28")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.3, 0.25, 0.18, 1.0), _furniture_layer)
		for i in range(3):
			_create_color_tile(pos, Color(0.2, 0.16, 0.12, 1.0), _furniture_layer,
				Vector2(TILE_SIZE - 4, 1), Vector2(2, 3 + i * 4))


func _draw_memorial_tile(pos: Vector2, grid_pos: Vector2i) -> void:
	if _world_atlas_available:
		# Use a wall tile as base (memorial is mounted on wall)
		var wall_name := _get_tavern_wall_tile(grid_pos)
		var wall_sprite := _create_world_tile_sprite(pos, wall_name)
		_wall_layer.add_child(wall_sprite)
		# Overlay with the light/decoration sprite as a plaque accent
		var decor_sprite := _create_world_tile_sprite(pos, &"decor-32")
		_wall_layer.add_child(decor_sprite)
	else:
		_create_color_tile(pos, Color(0.22, 0.18, 0.14, 1.0), _wall_layer)
		_create_color_tile(pos, Color(0.5, 0.45, 0.3, 1.0), _wall_layer,
			Vector2(10, 10), Vector2(3, 3))


func _draw_room_tile(pos: Vector2, grid_pos: Vector2i) -> void:
	if _world_atlas_available:
		# Use directional wall tile for the room alcove area
		var wall_name := _get_tavern_wall_tile(grid_pos)
		var sprite := _create_world_tile_sprite(pos, wall_name)
		# Darken it slightly to indicate a recessed/dark area
		sprite.modulate = Color(0.6, 0.6, 0.6, 1.0)
		_wall_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.2, 0.17, 0.13, 1.0), _wall_layer)


func _draw_door_tile(pos: Vector2) -> void:
	if _world_atlas_available:
		var sprite := _create_world_tile_sprite(pos, &"doors0-0")
		_furniture_layer.add_child(sprite)
	else:
		_create_color_tile(pos, Color(0.4, 0.3, 0.15, 1.0), _furniture_layer)
		_create_color_tile(pos, Color(0.7, 0.6, 0.3, 1.0), _furniture_layer,
			Vector2(3, 3), Vector2(4, 7))


func _place_npcs() -> void:
	# Barkeep Marta — warm amber tint
	var marta := _create_npc_sprite("Marta", BARKEEP_POS, Color(0.8, 0.5, 0.3, 1.0))
	_npc_sprites["Marta"] = marta
	_npc_positions[BARKEEP_POS] = "marta"

	# Old Tom — earthy brown tint (grizzled veteran)
	var old_tom := _create_npc_sprite("OldTom", OLD_TOM_POS, Color(0.55, 0.4, 0.25, 1.0))
	_npc_sprites["OldTom"] = old_tom
	_npc_positions[OLD_TOM_POS] = "old_tom"
	# Mark Old Tom's position as non-walkable
	_walkable[OLD_TOM_POS.y][OLD_TOM_POS.x] = false

	# Elara the Quiet — deep purple/blue tint (mysterious)
	var elara := _create_npc_sprite("Elara", ELARA_POS, Color(0.4, 0.3, 0.7, 1.0))
	_npc_sprites["Elara"] = elara
	_npc_positions[ELARA_POS] = "elara"
	# Mark Elara's position as non-walkable
	_walkable[ELARA_POS.y][ELARA_POS.x] = false


func _create_npc_sprite(npc_name: String, grid_pos: Vector2i, fallback_color: Color) -> Sprite2D:
	var center := Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2, grid_pos.y * TILE_SIZE + TILE_SIZE / 2)

	if _char_atlas_available and NPC_SPRITES.has(npc_name):
		var sprite_name: StringName = NPC_SPRITES[npc_name]
		var sprite := _create_character_tile_sprite(center, sprite_name)
		sprite.name = npc_name
		_npc_layer.add_child(sprite)
		return sprite
	else:
		# ColorRect fallback — create a simple colored square
		var sprite := Sprite2D.new()
		sprite.name = npc_name
		sprite.position = center
		var img := Image.create(TILE_SIZE - 2, TILE_SIZE - 2, false, Image.FORMAT_RGBA8)
		img.fill(fallback_color)
		var tex := ImageTexture.create_from_image(img)
		sprite.texture = tex
		_npc_layer.add_child(sprite)
		return sprite


func _place_player() -> void:
	player_pos = PLAYER_SPAWN
	var center := Vector2(
		player_pos.x * TILE_SIZE + TILE_SIZE / 2,
		player_pos.y * TILE_SIZE + TILE_SIZE / 2,
	)

	if _char_atlas_available:
		player_sprite = _create_character_tile_sprite(center, PLAYER_SPRITE_NAME)
		player_sprite.name = "Player"
	else:
		# ColorRect fallback — blue square
		player_sprite = Sprite2D.new()
		player_sprite.name = "Player"
		player_sprite.position = center
		var img := Image.create(TILE_SIZE - 2, TILE_SIZE - 2, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.3, 0.5, 0.9, 1.0))
		var tex := ImageTexture.create_from_image(img)
		player_sprite.texture = tex

	_player_layer.add_child(player_sprite)

	# Center camera on player
	var camera := Camera2D.new()
	camera.name = "TavernCamera"
	camera.zoom = Vector2(2.0, 2.0)
	player_sprite.add_child(camera)
	camera.make_current()


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
	if new_pos.x < 0 or new_pos.x >= MAP_WIDTH or new_pos.y < 0 or new_pos.y >= MAP_HEIGHT:
		return

	# Check for door (exit)
	if TAVERN_LAYOUT[new_pos.y][new_pos.x] == "D":
		exit_triggered.emit()
		return

	# Check for NPC interaction (bump-to-interact)
	if _npc_positions.has(new_pos):
		# Don't spam dialogue while choices are pending
		if _nm and _nm.is_awaiting_choice():
			return
		var npc_id: String = _npc_positions[new_pos]
		var npc_profile: Dictionary = _npc_profiles.get(npc_id, {})
		var npc_display_name: String = npc_profile.get("name", npc_id)
		npc_interacted.emit(npc_display_name)

		# Send to orchestrator if available (with NPC profile context)
		if _oc and _oc.orchestrator_available:
			_oc.send_action("speak", npc_id, "", "", "", npc_profile)
		else:
			_handle_npc_interaction_local(npc_id, npc_profile)
		return

	# Check walkability
	if not _walkable[new_pos.y][new_pos.x]:
		# Bump interaction for special obstacles
		if _obstacle_interaction_active:
			return
		var obstacle: String = _obstacles.get(new_pos, "")
		match obstacle:
			"Q":
				_interact_quest_board()
			"M":
				_interact_memorial_wall()
			"s":
				_interact_shop()
			"S":
				_nm.add_narrative(
					"The [color=#d9d566]stairs[/color] lead up to the rooms. "
					+ "You could rest here."
				)
			"R":
				_nm.add_narrative(
					"The [color=#d9d566]room door[/color] is locked. "
					+ "Ask the barkeep about lodging."
				)
			"B":
				_nm.add_narrative(
					"The [color=#d9d566]bar counter[/color] is polished to a warm sheen."
				)
		return

	# Move the player
	player_pos = new_pos
	player_sprite.position = Vector2(
		player_pos.x * TILE_SIZE + TILE_SIZE / 2,
		player_pos.y * TILE_SIZE + TILE_SIZE / 2,
	)


## Handle NPC interaction locally when orchestrator is unavailable.
## Shows the NPC's greeting from their profile and offers hardcoded choices.
## On repeat interactions, shows a short acknowledgment instead of the full greeting.
func _handle_npc_interaction_local(npc_id: String, npc_profile: Dictionary) -> void:
	var npc_name: String = npc_profile.get("name", npc_id)
	var greeting: String = npc_profile.get("greeting", "...")

	# Track interaction count
	var interact_count: int = _npc_interacted.get(npc_id, 0)
	_npc_interacted[npc_id] = interact_count + 1

	# On repeat interactions, show a short acknowledgment and skip to choices
	if interact_count > 0:
		_handle_npc_repeat_interaction(npc_id, npc_name, interact_count)
		return

	match npc_id:
		"marta":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] looks up from polishing a mug. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				["Ask about the cellar", "Order a drink", "Ask about rumors"],
				func(index: int) -> void:
					match index:
						0:
							_nm.add_narrative(
								'"[i]Strange noises down there lately. '
								+ "I'll pay you well to clear it out.[/i]\""
							)
						1:
							_nm.add_narrative(
								'"[i]Coming right up. One ale, on the house '
								+ 'for a fellow adventurer.[/i]"'
							)
						2:
							_nm.add_narrative(
								"\"[i]Word is there's been disappearances on the "
								+ 'east road. Merchants, mostly.[/i]"'
							)
			)
		"old_tom":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] looks up from his ale with bloodshot eyes. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				["Ask about his adventures", "Ask about the area", "Buy him a drink"],
				func(index: int) -> void:
					match index:
						0:
							_nm.add_narrative(
								'"[i]Did I ever tell you about the time I fought '
								+ "a dragon? Well, it was more of a drake, but still... "
								+ 'nearly took my arm off.[/i]"'
							)
						1:
							_nm.add_narrative(
								'"[i]The old crypt north of town? Stay away from there, '
								+ "I say. But if you must go, bring fire. "
								+ 'The things down there hate fire.[/i]"'
							)
						2:
							_nm.add_narrative(
								'"[i]Well now, that\'s the spirit! You remind me of '
								+ "myself, thirty years ago. Here's a tip — never trust "
								+ 'a locked chest in a dungeon.[/i]"'
							)
			)
		"elara":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] glances at you from beneath her hood. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				["Ask who she is", "Ask about the east road", "Sit down quietly"],
				func(index: int) -> void:
					match index:
						0:
							_nm.add_narrative(
								"She regards you with pale eyes. "
								+ '"[i]Names are currency. I do not spend mine freely.[/i]"'
							)
						1:
							_nm.add_narrative(
								"A slight tilt of her head. "
								+ '"[i]The east road... yes. Something stirs there. '
								+ 'Not all who vanish are dead.[/i]"'
							)
						2:
							_nm.add_narrative(
								"You sit across from her in silence. After a long moment, "
								+ 'she nods approvingly. "[i]Patience. A rare quality.[/i]"'
							)
			)
		_:
			# Generic fallback for unknown NPCs
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] regards you. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)


## Handle repeat NPC interactions with varied short acknowledgments.
## Shows a brief line instead of the full greeting, then presents choices.
func _handle_npc_repeat_interaction(npc_id: String, npc_name: String, interact_count: int) -> void:
	# Varied acknowledgments per NPC — cycles through them
	var acknowledgments: Array[String] = []
	var choices: Array[String] = []
	var choice_callback: Callable

	match npc_id:
		"marta":
			acknowledgments = [
				"[color=#d9d566]%s[/color] is busy polishing mugs." % npc_name,
				"[color=#d9d566]%s[/color] nods at you from behind the bar." % npc_name,
				"[color=#d9d566]%s[/color] glances up. \"[i]Back again?[/i]\"" % npc_name,
			]
			choices = ["Ask about the cellar", "Order a drink", "Ask about rumors"]
			choice_callback = func(index: int) -> void:
				match index:
					0:
						_nm.add_narrative(
							'"[i]Strange noises down there lately. '
							+ "I'll pay you well to clear it out.[/i]\""
						)
					1:
						_nm.add_narrative(
							'"[i]Coming right up. One ale, on the house '
							+ 'for a fellow adventurer.[/i]"'
						)
					2:
						_nm.add_narrative(
							"\"[i]Word is there's been disappearances on the "
							+ 'east road. Merchants, mostly.[/i]"'
						)
		"old_tom":
			acknowledgments = [
				"[color=#d9d566]%s[/color] nods at you." % npc_name,
				"[color=#d9d566]%s[/color] grunts into his ale." % npc_name,
				"[color=#d9d566]%s[/color] squints at you. \"[i]You again, eh?[/i]\"" % npc_name,
			]
			choices = ["Ask about his adventures", "Ask about the area", "Buy him a drink"]
			choice_callback = func(index: int) -> void:
				match index:
					0:
						_nm.add_narrative(
							'"[i]Did I ever tell you about the time I fought '
							+ "a dragon? Well, it was more of a drake, but still... "
							+ 'nearly took my arm off.[/i]"'
						)
					1:
						_nm.add_narrative(
							'"[i]The old crypt north of town? Stay away from there, '
							+ "I say. But if you must go, bring fire. "
							+ 'The things down there hate fire.[/i]"'
						)
					2:
						_nm.add_narrative(
							'"[i]Well now, that\'s the spirit! You remind me of '
							+ "myself, thirty years ago. Here's a tip — never trust "
							+ 'a locked chest in a dungeon.[/i]"'
						)
		"elara":
			acknowledgments = [
				"[color=#d9d566]%s[/color] acknowledges you with a slight nod." % npc_name,
				"[color=#d9d566]%s[/color] watches you from beneath her hood." % npc_name,
				"[color=#d9d566]%s[/color] raises an eyebrow but says nothing." % npc_name,
			]
			choices = ["Ask who she is", "Ask about the east road", "Sit down quietly"]
			choice_callback = func(index: int) -> void:
				match index:
					0:
						_nm.add_narrative(
							"She regards you with pale eyes. "
							+ '"[i]Names are currency. I do not spend mine freely.[/i]"'
						)
					1:
						_nm.add_narrative(
							"A slight tilt of her head. "
							+ '"[i]The east road... yes. Something stirs there. '
							+ 'Not all who vanish are dead.[/i]"'
						)
					2:
						_nm.add_narrative(
							"You sit across from her in silence. After a long moment, "
							+ 'she nods approvingly. "[i]Patience. A rare quality.[/i]"'
						)
		_:
			# Generic fallback for unknown NPCs
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] acknowledges you." % npc_name
			)
			return

	# Pick a varied acknowledgment line (cycle through the list)
	var ack_index: int = (interact_count - 1) % acknowledgments.size()
	_nm.add_narrative(acknowledgments[ack_index])
	_nm.present_choices(choices, choice_callback)


## --- Obstacle Interaction Handlers ---


## L1: Quest board interaction — shows placeholder quest list with choices.
func _interact_quest_board() -> void:
	_obstacle_interaction_active = true
	_nm.add_narrative(
		"[color=#6cb4c4][b]Quest Board[/b][/color]\n"
		+ "You approach the wooden board nailed to the wall. "
		+ "A few rusty pins hold scraps of parchment, but most have "
		+ "faded beyond reading. One notice remains legible:"
	)
	_nm.add_narrative(
		"[color=#d9d566]\"Adventurers Wanted\"[/color]\n"
		+ "[i]No quests available yet — check back after your first adventure. "
		+ "The board fills as the world awakens.[/i]"
	)
	_nm.present_choices(
		["Look more closely", "Step away"],
		func(index: int) -> void:
			_obstacle_interaction_active = false
			match index:
				0:
					_nm.add_narrative(
						"You squint at the faded parchment scraps. Most are old "
						+ "bounties long since claimed, shopping lists someone pinned "
						+ "by mistake, and a crude drawing of a dragon labeled "
						+ "\"[i]Bort wuz here.[/i]\""
					)
				1:
					_nm.add_narrative(
						"You turn away from the quest board. Perhaps the barkeep "
						+ "knows of work that needs doing."
					)
	)


## L2: Shop interaction — shows a list of basic items with prices.
func _interact_shop() -> void:
	_obstacle_interaction_active = true
	_nm.add_narrative(
		"[color=#6cb4c4][b]General Store[/b][/color]\n"
		+ "You lean over the shop counter. A hand-written price list "
		+ "is tacked to the wall behind it:"
	)
	_nm.add_narrative(
		"[color=#d9d566]Wares for Sale:[/color]\n"
		+ "  [color=#d9d566]Health Potion[/color] ........ 50 gp\n"
		+ "  [color=#d9d566]Torch[/color] .................. 1 gp\n"
		+ "  [color=#d9d566]Rations (1 day)[/color] ....... 5 sp\n"
		+ "  [color=#d9d566]Rope, 50 ft[/color] ........... 1 gp\n"
		+ "  [color=#d9d566]Antidote[/color] .............. 50 gp"
	)
	_nm.present_choices(
		["Browse the Health Potions", "Ask about special stock", "Step away"],
		func(index: int) -> void:
			_obstacle_interaction_active = false
			match index:
				0:
					_nm.add_narrative(
						"You eye the row of small red vials behind the counter. "
						+ "They look genuine enough, but the shopkeeper is nowhere to be seen. "
						+ "[i](Purchasing coming soon.)[/i]"
					)
				1:
					_nm.add_narrative(
						"A small sign reads: \"[i]Ask about enchanted items — "
						+ "by appointment only.[/i]\" The counter remains unattended. "
						+ "[i](Special stock coming soon.)[/i]"
					)
				2:
					_nm.add_narrative(
						"You step back from the shop counter. The prices seem "
						+ "fair enough — you'll return when the shopkeeper is about."
					)
	)


## L3: Memorial wall interaction — shows names of fallen characters.
func _interact_memorial_wall() -> void:
	_obstacle_interaction_active = true
	_nm.add_narrative(
		"[color=#6cb4c4][b]Memorial Wall[/b][/color]\n"
		+ "A solemn bronze plaque is set into the stone wall, "
		+ "surrounded by small candle-stubs and dried flowers."
	)

	# Try to read fallen heroes from memorial file
	var fallen_names: Array[String] = _load_fallen_heroes()
	if fallen_names.size() > 0:
		var names_text := ""
		for hero_name: String in fallen_names:
			names_text += "  [color=#d44e4e]%s[/color]\n" % hero_name
		_nm.add_narrative(
			"[color=#d9d566]In Memoriam:[/color]\n" + names_text
			+ "[i]May they find peace beyond the veil.[/i]"
		)
	else:
		_nm.add_narrative(
			"The plaque reads:\n"
			+ "[i]\"No fallen heroes... yet. May this wall remain bare, "
			+ "but the brave know it never does for long.\"[/i]"
		)

	_nm.present_choices(
		["Pay your respects", "Step away"],
		func(index: int) -> void:
			_obstacle_interaction_active = false
			match index:
				0:
					_nm.add_narrative(
						"You bow your head for a moment of silence. "
						+ "The candlelight flickers as if in acknowledgement."
					)
				1:
					_nm.add_narrative(
						"You turn from the memorial wall, reminded that "
						+ "every adventure carries a price."
					)
	)


## Load fallen hero names from the memorial file (user://memorial.json).
## Returns an empty array if no memorial file exists.
func _load_fallen_heroes() -> Array[String]:
	var names: Array[String] = []
	var memorial_path := "user://memorial.json"
	if not FileAccess.file_exists(memorial_path):
		return names

	var file := FileAccess.open(memorial_path, FileAccess.READ)
	if not file:
		return names

	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Variant = json.data
		if data is Dictionary and data.has("fallen_heroes"):
			var heroes: Variant = data["fallen_heroes"]
			if heroes is Array:
				for entry: Variant in heroes:
					if entry is Dictionary:
						var hero_name: String = entry.get("name", "Unknown")
						var hero_class: String = entry.get("class", "")
						var hero_level: String = str(entry.get("level", ""))
						var display := hero_name
						if hero_class != "" or hero_level != "":
							display += " — "
							if hero_class != "":
								display += hero_class
							if hero_level != "":
								display += " Lv.%s" % hero_level
						names.append(display)
					elif entry is String:
						names.append(entry)
	file.close()
	return names
