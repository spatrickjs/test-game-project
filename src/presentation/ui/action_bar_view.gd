class_name ActionBarView
extends Control
## Displays the action bar: remaining of maximum. Never mutates the authoritative bar.
## Connect to FarmingController.actions_remaining_changed to update the display.

@export var action_bar_label: Label


func _ready() -> void:
	if action_bar_label != null:
		action_bar_label.text = "Actions: 0 / 0"


func validate_configuration() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if action_bar_label == null:
		errors.append("ActionBarView: assign action_bar_label.")
	return errors


func set_counts(remaining: int, max: int) -> void:
	if action_bar_label != null:
		action_bar_label.text = "Actions: %d / %d" % [remaining, max]
