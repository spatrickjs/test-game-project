class_name MainMenuView
extends Control
## Main Menu navigation buttons. Forwards button presses as signals; owns no
## navigation state. Assign every button reference below in the Inspector.

signal settings_pressed
signal about_us_pressed
signal play_pressed
signal exit_pressed

@export_group("Navigation Buttons")
## Opens the Settings panel. Visible by default after the Game loads.
@export var settings_button: Button
## Opens the About Us panel. Visible by default after the Game loads.
@export var about_us_button: Button
## Opens the Play menu. Visible by default after the Game loads.
@export var play_button: Button
## Requests game exit (opens the exit confirmation dialog). Visible by default.
@export var exit_button: Button


func _ready() -> void:
	if settings_button != null and not settings_button.pressed.is_connected(_on_settings_pressed):
		settings_button.pressed.connect(_on_settings_pressed)
	if about_us_button != null and not about_us_button.pressed.is_connected(_on_about_us_pressed):
		about_us_button.pressed.connect(_on_about_us_pressed)
	if play_button != null and not play_button.pressed.is_connected(_on_play_pressed):
		play_button.pressed.connect(_on_play_pressed)
	if exit_button != null and not exit_button.pressed.is_connected(_on_exit_pressed):
		exit_button.pressed.connect(_on_exit_pressed)
	# The Main Menu is the entry screen; ensure it is visible after the Game loads.
	show()


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if settings_button == null:
		errors.append("MainMenuView: assign settings_button.")
	if about_us_button == null:
		errors.append("MainMenuView: assign about_us_button.")
	if play_button == null:
		errors.append("MainMenuView: assign play_button.")
	if exit_button == null:
		errors.append("MainMenuView: assign exit_button.")
	return errors


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _on_about_us_pressed() -> void:
	about_us_pressed.emit()


func _on_play_pressed() -> void:
	play_pressed.emit()


func _on_exit_pressed() -> void:
	exit_pressed.emit()
