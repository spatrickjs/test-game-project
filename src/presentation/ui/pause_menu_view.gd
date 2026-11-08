class_name PauseMenuView
extends Control
## Full-screen pause overlay shown above the game HUD. Forwards the Continue and
## Exit to Main Menu button presses as signals so FieldPrototypePresenter can
## resume or leave the game. Stays interactive while the SceneTree is paused
## (process_mode is ALWAYS); the presenter toggles visibility and tree pausing.

signal continue_pressed
signal exit_to_menu_pressed

@export_group("Buttons")
@export var continue_button: Button
@export var exit_to_menu_button: Button


func _ready() -> void:
	# The menu must keep receiving input and signals while the tree is paused so
	# its buttons stay clickable. Children inherit this mode.
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if continue_button != null and not continue_button.pressed.is_connected(_on_continue_pressed):
		continue_button.pressed.connect(_on_continue_pressed)
	if exit_to_menu_button != null and not exit_to_menu_button.pressed.is_connected(_on_exit_to_menu_pressed):
		exit_to_menu_button.pressed.connect(_on_exit_to_menu_pressed)


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if continue_button == null:
		errors.append("PauseMenuView: assign continue_button.")
	if exit_to_menu_button == null:
		errors.append("PauseMenuView: assign exit_to_menu_button.")
	return errors


func show_menu() -> void:
	visible = true


func hide_menu() -> void:
	visible = false


## Escape resumes the game while the menu is open. Runs even when the tree is
## paused because process_mode is ALWAYS; the presenter (pausable) cannot.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.pressed and not key.echo and key.keycode == KEY_ESCAPE:
			continue_pressed.emit()
			get_viewport().set_input_as_handled()


func _on_continue_pressed() -> void:
	continue_pressed.emit()


func _on_exit_to_menu_pressed() -> void:
	exit_to_menu_pressed.emit()
