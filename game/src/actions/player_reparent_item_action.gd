class_name PlayerReparentItemAction
extends ReparentItemAction


func _init(p_item: Item, p_new_parent: Item = null) -> void:
	super(World.active_character, p_item, p_new_parent)
