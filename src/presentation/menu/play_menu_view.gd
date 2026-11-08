class_name PlayMenuView
extends Control
## Game selection panel shown from the Main Menu.
## Exposes New Game and Continue buttons; emits new_game_pressed and
## continue_pressed when the player selects them. The Continue button's
## disabled state is controlled externally by the presenter based on
## SaveGameController.has_saved_game(). Visibility is toggled by the
## presenter in response to NavigationController.screen_changed.

signal new_game_pressed
signal continue_pressed

@export_group("Structure")
@export var new_game_button: Button
@export var continue_button: Button


func _ready() -> void:
	if new_game_button != null and not new_game_button.pressed.is_connected(_on_new_game_pressed):
		new_game_button.pressed.connect(_on_new_game_pressed)
	if continue_button != null and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if new_game_button == null:
		errors.append("PlayMenuView: assign new_game_button.")
	if continue_button == null:
		errors.append("PlayMenuView: assign continue_button.")
	return errors


## Toggles the Continue button. The presenter calls this from
## SaveGameController.save_state_changed / has_saved_game so the Continue
## option is disabled when no saved game exists.
func set_continue_enabled(enabled: bool) -> void:
	if continue_button != null:
		continue_button.disabled = not enabled


## Returns whether the Continue button is currently interactive.
func is_continue_enabled() -> bool:
	return continue_button != null and not continue_button.disabled


func _on_new_game_pressed() -> void:
	new_game_pressed.emit()


func _on_continue_pressed() -> void:
	continue_pressed.emit()
