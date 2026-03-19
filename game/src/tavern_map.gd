class_name TavernMap
extends RefCounted

## Pure data model for the tavern layout.
## No scene tree dependencies — used by TavernRenderer and TavernController.
## Supports loading from JSON (Forge-generated) or hardcoded fallback.

# Map dimensions (set by JSON or fallback)
var map_width: int = 24
var map_height: int = 20
var tile_size: int = 16

# Layout and metadata
var layout: Array[String] = []
var tile_legend: Dictionary = {}
var player_spawn: Vector2i = Vector2i(21, 17)
var player_sprite_name: StringName = &"player-4"
var tavern_name: String = "The Welcome Wench"
var location_type: String = "tavern"

# NPC data from JSON
var npc_data: Array[Dictionary] = []

# Atmosphere data from JSON
var atmosphere: Dictionary = {}

# Zone data from JSON
var zones: Array[Dictionary] = []

# Entrance narration from JSON
var entrance_narration: Array[String] = []

# Whether this was loaded from JSON
var loaded_from_json: bool = false
var json_path: String = ""

# --- Hardcoded fallback constants ---
const _FALLBACK_WIDTH := 24
const _FALLBACK_HEIGHT := 20

const _FALLBACK_LAYOUT: Array[String] = [
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

const _FALLBACK_LEGEND: Dictionary = {
	"#": {"name": "wall", "walkable": false, "wall_like": true},
	".": {"name": "floor", "walkable": true},
	"B": {"name": "bar_counter", "walkable": false},
	"T": {"name": "table", "walkable": false},
	"c": {"name": "chair", "walkable": true},
	"Q": {"name": "quest_board", "walkable": false},
	"s": {"name": "shop_counter", "walkable": false},
	"S": {"name": "stairs", "walkable": false},
	"M": {"name": "memorial", "walkable": false, "wall_like": true},
	"R": {"name": "room_door", "walkable": false, "wall_like": true},
	"D": {"name": "entrance_door", "walkable": true},
	"*": {"name": "barkeep_position", "walkable": false, "is_npc_slot": true},
}

# Walkable grid (true = walkable)
var _walkable: Array = []  # Array of Array of bool

# Obstacle dictionary (grid_pos -> char code)
var _obstacles: Dictionary = {}  # Vector2i -> String

# NPC positions (grid_pos -> npc_id)
var _npc_positions: Dictionary = {}  # Vector2i -> String


func _init() -> void:
	_use_fallback()


## Load tavern from a JSON file. Returns true on success.
static func from_json(path: String) -> TavernMap:
	var tm := TavernMap.new()
	if tm._load_json(path):
		return tm
	# JSON load failed — fallback already in place from _init()
	push_warning("TavernMap: Failed to load '%s', using hardcoded fallback" % path)
	return tm


func _load_json(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_warning("TavernMap: JSON file not found: %s" % path)
		return false

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("TavernMap: Cannot open %s" % path)
		return false

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_warning("TavernMap: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return false

	var data: Variant = json.data
	if not data is Dictionary:
		push_warning("TavernMap: JSON root must be a dictionary in %s" % path)
		return false

	var d: Dictionary = data

	# Required fields
	if not d.has("layout") or not d.has("tile_legend") or not d.has("width") or not d.has("height"):
		push_warning("TavernMap: Missing required fields in %s" % path)
		return false

	# Populate from JSON
	map_width = int(d["width"])
	map_height = int(d["height"])
	tile_size = int(d.get("tile_size", 16))
	tavern_name = str(d.get("name", "Unknown Tavern"))
	location_type = str(d.get("location_type", "tavern"))

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

	# NPCs
	npc_data = []
	if d.has("npcs") and d["npcs"] is Array:
		for npc: Variant in d["npcs"]:
			if npc is Dictionary:
				npc_data.append(npc as Dictionary)

	# Atmosphere
	atmosphere = d.get("atmosphere", {}) as Dictionary

	# Zones
	zones = []
	if d.has("zones") and d["zones"] is Array:
		for zone: Variant in d["zones"]:
			if zone is Dictionary:
				zones.append(zone as Dictionary)

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
	return true


func _use_fallback() -> void:
	map_width = _FALLBACK_WIDTH
	map_height = _FALLBACK_HEIGHT
	layout = []
	for row: String in _FALLBACK_LAYOUT:
		layout.append(row)
	tile_legend = _FALLBACK_LEGEND.duplicate(true)
	player_spawn = Vector2i(21, 17)
	player_sprite_name = &"player-4"
	tavern_name = "The Welcome Wench"

	npc_data = [
		{"npc_id": "marta", "display_name": "Marta", "position": [12, 13],
		 "sprite_name": "player-25", "modulate": [0.8, 0.5, 0.3, 1.0]},
		{"npc_id": "old_tom", "display_name": "OldTom", "position": [10, 3],
		 "sprite_name": "player-31", "modulate": [0.55, 0.4, 0.25, 1.0]},
		{"npc_id": "elara", "display_name": "Elara", "position": [17, 5],
		 "sprite_name": "player-4", "modulate": [0.4, 0.3, 0.7, 1.0]},
	]

	atmosphere = {
		"candle_positions": [[12, 11], [13, 4], [20, 17]],
		"candle_color": [1.0, 0.85, 0.5],
		"candle_energy": 0.6,
		"candle_flicker_range": [0.5, 0.7],
		"dust_mote_color": [1.0, 0.9, 0.7, 0.8],
	}

	entrance_narration = [
		"[color=#6cb4c4][b]The Welcome Wench[/b][/color]\nYou push open the heavy oak door. The warmth of the tavern washes over you — crackling hearth, the clink of mugs, and the low murmur of conversation.",
		"[color=#d9d566]Barkeep Marta[/color] stands behind the polished bar, wiping down a mug. [color=#d9d566]Old Tom[/color] nurses an ale at a nearby table. A [color=#d9d566]hooded figure[/color] sits alone in the corner. A [color=#d9d566]quest board[/color] on the far wall catches your eye.",
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


## Get all NPC IDs in the tavern.
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
