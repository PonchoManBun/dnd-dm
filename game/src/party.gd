class_name Party
extends RefCounted

## Manages the player's party of companions (up to 3 + the player = 4 total).

const MAX_COMPANIONS := 3

## Companion monsters (does NOT include the player)
var members: Array[Monster] = []


func add_member(monster: Monster) -> bool:
	if is_full() or is_party_member(monster):
		return false
	members.append(monster)
	return true


func remove_member(monster: Monster) -> bool:
	var idx := members.find(monster)
	if idx == -1:
		return false
	members.remove_at(idx)
	return true


## Returns true if monster is the player OR a companion
func is_party_member(monster: Monster) -> bool:
	if monster == World.player:
		return true
	return monster in members


## Returns all party members: player first, then companions
func get_all_members() -> Array[Monster]:
	var all: Array[Monster] = []
	if World.player:
		all.append(World.player)
	all.append_array(members)
	return all


## Returns true if all party members (player + companions) are dead
func all_dead() -> bool:
	if World.player and not World.player.is_dead:
		return false
	for member in members:
		if not member.is_dead:
			return false
	return true


func is_full() -> bool:
	return members.size() >= MAX_COMPANIONS


func size() -> int:
	# Total party size including player
	return 1 + members.size()


## Returns only living party members
func get_living_members() -> Array[Monster]:
	var living: Array[Monster] = []
	if World.player and not World.player.is_dead:
		living.append(World.player)
	for member in members:
		if not member.is_dead:
			living.append(member)
	return living
