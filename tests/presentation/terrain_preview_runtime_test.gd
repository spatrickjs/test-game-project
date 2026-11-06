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
	for y: int in range(field_size.y):
		for x: int in range(field_size.x):
			_check(scene.world_view.terrain_layer.get_cell_source_id(Vector2i(x, y)) >= 0, "Runtime paints every logical field tile, with optional cosmetic border")
	var terrain: TileMapLayer = scene.world_view.terrain_layer
	var crops: TileMapLayer = scene.world_view.crop_layer
	for coordinates: Vector2i in terrain.get_used_cells():
		_check(terrain.to_global(terrain.map_to_local(coordinates)).is_equal_approx(crops.to_global(crops.map_to_local(coordinates))), "Crop roots share terrain cell centers")
	var original_crop_tiles: TileSet = crops.tile_set
	var original_size: Vector2i = original_crop_tiles.tile_size
	terrain.tile_set = terrain.tile_set.duplicate() as TileSet
	terrain.tile_set.tile_size = Vector2i(160, 80)
	terrain.position = Vector2(17, 29)
	scene.world_view._align_crop_grid()
	_check(original_crop_tiles.tile_size == original_size, "Alignment preserves shared crop resource")
	for coordinates: Vector2i in [Vector2i.ZERO, Vector2i(8, 8), Vector2i(2, 7)]:
		_check(terrain.to_global(terrain.map_to_local(coordinates)).is_equal_approx(crops.to_global(crops.map_to_local(coordinates))), "Crop alignment follows changed terrain dimensions and transform")
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
