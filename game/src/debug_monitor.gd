extends Node

## Debug monitor autoload. Captures viewport screenshots every 5 seconds
## with JSON metadata sidecars for remote visual debugging.
##
## Activated only when sentinel file res://screenshots/.monitoring exists.
## Keeps a rolling window of the last 100 screenshots.

const SCREENSHOT_DIR := "res://screenshots/"
const SENTINEL_FILE := "res://screenshots/.monitoring"
const DEFAULT_CAPTURE_INTERVAL := 5.0
const PLAYTEST_CAPTURE_INTERVAL := 2.0
const MAX_SCREENSHOTS := 100

var _enabled := false
var _timer: Timer
var _shot_counter := 0
var _playtest_mode := false


func _ready() -> void:
	# Check for sentinel file to enable monitoring
	_enabled = FileAccess.file_exists(SENTINEL_FILE)
	if not _enabled:
		print("DebugMonitor: disabled (no sentinel file)")
		return

	# Playtest mode uses faster capture interval
	_playtest_mode = "--skip-menu" in OS.get_cmdline_user_args()
	var interval := PLAYTEST_CAPTURE_INTERVAL if _playtest_mode else DEFAULT_CAPTURE_INTERVAL
	print("DebugMonitor: enabled — capturing every %ds%s" % [
		int(interval), " (playtest mode)" if _playtest_mode else ""
	])

	# Ensure output directory exists
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists("screenshots"):
		dir.make_dir("screenshots")

	# Find the next shot counter by scanning existing files
	_shot_counter = _find_next_counter()

	# Create capture timer
	_timer = Timer.new()
	_timer.wait_time = interval
	_timer.autostart = true
	_timer.timeout.connect(_capture)
	add_child(_timer)

	# Take an initial screenshot after a short delay (let first frame render)
	get_tree().create_timer(1.0).timeout.connect(_capture)


func _capture() -> void:
	if not _enabled:
		return

	_shot_counter += 1
	var name := "shot_%04d" % _shot_counter
	var png_path := SCREENSHOT_DIR + name + ".png"
	var json_path := SCREENSHOT_DIR + name + ".json"

	# Capture viewport
	var image := get_viewport().get_texture().get_image()
	if not image:
		push_error("DebugMonitor: failed to get viewport image")
		return

	var err := image.save_png(ProjectSettings.globalize_path(png_path))
	if err != OK:
		push_error("DebugMonitor: failed to save PNG: %s" % error_string(err))
		return

	# Write JSON sidecar with game state metadata
	var metadata := _collect_metadata()
	var json_string := JSON.stringify(metadata, "\t")
	var file := FileAccess.open(json_path, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()

	print("DebugMonitor: captured %s" % name)

	# Rolling window cleanup
	_cleanup_old_screenshots()


func _collect_metadata() -> Dictionary:
	var data := {}

	# Current scene
	var scene_tree := get_tree()
	var current_scene := scene_tree.current_scene
	data["scene"] = _detect_screen(current_scene)
	data["timestamp"] = Time.get_datetime_string_from_system()
	data["shot"] = _shot_counter

	# Access autoload singletons
	var world := get_node_or_null("/root/World")
	var narrative := get_node_or_null("/root/NarrativeManager")
	var modals := get_node_or_null("/root/Modals")

	# Game state from World singleton (safe access)
	data["turn"] = world.get("current_turn") if world else 0
	data["game_over"] = world.get("game_over") if world else false
	var current_map: Variant = world.get("current_map") if world else null
	data["depth"] = current_map.get("depth") if current_map else 0
	data["max_depth"] = world.get("max_depth") if world else 0

	# Player stats and position
	var player: Variant = world.get("player") if world else null
	var player_pos := Vector2i(-1, -1)
	if player and current_map and current_map.has_method("find_monster_position"):
		player_pos = current_map.find_monster_position(player)

	if player:
		data["player_hp"] = player.get("hp")
		data["player_max_hp"] = player.get("max_hp")
		data["player_name"] = player.name
		data["player_pos"] = [player_pos.x, player_pos.y]
	else:
		data["player_hp"] = 0
		data["player_max_hp"] = 0
		data["player_name"] = ""
		data["player_pos"] = [-1, -1]

	# Waiting for input — check game scene
	data["waiting_for_input"] = false
	if current_scene and current_scene.get("waiting_for_player_input") != null:
		data["waiting_for_input"] = current_scene.waiting_for_player_input

	# Walkable neighbors around player
	data["walkable_neighbors"] = []
	if current_map and player_pos.x >= 0:
		var neighbors: Array = []
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var npos := player_pos + Vector2i(dx, dy)
				if current_map.has_method("is_in_bounds") and current_map.is_in_bounds(npos):
					var cell: Variant = current_map.get_cell(npos)
					if cell and cell.has_method("is_walkable") and cell.is_walkable():
						neighbors.append([npos.x, npos.y])
		data["walkable_neighbors"] = neighbors

	# Visible monsters (excluding player)
	data["monsters_visible"] = []
	if current_map and current_map.has_method("get_visible_monsters"):
		var visible: Array = current_map.get_visible_monsters()
		var monster_list: Array = []
		for m in visible:
			if m == player:
				continue
			var mpos: Vector2i = current_map.find_monster_position(m)
			monster_list.append({
				"pos": [mpos.x, mpos.y],
				"name": m.name,
				"hp": m.get("hp"),
				"hostile": m.is_hostile_to(player) if m.has_method("is_hostile_to") else false
			})
		data["monsters_visible"] = monster_list

	# Monster count on current map
	if current_map and current_map.has_method("get_monsters"):
		var monsters: Array = current_map.get_monsters()
		data["monster_count"] = maxi(0, monsters.size() - 1)
	else:
		data["monster_count"] = 0

	# Items at player's feet
	data["items_at_feet"] = []
	if current_map and player_pos.x >= 0 and current_map.has_method("get_items"):
		var items: Array = current_map.get_items(player_pos)
		var item_list: Array = []
		for item in items:
			item_list.append({"name": item.get_name() if item.has_method("get_name") else str(item)})
		data["items_at_feet"] = item_list

	# Stairs positions (scan map for stairs)
	data["stairs_down_pos"] = null
	data["stairs_up_pos"] = null
	if current_map and current_map.get("width") and current_map.get("height"):
		for x in range(current_map.width):
			for y in range(current_map.height):
				var pos := Vector2i(x, y)
				var cell: Variant = current_map.get_cell(pos)
				if cell and cell.get("obstacle") and cell.obstacle:
					if cell.obstacle.type == Obstacle.Type.STAIRS_UP:
						data["stairs_up_pos"] = [x, y]
					elif cell.obstacle.type == Obstacle.Type.STAIRS_DOWN:
						data["stairs_down_pos"] = [x, y]

	# DM text length from NarrativeManager
	if narrative and narrative.has_method("get_history"):
		data["dm_text_length"] = narrative.get_history().size()
	else:
		data["dm_text_length"] = 0

	# UI visibility — safely check via the game scene
	data["initiative_visible"] = false
	data["srd_visible"] = false
	data["modal_visible"] = modals.has_visible_modals() if modals and modals.has_method("has_visible_modals") else false

	if current_scene and current_scene.has_method("_check_player_input"):
		# We're in the game scene — check UI elements
		if current_scene.get("initiative_tracker"):
			data["initiative_visible"] = current_scene.initiative_tracker.visible
		if current_scene.get("srd_reference"):
			data["srd_visible"] = current_scene.srd_reference.visible

	# Game mode (exploration vs combat)
	var game_mode_node: Variant = world.get("game_mode") if world else null
	if game_mode_node and game_mode_node.has_method("is_combat"):
		data["game_mode"] = "combat" if game_mode_node.is_combat() else "exploration"
	else:
		data["game_mode"] = "exploration"

	# Combat state details
	data["combat_state"] = null
	if game_mode_node and game_mode_node.has_method("is_combat") and game_mode_node.is_combat():
		var combat_info := {}
		combat_info["is_player_turn"] = game_mode_node.is_player_turn() if game_mode_node.has_method("is_player_turn") else false

		var player_cs: Variant = game_mode_node.get_combat_state(player) if game_mode_node.has_method("get_combat_state") and player else null
		combat_info["movement_remaining"] = player_cs.movement_remaining if player_cs else 0
		combat_info["has_action"] = player_cs.has_action if player_cs else false

		# All combatants
		var combatant_list: Array = []
		if game_mode_node.get("combatants"):
			for cs in game_mode_node.combatants:
				combatant_list.append({
					"name": cs.combatant.name,
					"initiative": cs.initiative,
					"hp": cs.combatant.get("hp"),
				})
		combat_info["combatants"] = combatant_list
		data["combat_state"] = combat_info

	return data


func _detect_screen(scene: Node) -> String:
	if not scene:
		return "unknown"

	var scene_path := scene.scene_file_path
	if "main_menu" in scene_path:
		return "menu"
	elif "character_creation" in scene_path:
		return "character_creation"
	elif "dm_selection" in scene_path:
		return "dm_selection"
	elif "death_screen" in scene_path:
		return "death_screen"
	elif "game" in scene_path:
		return "game"
	elif "quit" in scene_path:
		return "quit"

	return scene_path.get_file().get_basename()


func _find_next_counter() -> int:
	var dir := DirAccess.open(SCREENSHOT_DIR)
	if not dir:
		return 0

	var max_num := 0
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.begins_with("shot_") and file_name.ends_with(".png"):
			var num_str := file_name.replace("shot_", "").replace(".png", "")
			if num_str.is_valid_int():
				max_num = maxi(max_num, num_str.to_int())
		file_name = dir.get_next()
	dir.list_dir_end()
	return max_num


func _cleanup_old_screenshots() -> void:
	if _shot_counter <= MAX_SCREENSHOTS:
		return

	var oldest := _shot_counter - MAX_SCREENSHOTS
	var dir := DirAccess.open(SCREENSHOT_DIR)
	if not dir:
		return

	# Delete shots older than the rolling window
	for i in range(maxi(1, oldest - 10), oldest + 1):
		var name := "shot_%04d" % i
		if dir.file_exists(name + ".png"):
			dir.remove(name + ".png")
		if dir.file_exists(name + ".json"):
			dir.remove(name + ".json")
