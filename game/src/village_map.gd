class_name VillageMap
extends RefCounted

## Pure data model for the village layout.
## No scene tree dependencies — used by VillageRenderer and VillageController.
## Supports loading from JSON (Forge-generated) or hardcoded fallback.
## The village is the main hub, containing buildings with visible interiors.

# Map dimensions (set by JSON or fallback)
var map_width: int = 40
var map_height: int = 30
var tile_size: int = 16

# Layout and metadata
var layout: Array[String] = []
var tile_legend: Dictionary = {}
var buildings: Array[Dictionary] = []  # {id, name, type, door_positions: Array, rect: {x,y,w,h}}
var npcs: Array[Dictionary] = []
var player_spawn: Vector2i = Vector2i(15, 27)
var player_sprite_name: StringName = &"player-4"
var village_name: String = "Hommlet"
var location_type: String = "village"

# Exits from the village (e.g. dungeon gate)
var exits: Dictionary = {}  # Vector2i -> String (destination scene path)

# NPC data from JSON (alias for npcs to match tavern pattern)
var npc_data: Array[Dictionary] = []

# Atmosphere data from JSON
var atmosphere: Dictionary = {}

# Entrance narration from JSON
var entrance_narration: Array[String] = []

# Whether this was loaded from JSON
var loaded_from_json: bool = false
var json_path: String = ""

# Walkable grid (true = walkable)
var _walkable: Array = []  # Array of Array of bool

# Obstacle dictionary (grid_pos -> char code)
var _obstacles: Dictionary = {}  # Vector2i -> String

# NPC positions (grid_pos -> npc_id)
var _npc_positions: Dictionary = {}  # Vector2i -> String

# --- Hardcoded fallback constants ---
const _FALLBACK_WIDTH := 30
const _FALLBACK_HEIGHT := 22

# A small village with a tavern (left) and blacksmith (right), grass, paths, trees
# Legend: w=grass, d=dirt_path, t=tree, #=wall, .=floor, B=bar_counter,
#         T=table, c=chair, D=door, G=dungeon_gate, *=npc_slot, b=barrel,
#         k=crate, f=fence, A=anvil, F=forge_fire
const _FALLBACK_LAYOUT: Array[String] = [
	"tttttttttttttttttttttttttttttt",  # 0
	"twwwwwwwwwwwwwwwwwwwwwwwwwwwwt",  # 1
	"tww######wwwwwwwww######wwwwwt",  # 2
	"tww#..*B#wwwwwwwww#..kb#wwwwwt",  # 3
	"tww#..T.#wwwwwwwww#....#wwwwwt",  # 4
	"tww#..Tc#wwwwwwwww#.A..#wwwwwt",  # 5
	"tww#....#wwwwwwwww#..*.#wwwwwt",  # 6
	"tww###D##wwwwwwwww###D##wwwwwt",  # 7
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 8
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 9
	"twwwwwddddddddddddddddwwwwwwwt",  # 10
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 11
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 12
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 13
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 14
	"twwwwwdwwwwwwwfbfwwwwdwwwwwwwt",  # 15
	"twwwwwdwwwwwwwfwfwwwwdwwwwwwwt",  # 16
	"twwwwwdwwwwwwwwwwwwwwdwwwwwwwt",  # 17
	"twwwwwddddddddddddddddwwwwwwwt",  # 18
	"twwwwwwwwwwwwwdwwwwwwwwwwwwwwt",  # 19
	"twwwwwwwwwwwwwGwwwwwwwwwwwwwwt",  # 20
	"tttttttttttttttttttttttttttttt",  # 21
]

const _FALLBACK_LEGEND: Dictionary = {
	"w": {"name": "grass", "walkable": true, "atlas": "world", "tile_name": "floor-5-nsew"},
	"d": {"name": "dirt_path", "walkable": true, "atlas": "world", "tile_name": "floor-6-nsew"},
	"t": {"name": "tree", "walkable": false, "atlas": "outdoor", "tile_name": "tree0-0"},
	"#": {"name": "wall", "walkable": false, "wall_like": true},
	".": {"name": "floor", "walkable": true, "atlas": "indoor", "tile_name": "indoor-77"},
	"B": {"name": "bar_counter", "walkable": false, "atlas": "world", "tile_name": "decor-5"},
	"T": {"name": "table", "walkable": false, "atlas": "world", "tile_name": "decor-25"},
	"c": {"name": "chair", "walkable": true, "atlas": "world", "tile_name": "decor-24"},
	"D": {"name": "door", "walkable": true, "atlas": "world", "tile_name": "doors0-0"},
	"G": {"name": "dungeon_gate", "walkable": true, "atlas": "world", "tile_name": "tile-28"},
	"*": {"name": "npc_slot", "walkable": false, "is_npc_slot": true},
	"b": {"name": "barrel", "walkable": false, "atlas": "world", "tile_name": "decor-48"},
	"k": {"name": "crate", "walkable": false, "atlas": "world", "tile_name": "decor-49"},
	"f": {"name": "fence", "walkable": false, "atlas": "outdoor", "tile_name": "fence-0"},
	"A": {"name": "anvil", "walkable": false, "atlas": "world", "tile_name": "decor-0"},
}


func _init() -> void:
	_use_fallback()


## Load village from a JSON file. Returns a VillageMap instance.
static func from_json(path: String) -> VillageMap:
	var vm := VillageMap.new()
	if vm._load_json(path):
		return vm
	# JSON load failed — fallback already in place from _init()
	push_warning("VillageMap: Failed to load '%s', using hardcoded fallback" % path)
	return vm


func _load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("VillageMap: JSON file not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("VillageMap: Cannot open %s" % path)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("VillageMap: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("VillageMap: JSON root must be a dictionary in %s" % path)
		return false

	var d: Dictionary = data

	# Required fields
	if not d.has("layout") or not d.has("tile_legend") or not d.has("width") or not d.has("height"):
		push_warning("VillageMap: Missing required fields in %s" % path)
		return false

	# Populate from JSON
	map_width = int(d["width"])
	map_height = int(d["height"])
	tile_size = int(d.get("tile_size", 16))
	village_name = str(d.get("name", "Unknown Village"))
	location_type = str(d.get("location_type", "village"))

	# Layout
	layout = []
	var raw_layout: Array = d["layout"]
	for row: Variant in raw_layout:
		layout.append(str(row))

	# Tile legend
	tile_legend = {}
	var raw_legend: Dictionary = d["tile_legend"]
	for ch: Variant in raw_legend:
		tile_legend[str(ch)] = raw_legend[ch]

	# Player spawn
	if d.has("player_spawn") and d["player_spawn"] is Array:
		var sp: Array = d["player_spawn"]
		if sp.size() >= 2:
			player_spawn = Vector2i(int(sp[0]), int(sp[1]))

	# Player sprite
	if d.has("player_sprite"):
		player_sprite_name = StringName(str(d["player_sprite"]))

	# Buildings
	buildings = []
	if d.has("buildings") and d["buildings"] is Array:
		for bld: Variant in d["buildings"]:
			if bld is Dictionary:
				buildings.append(bld as Dictionary)

	# NPCs
	npc_data = []
	npcs = []
	if d.has("npcs") and d["npcs"] is Array:
		for npc: Variant in d["npcs"]:
			if npc is Dictionary:
				npc_data.append(npc as Dictionary)
				npcs.append(npc as Dictionary)

	# Exits
	exits = {}
	if d.has("exits") and d["exits"] is Array:
		for ex: Variant in d["exits"]:
			if ex is Dictionary:
				var ex_d: Dictionary = ex
				var pos_arr: Variant = ex_d.get("position", [])
				if pos_arr is Array and (pos_arr as Array).size() >= 2:
					var arr: Array = pos_arr
					var pos := Vector2i(int(arr[0]), int(arr[1]))
					exits[pos] = str(ex_d.get("destination", ""))

	# Atmosphere
	atmosphere = d.get("atmosphere", {}) as Dictionary

	# Entrance narration
	entrance_narration = []
	if d.has("entrance_narration") and d["entrance_narration"] is Array:
		for line: Variant in d["entrance_narration"]:
			entrance_narration.append(str(line))

	loaded_from_json = true
	json_path = path

	# Build walkability and obstacles from the loaded data
	_build_grid()
	_register_npcs_from_data()
	_register_exits_from_layout()
	return true


func _use_fallback() -> void:
	map_width = _FALLBACK_WIDTH
	map_height = _FALLBACK_HEIGHT
	layout = []
	for row: String in _FALLBACK_LAYOUT:
		layout.append(row)
	tile_legend = _FALLBACK_LEGEND.duplicate(true)
	player_spawn = Vector2i(14, 19)
	player_sprite_name = &"player-4"
	village_name = "Hommlet"

	# Buildings with visible interiors
	buildings = [
		{
			"id": "tavern", "name": "The Welcome Wench", "type": "tavern",
			"rect": {"x": 3, "y": 2, "w": 6, "h": 6},
			"door_positions": [[6, 7]],
		},
		{
			"id": "blacksmith", "name": "Ironhammer Smithy", "type": "blacksmith",
			"rect": {"x": 18, "y": 2, "w": 6, "h": 6},
			"door_positions": [[21, 7]],
		},
	]

	npc_data = [
		{"npc_id": "marta", "display_name": "Marta", "position": [6, 3],
		 "sprite_name": "player-25", "modulate": [0.8, 0.5, 0.3, 1.0]},
		{"npc_id": "garrick", "display_name": "Garrick", "position": [21, 6],
		 "sprite_name": "player-31", "modulate": [0.6, 0.3, 0.2, 1.0]},
	]
	npcs = npc_data.duplicate(true)

	# The dungeon gate exit
	exits = {
		Vector2i(14, 20): "res://scenes/game/game.tscn",
	}

	atmosphere = {
		"time_of_day": "morning",
		"weather": "clear",
	}

	entrance_narration = [
		"[color=#6cb4c4][b]Village of Hommlet[/b][/color]\nYou arrive at the village of Hommlet. Thatched roofs and cobblestone paths stretch before you. Smoke curls from chimneys, and the sounds of daily life fill the air.",
		"[color=#d9d566]The Welcome Wench[/color] tavern stands to the left, its heavy oak door slightly ajar. To the right, the ring of hammer on anvil echoes from [color=#d9d566]Ironhammer Smithy[/color]. A worn path leads south toward the [color=#d9d566]dungeon gate[/color].",
	]

	loaded_from_json = false
	_build_grid()
	_register_npcs_from_data()


func _build_grid() -> void:
	_walkable = []
	_obstacles = {}
	for y in range(map_height):
		var row: Array = []
		for x in range(map_width):
			if y >= layout.size() or x >= layout[y].length():
				row.append(false)
				continue
			var ch: String = layout[y][x]
			var legend: Variant = tile_legend.get(ch, null)
			var walkable := false
			if legend is Dictionary:
				walkable = legend.get("walkable", false)
			if not walkable:
				_obstacles[Vector2i(x, y)] = ch
			row.append(walkable)
		_walkable.append(row)


func _register_npcs_from_data() -> void:
	_npc_positions = {}
	for npc: Dictionary in npc_data:
		var pos_arr: Variant = npc.get("position", [])
		if pos_arr is Array and (pos_arr as Array).size() >= 2:
			var arr: Array = pos_arr
			var pos := Vector2i(int(arr[0]), int(arr[1]))
			var npc_id: String = str(npc.get("npc_id", ""))
			_npc_positions[pos] = npc_id
			# Mark NPC positions as non-walkable
			if pos.y < _walkable.size() and pos.x < (_walkable[pos.y] as Array).size():
				_walkable[pos.y][pos.x] = false


## Register exit positions from the layout (any 'G' tile = dungeon gate exit)
func _register_exits_from_layout() -> void:
	# Only add layout-based exits if no JSON exits were provided
	if not exits.is_empty():
		return
	for y in range(map_height):
		if y >= layout.size():
			break
		for x in range(layout[y].length()):
			var ch: String = layout[y][x]
			if ch == "G":
				exits[Vector2i(x, y)] = "res://scenes/game/game.tscn"


func is_walkable(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return false
	return _walkable[pos.y][pos.x]


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < map_width and pos.y >= 0 and pos.y < map_height


func get_npc_at(pos: Vector2i) -> String:
	return _npc_positions.get(pos, "")


func has_npc(pos: Vector2i) -> bool:
	return _npc_positions.has(pos)


## Get all NPC IDs in the village.
func get_all_npc_ids() -> Array[String]:
	var ids: Array[String] = []
	for npc_id: Variant in _npc_positions.values():
		ids.append(str(npc_id))
	return ids


func get_obstacle_at(pos: Vector2i) -> String:
	return _obstacles.get(pos, "")


func get_char_at(pos: Vector2i) -> String:
	if not is_in_bounds(pos):
		return ""
	if pos.y >= layout.size() or pos.x >= layout[pos.y].length():
		return ""
	return layout[pos.y][pos.x]


func is_wall_like_char(ch: String) -> bool:
	var legend: Variant = tile_legend.get(ch, null)
	if legend is Dictionary:
		return legend.get("wall_like", false)
	return false


## Returns the building dictionary if pos is inside a building rect, empty dict otherwise.
func get_building_at(pos: Vector2i) -> Dictionary:
	for bld: Dictionary in buildings:
		var rect: Variant = bld.get("rect", null)
		if rect is Dictionary:
			var r: Dictionary = rect
			var rx: int = int(r.get("x", 0))
			var ry: int = int(r.get("y", 0))
			var rw: int = int(r.get("w", 0))
			var rh: int = int(r.get("h", 0))
			if pos.x >= rx and pos.x < rx + rw and pos.y >= ry and pos.y < ry + rh:
				return bld
	return {}


## Returns destination scene path if pos is an exit, empty string otherwise.
func get_exit_at(pos: Vector2i) -> String:
	return exits.get(pos, "")


## Check if a position is inside any building (used by renderer for floor tiles).
func is_inside_building(pos: Vector2i) -> bool:
	return not get_building_at(pos).is_empty()
