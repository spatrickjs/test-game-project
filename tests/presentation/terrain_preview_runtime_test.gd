extends SceneTree
var _failures: PackedStringArray = PackedStringArray()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	root.add_child(scene)
	for frame: int in range(5):
		await process_frame
	var preview: FieldTerrainPreview = scene.get_node("World/TerrainPreview") as FieldTerrainPreview
	_check(not preview.is_processing(), "Preview processing disabled in gameplay")
	preview.refresh_preview()
	_check(preview.get_preview_cell_count() == 0 and preview.get_child_count(true) == 0, "No preview layer exists at runtime")
	_check(scene.farming_controller.is_initialized(), "Normal gameplay initializes")
	var field_size: Vector2i = scene.farming_controller.field_size
	_check(scene.world_view.terrain_layer.get_used_cells().size() == field_size.x * field_size.y, "Runtime still paints the complete field")
	scene.queue_free()
	await process_frame
	if _failures.is_empty():
		print("TERRAIN_PREVIEW_RUNTIME_PASS")
		quit(0)
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
