@tool
extends RefCounted
var _failures: PackedStringArray = PackedStringArray()

func run(tree: SceneTree) -> int:
	for frame: int in range(10):
		await tree.process_frame
	EditorInterface.open_scene_from_path("res://field_prototype.tscn")
	for frame: int in range(10):
		await tree.process_frame
	var scene: Node = EditorInterface.get_edited_scene_root()
	var preview: FieldTerrainPreview = scene.get_node("World/TerrainPreview") as FieldTerrainPreview
	var configuration: Node = scene.get("farming_controller") as Node
	var world: Node = scene.get("world_view") as Node
	var terrain: TileMapLayer = world.get("terrain_layer") as TileMapLayer
	var original_cells: Array[Vector2i] = terrain.get_used_cells()
	var original_size: Vector2i = configuration.get("field_size")
	var original_bands: Array = configuration.get("terrain_bands")
	preview.refresh_preview()
	_check(preview.last_error.is_empty(), "Valid scene preview")
	_check(preview.get_preview_cell_count() == original_size.x * original_size.y, "Configured field appears in editor")
	var generated: TileMapLayer = preview.get("_preview_layer") as TileMapLayer
	_check(generated != null and generated.owner == null, "Generated layer is transient")
	var mapping: TerrainTileVisualMap = world.get("visual_map") as TerrainTileVisualMap
	for x: int in range(original_size.x):
		var band_index: int = mini(floori(float(x) * float(original_bands.size()) / float(original_size.x)), original_bands.size() - 1)
		var visual: TerrainTileVisual = mapping.get_visual(original_bands[band_index])
		_check(generated.get_cell_source_id(Vector2i(x, 0)) == visual.source_id, "Preview follows runtime band/source mapping")
	configuration.set("field_size", Vector2i(4, 3))
	await tree.create_timer(0.4).timeout
	_check(preview.get_preview_cell_count() == 12, "Inspector changes refresh automatically")
	preview.preview_enabled = false
	preview.refresh_preview()
	_check(preview.get_preview_cell_count() == 0, "Preview can be disabled")
	preview.preview_enabled = true
	configuration.set("field_size", Vector2i(-1, 3))
	preview.refresh_preview()
	_check(not preview.last_error.is_empty() and preview.get_preview_cell_count() == 0, "Invalid config clears preview and reports diagnostic")
	configuration.set("field_size", Vector2i(10001, 1))
	preview.refresh_preview()
	_check(preview.last_error.contains("10,000"), "Huge preview safely bounded")
	configuration.set("field_size", original_size)
	preview.refresh_preview()
	preview.refresh_preview()
	_check(preview.get_child_count(true) == 1, "Repeated refresh does not duplicate layers")
	_check(terrain.get_used_cells() == original_cells, "Runtime terrain layer remains untouched")
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(scene) == OK, "Preview-equipped scene packs")
	var state: SceneState = packed.get_state()
	for index: int in range(state.get_node_count()):
		_check(state.get_node_name(index) != &"GeneratedTerrainPreview", "Generated tile layer is not serialized")
	var instance: Node = packed.instantiate()
	_check(instance.get_node("World/TerrainPreview").get_child_count(true) == 0, "Packed scene has no generated preview cells")
	instance.free()
	EditorInterface.get_selection().clear()
	EditorInterface.edit_node(null)
	for frame: int in range(5):
		await tree.process_frame
	if _failures.is_empty():
		print("TERRAIN_PREVIEW_EDITOR_PASS")
	else:
		for failure: String in _failures:
			printerr("FAIL: " + failure)
	return 0 if _failures.is_empty() else 1

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
