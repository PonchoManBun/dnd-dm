class_name PlayerUseItemAction
extends UseItemAction


func _init(p_item: Item) -> void:
	super(World.active_character, p_item)


func _to_string() -> String:
	return "PlayerUseItemAction(item: %s)" % item
