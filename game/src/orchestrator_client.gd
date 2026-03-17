extends Node

## HTTP client for communicating with the Python/FastAPI DM Orchestrator.
## Sends player actions via POST /action, receives DM narration + choices.
## Falls back to Phase 1 hardcoded behavior if orchestrator is unavailable.

signal response_received(narration: String, choices: Array[String])
signal request_started
signal request_finished
signal orchestrator_status_changed(available: bool)
signal state_synced(state_data: Dictionary)

## Orchestrator base URL (Jetson runs on same machine, or dev machine runs locally)
var base_url: String = "http://localhost:8000"

## Whether the orchestrator is currently reachable
var orchestrator_available: bool = false

## Whether a request is currently in flight
var _request_in_flight: bool = false

## HTTP request node (reusable)
var _http_request: HTTPRequest

## Periodic state sync timer
var _sync_timer: Timer
var _sync_interval: float = 5.0  # Sync every 5 seconds
var _nm: Node  # NarrativeManager autoload (resolved at runtime to avoid ARM64 parse issues)


func _ready() -> void:
	_nm = get_node_or_null("/root/NarrativeManager")
	_http_request = HTTPRequest.new()
	_http_request.timeout = 15.0  # 15 second timeout
	add_child(_http_request)

	# Add sync timer
	_sync_timer = Timer.new()
	_sync_timer.wait_time = _sync_interval
	_sync_timer.autostart = false
	_sync_timer.timeout.connect(_on_sync_timer)
	add_child(_sync_timer)

	# Check orchestrator health on startup
	_check_health()


## Start periodic state syncing (call after character is created).
func start_sync() -> void:
	if orchestrator_available:
		_sync_timer.start()


## Stop periodic state syncing.
func stop_sync() -> void:
	_sync_timer.stop()


func _on_sync_timer() -> void:
	if orchestrator_available:
		get_state(_apply_state_delta)


## Apply state changes from orchestrator to local game state.
func _apply_state_delta(state_data: Dictionary) -> void:
	if not state_data.has("character"):
		return

	var char_data: Dictionary = state_data["character"]
	var player: Monster = World.player
	if not player or not player.character_data:
		return

	# Sync HP
	var new_hp: int = int(char_data.get("current_hp", player.character_data.current_hp))
	if new_hp != player.character_data.current_hp:
		player.character_data.current_hp = new_hp
		player.hp = new_hp

	# Sync narration
	if state_data.has("narrative"):
		var narrative: Dictionary = state_data["narrative"]
		var narration: String = narrative.get("current_narration", "")
		if not narration.is_empty() and _nm:
			var choices_raw: Array = narrative.get("current_choices", [])
			if not choices_raw.is_empty():
				var choices: Array[String] = []
				for c: Variant in choices_raw:
					choices.append(str(c))
				_nm.present_choices(choices, func(index: int) -> void:
					send_action("custom", "", choices[index])
				)

	state_synced.emit(state_data)


## Send a player action to the orchestrator.
## action_type: one of "move", "attack", "speak", "use_item", "interact", "rest", "look", "custom"
## Returns immediately; results come via response_received signal.
func send_action(
	action_type: String,
	target: String = "",
	message: String = "",
	direction: String = "",
	item_slug: String = "",
	extra: Dictionary = {},
) -> void:
	if _request_in_flight:
		Log.w("OrchestratorClient: request already in flight, ignoring")
		return

	var body := {"action_type": action_type}
	if not target.is_empty():
		body["target"] = target
	if not message.is_empty():
		body["message"] = message
	if not direction.is_empty():
		body["direction"] = direction
	if not item_slug.is_empty():
		body["item_slug"] = item_slug
	if not extra.is_empty():
		body["extra"] = extra

	if not orchestrator_available:
		# Fallback: generate local response without HTTP
		_handle_fallback(action_type, target, message)
		return

	_request_in_flight = true
	request_started.emit()

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := base_url + "/action"

	# Create a fresh HTTPRequest for this call (the built-in one is single-use per request)
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
			_on_action_response(result, code, body_bytes)
			req.queue_free()
	)

	var err := req.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		Log.e("OrchestratorClient: failed to send request: %d" % err)
		_request_in_flight = false
		request_finished.emit()
		_handle_fallback(action_type, target, message)
		req.queue_free()


## Request the current game state from the orchestrator.
func get_state(callback: Callable) -> void:
	if not orchestrator_available:
		Log.w("OrchestratorClient: orchestrator not available for state sync")
		return

	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
			if result == HTTPRequest.RESULT_SUCCESS and code == 200:
				var json := JSON.new()
				var parse_err := json.parse(body_bytes.get_string_from_utf8())
				if parse_err == OK:
					callback.call(json.data)
				else:
					Log.e("OrchestratorClient: failed to parse state response")
			else:
				Log.w("OrchestratorClient: state request failed (result=%d, code=%d)" % [result, code])
			req.queue_free()
	)

	var err := req.request(base_url + "/state")
	if err != OK:
		Log.e("OrchestratorClient: failed to send state request: %d" % err)
		req.queue_free()


## Check orchestrator health and update availability status.
func _check_health() -> void:
	var req := HTTPRequest.new()
	req.timeout = 5.0
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			var was_available := orchestrator_available
			orchestrator_available = (result == HTTPRequest.RESULT_SUCCESS and code == 200)

			if orchestrator_available != was_available:
				orchestrator_status_changed.emit(orchestrator_available)
				if orchestrator_available:
					Log.i("OrchestratorClient: orchestrator connected at %s" % base_url)
				else:
					Log.w("OrchestratorClient: orchestrator not available, using fallback mode")

			req.queue_free()
	)

	var err := req.request(base_url + "/health")
	if err != OK:
		orchestrator_available = false
		Log.w("OrchestratorClient: cannot reach orchestrator at %s" % base_url)
		req.queue_free()


## Handle the HTTP response from POST /action.
func _on_action_response(result: int, code: int, body_bytes: PackedByteArray) -> void:
	_request_in_flight = false
	request_finished.emit()

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Log.w("OrchestratorClient: action request failed (result=%d, code=%d)" % [result, code])
		# Mark orchestrator as potentially down
		if result == HTTPRequest.RESULT_CANT_CONNECT or result == HTTPRequest.RESULT_CONNECTION_ERROR:
			orchestrator_available = false
			orchestrator_status_changed.emit(false)
		return

	var json := JSON.new()
	var parse_err := json.parse(body_bytes.get_string_from_utf8())
	if parse_err != OK:
		Log.e("OrchestratorClient: failed to parse action response JSON")
		return

	var data: Dictionary = json.data

	var narration: String = data.get("narration", "")
	var raw_choices: Array = data.get("choices", [])
	var choices: Array[String] = []
	for choice: Variant in raw_choices:
		choices.append(str(choice))

	# Check for errors from orchestrator
	var error: Variant = data.get("error", null)
	if error != null and not str(error).is_empty():
		Log.w("OrchestratorClient: orchestrator reported error: %s" % str(error))

	# Relay to NarrativeManager
	if not narration.is_empty() and _nm:
		_nm.add_narrative(narration)
		if choices.size() > 0:
			_nm.present_choices(choices, func(index: int) -> void:
				# When player picks a choice, send it as a new action
				send_action("custom", "", choices[index])
			)

	response_received.emit(narration, choices)


## Generate a local fallback response when the orchestrator is unavailable.
## This preserves Phase 1 behavior — the game remains playable without the backend.
func _handle_fallback(action_type: String, target: String, message: String) -> void:
	var narration := ""
	var choices: Array[String] = []

	match action_type:
		"look":
			narration = "You look around carefully, taking in your surroundings."
			choices = ["Move forward", "Check inventory", "Rest"]
		"move":
			narration = "You move cautiously through the area."
			choices = ["Look around", "Continue forward", "Go back"]
		"attack":
			if not target.is_empty():
				narration = "You attack %s!" % target
			else:
				narration = "You swing your weapon at the enemy!"
			choices = ["Attack again", "Defend", "Retreat"]
		"speak":
			if not target.is_empty():
				narration = "You address %s." % target
				if not message.is_empty():
					narration += ' "%s"' % message
			else:
				narration = "You speak aloud."
			choices = ["Ask a question", "Look around", "Move on"]
		"rest":
			narration = "You take a moment to rest and gather your strength."
			choices = ["Continue exploring", "Check inventory", "Look around"]
		"interact":
			if not target.is_empty():
				narration = "You examine %s closely." % target
			else:
				narration = "You interact with the object."
			choices = ["Look around", "Move on", "Check inventory"]
		_:
			narration = "You consider your next move."
			choices = ["Look around", "Move forward", "Check inventory"]

	# Relay to NarrativeManager
	if _nm:
		_nm.add_narrative(narration)
		if choices.size() > 0:
			_nm.present_choices(choices, func(index: int) -> void:
				send_action("custom", "", choices[index])
			)

	response_received.emit(narration, choices)
