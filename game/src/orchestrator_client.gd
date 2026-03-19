extends Node

## HTTP client for communicating with the Python/FastAPI DM Orchestrator.
## Sends player actions via POST /action, receives DM narration + choices.
## Falls back to Phase 1 hardcoded behavior if orchestrator is unavailable.

signal response_received(narration: String, choices: Array[String])
signal request_started
signal request_finished
signal orchestrator_status_changed(available: bool)
signal state_synced(state_data: Dictionary)
signal npc_response_received(data: Dictionary)
signal thinking_started
signal thinking_finished

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
var _health_timer: Timer
var _health_interval: float = 30.0


func _ready() -> void:
	_nm = get_node_or_null("/root/NarrativeManager")
	_http_request = HTTPRequest.new()
	_http_request.timeout = 45.0  # 45 second timeout
	add_child(_http_request)

	# Add sync timer
	_sync_timer = Timer.new()
	_sync_timer.wait_time = _sync_interval
	_sync_timer.autostart = false
	_sync_timer.timeout.connect(_on_sync_timer)
	add_child(_sync_timer)

	# Add health re-check timer for recovery
	_health_timer = Timer.new()
	_health_timer.wait_time = _health_interval
	_health_timer.autostart = true
	_health_timer.timeout.connect(_check_health)
	add_child(_health_timer)

	# Wire free-text input from NarrativeManager to orchestrator
	if _nm and _nm.has_signal("player_input_submitted"):
		_nm.player_input_submitted.connect(_on_player_input)

	# Auto-narrate on room entry when offline
	World.map_changed.connect(_on_map_changed)

	# Check orchestrator health on startup
	_check_health()


## Sync the player character to the orchestrator on game start.
func sync_character() -> void:
	if not orchestrator_available:
		return

	var player: Monster = World.player
	if not player or not player.character_data:
		return

	var cd: CharacterData = player.character_data
	var body := {
		"name": cd.character_name,
		"race": CharacterData.Race.keys()[cd.race].to_lower(),
		"dnd_class": CharacterData.DndClass.keys()[cd.dnd_class].to_lower(),
		"level": cd.level,
		"max_hp": cd.max_hp,
		"current_hp": cd.current_hp,
		"strength": cd.strength,
		"dexterity": cd.dexterity,
		"constitution": cd.constitution,
		"intelligence": cd.intelligence,
		"wisdom": cd.wisdom,
		"charisma": cd.charisma,
	}

	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])

	var req := HTTPRequest.new()
	req.timeout = 10.0
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			if result == HTTPRequest.RESULT_SUCCESS and (code == 200 or code == 201):
				Log.i("OrchestratorClient: character synced to orchestrator")
			else:
				Log.w("OrchestratorClient: character sync failed (result=%d, code=%d)" % [result, code])
			req.queue_free()
	)

	var err := req.request(base_url + "/character/create", headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		Log.e("OrchestratorClient: failed to send character sync: %d" % err)
		req.queue_free()


## Start periodic state syncing (call after character is created).
func start_sync() -> void:
	if orchestrator_available:
		_sync_timer.start()
		sync_character()


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

	# Sync narration (choices suppressed — only NPC/obstacle interactions show choices)
	if state_data.has("narrative"):
		var narrative: Dictionary = state_data["narrative"]
		var narration: String = narrative.get("current_narration", "")
		if not narration.is_empty() and _nm:
			_nm.add_narrative(narration)

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

	# Route NPC speech to dedicated endpoint
	if action_type == "speak" and not target.is_empty() and orchestrator_available:
		send_npc_speak(target, message if not message.is_empty() else "Hello")
		return

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
	req.timeout = 45.0
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


## Send a message to a specific NPC via the dedicated NPC endpoint.
## Returns immediately; results come via npc_response_received signal.
func send_npc_speak(npc_id: String, message: String, speaker: String = "adventurer") -> void:
	if _request_in_flight:
		Log.w("OrchestratorClient: request already in flight, ignoring")
		return

	if not orchestrator_available:
		_handle_fallback("speak", npc_id, message)
		return

	_request_in_flight = true
	request_started.emit()
	thinking_started.emit()

	var body := {
		"npc_id": npc_id,
		"message": message,
		"speaker": speaker,
	}
	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := base_url + "/npc/speak"

	var req := HTTPRequest.new()
	req.timeout = 45.0
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
			_on_npc_response(result, code, body_bytes)
			req.queue_free()
	)

	var err := req.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		Log.e("OrchestratorClient: failed to send NPC request: %d" % err)
		_request_in_flight = false
		request_finished.emit()
		thinking_finished.emit()
		_handle_fallback("speak", npc_id, message)
		req.queue_free()


## Send a skill check against an NPC.
func send_npc_skill_check(npc_id: String, skill: String) -> void:
	if _request_in_flight:
		Log.w("OrchestratorClient: request already in flight, ignoring")
		return

	if not orchestrator_available:
		return

	_request_in_flight = true
	request_started.emit()
	thinking_started.emit()

	var body := {"npc_id": npc_id, "skill": skill}
	var json_body := JSON.stringify(body)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var url := base_url + "/npc/skill_check"

	var req := HTTPRequest.new()
	req.timeout = 45.0
	add_child(req)
	req.request_completed.connect(
		func(result: int, code: int, _headers: PackedStringArray, body_bytes: PackedByteArray) -> void:
			_on_npc_response(result, code, body_bytes)
			req.queue_free()
	)

	var err := req.request(url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		Log.e("OrchestratorClient: failed to send skill check request: %d" % err)
		_request_in_flight = false
		request_finished.emit()
		thinking_finished.emit()
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

	# Relay narration to NarrativeManager (suppress generic LLM choices —
	# choices only come from direct NPC/obstacle interactions)
	if not narration.is_empty() and _nm:
		_nm.add_narrative(narration)

	response_received.emit(narration, choices)


## Handle the HTTP response from NPC endpoints.
func _on_npc_response(result: int, code: int, body_bytes: PackedByteArray) -> void:
	_request_in_flight = false
	request_finished.emit()
	thinking_finished.emit()

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		Log.w("OrchestratorClient: NPC request failed (result=%d, code=%d)" % [result, code])
		if result == HTTPRequest.RESULT_CANT_CONNECT or result == HTTPRequest.RESULT_CONNECTION_ERROR:
			orchestrator_available = false
			orchestrator_status_changed.emit(false)
		return

	var json := JSON.new()
	var parse_err := json.parse(body_bytes.get_string_from_utf8())
	if parse_err != OK:
		Log.e("OrchestratorClient: failed to parse NPC response JSON")
		return

	var data: Dictionary = json.data
	var narration: String = data.get("narration", "")
	var raw_choices: Array = data.get("choices", [])
	var choices: Array[String] = []
	for choice: Variant in raw_choices:
		choices.append(str(choice))

	var npc_id: String = data.get("npc_id", "")
	var mode: String = data.get("mode", "chatting")

	# Relay to NarrativeManager
	if not narration.is_empty() and _nm:
		_nm.add_narrative(narration)
		if choices.size() > 0:
			_nm.present_choices(choices, func(index: int) -> void:
				_handle_npc_choice(npc_id, mode, choices, index)
			)

	npc_response_received.emit(data)
	response_received.emit(narration, choices)


## Handle a choice selection during an NPC conversation.
func _handle_npc_choice(npc_id: String, mode: String, choices: Array[String], index: int) -> void:
	var choice_text: String = choices[index] if index < choices.size() else ""

	# Echo the player's choice in the narrative
	if _nm and not choice_text.is_empty():
		_nm.add_narrative("[color=#6cb4c4]> %s[/color]" % choice_text)

	# Check for skill check choices
	if choice_text.begins_with("Try Persuasion"):
		send_npc_skill_check(npc_id, "persuasion")
		return
	if choice_text.begins_with("Try Intimidation"):
		send_npc_skill_check(npc_id, "intimidation")
		return
	if choice_text.begins_with("Make your case"):
		send_npc_skill_check(npc_id, "persuasion")
		return

	# End conversation
	if choice_text in ["End conversation", "Walk away", "Leave", "Decline"]:
		if _nm:
			_nm.add_narrative("[color=#888888]You step away.[/color]")
		return

	# Otherwise, send the choice text as a new message to the NPC
	send_npc_speak(npc_id, choice_text)


## Handle free-text player input — send to orchestrator as a "speak" action.
func _on_player_input(text: String) -> void:
	if text.strip_edges().is_empty():
		return
	# Parse speaker/target context from the text if present
	var clean_text := text
	var speak_target := ""

	# Extract [Speaking to: X] prefix if present
	var to_match := RegEx.new()
	to_match.compile("\\[Speaking to: (.+?)\\] (.*)")
	var to_result := to_match.search(clean_text)
	if to_result:
		speak_target = to_result.get_string(1)
		clean_text = to_result.get_string(2)

	# Extract [Speaking as: X] prefix if present
	var as_match := RegEx.new()
	as_match.compile("\\[Speaking as: (.+?)\\] (.*)")
	var as_result := as_match.search(clean_text)
	if as_result:
		# Include speaker context in the message
		clean_text = as_result.get_string(2)

	send_action("speak", speak_target, clean_text)


## Generate a local fallback response when the orchestrator is unavailable.
## Produces narration only — no generic choices (choices come from NPC/obstacle interactions).
func _handle_fallback(action_type: String, target: String, message: String) -> void:
	var narration := ""

	match action_type:
		"speak":
			if not target.is_empty():
				narration = "You address %s." % target
				if not message.is_empty():
					narration += " \"%s\"" % message
				narration += "\n[color=#888888](DM is offline — no LLM response available)[/color]"
			else:
				narration = "You speak aloud."
				if not message.is_empty():
					narration += " \"%s\"" % message
				narration += "\n[color=#888888](DM is offline — no LLM response available)[/color]"
		"attack":
			if not target.is_empty():
				narration = "You attack %s!" % target
			else:
				narration = "You swing your weapon at the enemy!"
		"rest":
			narration = "You take a moment to rest and gather your strength."
		"interact":
			if not target.is_empty():
				narration = "You examine %s closely." % target
			else:
				narration = "You interact with the object."
		_:
			narration = "You consider your next move."

	# Relay narration to NarrativeManager
	if _nm:
		_nm.add_narrative(narration)

	var choices: Array[String] = []
	response_received.emit(narration, choices)


## Auto-narrate on room/map entry when orchestrator is offline.
func _on_map_changed(map: Map) -> void:
	if orchestrator_available or not map or not _nm:
		return

	# Build a brief room-entry narration from map data
	var parts: Array[String] = []

	# Map identity
	if map.depth == 1:
		parts.append("You enter the first level of the dungeon.")
	else:
		parts.append("You descend to depth %d." % map.depth)

	# Monster count
	var monsters := map.get_monsters()
	var hostile_count := 0
	for m: Monster in monsters:
		if not World.party.is_party_member(m) and m != World.player:
			hostile_count += 1
	if hostile_count == 1:
		parts.append("You sense a creature lurking nearby.")
	elif hostile_count > 1:
		parts.append("You sense %d creatures lurking in the shadows." % hostile_count)

	# Stairs
	if map.has_stairs_down():
		parts.append("A stairway leads further down.")
	if map.has_stairs_up():
		parts.append("Stairs lead back up.")

	var narration := "[color=#6cb4c4]%s[/color]" % " ".join(parts)
	_nm.add_narrative(narration)
