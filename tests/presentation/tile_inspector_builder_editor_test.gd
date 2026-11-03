@tool
extends RefCounted
## Invoked by the gated editor plugin, never via --editor --script.

const Builder: Script = preload("res://src/presentation/ui/inspectors/build_tile_inspector_scene.gd")
var _failures: PackedStringArray = PackedStringArray()


func run(tree: SceneTree) -> int:
	for frame: int in range(10):
		await tree.process_frame
	EditorInterface.open_scene_from_path("res://field_prototype.tscn")
	for frame: int in range(10):
		await tree.process_frame
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if scene_root == null:
		printerr("BUILDER_TEST_FAIL: no edited scene")
		return 1
	var had_panel: bool = scene_root.has_node(^"HUD/TileInspectorPanel")
	var previous_binding: Node = scene_root.get("tile_inspector") as Node
	var builder: EditorScript = Builder.new() as EditorScript
	builder._run()
	var panel: Node = scene_root.get_node_or_null(^"HUD/TileInspectorPanel")
	if panel == null:
		printerr("BUILDER_TEST_FAIL: panel was not created")
		return 1
	_check_bindings(scene_root, panel)
	var count_before: int = panel.find_children("*", "", true, false).size()
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(scene_root))
	_check(history != null, "Undo history exists")
	if history != null:
		history.undo()
		if not had_panel:
			_check(not scene_root.has_node(^"HUD/TileInspectorPanel"), "Undo removes created panel")
		_check(scene_root.get("tile_inspector") == previous_binding, "Undo restores presenter binding")
		history.redo()
		panel = scene_root.get_node_or_null(^"HUD/TileInspectorPanel")
		_check(panel != null, "Redo restores panel")
		if panel != null:
			_check_bindings(scene_root, panel)
	builder._run()
	panel = scene_root.get_node_or_null(^"HUD/TileInspectorPanel")
	_check(panel.find_children("*", "", true, false).size() == count_before, "Rerun does not duplicate nodes")
	_check_bindings(scene_root, panel)
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(scene_root) == OK, "Godot can pack the owned scene tree")
	var instance: Node = packed.instantiate()
	var saved_panel: Node = instance.get_node_or_null(^"HUD/TileInspectorPanel")
	_check(saved_panel != null, "Inspector survives in-memory scene round trip")
	if saved_panel != null:
		_check_bindings(instance, saved_panel)
	instance.free()
	# Exercise the missing-HUD path without changing the saved user scene.
	var old_hud: Node = scene_root.get_node(^"HUD")
	scene_root.remove_child(old_hud)
	scene_root.set("tile_inspector", null)
	for property_name: StringName in Builder.HUD_BINDINGS:
		scene_root.set(property_name, null)
	builder._run()
	panel = scene_root.get_node(^"HUD/TileInspectorPanel")
	_check_bindings(scene_root, panel)
	_check(bool(panel.get("visible")), "Inspector visible for editor authoring")
	var rebuilt: PackedScene = PackedScene.new()
	_check(rebuilt.pack(scene_root) == OK, "New HUD packs with ownership")
	var rebuilt_instance: Node = rebuilt.instantiate()
	_check_bindings(rebuilt_instance, rebuilt_instance.get_node(^"HUD/TileInspectorPanel"))
	rebuilt_instance.free()
	# Release undo references before freeing the detached original HUD.
	if history != null:
		history.clear_history()
	old_hud.free()
	# Let deferred editor UI updates and queued deletions finish before shutdown.
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(null)
	for frame: int in range(5):
		await tree.process_frame
	if _failures.is_empty():
		print("TILE_INSPECTOR_BUILDER_EDITOR_PASS")
	else:
		for failure: String in _failures:
			printerr("BUILDER_TEST_FAIL: " + failure)
	# No ResourceSaver.save(), save_scene(), or raw scene output.
	return 0 if _failures.is_empty() else 1


func _check_bindings(scene_root: Node, panel: Node) -> void:
	for property_name: StringName in Builder.HUD_BINDINGS:
		_check(scene_root.get(property_name) == scene_root.get_node(Builder.HUD_BINDINGS[property_name]), "HUD binding: %s" % property_name)
	_check(scene_root.get("tile_inspector") == panel, "Presenter points to panel")
	_check(panel.get_script() == Builder.VIEW_SCRIPT, "View script attached")
	for property_name: StringName in Builder.BINDINGS:
		var bound: Node = panel.get(property_name) as Node
		_check(bound == scene_root.get_node(Builder.BINDINGS[property_name]), "Binding: %s" % property_name)
	for path: String in Builder.NODE_TYPES:
		_check(scene_root.get_node(NodePath(path)).owner == scene_root, "Scene owner: %s" % path)


func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
