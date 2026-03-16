extends Control

@onready var continue_button: Button = %ContinueButton
@onready var play_button: Button = %PlayButton
@onready var center_container: CenterContainer = $CenterContainer

var _character_creation: CharacterCreation = null
var _dm_selection: DMSelection = null
var _pending_character_data: CharacterData = null

# Uncomment this to test the game immediately after running
# func _ready() -> void:
# 	call_deferred("_on_play_button_pressed")


func _ready() -> void:
	# Show/hide continue button based on whether a save file exists
	continue_button.visible = AutoSave.save_exists()

	# If a save exists, focus the continue button; otherwise focus play
	if continue_button.visible:
		continue_button.grab_focus()
	else:
		play_button.grab_focus()


func _on_continue_button_pressed() -> void:
	var success := AutoSave.load_game()
	if success:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")
	else:
		# If load fails, delete the corrupt save and refresh the menu
		AutoSave.delete_save()
		continue_button.visible = false
		play_button.grab_focus()


func _on_play_button_pressed() -> void:
	# Delete any existing save when starting a new game
	if AutoSave.save_exists():
		AutoSave.delete_save()

	# Load and show the character creation scene
	var cc_scene: PackedScene = load("res://scenes/character_creation/character_creation.tscn")
	_character_creation = cc_scene.instantiate() as CharacterCreation
	_character_creation.character_created.connect(_on_character_created)
	_character_creation.cancel.connect(_on_character_creation_cancelled)
	add_child(_character_creation)

	# Hide the main menu panel while character creation is active
	center_container.visible = false


func _on_character_creation_cancelled() -> void:
	if _character_creation:
		_character_creation.queue_free()
		_character_creation = null
	center_container.visible = true
	play_button.grab_focus()


func _on_character_created(data: CharacterData) -> void:
	# Store character data temporarily and move to DM selection
	_pending_character_data = data

	# Remove character creation screen
	if _character_creation:
		_character_creation.queue_free()
		_character_creation = null

	# Load and show the DM archetype selection screen
	var dm_scene: PackedScene = load("res://scenes/menu/dm_selection.tscn")
	_dm_selection = dm_scene.instantiate() as DMSelection
	_dm_selection.archetype_selected.connect(_on_archetype_selected)
	_dm_selection.cancel.connect(_on_dm_selection_cancelled)
	add_child(_dm_selection)


func _on_dm_selection_cancelled() -> void:
	# Go back to character creation
	if _dm_selection:
		_dm_selection.queue_free()
		_dm_selection = null
	_pending_character_data = null

	# Re-open character creation
	var cc_scene: PackedScene = load("res://scenes/character_creation/character_creation.tscn")
	_character_creation = cc_scene.instantiate() as CharacterCreation
	_character_creation.character_created.connect(_on_character_created)
	_character_creation.cancel.connect(_on_character_creation_cancelled)
	add_child(_character_creation)


func _on_archetype_selected(archetype_id: int) -> void:
	# Store both character data and DM archetype, then start the game
	World.set_meta("player_character_data", _pending_character_data)
	World.set_meta("dm_archetype", archetype_id)
	_pending_character_data = null
	get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
