class_name TavernNpcHandler
extends RefCounted

## Handles NPC interactions in the tavern.
## Routes to orchestrator when available, falls back to local dialogue.

## Maps DndClass enum name strings to their enum values.
const DND_CLASS_MAP := {
	"FIGHTER": CharacterData.DndClass.FIGHTER,
	"WIZARD": CharacterData.DndClass.WIZARD,
	"ROGUE": CharacterData.DndClass.ROGUE,
	"CLERIC": CharacterData.DndClass.CLERIC,
	"RANGER": CharacterData.DndClass.RANGER,
	"PALADIN": CharacterData.DndClass.PALADIN,
	"BARBARIAN": CharacterData.DndClass.BARBARIAN,
	"BARD": CharacterData.DndClass.BARD,
	"DRUID": CharacterData.DndClass.DRUID,
	"MONK": CharacterData.DndClass.MONK,
	"SORCERER": CharacterData.DndClass.SORCERER,
	"WARLOCK": CharacterData.DndClass.WARLOCK,
}

var _nm: Node  # NarrativeManager
var _oc: Node  # OrchestratorClient
var _npc_profiles: Dictionary = {}
var _npc_interacted: Dictionary = {}  # npc_id -> int (interaction count)
var _recruited_npcs: Dictionary = {}  # npc_id -> true (already recruited)


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
				_build_choices(["Ask about his adventures", "Ask about the area", "Buy him a drink"], npc_id),
				_old_tom_choice_callback
			)
		"elara":
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] glances at you from beneath her hood. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			_nm.present_choices(
				_build_choices(["Ask who she is", "Ask about the east road", "Sit down quietly"], npc_id),
				_elara_choice_callback
			)
		_:
			var base_choices: Array[String] = []
			if _is_recruitable(npc_id):
				base_choices = _build_choices([], npc_id)
			_nm.add_narrative(
				"[color=#d9d566]%s[/color] regards you. " % npc_name
				+ '"[i]%s[/i]"' % greeting
			)
			if base_choices.size() > 0:
				_nm.present_choices(base_choices, _make_generic_recruit_callback(npc_id))


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
			choices = _build_choices(["Ask about his adventures", "Ask about the area", "Buy him a drink"], npc_id)
			callback = _old_tom_choice_callback
		"elara":
			acknowledgments = [
				"[color=#d9d566]%s[/color] acknowledges you with a slight nod." % npc_name,
				"[color=#d9d566]%s[/color] watches you from beneath her hood." % npc_name,
				"[color=#d9d566]%s[/color] raises an eyebrow but says nothing." % npc_name,
			]
			choices = _build_choices(["Ask who she is", "Ask about the east road", "Sit down quietly"], npc_id)
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
	if _is_recruit_choice(index, 3, "old_tom"):
		_attempt_recruit("old_tom")
		return

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
	if _is_recruit_choice(index, 3, "elara"):
		_attempt_recruit("elara")
		return

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


## -- Recruitment helpers --


## Returns true if the NPC profile has `recruitable: true`.
func _is_recruitable(npc_id: String) -> bool:
	if _recruited_npcs.has(npc_id):
		return false
	var profile: Dictionary = _npc_profiles.get(npc_id, {})
	return profile.get("recruitable", false)


## Build the choice list, appending "Recruit to Party" if the NPC is recruitable.
func _build_choices(base_choices: Array[String], npc_id: String) -> Array[String]:
	var choices: Array[String] = []
	choices.assign(base_choices)
	if _is_recruitable(npc_id):
		choices.append("Recruit to Party")
	return choices


## Returns true if the selected index is the recruit option (appended after base_count choices).
func _is_recruit_choice(index: int, base_count: int, npc_id: String) -> bool:
	return index == base_count and _is_recruitable(npc_id)


## Attempt to recruit the NPC using the Recruitment system.
func _attempt_recruit(npc_id: String) -> void:
	var profile: Dictionary = _npc_profiles.get(npc_id, {})
	var npc_name: String = profile.get("name", npc_id)
	var slug := StringName(profile.get("stat_block_slug", "commoner"))
	var dc: int = profile.get("recruitment_dc", 10)
	var dnd_class: int = _resolve_dnd_class(profile.get("dnd_class", ""))

	var companion := Recruitment.recruit_npc(slug, npc_name, dnd_class, dc)
	if companion:
		_recruited_npcs[npc_id] = true
		_nm.add_narrative(
			"[color=#d9d566]%s[/color] gathers their things. " % npc_name
			+ '"[i]Very well. Let us see what fate has in store.[/i]"'
		)
	else:
		_nm.add_narrative(
			"[color=#d9d566]%s[/color] shakes their head slowly." % npc_name
		)


## Resolve a class name string (e.g. "FIGHTER") to the CharacterData.DndClass enum value.
## Returns -1 to let StatBlockConverter infer from ability scores.
func _resolve_dnd_class(class_name_str: String) -> int:
	if class_name_str.is_empty():
		return -1
	return DND_CLASS_MAP.get(class_name_str, -1)


## Creates a generic recruit callback for NPCs that only have a recruit option.
func _make_generic_recruit_callback(npc_id: String) -> Callable:
	return func(index: int) -> void:
		if index == 0:
			_attempt_recruit(npc_id)
