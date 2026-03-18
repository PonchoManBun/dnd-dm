class_name TavernRenderer
extends Node2D

## Renders the tavern using TileMapLayers following MapRenderer's proven patterns.
## 4 layers: floor (indoor tiles), walls (world tiles), furniture (world tiles),
## decoration (indoor tiles). Spawns warm-colored DustMotes for atmosphere.
## Supports data-driven tile_legend from JSON or hardcoded fallback constants.

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var furniture_layer: TileMapLayer
var decoration_layer: TileMapLayer
var dust_motes: Array[DustMotes] = []

# Fallback furniture tile mappings (used when no tile_legend in data)
const _BAR_TILE := &"decor-5"
const _TABLE_TILE := &"decor-25"
const _CHAIR_TILE := &"decor-24"
const _QUEST_BOARD_TILE := &"decor-0"
const _SHOP_TILE := &"decor-0"
const _STAIRS_TILE := &"tile-28"
const _DOOR_TILE := &"doors0-0"
const _MEMORIAL_DECOR_TILE := &"decor-32"
const _FLOOR_TILE := &"indoor-77"

# Floor tile variants for visual variety (position-hashed, deterministic)
const _FLOOR_VARIANTS: Array[StringName] = [
	&"indoor-76", &"indoor-77", &"indoor-77", &"indoor-77",  # weight toward default
	&"indoor-78", &"indoor-79", &"indoor-80", &"indoor-81", &"indoor-83",
]

# Char -> tile name fallback (matches original hardcoded behavior)
const _FALLBACK_CHAR_TILES: Dictionary = {
	"B": &"decor-5",
	"T": &"decor-25",
	"c": &"decor-24",
	"Q": &"decor-0",
	"s": &"decor-0",
	"S": &"tile-28",
	"D": &"doors0-0",
	"M": &"decor-32",
}


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

	var map_w: int = tavern_map.map_width
	var map_h: int = tavern_map.map_height
	var tl: Dictionary = tavern_map.tile_legend
	var use_legend: bool = not tl.is_empty()

	# Determine floor tile name from legend or fallback
	var floor_tile_name: StringName = _FLOOR_TILE
	if use_legend and tl.has("."):
		var dot_entry: Variant = tl["."]
		if dot_entry is Dictionary and (dot_entry as Dictionary).has("tile_name"):
			floor_tile_name = StringName(str((dot_entry as Dictionary)["tile_name"]))

	for y in range(map_h):
		if y >= tavern_map.layout.size():
			break
		for x in range(map_w):
			if x >= (tavern_map.layout[y] as String).length():
				break
			var pos := Vector2i(x, y)
			var ch: String = tavern_map.layout[y][x]

			# Get legend entry for this char
			var legend: Dictionary = {}
			if use_legend and tl.has(ch):
				var entry: Variant = tl[ch]
				if entry is Dictionary:
					legend = entry

			var is_wall_like: bool = legend.get("wall_like", false) if not legend.is_empty() else (ch == "#" or ch == "M" or ch == "R")

			# Draw floor under everything except pure walls
			if not is_wall_like or legend.get("base", "") == "wall":
				if ch != "#":
					# Use explicit tile_name for special floor types (carpet, stone),
					# otherwise apply position-hashed variation for wood floors
					var actual_floor: StringName = floor_tile_name
					if ch == "." or ch == "*" or ch == "c" or ch == "n":
						actual_floor = _get_floor_tile(pos)
					elif use_legend and not legend.is_empty():
						var leg_tile: String = legend.get("tile_name", "")
						if leg_tile != "" and legend.get("walkable", false):
							actual_floor = StringName(leg_tile)
					floor_layer.set_cell(pos, 0, IndoorTiles.get_coords(actual_floor))

			if is_wall_like:
				# Wall-like tiles get directional wall rendering
				var wall_tile: StringName = _get_wall_tile(pos, tavern_map, map_w, map_h)
				wall_layer.set_cell(pos, 0, WorldTiles.get_coords(wall_tile))
				# Some wall-like tiles have a furniture overlay (e.g., memorial)
				var overlay_tile: String = legend.get("tile_name", "")
				if overlay_tile != "":
					var atlas: String = legend.get("atlas", "world")
					if atlas == "indoor":
						decoration_layer.set_cell(pos, 0, IndoorTiles.get_coords(StringName(overlay_tile)))
					else:
						furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(StringName(overlay_tile)))
			elif use_legend and not legend.is_empty():
				# Data-driven: render from tile_legend
				var tile_name_str: String = legend.get("tile_name", "")
				if tile_name_str != "":
					var atlas: String = legend.get("atlas", "world")
					var tile_sn := StringName(tile_name_str)
					if atlas == "indoor":
						# Indoor tiles go on decoration layer (over floor)
						if ch != ".":
							decoration_layer.set_cell(pos, 0, IndoorTiles.get_coords(tile_sn))
					else:
						furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(tile_sn))
			else:
				# Fallback: hardcoded char mapping
				if _FALLBACK_CHAR_TILES.has(ch):
					var tile_sn: StringName = _FALLBACK_CHAR_TILES[ch]
					furniture_layer.set_cell(pos, 0, WorldTiles.get_coords(tile_sn))

	_spawn_dust_motes(tavern_map)


func _get_floor_tile(pos: Vector2i) -> StringName:
	# Deterministic hash — same position always gets same variant
	var h: int = absi((pos.x * 374761393 + pos.y * 668265263)) % _FLOOR_VARIANTS.size()
	return _FLOOR_VARIANTS[h]


func _get_wall_tile(pos: Vector2i, tavern_map: RefCounted, map_w: int, map_h: int) -> StringName:
	var x: int = pos.x
	var y: int = pos.y
	var n: bool = y > 0 and tavern_map.is_wall_like_char(tavern_map.get_char_at(Vector2i(x, y - 1)))
	var s: bool = y < map_h - 1 and tavern_map.is_wall_like_char(tavern_map.get_char_at(Vector2i(x, y + 1)))
	var e: bool = x < map_w - 1 and tavern_map.is_wall_like_char(tavern_map.get_char_at(Vector2i(x + 1, y)))
	var w: bool = x > 0 and tavern_map.is_wall_like_char(tavern_map.get_char_at(Vector2i(x - 1, y)))

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


func _spawn_dust_motes(tavern_map: RefCounted) -> void:
	# Clear existing dust motes
	for mote in dust_motes:
		mote.queue_free()
	dust_motes.clear()

	var map_w: int = tavern_map.map_width
	var map_h: int = tavern_map.map_height
	var ts: int = tavern_map.tile_size

	# Spawn a warm-colored dust mote covering the tavern interior
	var dust_scene := preload("res://scenes/fx/dust_motes.tscn")
	var dust: DustMotes = dust_scene.instantiate()

	# Center on the tavern interior
	var center_x: int = map_w / 2
	var center_y: int = map_h / 2
	dust.position = Vector2(center_x * ts, center_y * ts)

	# Cover the entire interior
	var half_w: float = (map_w * ts) / 2.0
	var half_h: float = (map_h * ts) / 2.0
	dust.set_rect(Rect2(-half_w, -half_h, map_w * ts, map_h * ts))

	# Dust mote color from atmosphere or fallback
	var atm: Dictionary = tavern_map.atmosphere
	var dust_color := Color(1.0, 0.9, 0.7, 0.8)
	if atm.has("dust_mote_color"):
		var c: Array = atm["dust_mote_color"]
		if c.size() >= 4:
			dust_color = Color(float(c[0]), float(c[1]), float(c[2]), float(c[3]))
	dust.modulate = dust_color

	add_child(dust)
	dust_motes.append(dust)
