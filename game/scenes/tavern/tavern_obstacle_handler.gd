class_name TavernObstacleHandler
extends RefCounted

## Handles obstacle interactions in the tavern (quest board, shop, memorial, etc.).

var _nm: Node  # NarrativeManager
var _active: bool = false


func _init(narrative_manager: Node) -> void:
	_nm = narrative_manager


func is_active() -> bool:
	return _active


func handle_obstacle(obstacle_char: String) -> void:
	match obstacle_char:
		"Q":
			_interact_quest_board()
		"M":
			_interact_memorial_wall()
		"s":
			_interact_shop()
		"S":
			_nm.add_narrative(
				"The [color=#d9d566]stairs[/color] lead up to the rooms. "
				+ "You could rest here."
			)
		"R":
			_nm.add_narrative(
				"The [color=#d9d566]room door[/color] is locked. "
				+ "Ask the barkeep about lodging."
			)
		"B":
			_nm.add_narrative(
				"The [color=#d9d566]bar counter[/color] is polished to a warm sheen."
			)


func _interact_quest_board() -> void:
	_active = true
	_nm.add_narrative(
		"[color=#6cb4c4][b]Quest Board[/b][/color]\n"
		+ "You approach the wooden board nailed to the wall. "
		+ "A few rusty pins hold scraps of parchment, but most have "
		+ "faded beyond reading. One notice remains legible:"
	)
	_nm.add_narrative(
		"[color=#d9d566]\"Adventurers Wanted\"[/color]\n"
		+ "[i]No quests available yet — check back after your first adventure. "
		+ "The board fills as the world awakens.[/i]"
	)
	_nm.present_choices(
		["Look more closely", "Step away"],
		func(index: int) -> void:
			_active = false
			match index:
				0:
					_nm.add_narrative(
						"You squint at the faded parchment scraps. Most are old "
						+ "bounties long since claimed, shopping lists someone pinned "
						+ "by mistake, and a crude drawing of a dragon labeled "
						+ "\"[i]Bort wuz here.[/i]\""
					)
				1:
					_nm.add_narrative(
						"You turn away from the quest board. Perhaps the barkeep "
						+ "knows of work that needs doing."
					)
	)


func _interact_shop() -> void:
	_active = true
	_nm.add_narrative(
		"[color=#6cb4c4][b]General Store[/b][/color]\n"
		+ "You lean over the shop counter. A hand-written price list "
		+ "is tacked to the wall behind it:"
	)
	_nm.add_narrative(
		"[color=#d9d566]Wares for Sale:[/color]\n"
		+ "  [color=#d9d566]Health Potion[/color] ........ 50 gp\n"
		+ "  [color=#d9d566]Torch[/color] .................. 1 gp\n"
		+ "  [color=#d9d566]Rations (1 day)[/color] ....... 5 sp\n"
		+ "  [color=#d9d566]Rope, 50 ft[/color] ........... 1 gp\n"
		+ "  [color=#d9d566]Antidote[/color] .............. 50 gp"
	)
	_nm.present_choices(
		["Browse the Health Potions", "Ask about special stock", "Step away"],
		func(index: int) -> void:
			_active = false
			match index:
				0:
					_nm.add_narrative(
						"You eye the row of small red vials behind the counter. "
						+ "They look genuine enough, but the shopkeeper is nowhere to be seen. "
						+ "[i](Purchasing coming soon.)[/i]"
					)
				1:
					_nm.add_narrative(
						"A small sign reads: \"[i]Ask about enchanted items — "
						+ "by appointment only.[/i]\" The counter remains unattended. "
						+ "[i](Special stock coming soon.)[/i]"
					)
				2:
					_nm.add_narrative(
						"You step back from the shop counter. The prices seem "
						+ "fair enough — you'll return when the shopkeeper is about."
					)
	)


func _interact_memorial_wall() -> void:
	_active = true
	_nm.add_narrative(
		"[color=#6cb4c4][b]Memorial Wall[/b][/color]\n"
		+ "A solemn bronze plaque is set into the stone wall, "
		+ "surrounded by small candle-stubs and dried flowers."
	)

	var fallen_names: Array[String] = _load_fallen_heroes()
	if fallen_names.size() > 0:
		var names_text := ""
		for hero_name: String in fallen_names:
			names_text += "  [color=#d44e4e]%s[/color]\n" % hero_name
		_nm.add_narrative(
			"[color=#d9d566]In Memoriam:[/color]\n" + names_text
			+ "[i]May they find peace beyond the veil.[/i]"
		)
	else:
		_nm.add_narrative(
			"The plaque reads:\n"
			+ "[i]\"No fallen heroes... yet. May this wall remain bare, "
			+ "but the brave know it never does for long.\"[/i]"
		)

	_nm.present_choices(
		["Pay your respects", "Step away"],
		func(index: int) -> void:
			_active = false
			match index:
				0:
					_nm.add_narrative(
						"You bow your head for a moment of silence. "
						+ "The candlelight flickers as if in acknowledgement."
					)
				1:
					_nm.add_narrative(
						"You turn from the memorial wall, reminded that "
						+ "every adventure carries a price."
					)
	)


func _load_fallen_heroes() -> Array[String]:
	var names: Array[String] = []
	var memorial_path := "user://memorial.json"
	if not FileAccess.file_exists(memorial_path):
		return names

	var file := FileAccess.open(memorial_path, FileAccess.READ)
	if not file:
		return names

	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data: Variant = json.data
		if data is Dictionary and data.has("fallen_heroes"):
			var heroes: Variant = data["fallen_heroes"]
			if heroes is Array:
				for entry: Variant in heroes:
					if entry is Dictionary:
						var hero_name: String = entry.get("name", "Unknown")
						var hero_class: String = entry.get("class", "")
						var hero_level: String = str(entry.get("level", ""))
						var display := hero_name
						if hero_class != "" or hero_level != "":
							display += " — "
							if hero_class != "":
								display += hero_class
							if hero_level != "":
								display += " Lv.%s" % hero_level
						names.append(display)
					elif entry is String:
						names.append(entry)
	file.close()
	return names
