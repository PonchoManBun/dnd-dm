class_name TavernRenderer
extends Node2D

## Renders the tavern using TileMapLayers following MapRenderer's proven patterns.
## 4 layers: floor (indoor tiles), walls (world tiles), furniture (world tiles),
## decoration (indoor tiles). Spawns warm-colored DustMotes for atmosphere.

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var furniture_layer: TileMapLayer
var decoration_layer: TileMapLayer
var dust_motes: Array[DustMotes] = []

# Furniture tile mappings (world_tiles atlas — proven sprites from Phase 1)
const BAR_TILE := &"decor-5"
const TABLE_TILE := &"decor-25"
const CHAIR_TILE := &"decor-24"
const QUEST_BOARD_TILE := &"decor-0"
const SHOP_TILE := &"decor-0"
const STAIRS_TILE := &"tile-28"
const DOOR_TILE := &"doors0-0"
const MEMORIAL_DECOR_TILE := &"decor-32"

# Floor tile mapping (indoor_tiles atlas)
const FLOOR_TILE := &"indoor-77"


func _ready() -> void:
	_initialize_layers()


func _initialize_layers() -> void:
	var indoor_tileset: TileSet = preload("res://assets/generated/indoor_tiles.tres")
	indoor_tileset.tile_size = Vector2i(16, 16)
	var world_tileset: TileSet = preload("res://assets/generated/world_tiles.tres")
	world_tileset.tile_size = Vector2i(16, 16)

	# Floor (bottom) — indoor tiles for wood planks
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = indoor_tileset
	add_child(floor_layer)

	# Walls — world tiles (16 directional variants)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = world_tileset
	add_child(wall_layer)

	# Furniture — world tiles (decor sprites: tables, chairs, bar, etc.)
	furniture_layer = TileMapLayer.new()
	furniture_layer.name = "Furniture"
	furniture_layer.tile_set = world_tileset
	add_child(furniture_layer)

	# Decoration — indoor tiles (candles, accents)
	decoration_layer = TileMapLayer.new()
	decoration_layer.name = "Decoration"
	decoration_layer.tile_set = indoor_tileset
	add_child(decoration_layer)


func render_tavern(tavern_map: RefCounted) -> void:
	floor_layer.clear()
	wall_layer.clear()
	furniture_layer.clear()
	decoration_layer.clear()

	var map_w: int = tavern_map.MAP_WIDTH
	var map_h: int = tavern_map.MAP_HEIGHT
	var layout: Array[String] = tavern_map.TAVERN_LAYOUT

	for y in range(map_h):
		for x in range(map_w):
			var pos := Vector2i(x, y)
			var ch: String = layout[y][x]

			# Draw floor under everything except walls
			if ch != "#":
				floor_layer.set_cell(pos, 0, IndoorTiles.get_coords(FLOOR_TILE))

			match ch:
				"#":
					var wall_tile: StringName = _get_wall_tile(pos, tavern_map, layout, map_w, map_h)
					wall_layer.set_cell(pos, 0, WorldTiles.get_coords(wall_tile))
				"B":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(BAR_TILE))
				"T":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(TABLE_TILE))
				"c":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(CHAIR_TILE))
				"Q":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(QUEST_BOARD_TILE))
				"s":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(SHOP_TILE))
				"S":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(STAIRS_TILE))
				"M":
					# Memorial: wall base + decoration overlay
					var wall_tile: StringName = _get_wall_tile(pos, tavern_map, layout, map_w, map_h)
					wall_layer.set_cell(pos, 0, WorldTiles.get_coords(wall_tile))
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(MEMORIAL_DECOR_TILE))
				"R":
					# Room alcove: wall tile
					var wall_tile: StringName = _get_wall_tile(pos, tavern_map, layout, map_w, map_h)
					wall_layer.set_cell(pos, 0, WorldTiles.get_coords(wall_tile))
				"D":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(DOOR_TILE))

	_spawn_dust_motes(map_w, map_h)


func _get_wall_tile(pos: Vector2i, tavern_map: RefCounted, layout: Array[String], map_w: int, map_h: int) -> StringName:
	var x: int = pos.x
	var y: int = pos.y
	var n: bool = y > 0 and tavern_map.is_wall_like_char(layout[y - 1][x])
	var s: bool = y < map_h - 1 and tavern_map.is_wall_like_char(layout[y + 1][x])
	var e: bool = x < map_w - 1 and tavern_map.is_wall_like_char(layout[y][x + 1])
	var w: bool = x > 0 and tavern_map.is_wall_like_char(layout[y][x - 1])

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


func _spawn_dust_motes(map_w: int, map_h: int) -> void:
	# Clear existing dust motes
	for mote in dust_motes:
		mote.queue_free()
	dust_motes.clear()

	# Spawn a warm-colored dust mote covering the tavern interior
	var dust_scene := preload("res://scenes/fx/dust_motes.tscn")
	var dust: DustMotes = dust_scene.instantiate()

	# Center on the tavern interior
	var center_x: int = map_w / 2
	var center_y: int = map_h / 2
	dust.position = Vector2(center_x * 16, center_y * 16)

	# Cover the entire interior
	var half_w: float = (map_w * 16) / 2.0
	var half_h: float = (map_h * 16) / 2.0
	dust.set_rect(Rect2(-half_w, -half_h, map_w * 16, map_h * 16))

	# Warm tint for tavern dust motes
	dust.modulate = Color(1.0, 0.9, 0.7, 0.8)

	add_child(dust)
	dust_motes.append(dust)
