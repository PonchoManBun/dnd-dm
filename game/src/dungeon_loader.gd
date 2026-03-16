class_name DungeonLoader
extends RefCounted

## Loads dungeon layouts from JSON and populates Maps with cells, monsters, items, and triggers.

class DungeonData:
	extends RefCounted
	var name: String
	var description: String
	var floors: Array[FloorData] = []

class FloorData:
	extends RefCounted
	var id: String
	var depth: int
	var name: String
	var width: int
	var height: int
	var rooms: Array[RoomData] = []
	var corridors: Array[CorridorData] = []

class RoomData:
	extends RefCounted
	var id: int
	var name: String
	var x: int
	var y: int
	var w: int
	var h: int
	var type: String  # entrance, combat, treasure, trap, boss
	var narrative: String
	var monsters: Array[Dictionary] = []
	var items: Array[Dictionary] = []
	var stairs_up: bool = false
	var stairs_down: bool = false
	var trap: Dictionary = {}
	var choices: Array[Dictionary] = []
	var on_clear: Dictionary = {}

class CorridorData:
	extends RefCounted
	var from_room: int
	var to_room: int


static func load_dungeon(path: String) -> DungeonData:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		Log.e("Failed to open dungeon file: %s" % path)
		return null

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		Log.e("Failed to parse dungeon JSON: %s" % json.get_error_message())
		return null

	var raw: Dictionary = json.data
	var dungeon := DungeonData.new()
	dungeon.name = raw.get("name", "Unknown Dungeon")
	dungeon.description = raw.get("description", "")

	for floor_raw: Dictionary in raw.get("floors", []):
		var floor_data := FloorData.new()
		floor_data.id = floor_raw.get("id", "")
		floor_data.depth = floor_raw.get("depth", 1)
		floor_data.name = floor_raw.get("name", "")
		floor_data.width = floor_raw.get("width", 30)
		floor_data.height = floor_raw.get("height", 20)

		for room_raw: Dictionary in floor_raw.get("rooms", []):
			var room := RoomData.new()
			room.id = room_raw.get("id", 0)
			room.name = room_raw.get("name", "")
			room.x = room_raw.get("x", 0)
			room.y = room_raw.get("y", 0)
			room.w = room_raw.get("w", 5)
			room.h = room_raw.get("h", 5)
			room.type = room_raw.get("type", "")
			room.narrative = room_raw.get("narrative", "")
			room.stairs_up = room_raw.get("stairs_up", false)
			room.stairs_down = room_raw.get("stairs_down", false)
			room.trap = room_raw.get("trap", {})
			room.choices = []
			for choice: Dictionary in room_raw.get("choices", []):
				room.choices.append(choice)
			room.on_clear = room_raw.get("on_clear", {})

			for m: Dictionary in room_raw.get("monsters", []):
				room.monsters.append(m)
			for i: Dictionary in room_raw.get("items", []):
				room.items.append(i)

			floor_data.rooms.append(room)

		for corr_raw: Dictionary in floor_raw.get("corridors", []):
			var corr := CorridorData.new()
			corr.from_room = corr_raw.get("from", 0)
			corr.to_room = corr_raw.get("to", 0)
			floor_data.corridors.append(corr)

		dungeon.floors.append(floor_data)

	return dungeon


## Generate a Map from a FloorData definition.
## Creates rooms, corridors, places monsters and items.
static func generate_map_from_floor(floor_data: FloorData) -> Map:
	var map := Map.new(floor_data.width, floor_data.height, floor_data.depth, floor_data.id)

	# Carve rooms
	for room_data: RoomData in floor_data.rooms:
		_carve_room(map, room_data)

	# Carve corridors between rooms
	for corridor: CorridorData in floor_data.corridors:
		var from_room := _find_room(floor_data, corridor.from_room)
		var to_room := _find_room(floor_data, corridor.to_room)
		if from_room and to_room:
			_carve_corridor(map, from_room, to_room)

	# Place stairs, monsters, and items
	for room_data: RoomData in floor_data.rooms:
		_populate_room(map, room_data)

	return map


static func _carve_room(map: Map, room_data: RoomData) -> void:
	for x in range(room_data.x, room_data.x + room_data.w):
		for y in range(room_data.y, room_data.y + room_data.h):
			if x >= 0 and x < map.width and y >= 0 and y < map.height:
				var cell := map.get_cell(Vector2i(x, y))
				cell.terrain.type = Terrain.Type.DUNGEON_FLOOR
				cell.area_type = MapCell.Type.ROOM
				cell.room_id = room_data.id


static func _carve_corridor(map: Map, from_room: RoomData, to_room: RoomData) -> void:
	# Simple L-shaped corridor from center of one room to center of another
	var from_center := Vector2i(from_room.x + from_room.w / 2, from_room.y + from_room.h / 2)
	var to_center := Vector2i(to_room.x + to_room.w / 2, to_room.y + to_room.h / 2)

	# Horizontal first, then vertical
	var x := from_center.x
	var x_dir := 1 if to_center.x > from_center.x else -1
	while x != to_center.x:
		if x >= 0 and x < map.width and from_center.y >= 0 and from_center.y < map.height:
			var cell := map.get_cell(Vector2i(x, from_center.y))
			if cell.terrain.type == Terrain.Type.DUNGEON_WALL or cell.terrain.type == Terrain.Type.EMPTY:
				cell.terrain.type = Terrain.Type.DUNGEON_FLOOR
				cell.area_type = MapCell.Type.CORRIDOR
		x += x_dir

	var y := from_center.y
	var y_dir := 1 if to_center.y > from_center.y else -1
	while y != to_center.y + y_dir:
		if to_center.x >= 0 and to_center.x < map.width and y >= 0 and y < map.height:
			var cell := map.get_cell(Vector2i(to_center.x, y))
			if cell.terrain.type == Terrain.Type.DUNGEON_WALL or cell.terrain.type == Terrain.Type.EMPTY:
				cell.terrain.type = Terrain.Type.DUNGEON_FLOOR
				cell.area_type = MapCell.Type.CORRIDOR
		y += y_dir


static func _populate_room(map: Map, room_data: RoomData) -> void:
	# Place stairs
	if room_data.stairs_up:
		var pos := Vector2i(room_data.x + 1, room_data.y + 1)
		var cell := map.get_cell(pos)
		var stairs_up := Obstacle.new()
		stairs_up.type = Obstacle.Type.STAIRS_UP
		cell.obstacle = stairs_up

	if room_data.stairs_down:
		var pos := Vector2i(room_data.x + room_data.w - 2, room_data.y + room_data.h - 2)
		var cell := map.get_cell(pos)
		var stairs_down := Obstacle.new()
		stairs_down.type = Obstacle.Type.STAIRS_DOWN
		cell.obstacle = stairs_down

	# Place monsters
	for monster_def: Dictionary in room_data.monsters:
		var slug := StringName(monster_def.get("slug", ""))
		var pos := Vector2i(monster_def.get("x", 0), monster_def.get("y", 0))

		var monster: Monster
		if DndMonsterFactory.has_monster(slug):
			monster = DndMonsterFactory.create_monster(slug)
		else:
			monster = MonsterFactory.create_monster(slug)

		if pos.x >= 0 and pos.x < map.width and pos.y >= 0 and pos.y < map.height:
			var cell := map.get_cell(pos)
			if cell.monster == null and cell.terrain.is_walkable():
				cell.monster = monster

	# Place items
	for item_def: Dictionary in room_data.items:
		var slug := StringName(item_def.get("slug", ""))
		var pos := Vector2i(item_def.get("x", 0), item_def.get("y", 0))
		var quantity: int = item_def.get("quantity", 1)

		var item := ItemFactory.create_item(slug)
		item.quantity = quantity

		if pos.x >= 0 and pos.x < map.width and pos.y >= 0 and pos.y < map.height:
			map.add_item(pos, item)


static func _find_room(floor_data: FloorData, room_id: int) -> RoomData:
	for room: RoomData in floor_data.rooms:
		if room.id == room_id:
			return room
	return null
