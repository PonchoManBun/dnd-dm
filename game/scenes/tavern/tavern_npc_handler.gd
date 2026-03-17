class_name TavernNpcHandler
extends RefCounted

## Handles NPC interactions in the tavern.
## Routes to orchestrator when available, falls back to local dialogue.

var _nm: Node  # NarrativeManager
var _oc: Node  # OrchestratorClient
var _npc_profiles: Dictionary = {}
var _npc_interacted: Dictionary = {}  # npc_id -> int (interaction count)


func _init(narrative_manager: Node, orchestrator_client: Node) -> void:
	_nm = narrative_manager
	_oc = orchestrator_client
	_load_profiles()


func _load_profiles() -> void:
	var file := FileAccess.open("res://assets/data/npc_profiles.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		if json.parse(file.get_as_text()) == OK:
			_npc_profiles = json.data
		file.close()
	else:
		push_warning("TavernNpcHandler: could not load npc_profiles.json")


func get_profile(npc_id: String) -> Dictionary:
	return _npc_profiles.get(npc_id, {})


func handle_npc_interaction(npc_id: String) -> void:
	var npc_profile: Dictionary = _npc_profiles.get(npc_id, {})

	# Route to orchestrator if available
	if _oc and _oc.orchestrator_available:
		_oc.send_action("speak", npc_id, "", "", "", npc_profile)
		return

	# Local handling
	var npc_name: String = npc_profile.get("name", npc_id)
	var interact_count: int = _npc_interacted.get(npc_id, 0)
	_npc_interacted[npc_id] = interact_count + 1

	if interact_count > 0:
		_handle_repeat(npc_id, npc_name, interact_count)
		return

	_handle_first(npc_id, npc_name, npc_profile)


func _handle_first(npc_id: String, npc_name: String, npc_profile: Dictionary) -> void:
	var greeting: String = npc_profile.get("greeting", "...")

	match npc_id:
		"marta":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] looks up from polishing a mug. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				["Ask about the cellar", "Order a drink", "Ask about rumors"],
				_marta_choice_callback
			)
		"old_tom":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] looks up from his ale with bloodshot eyes. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				["Ask about his adventures", "Ask about the area", "Buy him a drink"],
				_old_tom_choice_callback
			)
		"elara":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] glances at you from beneath her hood. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				["Ask who she is", "Ask about the east road", "Sit down quietly"],
				_elara_choice_callback
			)
		_:
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] regards you. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)


func _handle_repeat(npc_id: String, npc_name: String, interact_count: int) -> void:
	var acknowledgments: Array[String] = []
	var choices: Array[String] = []
	var callback: Callable

	match npc_id:
		"marta":
			acknowledgments = [
				"[color=#d9d566]%s[/color] is busy polishing mugs." % npc_name,
				"[color=#d9d566]%s[/color] nods at you from behind the bar." % npc_name,
				"[color=#d9d566]%s[/color] glances up. \"[i]Back again?[/i]\"" % npc_name,
			]
			choices = ["Ask about the cellar", "Order a drink", "Ask about rumors"]
			callback = _marta_choice_callback
		"old_tom":
			acknowledgments = [
				"[color=#d9d566]%s[/color] nods at you." % npc_name,
				"[color=#d9d566]%s[/color] grunts into his ale." % npc_name,
				"[color=#d9d566]%s[/color] squints at you. \"[i]You again, eh?[/i]\"" % npc_name,
			]
			choices = ["Ask about his adventures", "Ask about the area", "Buy him a drink"]
			callback = _old_tom_choice_callback
		"elara":
			acknowledgments = [
				"[color=#d9d566]%s[/color] acknowledges you with a slight nod." % npc_name,
				"[color=#d9d566]%s[/color] watches you from beneath her hood." % npc_name,
				"[color=#d9d566]%s[/color] raises an eyebrow but says nothing." % npc_name,
			]
			choices = ["Ask who she is", "Ask about the east road", "Sit down quietly"]
			callback = _elara_choice_callback
		_:
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] acknowledges you." % npc_name
			)
			return

	var ack_index: int = (interact_count - 1) % acknowledgments.size()
	_nm.add_narrative(acknowledgments[ack_index])
	_nm.present_choices(choices, callback)


func _marta_choice_callback(index: int) -> void:
	match index:
		0:
			_nm.add_narrative(
				'"[i]Strange noises down there lately. '
				+ "I'll pay you well to clear it out.[/i]\""
			)
		1:
			_nm.add_narrative(
				'"[i]Coming right up. One ale, on the house '
				+ 'for a fellow adventurer.[/i]"'
			)
		2:
			_nm.add_narrative(
				"\"[i]Word is there's been disappearances on the "
				+ 'east road. Merchants, mostly.[/i]"'
			)


func _old_tom_choice_callback(index: int) -> void:
	match index:
		0:
			_nm.add_narrative(
				'"[i]Did I ever tell you about the time I fought '
				+ "a dragon? Well, it was more of a drake, but still... "
				+ 'nearly took my arm off.[/i]"'
			)
		1:
			_nm.add_narrative(
				'"[i]The old crypt north of town? Stay away from there, '
				+ "I say. But if you must go, bring fire. "
				+ 'The things down there hate fire.[/i]"'
			)
		2:
			_nm.add_narrative(
				'"[i]Well now, that\'s the spirit! You remind me of '
				+ "myself, thirty years ago. Here's a tip — never trust "
				+ 'a locked chest in a dungeon.[/i]"'
			)


func _elara_choice_callback(index: int) -> void:
	match index:
		0:
			_nm.add_narrative(
				"She regards you with pale eyes. "
				+ '"[i]Names are currency. I do not spend mine freely.[/i]"'
			)
		1:
			_nm.add_narrative(
				"A slight tilt of her head. "
				+ '"[i]The east road... yes. Something stirs there. '
				+ 'Not all who vanish are dead.[/i]"'
			)
		2:
			_nm.add_narrative(
				"You sit across from her in silence. After a long moment, "
				+ 'she nods approvingly. "[i]Patience. A rare quality.[/i]"'
			)
