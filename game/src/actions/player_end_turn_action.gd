class_name PlayerEndTurnAction
extends BaseAction

## Explicitly ends the player's combat turn, forfeiting remaining actions.


func _execute(_map: Map, result: ActionResult) -> bool:
	result.success = true
	result.message = "You end your turn."
	return true


func _to_string() -> String:
	return "PlayerEndTurnAction()"
