extends SceneTree

var failures: PackedStringArray = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var button := Button.new()
	button.position = Vector2(20, 20)
	button.size = Vector2(80, 80)
	button.toggle_mode = true
	button.text = "Tool"
	var feedback := Control.new()
	feedback.set_script(load("res://src/presentation/ui/button_feedback.gd"))
	feedback.set("button", button)
	button.add_child(feedback)
	root.add_child(button)
	await process_frame
	var rect := button.get_global_rect()
	var motion := InputEventMouseMotion.new()
	motion.position = rect.get_center()
	root.push_input(motion, true)
	var down := InputEventMouseButton.new()
	down.position = rect.get_center()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	root.push_input(down, true)
	await process_frame
	feedback.call("_process", 0.1)
	check(feedback.get("_press_amount") == 1.0, "Press feedback follows viewport input")
	check(button.get_global_rect() == rect, "Press preserves input bounds")
	var up := InputEventMouseButton.new()
	up.position = rect.get_center()
	up.button_index = MOUSE_BUTTON_LEFT
	root.push_input(up, true)
	await process_frame
	feedback.call("_process", 0.1)
	check(feedback.get("_press_amount") == 0.0, "Release restores drawing")
	check(feedback.get("_selected"), "Selection indicator follows click")
	button.set_pressed_no_signal(false)
	await process_frame
	check(not feedback.get("_selected"), "Silent selection changes update feedback")
	button.button_down.emit()
	button.disabled = true
	await process_frame
	feedback.call("_process", 0.1)
	check(feedback.get("_press_amount") == 0.0, "Disabled control clears press")
	check(button.material.get_shader_parameter("disabled_amount") == 1.0, "Disabled control is dimmed")
	button.disabled = false
	button.button_down.emit()
	feedback.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	feedback.call("_process", 0.1)
	check(feedback.get("_press_amount") == 0.0, "Focus loss clears press")
	button.free()
	for failure in failures:
		print("FAIL: ", failure)
	print("BUTTON_FEEDBACK_PASS" if failures.is_empty() else "BUTTON_FEEDBACK_FAIL")
	quit(0 if failures.is_empty() else 1)

