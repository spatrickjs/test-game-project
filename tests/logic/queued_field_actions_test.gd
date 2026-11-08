extends SceneTree
const GameplayFixture = preload("res://tests/logic/gameplay_test_fixture.gd")
const QueueDriver = preload("res://tests/logic/queued_action_test_driver.gd")
const Kind = SimulationEnums.FieldActionKind
var _failures: PackedStringArray = PackedStringArray()
var _scene: FieldPrototypePresenter
var _farming: FarmingController
var _world: FieldWorldView
var _arrivals: Array[Vector2i] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	_scene = (load("res://field_prototype.tscn") as PackedScene).instantiate() as FieldPrototypePresenter
	# Explicit test layout; authored band order is intentionally configurable.
	_scene.farming_controller.terrain_bands = [SimulationEnums.TerrainType.DRY_SOIL, SimulationEnums.TerrainType.PADDY_MUD, SimulationEnums.TerrainType.GRASS]
	GameplayFixture.prepare(_scene, true)
	root.add_child(_scene)
	GameplayFixture.start(_scene)
	for frame: int in range(5):
		await process_frame
	_farming = _scene.farming_controller
	_world = _scene.world_view
	_check(_world.farmer_agent != null and _world.selection_overlay != null and _scene.water_bucket_button != null, "Saved nodes and HUD bindings")
	_world.farmer_agent.set_process(false)
	_world.farmer_agent.arrived.connect(_record_arrival)
	_check(_world.y_sort_enabled and _world.crop_layer.y_sort_enabled and _world.farmer_agent.z_index == _world.crop_layer.z_index, "Farmer and crops share depth sorting")
	_test_logic()
	_test_transfer()
	_test_gestures()
	if OS.get_cmdline_user_args().has("--capture"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/queued_actions.png")
	_scene.free()
	await process_frame
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	if _failures.is_empty():
		print("QUEUED_FIELD_ACTIONS_PASS")
	quit(0 if _failures.is_empty() else 1)

func _request(kind: SimulationEnums.FieldActionKind, coords: Vector2i, source: Vector2i = Vector2i(-1, -1)) -> FieldAction:
	var action: FieldAction = FieldAction.new()
	action.kind = kind
	action.target = coords
	action.source = source
	action.crop_type = SimulationEnums.CropType.CORN
	return action

func _test_logic() -> void:
	var grass: Vector2i = Vector2i(6, 3)
	var dry: Vector2i = Vector2i(0, 3)
	_world.tuft_spawn_chance = 1.0
	_world.render_grid(_farming.get_grid_snapshot())
	_check(_world.grass_overlay_layer.get_cell_source_id(grass) >= 0, "Grass tuft fixture exists")
	_check(not _farming.enqueue_action(_request(Kind.MAKE_PADDY, grass)), "Grass cannot directly become paddy")
	_check(not _farming.enqueue_action(_request(Kind.DIG_GRASS, dry)), "Digging rejects dry soil")
	_check(not _farming.enqueue_action(_request(Kind.DIG_GRASS, Vector2i(-1, 0))), "Outside field rejected")
	_check(_farming.enqueue_action(_request(Kind.DIG_GRASS, grass)), "Dig queued")
	_check(_farming.get_grid_snapshot().get_cell(grass).terrain_type == SimulationEnums.TerrainType.GRASS, "Enqueue does not mutate terrain")
	_check(not _farming.enqueue_action(_request(Kind.DIG_GRASS, grass)), "Duplicate plot reservation rejected")
	_check(_scene.next_turn_button.disabled and not _scene.turn_controller.advance_turn(), "Queue blocks turns in HUD and Logic")
	var detached: FieldAction = _farming.get_current_action()
	detached.target = dry
	_check(_farming.get_current_action().target == grass, "Task snapshot detached")
	_check(not _farming.arrive_at_action(detached.id + 100, grass), "Outdated arrival ignored")
	_check(QueueDriver.finish(_scene), "Dig walker arrives")
	var cell: FieldCellState = _farming.get_grid_snapshot().get_cell(grass)
	_check(cell.terrain_type == SimulationEnums.TerrainType.DRY_SOIL and cell.soil != null and not cell.has_crop, "Dig commits valid empty soil")
	_check(cell.soil != _farming.initial_soil and cell.soil.moisture == _farming.initial_soil.moisture, "Fresh soil copied from configured defaults")
	_check(_world.grass_overlay_layer.get_cell_source_id(grass) == -1, "Dig removes grass tuft immediately on arrival")
	_check(_world.selection_overlay.queued.is_empty(), "Finished highlight cleared")
	_check(_farming.enqueue_action(_request(Kind.MAKE_PADDY, grass)), "Dug soil can become paddy")
	_check(QueueDriver.finish(_scene), "Bucket walker arrives")
	_check(_farming.get_grid_snapshot().get_cell(grass).terrain_type == SimulationEnums.TerrainType.PADDY_MUD, "Bucket commits paddy")
	_check(_farming.try_plant(dry, SimulationEnums.CropType.CORN), "Occupied fixture")
	_check(not _farming.enqueue_action(_request(Kind.MAKE_PADDY, dry)), "Bucket protects occupied plot")
	_check(_farming.enqueue_action(_request(Kind.REMOVE_CROP, dry)), "Crop removal queued")
	_check(_farming.get_grid_snapshot().get_cell(dry).has_crop, "Crop survives enqueue")
	_check(QueueDriver.finish(_scene), "Shovel walker arrives")
	_check(not _farming.get_grid_snapshot().get_cell(dry).has_crop and _farming.get_grid_snapshot().get_cell(dry).soil != null, "Original crop-removal contract preserved")
	_check(_farming.enqueue_action(_request(Kind.PLANT, dry)), "Plant queued")
	_check(not _farming.get_grid_snapshot().get_cell(dry).has_crop, "Plant remains deferred")
	_check(QueueDriver.finish(_scene), "Plant walker arrives")
	_check(_farming.enqueue_action(_request(Kind.REMOVE_CROP, dry)), "Removal queued before external replacement")
	_farming.remove_crop(dry)
	_farming.try_plant(dry, SimulationEnums.CropType.CORN)
	_check(QueueDriver.finish(_scene), "Stale task is retired")
	_check(_farming.get_grid_snapshot().get_cell(dry).has_crop, "Stale task cannot remove replacement crop")
	_check(_farming.enqueue_action(_request(Kind.DIG_GRASS, Vector2i(7, 3))), "Cancelable task queued")
	_farming.cancel_actions()
	_check(not _farming.has_pending_actions() and _world.selection_overlay.queued.is_empty(), "Cancel clears reservations and highlights")
	_check(_farming.get_grid_snapshot().validate().is_empty(), "Queue mutations preserve structural state")

func _test_transfer() -> void:
	var source: Vector2i = Vector2i(0, 3)
	var target: Vector2i = Vector2i(1, 3)
	_arrivals.clear()
	_check(_farming.enqueue_action(_request(Kind.MOVE_CROP, target, source)), "Transfer queued")
	_check(_world.selection_overlay.queued.has(source) and _world.selection_overlay.queued.has(target), "Both transfer endpoints blink")
	_check(not _farming.enqueue_action(_request(Kind.REMOVE_CROP, source)), "Transfer reserves source")
	_check(not _farming.enqueue_action(_request(Kind.PLANT, target)), "Transfer reserves destination")
	for step: int in range(2000):
		if _farming.get_current_action().source_visited:
			break
		_world.farmer_agent._process(1.0 / 60.0)
	_check(_farming.get_current_action().source_visited, "Source visit precedes delivery")
	_check(_farming.get_grid_snapshot().get_cell(source).has_crop and not _farming.get_grid_snapshot().get_cell(target).has_crop, "Pickup does not partially destroy state")
	_check(QueueDriver.finish(_scene), "Delivery completes")
	_check(_arrivals == [source, target], "Farmer visits source then destination: %s" % str(_arrivals))
	_check(not _farming.get_grid_snapshot().get_cell(source).has_crop and _farming.get_grid_snapshot().get_cell(target).has_crop, "Delivery atomically moves crop")
	_check(_farming.enqueue_action(_request(Kind.MOVE_CROP, source, target)), "Return transfer queued")
	var action: FieldAction = _farming.get_current_action()
	_farming.arrive_at_action(action.id, target)
	_farming.cancel_actions()
	_check(_farming.get_grid_snapshot().get_cell(target).has_crop, "Cancellation after pickup preserves crop")

func _test_gestures() -> void:
	_farming.initialize_field()
	(_scene.get_node("HUD") as CanvasLayer).hide()
	var grass: Vector2i = Vector2i(6, 3)
	var next_grass: Vector2i = Vector2i(7, 3)
	var crop: Vector2i = Vector2i(2, 3)
	_farming.try_plant(crop, SimulationEnums.CropType.CORN)
	_scene._on_remove_pressed()
	_check(_world.selection_overlay.eligible.has(grass) and _world.selection_overlay.eligible.has(crop), "Shovel advertises both contexts")
	var camera_before: Vector2 = _world.camera.global_position
	_mouse(grass, true)
	_drag(next_grass)
	_drag(crop)
	_check(_world.selection_overlay.selected.has(grass) and _world.selection_overlay.selected.has(next_grass) and not _world.selection_overlay.selected.has(crop), "Grass-first drag cannot select crops")
	_check(not _farming.has_pending_actions(), "Drag previews before release")
	_mouse(crop, false)
	_check(_world.camera.global_position == camera_before, "Tool drag never pans camera")
	_check(_farming.get_queued_coordinates().has(grass) and not _farming.get_queued_coordinates().has(crop), "Only matching drag cells queued")
	_check(QueueDriver.finish(_scene), "Multi-dig queue completes")
	_check(_farming.get_grid_snapshot().get_cell(crop).has_crop, "Grass drag preserves crop")
	var remaining_grass: Vector2i = Vector2i(8, 4)
	_mouse(crop, true)
	_drag(remaining_grass)
	_mouse(remaining_grass, false)
	_check(_farming.get_queued_coordinates() == [crop], "Crop-first drag selects only occupied crops")
	_check(QueueDriver.finish(_scene), "Removal drag completes")
	_scene._on_water_bucket_pressed()
	_check(_world.selection_overlay.eligible.has(grass) and not _world.selection_overlay.eligible.has(remaining_grass), "Bucket eligibility excludes grass")
	_mouse(grass, true)
	_drag(next_grass)
	_mouse(next_grass, false)
	_check(QueueDriver.finish(_scene), "Bucket drag completes")
	_check(_farming.get_grid_snapshot().get_cell(grass).terrain_type == SimulationEnums.TerrainType.PADDY_MUD, "Bucket drag converts dug plots")
	_scene._on_remove_pressed()
	_mouse(remaining_grass, true)
	_scene._enter_inspect_mode()
	_mouse(remaining_grass, false)
	_check(not _farming.has_pending_actions() and _world.selection_overlay.selected.is_empty(), "Mode switch cancels selection")
	_scene._on_remove_pressed()
	_mouse(remaining_grass, true)
	_world._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_mouse(remaining_grass, false)
	_check(not _farming.has_pending_actions(), "Focus loss cancels selection")
	_mouse(remaining_grass, true)
	_world._on_ui_input(InputEventMouseMotion.new())
	_mouse(remaining_grass, false)
	_check(not _farming.has_pending_actions(), "GUI consumed gesture cannot enqueue")
	_world.apply_zoom_ratio(1.8)
	camera_before = _world.camera.global_position
	var middle: InputEventMouseButton = InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	middle.position = Vector2(640, 420)
	middle.pressed = true
	_world._unhandled_input(middle)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = middle.position + Vector2(30, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	_world._unhandled_input(motion)
	middle.pressed = false
	_world._unhandled_input(middle)
	_check(_world.camera.global_position != camera_before and not _farming.has_pending_actions(), "Middle mouse pans while tool selected")
	_world.frame_field()
	_touch(0, remaining_grass, true)
	_touch(1, Vector2i(7, 4), true)
	_check(_world.selection_overlay.selected.is_empty(), "Second finger cancels tool selection")
	var touch_drag: InputEventScreenDrag = InputEventScreenDrag.new()
	touch_drag.index = 1
	touch_drag.position = _point(Vector2i(7, 4)) + Vector2(-60, 20)
	_world._unhandled_input(touch_drag)
	_check(_world.camera.zoom.x > _world.min_zoom, "Two-finger zoom remains active while tool selected")
	_touch(1, Vector2i(7, 4), false)
	_touch(0, remaining_grass, false)
	_check(not _farming.has_pending_actions(), "Two-finger camera gesture cannot enqueue")
	_world.frame_field()
	_touch(0, remaining_grass, true)
	touch_drag.index = 0
	touch_drag.position = _point(Vector2i(7, 4))
	_world._unhandled_input(touch_drag)
	_touch(0, Vector2i(7, 4), false)
	_check(_farming.get_queued_coordinates().size() == 2, "Single touch drag selects multiple grass plots")
	_check(QueueDriver.finish(_scene), "Touch queue completes")
	# Diamond vertices must track the actual terrain transform and tile footprint.
	var diamond: PackedVector2Array = _world.selection_overlay.diamond(grass)
	var center: Vector2 = _world.selection_overlay.to_local(_world.terrain_layer.to_global(_world.terrain_layer.map_to_local(grass)))
	_check(diamond.size() == 4 and ((diamond[0] + diamond[2]) * 0.5).is_equal_approx(center), "Highlight snapped to terrain diamond center")
	_scene._on_remove_pressed()
	_scene._select_crop(SimulationEnums.CropType.RICE)
	_mouse(grass, true)
	_mouse(grass, false)
	(_scene.get_node("HUD") as CanvasLayer).show()

func _record_arrival(_id: int, coords: Vector2i) -> void:
	_arrivals.append(coords)
	var center: Vector2 = _world.terrain_layer.to_global(_world.terrain_layer.map_to_local(coords))
	_check(_world.farmer_agent.global_position.distance_to(center) > 1.0, "Agent stands beside target, never at center")

func _point(coords: Vector2i) -> Vector2:
	return _world.terrain_layer.get_global_transform_with_canvas() * _world.terrain_layer.map_to_local(coords)

func _mouse(coords: Vector2i, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = _point(coords)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_world._unhandled_input(event)

func _drag(coords: Vector2i) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = _point(coords)
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	_world._unhandled_input(event)

func _touch(index: int, coords: Vector2i, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = index
	event.position = _point(coords)
	event.pressed = pressed
	_world._unhandled_input(event)

func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)
