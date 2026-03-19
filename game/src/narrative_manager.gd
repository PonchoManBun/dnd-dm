extends Node

## Singleton that manages narrative content for the DM panel.
## Queues narrative entries, presents player choices, and emits signals
## for the UI layer to consume.

signal narrative_added(text: String)
signal choices_presented(choices: Array[String])
signal choice_selected(index: int, text: String)
signal player_input_submitted(text: String)
signal narrative_cleared
signal choices_cleared
signal thinking_started
signal thinking_finished

## A single narrative entry with optional choices.
class NarrativeEntry:
	extends RefCounted
	var text: String = ""
	var choices: Array[String] = []
	var on_choice: Callable = Callable()

	func _init(p_text: String = "", p_choices: Array[String] = [], p_on_choice: Callable = Callable()) -> void:
		text = p_text
		choices = p_choices
		on_choice = p_on_choice

## Queue of pending narrative entries
var _queue: Array[NarrativeEntry] = []

## All narrative text shown so far (for scroll-back)
var _history: Array[String] = []

## Whether we are currently waiting for a player choice
var _awaiting_choice: bool = false

## The current active choices callback
var _current_on_choice: Callable = Callable()

## Reference to loaded narrative data
var _narrative_data: Dictionary = {}


func _ready() -> void:
	_load_narrative_data()
	_add_initial_narratives()
	# Clear stale choices/narratives on scene transitions
	World.map_changed.connect(_on_map_changed)
	World.game_mode.combat_started.connect(_on_combat_started)
	World.game_mode.combat_ended.connect(_on_combat_ended)


## Load narrative content from the JSON data file.
func _load_narrative_data() -> void:
	var file := FileAccess.open("res://assets/data/narratives.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var err := json.parse(file.get_as_text())
		if err == OK:
			_narrative_data = json.data
			Log.i("Loaded narrative data")
		else:
			Log.e("Failed to parse narratives.json: %s" % json.get_error_message())
		file.close()
	else:
		Log.w("narratives.json not found, using fallback narratives")


## Add opening narratives (scene-setting only, no choices).
func _add_initial_narratives() -> void:
	add_narrative(
		"[color=#6cb4c4][b]The Welcome Wench[/b][/color]\n"
		+ "You push open the heavy oak door of the inn. "
		+ "The smell of roasted meat and stale ale washes over you."
	)
	add_narrative(
		"A [color=#d9d566]hooded figure[/color] in the corner catches your eye. "
		+ "The barkeep polishes a mug, watching you with mild interest."
	)


## Add a narrative text entry to the queue and emit it immediately.
func add_narrative(text: String) -> void:
	var entry := NarrativeEntry.new(text)
	_queue.append(entry)
	_history.append(text)
	narrative_added.emit(text)


## Add a combat-specific narrative with red accent color.
func add_combat_narrative(text: String) -> void:
	var formatted := "[color=#d44e4e]%s[/color]" % text
	add_narrative(formatted)


## Present choices to the player. The callback receives the selected index.
func present_choices(choices: Array[String], callback: Callable = Callable()) -> void:
	_awaiting_choice = true
	_current_on_choice = callback

	var entry := NarrativeEntry.new("", choices, callback)
	_queue.append(entry)

	var typed_choices: Array[String] = []
	typed_choices.assign(choices)
	choices_presented.emit(typed_choices)


## Called by the UI when a choice button is pressed.
func select_choice(index: int) -> void:
	if not _awaiting_choice:
		return

	_awaiting_choice = false
	var choices_text := ""
	if _queue.size() > 0:
		var last_entry := _queue[-1]
		if last_entry.choices.size() > index:
			choices_text = last_entry.choices[index]

	choice_selected.emit(index, choices_text)

	if _current_on_choice.is_valid():
		_current_on_choice.call(index)
		_current_on_choice = Callable()


## Called by the UI when the player submits free-text input.
func submit_input(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	player_input_submitted.emit(text)
	# Echo the player's input in the narrative
	add_narrative("[color=#6cb4c4]> %s[/color]" % text)


## Show thinking indicator in the narrative.
func show_thinking() -> void:
	thinking_started.emit()


## Hide thinking indicator.
func hide_thinking() -> void:
	thinking_finished.emit()


## Clear all narrative history.
func clear() -> void:
	_queue.clear()
	_history.clear()
	_awaiting_choice = false
	_current_on_choice = Callable()
	narrative_cleared.emit()


## Get a random narrative string for a given category from the data file.
func get_random_narrative(category: String, key: String = "") -> String:
	if _narrative_data.is_empty():
		return ""

	if not _narrative_data.has(category):
		Log.w("Narrative category not found: %s" % category)
		return ""

	var entries: Variant = _narrative_data[category]

	if entries is Array:
		if entries.size() == 0:
			return ""
		return entries[randi() % entries.size()]
	elif entries is Dictionary and not key.is_empty():
		if entries.has(key):
			var sub_entries: Variant = entries[key]
			if sub_entries is Array and sub_entries.size() > 0:
				return sub_entries[randi() % sub_entries.size()]
		Log.w("Narrative key not found: %s/%s" % [category, key])

	return ""


## Get the full narrative history.
func get_history() -> Array[String]:
	return _history


## Whether we are currently waiting for a player choice.
func is_awaiting_choice() -> bool:
	return _awaiting_choice


## Clear all context — narrative history, pending choices, and callbacks.
## Called on scene transitions to prevent stale tavern choices in the dungeon.
func clear_context() -> void:
	_queue.clear()
	_history.clear()
	_awaiting_choice = false
	_current_on_choice = Callable()
	narrative_cleared.emit()


func _on_map_changed(_map: Map) -> void:
	clear_context()
	Log.i("NarrativeManager: cleared context on map change")


func _on_combat_started(_combatants: Array[Monster]) -> void:
	# Clear exploration choices when combat begins, but keep narrative history
	_awaiting_choice = false
	_current_on_choice = Callable()
	choices_cleared.emit()
	add_combat_narrative("Initiative rolled! Combat begins!")


func _on_combat_ended(victory: bool) -> void:
	_awaiting_choice = false
	_current_on_choice = Callable()
	choices_cleared.emit()
	if victory:
		add_combat_narrative("The battle is won!")
	else:
		add_combat_narrative("The party has fallen...")
