class_name AboutUsView
extends Control
## Static informational panel about the Game and its developers.
## Emits back_pressed when the player requests to return to the Main Menu.
## Visibility is toggled by the presenter in response to NavigationController.screen_changed.

signal back_pressed

@export_group("Structure")
@export var info_label: RichTextLabel
@export var back_button: Button


func _ready() -> void:
	if info_label != null:
		info_label.bbcode_enabled = true
	if back_button != null and not back_button.pressed.is_connected(_on_back_pressed):
		back_button.pressed.connect(_on_back_pressed)
	_populate_default_info()


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if info_label == null:
		errors.append("AboutUsView: assign info_label.")
	if back_button == null:
		errors.append("AboutUsView: assign back_button.")
	return errors


## Replaces the displayed text. Expects BBCode when info_label.bbcode_enabled is true.
func set_info_text(text: String) -> void:
	if info_label != null:
		info_label.text = text


func _populate_default_info() -> void:
	if info_label == null:
		return
	info_label.text = _default_info_text()


func _default_info_text() -> String:
	return """[b]Test Game Project[/b]

A turn-based farming simulation prototype built with Godot 4.7.

[b]Features[/b]
- Isometric tile-based field management
- Crop planting, growth, and harvesting
- Soil nutrient and moisture modeling
- Disease spread simulation (SIR, SEIR, and cellular automata models)
- Multiple algorithm overrides for disease modeling

[b]Developers[/b]
This game is developed as a test project exploring the four-layer
architecture (Data, Simulation, Logic, Presentation) for game development.

Built with Godot 4.7.2 using typed GDScript."""


func _on_back_pressed() -> void:
	back_pressed.emit()
