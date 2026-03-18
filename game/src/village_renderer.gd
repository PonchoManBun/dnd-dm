class_name VillageRenderer
extends Node2D

## Renders the village using TileMapLayers.
## 6 layers: ground (world: floor-2 grass, floor-1 stone), floor (world: floor-3 wood),
## walls (world: wall-11), furniture (world: decor), decoration (indoor), objects (outdoor).
## Supports both outdoor terrain and visible building interiors.

var ground_layer: TileMapLayer
var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var furniture_layer: TileMapLayer
var decoration_layer: TileMapLayer  # indoor-atlas items (shelves, beds, carpets)
var objects_layer: TileMapLayer
var dust_motes: Array[Node2D] = []

# Ground tile variants for visual variety — vibrant green grass (Floor block 2)
const _GROUND_VARIANTS: Array[StringName] = [
	&"floor-2-nsew", &"floor-2-nsew", &"floor-2-nsew",
]

# Floor tile variants for indoor variety — warm wood (Floor block 3)
const _FLOOR_VARIANTS: Array[StringName] = [
	&"floor-3-nsew", &"floor-3-nsew", &"floor-3-nsew",
]

# Stone path tile — gray cobblestone (Floor block 1)
const _STONE_PATH_TILE: StringName = &"floor-1-nsew"

# Fallback furniture tile mappings (used when no tile_legend atlas info)
const _FALLBACK_CHAR_TILES: Dictionary = {
	"B": &"decor-5",
	"T": &"decor-25",
	"c": &"decor-24",
	"D": &"doors0-0",
	"G": &"tile-28",
	"A": &"decor-0",
	"b": &"decor-48",
	"k": &"decor-49",
}



func _ready() -> void:
	_initialize_layers()


func _initialize_layers() -> void:
	var outdoor_tileset: TileSet = preload("res://assets/generated/outdoor_tiles.tres")
	outdoor_tileset.tile_size = Vector2i(16, 16)
	var indoor_tileset: TileSet = preload("res://assets/generated/indoor_tiles.tres")
	indoor_tileset.tile_size = Vector2i(16, 16)
	var world_tileset: TileSet = preload("res://assets/generated/world_tiles.tres")
	world_tileset.tile_size = Vector2i(16, 16)

	# Layer 1: Ground (bottom) — world tiles for grass (floor-2), stone paths (floor-1)
	ground_layer = TileMapLayer.new()
	ground_layer.name = "Ground"
	ground_layer.tile_set = world_tileset
	add_child(ground_layer)

	# Layer 2: Floor — world tiles for indoor wood (floor-3)
	floor_layer = TileMapLayer.new()
	floor_layer.name = "Floor"
	floor_layer.tile_set = world_tileset
	add_child(floor_layer)

	# Layer 3: Walls — world tiles (wall-11 directional variants)
	wall_layer = TileMapLayer.new()
	wall_layer.name = "Walls"
	wall_layer.tile_set = world_tileset
	add_child(wall_layer)

	# Layer 4: Furniture — world tiles (decor sprites: tables, chairs, bar, etc.)
	furniture_layer = TileMapLayer.new()
	furniture_layer.name = "Furniture"
	furniture_layer.tile_set = world_tileset
	add_child(furniture_layer)

	# Layer 5: Decoration — indoor tiles (shelves, beds, carpets over floor)
	decoration_layer = TileMapLayer.new()
	decoration_layer.name = "Decoration"
	decoration_layer.tile_set = indoor_tileset
	add_child(decoration_layer)

	# Layer 6: Objects — outdoor tiles (trees, fences, outdoor decorations)
	objects_layer = TileMapLayer.new()
	objects_layer.name = "Objects"
	objects_layer.tile_set = outdoor_tileset
	add_child(objects_layer)


func render_village(village_map: RefCounted) -> void:
	ground_layer.clear()
	floor_layer.clear()
	wall_layer.clear()
	furniture_layer.clear()
	decoration_layer.clear()
	objects_layer.clear()

	var map_w: int = village_map.map_width
	var map_h: int = village_map.map_height
	var tl: Dictionary = village_map.tile_legend
	var use_legend: bool = not tl.is_empty()

	for y in range(map_h):
		if y >= village_map.layout.size():
			break
		for x in range(map_w):
			if x >= (village_map.layout[y] as String).length():
				break
			var pos := Vector2i(x, y)
			var ch: String = village_map.layout[y][x]

			# Get legend entry for this char
			var legend: Dictionary = {}
			if use_legend and tl.has(ch):
				var entry: Variant = tl[ch]
				if entry is Dictionary:
					legend = entry

			var is_wall_like: bool = legend.get("wall_like", false) if not legend.is_empty() else (ch == "#")
			var atlas: String = legend.get("atlas", "") if not legend.is_empty() else ""

			# --- Layer 1: Ground (always render base terrain) ---
			if atlas == "world" and legend.get("walkable", false) and not legend.get("wall_like", false):
				# World-atlas walkable: grass (floor-2), stone paths (floor-1), dirt
				var tile_sn := StringName(legend.get("tile_name", "floor-2-nsew"))
				if ch == "w":
					tile_sn = _get_ground_tile(pos)
				ground_layer.set_cell(pos, 0, WorldTiles.get_coords(tile_sn))
			elif atlas == "outdoor" and legend.get("walkable", false):
				# Legacy outdoor walkable tiles (keep for compatibility)
				var tile_sn := StringName(legend.get("tile_name", "floor-2-nsew"))
				ground_layer.set_cell(pos, 0, WorldTiles.get_coords(_get_ground_tile(pos)))
			else:
				# Everything else: render grass underneath as base
				ground_layer.set_cell(pos, 0, WorldTiles.get_coords(_get_ground_tile(pos)))

			# --- Layer 2: Floor (wood tiles inside buildings) ---
			# Render floor under any non-wall tile that is inside a building
			if not is_wall_like and atlas != "outdoor":
				var inside: bool = village_map.is_inside_building(pos)
				if inside:
					floor_layer.set_cell(pos, 0, WorldTiles.get_coords(_get_floor_tile(pos)))

			# --- Layer 3: Walls (directional wall rendering) ---
			if is_wall_like:
				var wall_tile: StringName = _get_wall_tile(pos, village_map, map_w, map_h)
				wall_layer.set_cell(pos, 0, WorldTiles.get_coords(wall_tile))

			# --- Layer 4: Furniture (world tiles — tables, chairs, doors, etc.) ---
			# Skip walkable ground tiles (grass, paths) — those are rendered on the ground layer
			var is_ground_tile: bool = legend.get("walkable", false) and (ch == "w" or ch == "d")
			if not is_wall_like and atlas == "world" and not is_ground_tile:
				var tile_name_str: String = legend.get("tile_name", "")
				if tile_name_str != "":
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(StringName(tile_name_str)))
			elif not is_wall_like and not use_legend and _FALLBACK_CHAR_TILES.has(ch):
				var tile_sn: StringName = _FALLBACK_CHAR_TILES[ch]
				furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(tile_sn))

			# --- Layer 5: Decoration (indoor tiles — shelves, beds, carpets) ---
			if not is_wall_like and atlas == "indoor" and ch != ".":
				var tile_name_str: String = legend.get("tile_name", "")
				if tile_name_str != "":
					decoration_layer.set_cell(pos, 0, IndoorTiles.get_coords(StringName(tile_name_str)))

			# --- Layer 6: Objects (outdoor tiles — trees, fences, bushes) ---
			if atlas == "outdoor" and not legend.get("walkable", true):
				var tile_name_str: String = legend.get("tile_name", "")
				if tile_name_str != "":
					objects_layer.set_cell(pos, 0, OutdoorTiles.get_coords(StringName(tile_name_str)))

	_spawn_dust_motes(village_map)


func _get_ground_tile(pos: Vector2i) -> StringName:
	# Deterministic hash — same position always gets same variant
	var h: int = absi((pos.x * 374761393 + pos.y * 668265263)) % _GROUND_VARIANTS.size()
	return _GROUND_VARIANTS[h]


func _get_floor_tile(pos: Vector2i) -> StringName:
	# Deterministic hash — same position always gets same variant
	var h: int = absi((pos.x * 374761393 + pos.y * 668265263)) % _FLOOR_VARIANTS.size()
	return _FLOOR_VARIANTS[h]


func _get_wall_tile(pos: Vector2i, village_map: RefCounted, map_w: int, map_h: int) -> StringName:
	var x: int = pos.x
	var y: int = pos.y
	var n: bool = y > 0 and village_map.is_wall_like_char(village_map.get_char_at(Vector2i(x, y - 1)))
	var s: bool = y < map_h - 1 and village_map.is_wall_like_char(village_map.get_char_at(Vector2i(x, y + 1)))
	var e: bool = x < map_w - 1 and village_map.is_wall_like_char(village_map.get_char_at(Vector2i(x + 1, y)))
	var w: bool = x > 0 and village_map.is_wall_like_char(village_map.get_char_at(Vector2i(x - 1, y)))

	# All four directions
	if n and s and e and w:
		return &"wall-11-nsew"
	# Three directions
	if n and s and e and not w:
		return &"wall-11-nse"
	if n and s and not e and w:
		return &"wall-11-nsw"
	if n and not s and e and w:
		return &"wall-11-new"
	if not n and s and e and w:
		return &"wall-11-sew"
	# Two directions
	if n and s and not e and not w:
		return &"wall-11-ns"
	if not n and not s and e and w:
		return &"wall-11-ew"
	if n and e and not s and not w:
		return &"wall-11-ne"
	if n and w and not s and not e:
		return &"wall-11-nw"
	if s and e and not n and not w:
		return &"wall-11-se"
	if s and w and not n and not e:
		return &"wall-11-sw"
	# One direction
	if not n and not s and not w and e:
		return &"wall-11-ew"
	if not n and not s and w and not e:
		return &"wall-11-ew"
	if n and not s and not e and not w:
		return &"wall-11-n"
	if not n and s and not e and not w:
		return &"wall-11-ns"

	return &"wall-11-lone"


func _spawn_dust_motes(village_map: RefCounted) -> void:
	# Clear existing dust motes
	for mote: Node2D in dust_motes:
		mote.queue_free()
	dust_motes.clear()

	var map_w: int = village_map.map_width
	var map_h: int = village_map.map_height
	var ts: int = village_map.tile_size

	# Spawn a light-colored dust mote covering the village
	var dust_scene := preload("res://scenes/fx/dust_motes.tscn")
	var dust: Node2D = dust_scene.instantiate()

	# Center on the village
	var center_x: int = map_w / 2
	var center_y: int = map_h / 2
	dust.position = Vector2(center_x * ts, center_y * ts)

	# Cover the entire area
	var half_w: float = (map_w * ts) / 2.0
	var half_h: float = (map_h * ts) / 2.0
	if dust.has_method("set_rect"):
		dust.set_rect(Rect2(-half_w, -half_h, map_w * ts, map_h * ts))

	# Outdoor dust motes — lighter, more transparent
	dust.modulate = Color(1.0, 1.0, 0.9, 0.4)

	add_child(dust)
	dust_motes.append(dust)
