@tool
extends EditorScript
## Adds only the inoculation control; preserves existing authored UI and terrain.
func run_setup() -> int:
	var tree: SceneTree = EditorInterface.get_base_control().get_tree()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await tree.process_frame
	EditorInterface.open_scene_from_path("res://field_prototype.tscn")
	for frame: int in range(5):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	if scene == null or scene.scene_file_path != "res://field_prototype.tscn":
		push_error("Open the field scene before inoculation setup.")
		return 1
	var button: Button = scene.get("inoculate_button") as Button
	if button == null:
		var anchor: Button = scene.get("water_bucket_button") as Button
		if anchor == null:
			push_error("Assign the existing Water Bucket button first.")
			return 1
		button = Button.new()
		button.name = "InoculateButton"
		button.set_script(load("res://src/presentation/ui/camera_zoom_button.gd"))
		anchor.get_parent().add_child(button)
		button.owner = scene
		button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		button.custom_minimum_size = Vector2(132, 48)
		button.mouse_force_pass_scroll_events = false
		button.text = "Inoculate"
		button.toggle_mode = true
		scene.set("inoculate_button", button)
	button.offset_left = -206.0
	button.offset_right = -74.0
	button.offset_top = -51.0
	button.offset_bottom = -3.0
	scene.set("inoculation_cursor", load("res://assets/inoculation_cursor.svg"))
	EditorInterface.mark_scene_as_unsaved()
	var error: Error = EditorInterface.save_scene()
	if error != OK:
		push_error("Unable to save inoculation scene wiring.")
		return 1
	return 0
