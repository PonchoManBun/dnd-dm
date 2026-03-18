class_name PlayerAttackMoveAction
extends AttackMoveAction


func _init(dir: Vector2i) -> void:
	super(World.active_character, dir)


func _to_string() -> String:
	return "PlayerAttackMoveAction(direction: %s)" % direction
