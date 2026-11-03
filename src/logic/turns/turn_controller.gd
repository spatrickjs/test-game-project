class_name TurnController
extends Node
## Manual discrete clock. No frame callback or timer drives simulation.

signal turn_completed(turn_index: int)

@export var farming_controller: FarmingController

var turn_index: int = 0
var last_error: String = ""
var _advancing: bool = false


func reset_clock() -> void:
	if not _advancing:
		turn_index = 0
		last_error = ""


func advance_turn() -> bool:
	if _advancing:
		return false
	if farming_controller == null or not farming_controller.is_initialized():
		last_error = "Assign and initialize the FarmingController first."
		return false
	_advancing = true
	if not farming_controller.advance_growth():
		last_error = farming_controller.last_error
		_advancing = false
		return false
	turn_index += 1
	last_error = ""
	turn_completed.emit(turn_index)
	_advancing = false
	return true
