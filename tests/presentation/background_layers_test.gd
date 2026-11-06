extends SceneTree
var _failures: PackedStringArray = PackedStringArray()
var _clicks: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	var scene: FieldPrototypePresenter = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	root.add_child(scene)
	for frame: int in range(5):
		await process_frame
	var world: FieldWorldView = scene.world_view
	var painted: TileMapLayer = world.background_terrain_layer
	var decorations: TileMapLayer = world.background_decorations
	var automatic: TileMapLayer = world.background_fill_layer
	_check(scene.farming_controller.field_size == Vector2i(9, 9), "Saved playable field is 9 by 9")
	_check(not world.automatic_background_enabled, "Saved scene uses manual scenery")
	_check(automatic == null and world.get_node_or_null("AutomaticGrassBackground") == null, "Unused automatic grass node removed from manual scene")
	automatic = TileMapLayer.new()
	world.add_child(automatic)
	world.background_fill_layer = automatic
	world.automatic_background_enabled = true # Preserve opt-in fill regression coverage.
	world.frame_field()
	_check(painted != null and decorations != null and automatic != null, "Separate layers saved and wired")
	if painted == null or decorations == null or automatic == null:
		scene.free()
		_finish()
		return
	_check(painted.owner == scene and decorations.owner == scene, "Authored layers belong to the scene")
	_check(painted.tile_set != world.terrain_layer.tile_set and decorations.tile_set != painted.tile_set, "Editable TileSets are independent")
	_check(painted.tile_set.get_source(0) != world.terrain_layer.tile_set.get_source(0), "Editable atlas definitions are independent")
	_check(automatic.z_index == painted.z_index and painted.z_index == world.terrain_layer.z_index and decorations.z_index > painted.z_index, "Thick ground tiles share Y-sort tier, props draw above ground")
	var outside: Vector2i = Vector2i(-2, 0)
	painted.set_cell(outside, 0, Vector2i.ZERO)
	decorations.set_cell(Vector2i(-2, 1), 0, Vector2i.ZERO)
	var prop: Node2D = Node2D.new()
	prop.name = "AuthoredProp"
	decorations.add_child(prop)
	prop.owner = scene
	prop.position = Vector2(13, 27)
	var grid: FieldGridState = scene.farming_controller.get_grid_snapshot()
	world.render_grid(grid)
	world.camera_center_offset = Vector2(300, -150)
	world.frame_field()
	_check(painted.get_cell_source_id(outside) == 0 and decorations.get_cell_source_id(Vector2i(-2, 1)) == 0, "Rendering and framing preserve painted scenery")
	_check(automatic.get_cell_source_id(outside) == -1, "Authored terrain replaces automatic grass without stacked duplicate tiles")
	_check(prop.position == Vector2(13, 27), "Rendering preserves authored prop transforms")
	_check(world.terrain_layer.get_used_cells().size() == grid.width * grid.height, "Playable Terrain contains only logical field cells")
	_check(automatic.get_used_cells().size() > 0 and automatic.get_cell_source_id(Vector2i.ZERO) == -1, "Generated grass stays outside playable grid")
	world.cell_clicked.connect(func(_coords: Vector2i) -> void: _clicks += 1)
	world._emit_cell_at(world.terrain_layer.get_global_transform_with_canvas() * world.terrain_layer.map_to_local(outside))
	_check(_clicks == 0 and scene.farming_controller.get_grid_snapshot().get_cell(outside) == null, "Authored background is not a playable target")
	# Save and reload through Godot serialization; never alter the real scene.
	var packed: PackedScene = PackedScene.new()
	world.background_fill_layer = null # Temporary test fixture is not scene-owned.
	_check(packed.pack(scene) == OK, "Pack authored scenery")
	_check(ResourceSaver.save(packed, "res://.godot/background_roundtrip.tscn") == OK, "Serialize authored scenery")
	var restored: FieldPrototypePresenter = (ResourceLoader.load("res://.godot/background_roundtrip.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as FieldPrototypePresenter
	_check(restored.world_view.background_terrain_layer.get_cell_source_id(outside) == 0, "Painted terrain survives scene reload")
	_check(restored.world_view.background_decorations.get_node("AuthoredProp").position == Vector2(13, 27), "Placed props survive scene reload")
	restored.free()
	world.background_fill_layer = painted
	world._render_cosmetic_border(grid)
	_check(painted.get_cell_source_id(outside) == 0, "Misassigned fill reference never erases authored background")
	world.background_fill_layer = automatic
	scene.free()
	await process_frame
	_finish()

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _finish() -> void:
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("BACKGROUND_LAYERS_PASS")
	quit(0 if _failures.is_empty() else 1)
