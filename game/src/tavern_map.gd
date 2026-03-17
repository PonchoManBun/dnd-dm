class_name TavernMap
extends RefCounted

## Pure data model for the tavern layout.
## No scene tree dependencies — used by TavernRenderer and TavernController.

const MAP_WIDTH := 24
const MAP_HEIGHT := 20
const TILE_SIZE := 16

const PLAYER_SPAWN := Vector2i(21, 17)

const BARKEEP_POS := Vector2i(12, 13)
const OLD_TOM_POS := Vector2i(10, 3)
const ELARA_POS := Vector2i(17, 5)

const NPC_SPRITES: Dictionary = {
	"Marta": &"player-25",
	"OldTom": &"player-31",
	"Elara": &"player-4",
}
const PLAYER_SPRITE_NAME := &"player-4"

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

# Walkable grid (true = walkable)
var _walkable: Array = []  # Array of Array of bool

# Obstacle dictionary (grid_pos -> char code)
var _obstacles: Dictionary = {}  # Vector2i -> String

# NPC positions (grid_pos -> npc_id)
var _npc_positions: Dictionary = {}  # Vector2i -> String


func _init() -> void:
	_build_grid()
	_register_npcs()


func _build_grid() -> void:
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
					row.append(false)
					_obstacles[Vector2i(x, y)] = "*"
				"c":
					row.append(true)  # Chairs are walkable (decorative)
				"D":
					row.append(true)  # Door is walkable
				_:
					row.append(true)
		_walkable.append(row)


func _register_npcs() -> void:
	_npc_positions[BARKEEP_POS] = "marta"
	_npc_positions[OLD_TOM_POS] = "old_tom"
	_npc_positions[ELARA_POS] = "elara"
	# Mark NPC positions as non-walkable
	_walkable[OLD_TOM_POS.y][OLD_TOM_POS.x] = false
	_walkable[ELARA_POS.y][ELARA_POS.x] = false


func is_walkable(pos: Vector2i) -> bool:
	if not is_in_bounds(pos):
		return false
	return _walkable[pos.y][pos.x]


func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < MAP_WIDTH and pos.y >= 0 and pos.y < MAP_HEIGHT


func get_npc_at(pos: Vector2i) -> String:
	return _npc_positions.get(pos, "")


func has_npc(pos: Vector2i) -> bool:
	return _npc_positions.has(pos)


func get_obstacle_at(pos: Vector2i) -> String:
	return _obstacles.get(pos, "")


func get_char_at(pos: Vector2i) -> String:
	if not is_in_bounds(pos):
		return ""
	return TAVERN_LAYOUT[pos.y][pos.x]


func is_wall_like_char(ch: String) -> bool:
	return ch == "#" or ch == "M" or ch == "R"
