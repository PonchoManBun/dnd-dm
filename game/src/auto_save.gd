class_name AutoSave
extends Node

## Auto-save singleton. Saves game state after every turn.
## Uses atomic writes (write to temp, then rename) to prevent corruption.
## Implements roguelike anti-scumming: save is deleted on death and after loading.

const SAVE_PATH := "user://save.json"
const TEMP_SAVE_PATH := "user://save.json.tmp"

var _connected := false


func _ready() -> void:
	_connect_signals()
	# Reconnect signals whenever world reinitializes (new game / load)
	World.world_initialized.connect(_connect_signals)


func _connect_signals() -> void:
	if _connected:
		# Disconnect old signals to avoid duplicates
		if World.turn_ended.is_connected(_on_turn_ended):
			World.turn_ended.disconnect(_on_turn_ended)
		if World.game_ended.is_connected(_on_game_ended):
			World.game_ended.disconnect(_on_game_ended)

	World.turn_ended.connect(_on_turn_ended)
	World.game_ended.connect(_on_game_ended)
	_connected = true


func _on_turn_ended() -> void:
	if World.game_over:
		return
	_save_game()


func _on_game_ended() -> void:
	# Roguelike anti-scumming: delete save on death / game end
	delete_save()
	Log.i("Save file deleted (game ended)")


func _save_game() -> void:
	var data := GameStateSerializer.serialize_game_state()
	var json_string := JSON.stringify(data, "\t")

	# Atomic write: write to temp file first
	var temp_file := FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if not temp_file:
		Log.e("Failed to open temp save file: %s" % TEMP_SAVE_PATH)
		return

	temp_file.store_string(json_string)
	temp_file.close()

	# Rename temp file to actual save file (atomic on most filesystems)
	var dir := DirAccess.open("user://")
	if not dir:
		Log.e("Failed to open user:// directory")
		return

	# Remove existing save if present
	if dir.file_exists("save.json"):
		var err := dir.remove("save.json")
		if err != OK:
			Log.e("Failed to remove old save file: %s" % err)
			return

	var err := dir.rename("save.json.tmp", "save.json")
	if err != OK:
		Log.e("Failed to rename temp save to save file: %s" % err)
		return

	Log.d("Game saved (turn %d)" % World.current_turn)


static func save_exists() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func load_game() -> bool:
	if not save_exists():
		Log.e("No save file found")
		return false

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		Log.e("Failed to open save file: %s" % SAVE_PATH)
		return false

	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		Log.e("Failed to parse save file: %s" % json.get_error_message())
		return false

	var data: Dictionary = json.data as Dictionary
	if data == null:
		Log.e("Save file data is not a Dictionary")
		return false

	var success := GameStateSerializer.deserialize_game_state(data)
	if success:
		# Delete-on-resume: roguelike style, the save is consumed on load
		delete_save()
		Log.i("Save file consumed after successful load")
	return success


static func delete_save() -> void:
	if save_exists():
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("save.json")
			# Also clean up temp file if it exists
			if dir.file_exists("save.json.tmp"):
				dir.remove("save.json.tmp")
